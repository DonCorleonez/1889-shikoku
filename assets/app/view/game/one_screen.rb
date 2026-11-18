# frozen_string_literal: true

# backtick_javascript: true

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
      needs :action_panel
      needs :round_label
      needs :controls
      needs :game_log
      # player id (String) => AI level (String) for seats the computer plays
      needs :ai_seats, default: {}

      # Seat colours for the share bars; distinct in lightness, not hue alone.
      SEAT_COLORS = %w[#2B4ACB #7A8699 #B4BCC8 #4A5568 #8E9BF0 #D5DBE3].freeze
      POOL_COLOR = '#E2B93B'
      IPO_COLOR = '#EDF0F4'
      # label and the word that identifies the step in its description
      OR_STEPS = [
        { label: 'Track', word: 'track' },
        { label: 'Token', word: 'token' },
        { label: 'Routes', word: 'route' },
        { label: 'Dividend', word: 'dividend' },
        { label: 'Trains', word: 'train' },
      ].freeze

      def render
        h('div#shikoku-one-screen', [
          h(:style, ONE_SCREEN_STYLE),
          render_status_bar,
          h(OneScreenRoundTracker, game: @game),
          h('main.os-workspace', [
            h('div.os-col.os-col-left', [
              card('Players', [render_players]),
              card('Corporations', [render_share_legend, render_corporations], '', operating_order_hint),
            ]),
            h('div.os-col.os-col-center', [
              card('Shikoku', [h('div.os-map', [h(Map, game: @game, opacity: 1.0, tile_selector: @tile_selector)])],
                   'os-map-card'),
              h('div.os-row', [
                card(market_heading, [h('div.os-stock-zoom', [
                                        h(StockMarket, game: @game, show_bank: false, embedded_layout: true),
                                      ])], 'os-market-card'),
                card('Trains · Phase', render_trains_and_phase, 'os-trains-card'),
              ]),
            ]),
            h('div.os-col.os-col-right', [
              card('Current action', [
                render_action_header,
                h('div.os-current-round', [@round_label]),
                h('div.os-action-form', [@action_panel]),
                h('div.os-tools', @controls),
              ], 'os-action-card'),
              card('Game log', [@game_log], 'os-log-card'),
            ]),
          ]),
          h('div.os-extra', [
            details('Tile manifest', [h(TileManifest, game: @game, tile_selector: @tile_selector)]),
            details('Full game info', [h(GameInfo, game: @game)]),
          ]),
        ])
      end

      # Snabberb's h reads a lone VNode in the props slot as a hash, so title
      # (a String or a VNode) and body (an Array of children) go in as arrays.
      def card(title, body, custom_class = '', right = nil)
        selector = custom_class.empty? ? 'section.os-card' : "section.os-card.#{custom_class}"
        props = custom_class.include?('os-market-card') ? { attrs: { id: 'os-market-dock' } } : {}
        heading = [h('h2.os-card-title', [title])]
        heading << right if right
        h(selector, props, [
          h('header.os-card-heading', heading),
          h('div.os-card-body', body),
        ])
      end

      def details(title, body)
        h('details.os-details', [h(:summary, title), h('div.os-details-body', body)])
      end

      def market_heading
        expand = lambda do
          # Cosmetic DOM-only toggle; do not store UI state in game saves,
          # and do not re-render AiPlayers or the engine on each expansion.
          `document.getElementById('os-market-dock').classList.toggle('os-market-expanded')`
        end
        h('span.os-market-heading', [
          h(:span, 'Stock market'),
          h('button.os-btn.os-btn--small', {
              attrs: { type: 'button', title: 'Expand or collapse the market' },
              on: { click: expand },
            }, 'Expand'),
        ])
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

      # ---- players ----

      def seat_color(player)
        SEAT_COLORS[@game.players.index(player) % SEAT_COLORS.size]
      end

      def ai_level(player)
        @ai_seats[player.id.to_s]
      end

      def render_players
        priority = @game.priority_deal_player
        active = @game.round.active_step&.current_entity
        active_player = active&.player? ? active : active&.owner

        h('div.os-players', @game.players.map do |player|
          level = ai_level(player)
          role = level ? "AI · #{level.to_s.capitalize}" : 'Human'
          badges = [h("span.os-badge#{level ? '' : '.os-badge--human'}", role)]
          badges << h('span.os-badge.os-badge--priority', 'Priority') if priority == player
          holds = @game.corporations.select { |c| player.num_shares_of(c).positive? }
          classes = player == active_player ? 'div.os-player.os-player--active' : 'div.os-player'

          h(classes, [
            h('div.os-player-head', [
              h('span.os-avatar', { style: { background: seat_color(player) } }, initials(player.name)),
              h('div.os-player-name', [h('strong', player.name), h('span.os-badges', badges)]),
              h('div.os-player-cash', [h('strong.os-num', currency(player.cash)), h('span', 'cash')]),
            ]),
            h('div.os-player-stats', [
              stat('Value', currency(@game.player_value(player))),
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
            h('span.os-token', { style: { background: t.used ? corp.color : '#FFFFFF', borderColor: corp.color } })
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
                  h('span.os-avatar.os-avatar--lg', { style: { background: seat_color(entity) } }, initials(entity.name))
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
