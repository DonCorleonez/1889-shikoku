# frozen_string_literal: true

# backtick_javascript: true

require 'lib/storage'
require 'view/share_calculation'
require 'view/game/map'
require 'view/game/stock_market'
require 'view/game/tile_manifest'
require 'view/game/game_info'
require 'view/game/one_screen_round_tracker'
require 'view/game/one_screen_style'

module View
  module Game
    # The default 1889 game screen: everything on one page.
    # A *view only* workspace; core rules/actions remain in the existing views.
    # The GamePage parent still mounts AiPlayers exactly once.
    class OneScreen < Snabberb::Component
      include View::ShareCalculation

      needs :game
      needs :tile_selector, default: nil, store: true
      needs :map_zoom, default: nil, store: true
      needs :action_panel
      needs :round_label
      needs :controls
      needs :game_log
      # player id (String) => AI level (String) for seats the computer plays
      needs :ai_seats, default: {}

      # Seat colours for the share bars; distinct in lightness, not hue alone.
      SEAT_COLORS = %w[#2B4ACB #7A8699 #B4BCC8 #4A5568 #8E9BF0 #D5DBE3].freeze
      POOL_COLOR = '#E2B93B'
      IPO_COLOR = 'var(--sk-ipo)'
      # label and the word that identifies the step in its description
      OR_STEPS = [
        { label: 'Track', word: 'track' },
        { label: 'Token', word: 'token' },
        { label: 'Routes', word: 'route' },
        { label: 'Dividend', word: 'dividend' },
        { label: 'Trains', word: 'train' },
      ].freeze

      # Game-table layout: the board fills the middle of the screen with the
      # action bar under it, companies on the left, players and a running
      # game log on the right. On narrow screens the parts stack, board first.
      def render
        ensure_fitting_map_zoom
        h('div#shikoku-one-screen', [
          h(:style, ONE_SCREEN_STYLE),
          render_status_bar,
          h(OneScreenRoundTracker, game: @game),
          h('div.os-table', [
            h('div.os-stage', [
              render_board,
              render_dock,
            ]),
            h('aside.os-rail.os-rail-right', { attrs: { 'aria-label': 'Players and game log' } }, [
              card('Players', [render_players], 'os-players-card'),
              card('Game log', [render_feed], 'os-feed-card',
                   h('a.os-card-link', { attrs: { href: '#os-full-log' }, on: { click: ->(e) { open_full_log(e) } } },
                     'Full log')),
            ]),
            h('aside.os-rail.os-rail-left', { attrs: { 'aria-label': 'Corporations and trains' } }, [
              card('Corporations', [render_share_legend, render_corporations], 'os-corps-card', operating_order_hint),
              card('Trains · Phase', render_trains_and_phase, 'os-trains-card'),
            ]),
          ]),
          h('div.os-extra', [
            details('Full game log', [@game_log], 'os-full-log'),
            details('Tile manifest', [h(TileManifest, game: @game, tile_selector: @tile_selector)]),
            details('Full game info', [h(GameInfo, game: @game)]),
          ]),
        ])
      end

      def open_full_log(event)
        Native(event).preventDefault
        %x{
          var el = document.getElementById('os-full-log');
          if (el) { el.open = true; el.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
        }
      end

      # ---- board: map or stock market, switched in place ----

      def render_board
        h('section.os-board', { attrs: { id: 'os-board', 'aria-label': 'Board' } }, [
          h('div.os-board-bar', [
            h('div.os-seg', { attrs: { role: 'group', 'aria-label': 'Board view' } }, [
              board_switch_button('map', 'Map', true),
              board_switch_button('market', 'Stock market', false),
            ]),
            h('span.os-board-title', 'Shikoku'),
          ]),
          h('div.os-board-pane.os-board-pane--map', [
            h('div.os-map', [h(Map, game: @game, opacity: 1.0, tile_selector: @tile_selector)]),
          ]),
          h('div.os-board-pane.os-board-pane--market', [
            h('div.os-stock-zoom', [h(StockMarket, game: @game, show_bank: false, embedded_layout: true)]),
          ]),
        ])
      end

      def board_switch_button(view, label, pressed)
        h('button.os-seg-btn', {
            attrs: { type: 'button', 'data-view': view, 'aria-pressed': pressed.to_s },
            on: { click: ->(_e) { switch_board(view) } },
          }, label)
      end

      # Cosmetic DOM-only toggle, like the old market expander: no store
      # update, so AiPlayers and the engine do not re-render on a switch.
      def switch_board(view)
        %x{
          var board = document.getElementById('os-board');
          if (board) {
            board.classList.toggle('os-board--market', #{view} === 'market');
            board.querySelectorAll('.os-seg-btn').forEach(function(btn) {
              btn.setAttribute('aria-pressed', btn.getAttribute('data-view') === #{view} ? 'true' : 'false');
            });
          }
        }
      end

      # ---- action bar under the board ----

      def render_dock
        h('section.os-dock', { attrs: { 'aria-label': 'Current action' } }, [
          h('div.os-dock-intro', [
            render_turn_banner,
            render_action_header,
            h('div.os-current-round', [@round_label]),
          ].compact),
          h('div.os-dock-main', [
            h('div.os-action-form', [@action_panel]),
            h('div.os-tools', @controls),
          ]),
        ])
      end

      # ---- game log: a running feed, oldest at the top, kept scrolled to the newest ----

      FEED_COUNT = 40

      def render_feed
        entries = @game.log.map { |e| e.respond_to?(:message) ? e.message.to_s : e.to_s }
                       .reject { |m| m.strip.empty? }
                       .last(FEED_COUNT)
        return h('p.os-muted', 'No moves yet.') if entries.empty?

        corps = @game.corporations.to_h { |c| [c.id, c] }
        players = @game.players
        scroll = ->(vnode) { `var el = #{vnode}.elm; if (el) { el.scrollTop = el.scrollHeight; }` }

        items = entries.map do |message|
          next h('li.os-latest-round', message.sub(/^-+\s*/, '').sub(/\s*-+$/, '')) if message.start_with?('--')

          first = message.split.first.to_s
          lead = if (corp = corps[first])
                   corp_chip(corp, 'os-chip--sm')
                 elsif (player = players.find { |pl| message.start_with?(pl.name) })
                   h('span.os-avatar.os-avatar--xs', {
                       style: { background: seat_color(player), color: text_on(seat_color(player)) },
                     }, initials(player.name))
                 else
                   h('span.os-latest-dot')
                 end
          h('li.os-latest-item', [lead, h('span.os-latest-text', emphasize_money(message))])
        end

        h('ol.os-latest', { hook: { insert: scroll, postpatch: ->(_old, vnode) { scroll.call(vnode) } } }, items)
      end

      # Money amounts in bold, e.g. "runs a 4 train for ¥110".
      def emphasize_money(message)
        message.split(/(¥[\d,]+)/).reject(&:empty?).map do |part|
          part.start_with?('¥') ? h('strong.os-num', part) : part
        end
      end

      # The map is drawn in absolute pixels (the tile selector is positioned in
      # them too), so it is fitted with the map's own zoom setting rather than
      # CSS scaling. The version is bumped when the layout changes how much room
      # the board gets, so a zoom fitted for an older layout is fitted again
      # once; the +/- buttons above the map still change and remember it.
      MAP_FIT_VERSION = 'table-1'

      def ensure_fitting_map_zoom
        # 0 during server-side rendering, where there is no real window
        width = `(typeof window !== 'undefined' && typeof localStorage !== 'undefined' && window.innerWidth) || 0`
        return unless width.positive?
        return if Lib::Storage['map_zoom'] && Lib::Storage['os_map_fit'] == MAP_FIT_VERSION

        height = `window.innerHeight || 0`
        xs = @game.hexes.map(&:x).uniq.size
        ys = @game.hexes.map(&:y).uniq.size
        natural_w, natural_h = if @game.layout == :flat
                                 [(((xs * 1.5) + 0.5) * Map::EDGE_LENGTH) + (2 * Map::GAP),
                                  (((ys / 2) + 0.5) * Map::SIDE_TO_SIDE) + (2 * Map::GAP)]
                               else
                                 [((((xs / 2) + 0.5) * Map::SIDE_TO_SIDE) + (2 * Map::GAP)) + 1,
                                  (((ys * 1.5) + 0.5) * Map::EDGE_LENGTH) + (2 * Map::GAP)]
                               end
        zoom = if width >= TABLE_MIN_WIDTH
                 # width: both side rails, gaps and the board's padding.
                 # height: the table is the window less the sticky game tabs
                 # (76px); the board gets ~60% of it, less its view switch and
                 # zoom row (120px). Measured at 1280x800 and 1440x900.
                 [(width - 740) / natural_w, (((height - 76) * 0.6) - 120) / natural_h].min
               else
                 (width - 48) / natural_w
               end
        zoom = 1.0 if zoom > 1.0
        zoom = 0.35 if zoom < 0.35 || ys.zero?
        zoom = (zoom * 100).floor / 100.0
        Lib::Storage['map_zoom'] = zoom
        Lib::Storage['os_map_fit'] = MAP_FIT_VERSION
        store(:map_zoom, zoom, skip: true)
      end

      # Matches the @media width in ONE_SCREEN_STYLE where the table layout starts.
      TABLE_MIN_WIDTH = 1100

      # Snabberb's h reads a lone VNode in the props slot as a hash, so title
      # (a String or a VNode) and body (an Array of children) go in as arrays.
      def card(title, body, custom_class = '', right = nil)
        selector = custom_class.empty? ? 'section.os-card' : "section.os-card.#{custom_class}"
        heading = [h('h2.os-card-title', [title])]
        heading << right if right
        h(selector, [
          h('header.os-card-heading', heading),
          h('div.os-card-body', body),
        ])
      end

      def details(title, body, id = nil)
        props = id ? { attrs: { id: id } } : {}
        h('details.os-details', props, [h(:summary, title), h('div.os-details-body', body)])
      end

      # ---- status bar ----

      def round_text
        round = @game.round
        type = round.class.short_name
        return 'Game over' if @game.finished
        return "OR #{@game.turn}.#{round.round_num} of #{@game.operating_rounds}" if type == 'OR'

        "#{type} #{@game.turn}"
      end

      def current_entity
        @game.round.active_step&.current_entity
      end

      def acting_corporation
        entity = current_entity
        return unless entity

        entity.corporation? ? entity : nil
      end

      def render_status_bar
        entity = current_entity
        step = @game.round.active_step
        activity = if @game.finished
                     'Final results'
                   elsif entity
                     [entity.name, step&.description].compact.join(' · ')
                   else
                     ''
                   end
        total = @game.class::BANK_CASH
        bank = @game.bank.cash
        pct = total.is_a?(Numeric) && total.positive? ? [[bank * 100 / total, 0].max, 100].min : 0

        h('header.os-status', [
          h('div.os-status-pills', [
            h('span.os-pill.os-pill--round', round_text),
            h('span.os-pill', "Phase #{@game.phase.name}"),
            h('span.os-status-activity', activity),
          ]),
          h('div.os-bank', { attrs: { title: "Bank #{currency(bank)} of #{currency(total)}" } }, [
            h('div.os-bank-row', [h(:span, 'Bank'), h('strong.os-num', currency(bank))]),
            h('div.os-meter', [h('div.os-meter-fill', { style: { width: "#{pct}%" } })]),
          ]),
        ])
      end

      # Whose turn it is, in one glance: "Your turn" when the only human seat
      # is up, the seat's name when several people share the screen, and a
      # pulsing "playing" pill while the computer moves.
      def render_turn_banner
        return if @game.finished

        player = acting_player
        return unless player

        if (level = ai_level(player))
          return h('span.os-turn.os-turn--ai', { attrs: { role: 'status' } }, [
            h('span.os-turn-dot'),
            "#{player.name} is playing (AI #{level.to_s.capitalize})",
          ])
        end

        humans = @game.players.count { |p| !ai_level(p) }
        label = humans == 1 ? 'Your turn' : "#{player.name}'s turn"
        h('span.os-turn', { attrs: { role: 'status' } }, [
          h('span.os-avatar.os-avatar--xs', { style: { background: seat_color(player), color: text_on(seat_color(player)) } },
            initials(player.name)),
          label,
        ])
      end

      # The player who decides now: the entity itself, or its president.
      def acting_player
        entity = current_entity
        return unless entity

        return entity if entity.player?

        owner = entity.owner
        owner if owner&.player?
      end

      # ---- players ----

      def seat_color(player)
        SEAT_COLORS[@game.players.index(player) % SEAT_COLORS.size]
      end

      # White or dark text, whichever reads at 4.5:1 or better on the colour.
      def text_on(hex)
        channels = [1, 3, 5].map do |i|
          c = hex[i, 2].to_i(16) / 255.0
          c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
        end
        luminance = (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
        1.05 / (luminance + 0.05) >= 4.5 ? '#FFFFFF' : '#141A24'
      end

      def ai_level(player)
        @ai_seats[player.id.to_s]
      end

      def render_players
        priority = @game.priority_deal_player
        active = @game.round.active_step&.current_entity
        active_player = active&.player? ? active : active&.owner
        values = @game.players.to_h { |p| [p, @game.player_value(p)] }
        top = values.values.max
        # only once someone is ahead: at the start everyone is level
        leader = values.values.count(top) == 1 ? values.key(top) : nil

        h('div.os-players', @game.players.map do |player|
          level = ai_level(player)
          role = level ? "AI · #{level.to_s.capitalize}" : 'Human'
          badges = [h("span.os-badge#{level ? '' : '.os-badge--human'}", role)]
          badges << h('span.os-badge.os-badge--priority', 'Priority') if priority == player
          badges << h('span.os-badge.os-badge--lead', 'Leading') if leader == player
          holds = @game.corporations.select { |c| player.num_shares_of(c).positive? }
          classes = player == active_player ? 'div.os-player.os-player--active' : 'div.os-player'

          h(classes, [
            h('div.os-player-head', [
              h('span.os-avatar', { style: { background: seat_color(player), color: text_on(seat_color(player)) } },
                initials(player.name)),
              h('div.os-player-name', [h('strong', player.name), h('span.os-badges', badges)]),
              h('div.os-player-cash', [h('strong.os-num', currency(player.cash)), h('span', 'cash')]),
            ]),
            h('div.os-player-stats', [
              stat('Value', currency(values[player])),
              stat('Certs', "#{@game.num_certs(player)}/#{@game.cert_limit}"),
              h('div.os-stat', [h('span', 'Holds'), h('span.os-holds', holds.map { |c| corp_chip(c, 'os-chip--sm') })]),
            ]),
          ])
        end)
      end

      def stat(label, value)
        h('div.os-stat', [h('span', label), h('strong.os-num', value)])
      end

      def initials(name)
        words = name.to_s.split
        letters = words.size > 1 ? words.first(2).map { |w| w[0] } : [name.to_s[0], name.to_s[-1]]
        letters.join.upcase
      end

      # ---- corporations ----

      def corp_chip(corp, extra = '')
        selector = extra.empty? ? 'span.os-chip' : "span.os-chip.#{extra}"
        h(selector, { style: { background: corp.color, color: corp.text_color }, attrs: { title: corp.full_name } },
          corp.id)
      end

      def operating_order_hint
        h('span.os-card-hint', 'OR order')
      end

      def render_share_legend
        items = @game.players.map { |p| { label: p.name, color: seat_color(p) } }
        items << { label: 'Pool', color: POOL_COLOR }
        items << { label: 'IPO', color: IPO_COLOR }
        h('div.os-legend', items.map do |item|
          h('span.os-legend-item', [h('span.os-swatch', { style: { background: item[:color] } }), item[:label]])
        end)
      end

      def render_corporations
        acting = acting_corporation
        order = @game.round.respond_to?(:entities) && @game.round.class.short_name == 'OR' ? @game.round.entities : []
        corps = @game.corporations.sort_by { |c| [c.ipoed ? 0 : 1, order.index(c) || 99] }

        h('div.os-corps', corps.map do |corp|
          next render_unstarted(corp) unless corp.ipoed

          classes = corp == acting ? 'div.os-corp.os-corp--active' : 'div.os-corp'
          status = if corp == acting
                     h('span.os-badge.os-badge--active', 'Operating')
                   elsif (idx = order.index(corp))
                     h('span.os-order', "##{idx + 1}")
                   end
          par = corp.par_price&.price
          price = corp.share_price&.price
          trend = if par && price
                    diff = price - par
                    arrow = if diff.positive?
                              '▲'
                            else
                              diff.negative? ? '▼' : '•'
                            end
                    h("span.os-trend#{diff.negative? ? '.os-trend--down' : ''}", "#{arrow} par #{currency(par)}")
                  end
          trains = corp.trains.map { |t| h('span.os-train', t.name) }
          trains = [h('span.os-no-train', 'no train')] if trains.empty?
          tokens = corp.tokens.map do |t|
            h('span.os-token', { style: { background: t.used ? corp.color : 'transparent', borderColor: corp.color } })
          end

          h(classes, [
            h('div.os-corp-head', [
              corp_chip(corp),
              h('div.os-corp-name', [h('strong', corp.full_name), h('span', "President #{corp.owner&.name || '—'}")]),
              status,
            ].compact),
            h('div.os-corp-money', [
              h('strong.os-num.os-price', price ? currency(price) : '—'),
              trend,
              h('span.os-corp-cash', ['cash ', h('strong.os-num', currency(corp.cash))]),
            ].compact),
            share_bar(corp),
            h('div.os-corp-assets', [h('span.os-trains', trains), h('span.os-tokens', tokens)]),
          ])
        end)
      end

      def render_unstarted(corp)
        h('div.os-corp.os-corp--unstarted', [
          h('div.os-corp-head', [
            corp_chip(corp),
            h('div.os-corp-name', [h('span', corp.full_name)]),
            h('span.os-muted', 'Not started'),
          ]),
        ])
      end

      def share_bar(corp)
        holders = @game.players.map { |p| { name: p.name, pct: p.percent_of(corp), color: seat_color(p) } }
        holders << { name: 'Pool', pct: @game.share_pool.percent_of(corp), color: POOL_COLOR }
        holders << { name: 'IPO', pct: corp.ipo_shares.sum(&:percent), color: IPO_COLOR }
        held = holders.select { |seg| seg[:pct].to_i.positive? }
        label = held.map { |seg| "#{seg[:name]} #{seg[:pct]}%" }.join(', ')
        h('div.os-sharebar', { attrs: { role: 'img', 'aria-label': "Shares: #{label}" } },
          held.map do |seg|
            h('span.os-share', {
                style: { flexGrow: seg[:pct], background: seg[:color] },
                attrs: { title: "#{seg[:name]} #{seg[:pct]}%" },
              })
          end)
      end

      # ---- trains & phase ----

      def render_trains_and_phase
        phases = @game.phase.phases
        current = @game.phase.name
        cur_idx = phases.index { |p| p[:name] == current } || 0
        pills = phases.each_with_index.map do |ph, i|
          state = if i < cur_idx
                    'past'
                  else
                    i == cur_idx ? 'now' : 'next'
                  end
          h("span.os-phase.os-phase--#{state}", ph[:name])
        end
        info = phases[cur_idx] || {}
        tiles = Array(info[:tiles]).map(&:to_s).join(', ')
        summary = "Phase #{current}: train limit #{info[:train_limit]}, #{tiles} tiles, " \
                  "#{info[:operating_rounds]} OR#{info[:operating_rounds] == 1 ? '' : 's'} per set."

        upcoming = @game.depot.upcoming.group_by(&:name)
        rows = upcoming.map do |name, trains|
          unlimited = @game.class::TRAINS.find { |t| t[:name] == name }&.dig(:num).to_s == 'unlimited'
          left = unlimited ? 'unlimited' : "#{trains.size} left"
          h('div.os-depot-row', [
            h('span.os-train.os-train--big', name),
            h('strong.os-num', currency(trains.first.price)),
            h('span.os-muted', left),
          ])
        end
        rows << h('div.os-muted', 'No trains left in the depot') if rows.empty?
        discarded = @game.depot.discarded.map(&:name)

        [
          h('div.os-phases', pills),
          h('p.os-note', summary),
          h('div.os-depot', rows),
          discarded.empty? ? nil : h('p.os-note', "Discarded: #{discarded.join(', ')}"),
          @game.bank.broken? ? h('p.os-note.os-note--alert', 'The bank has broken.') : nil,
        ].compact
      end

      # ---- action header ----

      def render_action_header
        entity = current_entity
        return h(:span) if @game.finished || !entity

        sub = []
        if entity.corporation?
          sub << "#{currency(entity.cash)} treasury"
          sub << "#{entity.trains.size} train#{entity.trains.size == 1 ? '' : 's'}"
        elsif entity.respond_to?(:cash)
          sub << "#{currency(entity.cash)} cash"
        end
        owner = entity.corporation? ? entity.owner : entity
        if owner&.player? && (level = ai_level(owner))
          sub << "played by AI (#{level.to_s.capitalize})"
        end

        badge = if entity.corporation?
                  corp_chip(entity, 'os-chip--lg')
                elsif entity.player?
                  h('span.os-avatar.os-avatar--lg', {
                      style: { background: seat_color(entity), color: text_on(seat_color(entity)) },
                    }, initials(entity.name))
                end

        children = [
          h('div.os-action-head', [
            badge,
            h('div.os-action-title', [h('strong', entity.respond_to?(:full_name) ? entity.full_name : entity.name),
                                      h('span', sub.join(' · '))]),
          ].compact),
        ]
        children << render_or_steps if @game.round.class.short_name == 'OR'
        h('div.os-action-intro', children)
      end

      def render_or_steps
        description = @game.round.active_step&.description.to_s.downcase
        current = OR_STEPS.index { |step| description.include?(step[:word]) }
        items = OR_STEPS.each_with_index.map do |step, i|
          state = if current.nil?
                    'next'
                  elsif i < current
                    'done'
                  else
                    i == current ? 'now' : 'next'
                  end
          attrs = state == 'now' ? { 'aria-current': 'step' } : {}
          h("li.os-step.os-step--#{state}", { attrs: attrs }, [h('span.os-step-dot'), step[:label]])
        end
        h('ol.os-steps', { attrs: { 'aria-label': 'Operating steps' } }, items)
      end

      def share_count(value)
        value.is_a?(Numeric) && value == value.to_i ? value.to_i : value
      end

      def currency(value)
        @game.format_currency(value)
      end
    end
  end
end
