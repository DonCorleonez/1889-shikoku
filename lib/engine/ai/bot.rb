# frozen_string_literal: true

require_relative '../auto_router'

module Engine
  module AI
    # A heuristic computer player with three difficulty levels.
    #
    # The bot never mutates the game itself. It inspects the current step and
    # returns an ordered list of candidate actions; Engine::AI::Driver tries
    # them in order until the engine accepts one. Anything the bot does not
    # understand falls back to passing, and if even that is impossible the
    # driver gives up so a human can take over the seat.
    #
    # - easy:   legal but loose play (greedy routes, random track, timid stock play)
    # - normal: sensible defaults (best routes, track toward revenue, backs its own companies)
    # - hard:   plays for final net worth: values shares by expected dividends, sells weak
    #           holdings, defends and steals presidencies, times train purchases around
    #           rusting, withholds only when a train is needed, and sells its privates to
    #           its own companies at the highest allowed price
    class Bot
      LEVELS = %i[easy normal hard].freeze
      MAX_TILE_CANDIDATES = 6
      MAX_ROUTES_PER_TRAIN = 40
      ROUTE_SEARCH_WIDTH = 12
      ROUTE_SEARCH_EVALS = 300

      attr_reader :game, :entity, :level

      def self.level(name)
        LEVELS.find { |l| l.to_s == name.to_s } || :normal
      end

      def initialize(game, entity, level: :normal)
        @game = game
        @entity = entity
        @level = self.class.level(level)
        @step = game.round.active_step
      end

      def candidates
        actions = @game.round.actions_for(@entity) || []
        return [] if actions.empty?
        # Private companies' special abilities are optional; the bot declines them.
        return actions.include?('pass') ? [Engine::Action::Pass.new(@entity)] : [] if @entity.company?

        list = []
        list.concat(discard_train_candidates) if actions.include?('discard_train')
        list.concat(run_routes_candidates) if actions.include?('run_routes')
        list.concat(dividend_candidates) if actions.include?('dividend')
        list.concat(lay_tile_candidates) if actions.include?('lay_tile')
        list.concat(place_token_candidates) if actions.include?('place_token')
        if actions.include?('buy_train')
          list.concat(buy_train_candidates)
          # The president raises cash by selling as a player, so 'sell_shares' isn't in the corporation's actions.
          list.concat(player_sell_candidates) if !actions.include?('sell_shares') && must_buy_train?
        end
        list.concat(buy_company_candidates) if actions.include?('buy_company') && hard?
        list.concat(bid_candidates) if actions.include?('bid')
        list.concat(voluntary_sell_candidates) if actions.include?('sell_shares') && actions.include?('pass') && hard?
        list.concat(par_candidates) if actions.include?('par')
        list.concat(buy_shares_candidates) if actions.include?('buy_shares')
        list.concat(choose_candidates) if actions.include?('choose')
        list << Engine::Action::Pass.new(@entity) if actions.include?('pass')
        list.concat(sell_shares_candidates(forced: !actions.include?('pass'))) if actions.include?('sell_shares')
        # Only ever declare bankruptcy when the rules force a train purchase we can't fund.
        list << Engine::Action::Bankrupt.new(@entity) if actions.include?('bankrupt') && must_buy_train?
        list.compact
      end

      private

      def easy?
        @level == :easy
      end

      def hard?
        @level == :hard
      end

      def player
        @entity.player? ? @entity : @entity.player
      end

      def safe
        yield
      rescue StandardError => e
        LOGGER.debug { "AI: #{e.class}: #{e.message}" }
        nil
      end

      # ---- Operating round ------------------------------------------------

      def discard_train_candidates
        corps = @step.respond_to?(:crowded_corps) ? @step.crowded_corps : [@entity]
        corp = corps.find { |c| c.owner == player || c == @entity } || corps.first
        return [] unless corp

        corp.trains.sort_by(&:price).map { |t| Engine::Action::DiscardTrain.new(corp, train: t) }
      end

      def run_routes_candidates
        routes = safe { best_routes } || []
        [
          (unless routes.empty?
             Engine::Action::RunRoutes.new(
               @entity,
               routes: routes,
               extra_revenue: @game.extra_revenue(@entity, routes),
               subsidy: @game.routes_subsidy(routes),
             )
           end),
          Engine::Action::RunRoutes.new(@entity, routes: []),
        ].compact
      end

      # Route selection on top of the auto-router's path search (which is pure
      # Ruby; the browser's combination search is JavaScript). Easy picks
      # greedily; normal and hard run a bounded branch-and-bound search over
      # the best few routes of each train.
      def best_routes
        router = Engine::AutoRouter.new(@game)
        trains = @game.route_trains(@entity).sort_by(&:price)
        return [] if trains.empty?

        train_routes, = router.path(trains, @entity, path_timeout: 5, route_limit: MAX_ROUTES_PER_TRAIN)
        lists = train_routes.keys.sort_by { |t| -t.price }.map { |t| train_routes[t] }.reject(&:empty?)
        chosen = easy? ? greedy_routes(router, lists) : search_routes(router, lists)
        router.real_revenue(chosen) # leaves each route's cached state consistent with the final set
        chosen
      end

      def greedy_routes(router, lists)
        chosen = []
        lists.each do |routes|
          routes.each do |route|
            next if chosen.any? { |r| bitfield_conflict?(r.bitfield, route.bitfield) }

            trial = chosen + [route]
            next if router.real_revenue(trial).negative?

            chosen = trial
            break
          end
        end
        chosen
      end

      def search_routes(router, lists)
        lists = lists.map { |routes| routes.first(ROUTE_SEARCH_WIDTH) }
        # Revenue on its own, captured before combination checks touch the route caches.
        solo = lists.flatten.to_h { |r| [r, r.revenue] }
        bound = Array.new(lists.size + 1, 0)
        (lists.size - 1).downto(0) { |i| bound[i] = bound[i + 1] + solo[lists[i].first] }

        best = greedy_routes(router, lists)
        best_revenue = best.empty? ? 0 : router.real_revenue(best)
        evals = 0
        chosen = []

        search = lambda do |i, estimate|
          return if evals >= ROUTE_SEARCH_EVALS || estimate + bound[i] <= best_revenue

          if i == lists.size
            evals += 1
            revenue = router.real_revenue(chosen)
            if revenue > best_revenue
              best_revenue = revenue
              best = chosen.dup
            end
            return
          end

          lists[i].each do |route|
            break if estimate + solo[route] + bound[i + 1] <= best_revenue
            next if chosen.any? { |r| bitfield_conflict?(r.bitfield, route.bitfield) }

            chosen << route
            search.call(i + 1, estimate + solo[route])
            chosen.pop
          end
          search.call(i + 1, estimate) # this train sits out
        end
        search.call(0, 0)
        best
      end

      def bitfield_conflict?(a, b)
        a.each_with_index.any? { |v, i| b[i] && (v & b[i]) != 0 }
      end

      def dividend_candidates
        options = safe { @step.dividend_options(@entity) } || {}
        kinds = options.keys.map(&:to_s)
        kinds = Array(@step.dividend_types).map(&:to_s) if kinds.empty?
        preferred = hard? && withhold_for_train? ? %w[withhold half payout] : %w[payout half withhold]
        ordered = preferred.select { |k| kinds.include?(k) } + (kinds - preferred)
        ordered.map { |k| Engine::Action::Dividend.new(@entity, kind: k) }
      end

      # Keep the money when the company has to buy a train soon and can't pay for it,
      # so the president isn't forced to fund it.
      def withhold_for_train?
        return false if final_operating_rounds?

        next_train = depot_train
        return false unless next_train

        revenue = safe { @step.total_revenue } || 0
        doomed = @entity.trains.all? { |t| rusts_by?(t, next_train) }
        short = @entity.cash < next_train.price
        doomed && short && (@entity.cash + revenue >= next_train.price * 0.6 || @entity.trains.empty?)
      end

      def final_operating_rounds?
        bank = safe { @game.bank.cash } || 1_000_000
        start = safe { @game.class::BANK_CASH } || 1
        bank < start * 0.12
      end

      def lay_tile_candidates
        options = []
        lay = safe { @step.get_tile_lay(@entity) }
        targets = easy? ? [] : revenue_targets
        @game.hexes.each do |hex|
          next unless safe { @step.available_hex(@entity, hex) }

          upgrade = hex.tile.color != :white
          next if lay && !(upgrade ? lay[:upgrade] : lay[:lay])

          tiles = safe { @step.upgradeable_tiles(@entity, hex) } || []
          tiles.each do |tile|
            cost = safe { @game.upgrade_cost(hex.tile, hex, @entity, @entity) } || 0
            next if cost > @entity.cash
            next if hard? && cost.positive? && @entity.cash - cost < train_reserve

            Array(tile.legal_rotations).each do |rotation|
              tile.rotate!(rotation)
              options << [tile_score(hex, tile, cost, targets), hex, tile, rotation]
            end
          end
        end

        if easy?
          options.shuffle!
        else
          options.sort_by! { |score, *| -score }
        end
        options.first(MAX_TILE_CANDIDATES).map do |_, hex, tile, rotation|
          tile.rotate!(rotation)
          Engine::Action::LayTile.new(@entity, tile: tile, hex: hex, rotation: rotation)
        end
      end

      def tile_score(hex, tile, cost, targets)
        revenue = tile.cities.sum { |c| safe { c.max_revenue } || 0 } +
                  tile.towns.sum { |t| safe { t.max_revenue } || 0 }
        old_revenue = hex.tile.cities.sum { |c| safe { c.max_revenue } || 0 } +
                      hex.tile.towns.sum { |t| safe { t.max_revenue } || 0 }
        own_token = hex.tile.cities.any? { |c| c.tokened_by?(@entity) } ? 30 : 0
        upgrade = hex.tile.color == :white ? 0 : 15
        score = (revenue - old_revenue) + own_token + upgrade + (tile.exits.size * 2) - (cost / 4)
        score += reach_score(hex, tile, targets) unless targets.empty?
        score + rand(hard? ? 3 : 10)
      end

      # Revenue locations this company can't reach yet, with their value.
      def revenue_targets
        reached = safe { @game.graph_for_entity(@entity).connected_nodes(@entity) } || {}
        @game.hexes.flat_map do |hex|
          hex.tile.nodes.select { |n| n.city? || n.offboard? || n.town? }.filter_map do |node|
            next if reached[node]

            value = safe { node.max_revenue } || 0
            [hex, value] if value.positive?
          end
        end
      end

      # Reward new exits that point toward valuable unreached revenue.
      def reach_score(hex, tile, targets)
        new_exits = tile.exits - hex.tile.exits
        return 0 if new_exits.empty?

        new_exits.sum do |edge|
          neighbor = hex.neighbors[edge]
          next 0 unless neighbor

          targets.sum do |target, value|
            here = hex_distance(hex, target)
            there = hex_distance(neighbor, target)
            there < here ? value.to_f / (there + 1) : 0
          end
        end.round
      end

      # Hex distance on the doubled-coordinate grid 18xx maps use.
      def hex_distance(a, b)
        dx = (a.x - b.x).abs
        dy = (a.y - b.y).abs
        @game.layout == :flat ? dx + [0, (dy - dx) / 2].max : dy + [0, (dx - dy) / 2].max
      end

      def place_token_candidates
        tokens = safe { @step.available_tokens(@entity) } || []
        return [] if tokens.empty?

        token = tokens.first
        price = token.price || 0
        reserve = @entity.respond_to?(:trains) && @entity.trains.empty? ? (safe { @game.depot.min_depot_price } || 0) : 0
        reserve = [reserve, train_reserve].max if hard?
        return [] if !home_token_step? && @entity.cash - price < reserve
        return [] if easy? && !home_token_step? && rand < 0.5

        cities = []
        @game.hexes.each do |hex|
          next unless safe { @step.available_hex(@entity, hex) }

          hex.tile.cities.each do |city|
            next unless safe { city.tokenable?(@entity, tokens: tokens, free: home_token_step?) }

            cities << city
          end
        end

        cities.sort_by { |c| -token_score(c) }.first(4).map do |city|
          Engine::Action::PlaceToken.new(
            @entity,
            city: city,
            slot: city.get_slot(@entity),
            tokener: @game.token_owner(@entity),
            token_type: token.type,
          )
        end
      end

      def token_score(city)
        score = (safe { city.max_revenue } || 0) + rand(5)
        return score unless hard?

        # Taking the last free slot blocks rivals from running through.
        free = city.slots - city.tokens.compact.size
        score += 25 if free == 1
        score + (city.tile.exits.size * 3)
      end

      def home_token_step?
        @step.is_a?(Engine::Step::HomeToken)
      end

      def must_buy_train?
        !!safe { @step.must_buy_train?(@entity) }
      end

      # ---- Trains ----------------------------------------------------------

      def depot_train
        safe { @game.depot.min_depot_train }
      end

      def rusts_by?(train, new_train)
        !train.rusts_on.nil? && train.rusts_on == new_train.name
      end

      def rusts_soon?(train)
        upcoming = Array(@game.depot.upcoming).map(&:name).uniq.first(2)
        !train.rusts_on.nil? && upcoming.include?(train.rusts_on)
      end

      # Cash to keep for the next train when the current ones are about to rust.
      def train_reserve
        return 0 unless @entity.corporation?

        next_train = depot_train
        return 0 unless next_train
        # all? is true for an empty fleet too
        return 0 unless @entity.trains.all? { |t| rusts_by?(t, next_train) }

        next_train.price
      end

      # Trains [ours, rivals'] that buying this train would rust (if it's the first of its type).
      def rust_balance(train)
        return [0, 0] if @game.corporations.any? { |c| c.trains.any? { |t| t.name == train.name } }

        mine = 0
        theirs = 0
        @game.corporations.each do |corp|
          lost = corp.trains.count { |t| rusts_by?(t, train) }
          next if lost.zero?

          corp.owner == player ? mine += lost : theirs += lost
        end
        [mine, theirs]
      end

      def buy_train_candidates
        must = must_buy_train?
        room = safe { @step.room?(@entity) }
        return [] unless room

        trains = (safe { @step.buyable_trains(@entity) } || []).select { |t| t.owner == @game.depot }
        offers = trains.flat_map do |train|
          variants = safe { @step.buyable_train_variants(train, @entity) } || [{ name: train.name, price: train.price }]
          variants.map { |v| [train, v[:name], v[:price]] }
        end
        offers.sort_by! { |_, _, price| price }

        if must
          # Stuck without a train: also take one from another of the president's own companies, as cheaply as allowed.
          own_others = (safe { @step.buyable_trains(@entity) } || []).select do |t|
            t.owner != @game.depot && t.owner != @entity && t.owner.respond_to?(:owner) && t.owner.owner == player
          end
          own_others.sort_by(&:price).first(2).each do |train|
            min_price = (safe { @step.spend_minmax(@entity, train) } || [1]).first
            offers << [train, train.name, [min_price, 1].max]
          end
        end
        return [] if offers.empty?

        offers = optional_train_offers(offers) unless must
        offers.first(3).map do |train, variant, price|
          Engine::Action::BuyTrain.new(@entity, train: train, price: price, variant: variant)
        end
      end

      def optional_train_offers(offers)
        trains_owned = @game.num_corp_trains(@entity)
        affordable = offers.select { |_, _, price| price <= @entity.cash }
        return [] if affordable.empty?
        return trains_owned.zero? ? affordable.first(1) : [] if easy?
        return trains_owned.zero? ? affordable : affordable.last(1).reverse unless hard?
        return affordable.reverse if trains_owned.zero?

        train, = affordable.last
        mine, theirs = rust_balance(train)
        doomed = @entity.trains.all? { |t| rusts_by?(t, train) || rusts_soon?(t) }
        # Rush a phase change when it hurts rivals more than us, upgrade before our own
        # trains rust, and otherwise only add trains that don't wipe out our own fleet.
        good = theirs > mine || doomed || (mine.zero? && @entity.trains.size < 2)
        good ? affordable.last(1).reverse : []
      end

      # Hard: move money from the company to its president by buying the president's privates at full price.
      def buy_company_candidates
        return [] unless @entity.corporation?

        spare = @entity.cash - train_reserve
        player.companies.reject(&:closed?).sort_by { |c| -c.value }.filter_map do |company|
          max = safe { company.max_price(@entity) } || company.value
          price = [max, spare].min
          next if price < (company.min_price || 1) || price < company.value

          Engine::Action::BuyCompany.new(@entity, company: company, price: price)
        end.first(2)
      end

      # ---- Private auctions -----------------------------------------------

      def bid_candidates
        items = Array(safe { @step.respond_to?(:available) ? @step.available : [] })
        items = items.select { |i| bid_target_key(i) }
        return [] if items.empty?

        # Drafts (e.g. 1846, 18Mag) use bids to pick an item; the price is ignored.
        if items.any? { |i| safe { @step.may_choose?(i) } }
          return items.sample(2).map { |i| bid(i, safe { @step.min_bid(i) } || 0) }
        end

        # Keep cash for shares, but a bot that owns nothing yet takes the cheapest
        # thing it can afford so all-pass auctions can't loop forever.
        owns_nothing = player.companies.empty? && @game.minors.none? { |m| m.owner == player }
        priced = items.map { |i| [i, safe { @step.min_bid(i) }] }.select { |_, price| price }
        cheapest = priced.min_by { |_, price| price }
        share = { easy: 0.3, normal: 0.45, hard: 0.55 }[@level]
        priced.flat_map do |item, price|
          budget = owns_nothing && item == cheapest&.first ? player.cash : player.cash * share
          next [] if price > budget

          purchase = safe { @step.respond_to?(:may_purchase?) ? @step.may_purchase?(item) : true }
          value = item.respond_to?(:value) ? item.value.to_i : price
          next [] if !purchase && value < price

          [bid(item, price)]
        end.first(2)
      end

      def bid_target_key(item)
        if item.respond_to?(:company?) && item.company? then :company
        elsif item.respond_to?(:minor?) && item.minor? then :minor
        elsif item.respond_to?(:corporation?) && item.corporation? then :corporation
        end
      end

      def bid(item, price)
        Engine::Action::Bid.new(@entity, :price => price, bid_target_key(item) => item)
      end

      # ---- Stock round ----------------------------------------------------

      def presidencies
        @game.corporations.select { |c| c.president?(player) }
      end

      def par_candidates
        limit = easy? ? 1 : 2
        return [] if presidencies.size >= limit && presidencies.all?(&:floated?)

        corps = @game.corporations.reject(&:ipoed).select { |c| safe { @game.can_par?(c, @entity) } }
        corps = hard? ? corps.sort_by { |c| -home_value(c) } : corps.sample(3)
        corps.first(3).flat_map do |corp|
          prices = (safe { @step.get_par_prices(@entity, corp) } || []).sort_by(&:price)
          # Pick a price at which this player could float the company on their own.
          float_pct = [corp.float_percent || 60, corp.presidents_share&.percent || 20].max
          affordable = prices.select { |sp| sp.price * float_pct / 10 <= player.cash }
          # A forced par (e.g. after buying a private that comes with a president's share) still needs a price.
          sp = (easy? ? affordable.first : affordable.last) || prices.first
          next [] unless sp

          [Engine::Action::Par.new(@entity, corporation: corp, share_price: sp)]
        end
      end

      # How good a company's starting position is: revenue around its home hex.
      def home_value(corp)
        homes = Array(corp.coordinates).filter_map { |c| @game.hex_by_id(c) }
        homes.sum do |home|
          @game.hexes.sum do |hex|
            d = hex_distance(home, hex)
            next 0 if d > 6

            rev = hex.tile.nodes.sum { |n| n.city? || n.offboard? || n.town? ? (safe { n.max_revenue } || 0) : 0 }
            rev.to_f / (d + 1)
          end
        end
      end

      def buy_shares_candidates
        options = []
        @game.corporations.select(&:ipoed).each do |corp|
          held = player.percent_of(corp)
          own = corp.president?(player)
          next if held >= 60 && !own

          sources = corp.ipo_shares.select(&:buyable).group_by(&:percent).values.map(&:first)
          sources += @game.share_pool.shares_by_corporation[corp].group_by(&:percent).values.map(&:first)
          sources.each do |share|
            bundle = share.to_bundle
            next unless safe { @step.can_buy?(@entity, bundle) }
            next if bundle.price > player.cash

            score = hard? ? hard_share_score(corp, share) : simple_share_score(corp, share, own)
            options << [score, share]
          end
        end

        options.select { |score, _| score.positive? }.sort_by { |score, _| -score }.first(3).map do |_, share|
          Engine::Action::BuyShares.new(@entity, shares: share, share_price: share.price, percent: share.percent)
        end
      end

      def simple_share_score(corp, share, own)
        score = (own ? 100 : 0) + (corp.floated? ? 20 : 0) +
                ((corp.share_price&.price || 0) / 10) + (share.owner == @game.share_pool ? 5 : 0) + rand(10)
        score -= 50 if !own && !corp.floated? && corp.owner != player
        score -= 60 if easy? && !own && rand < 0.5
        score
      end

      # Expected gain from holding one more share until the end of the game.
      def share_value(corp)
        price = corp.share_price&.price || corp.par_price&.price || 0
        return 0 if price.zero?

        history = corp.operating_history.values.last(2)
        per_share =
          if history.empty?
            # Not operated yet: a floated company usually earns ~12% of its price per OR.
            corp.floated? || corp.president?(player) ? price * 0.12 : price * 0.06
          else
            paid = history.count { |h| h.dividend_kind == 'payout' }
            avg = history.sum(&:revenue).to_f / history.size
            (avg / 10) * paid / history.size
          end

        next_train = depot_train
        if next_train && !corp.trains.empty? && corp.cash < next_train.price &&
           corp.trains.all? { |t| rusts_by?(t, next_train) || rusts_soon?(t) }
          per_share *= 0.4 # likely to withhold, or to need its president to bail it out
        end
        per_share *= 0.3 if corp.floated? && corp.trains.empty? && corp.cash < (next_train&.price || 0)

        (per_share * remaining_operating_rounds) - (price * 0.05)
      end

      def remaining_operating_rounds
        bank = safe { @game.bank.cash } || 0
        start = safe { @game.class::BANK_CASH } || 1
        ors = safe { @game.phase.operating_rounds } || 2
        # The bank pays for everything, so what's left of it tracks how much game is left.
        [(bank.to_f / start * 4 * ors).ceil, 1].max
      end

      def hard_share_score(corp, share)
        own = corp.president?(player)
        value = share_value(corp)
        score = value / [share.price, 1].max * 100

        holders = corp.player_share_holders
        mine = holders[player] || 0
        rival_max = holders.reject { |p, _| p == player }.values.max || 0
        # Defend a presidency a rival could take, and take one that is in reach.
        score += 60 if own && rival_max >= mine - share.percent
        score += 50 if !own && corp.floated? && value.positive? && mine + share.percent > rival_max &&
                       mine + share.percent >= 20
        # Get our own companies floated; don't prop up rivals' unfloated ones.
        score += 80 if own && !corp.floated?
        score -= 40 if !own && !corp.floated?
        score += 3 if share.owner == @game.share_pool
        score
      end

      # Hard: dump shares in companies that look like losers before they drop.
      def voluntary_sell_candidates
        @game.corporations.select { |c| player.percent_of(c).positive? && !c.president?(player) }.flat_map do |corp|
          next [] unless share_value(corp) < -(corp.share_price&.price || 0) * 0.25

          bundle = Array(safe { @game.sellable_bundles(player, corp) }).max_by(&:percent)
          next [] unless bundle

          [Engine::Action::SellShares.new(player, shares: bundle.shares, share_price: bundle.share_price,
                                                  percent: bundle.percent)]
        end.first(1)
      end

      def sell_shares_candidates(forced:)
        return [] unless forced

        # Some games (e.g. 1846) make the corporation issue shares before its president may sell.
        issues = []
        if @entity.corporation? && @step.respond_to?(:issuable_shares)
          issues = (safe { @step.issuable_shares(@entity) } || []).sort_by(&:price).last(2).reverse.map do |bundle|
            Engine::Action::SellShares.new(@entity, shares: bundle.shares, share_price: bundle.share_price,
                                                    percent: bundle.percent)
          end
        end

        issues + player_sell_candidates
      end

      def player_sell_candidates
        bundles = @game.corporations.flat_map do |corp|
          list = safe do
            if @step.respond_to?(:sellable_bundles)
              @step.sellable_bundles(player, corp)
            else
              @game.sellable_bundles(player, corp)
            end
          end
          Array(list)
        end
        # Hard sells its worst holdings first; the others raise cash as cheaply as possible.
        bundles = hard? ? bundles.sort_by { |b| [share_value(b.corporation), b.price] } : bundles.sort_by(&:price)
        bundles.first(4).map do |bundle|
          Engine::Action::SellShares.new(
            @entity.corporation? && @step.respond_to?(:can_ebuy_sell_shares?) ? player : @entity,
            shares: bundle.shares,
            share_price: bundle.share_price,
            percent: bundle.percent,
          )
        end
      end

      def choose_candidates
        choices = safe { @step.choices } || safe { @step.choices_ability(@entity) }
        keys = choices.is_a?(Hash) ? choices.keys : Array(choices)
        keys.first(2).map { |c| Engine::Action::Choose.new(@entity, choice: c) }
      end
    end
  end
end
