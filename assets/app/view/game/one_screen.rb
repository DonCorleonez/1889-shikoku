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

      def render
        h('div#shikoku-one-screen', [
          h(:style, ONE_SCREEN_STYLE),
          render_header,
          h(OneScreenRoundTracker, game: @game),
          h('main.os-workspace', [
            h('section.os-financial-pane', [
              card('Players', render_players),
              card('Corporations', render_corporations),
            ]),
            card('Shikoku Board', [h(Map, game: @game, opacity: 1.0,
                                          tile_selector: @tile_selector)], 'os-map-card'),
            card('Current Action', [
              h('div.os-current-round', @round_label),
              h('div.os-action-form', @action_panel),
              h('div.os-tools', @controls),
            ], 'os-action-card'),
          ]),
          h('div.os-data-strip', [
            card(market_heading, [h('div.os-stock-zoom',
                                    h(StockMarket, game: @game, show_bank: false, embedded_layout: true))], 'os-market-card'),
            card('Bank · Trains · Phases', render_bank_and_phases),
            card('Tile Manifest', h(TileManifest, game: @game,
                                                 tile_selector: @tile_selector), 'os-tile-card'),
            card('Game Log', @game_log, 'os-log-card'),
          ]),
        ])
      end

      def market_heading
        expand = lambda do
          # Cosmetic DOM-only toggle; do not store UI state in game saves,
          # and do not re-render AiPlayers or the engine on each expansion.
          `document.getElementById('os-market-dock').classList.toggle('os-market-expanded')`
        end
        h('div.os-market-heading', [
          h(:span, 'Stock Market'),
          h(:button, { attrs: { type: 'button', title: 'Expand or collapse the market' },
                       on: { click: expand } }, 'Expand / Close'),
        ])
      end

      def card(title, body, custom_class = '')
        selector = custom_class.empty? ? 'section.os-card' : "section.os-card.#{custom_class}"
        h(selector, (custom_class.include?('os-market-card') ? { attrs: { id: 'os-market-dock' } } : {}), [
          h('header.os-card-heading', title),
          h('div.os-card-body', body),
        ])
      end

      def render_header
        current = @game.round.active_step&.current_entity
        corp = current&.corporation || (current if current&.corporation?)
        h('header.os-main-header', [
          h('strong.os-brand', '1889 SHIKOKU'),
          h('span', "#{@game.round.class.short_name} · Phase #{@game.phase.name} · Turn #{@game.turn}"),
          h('span', "Active: #{current&.name || '—'}"),
          corp ? h('span', "Corporation: #{corp.name}") : nil,
        ].compact)
      end

      def render_players
        cols = ['Player', 'Cash', 'Value', 'Liquidity', 'Shares', 'Companies', 'Certs', 'Priority']
        h('table.os-table', [
          h(:thead, h(:tr, cols.map { |c| h(:th, c) })),
          h(:tbody, @game.players.map do |player|
            shares = share_count(@game.all_corporations.sum { |c| c.minor? ? 0 : num_shares_of(player, c) })
            cells = [
              player.name,
              currency(player.cash),
              currency(@game.player_value(player)),
              currency(@game.liquidity(player)),
              shares,
              player.companies.map(&:sym).join(', '),
              "#{@game.num_certs(player)}/#{@game.cert_limit}",
              @game.priority_deal_player == player ? '●' : '',
            ]
            h(:tr, cells.map { |v| h(:td, v.to_s) })
          end),
        ])
      end

      def render_corporations
        cols = ['ID', 'Corporation', *@game.players.map(&:name), 'IPO', 'Pool', 'Par', 'Market', 'Cash', 'Trains', 'Tokens', 'Order', 'President']
        h('table.os-table', [
          h(:thead, h(:tr, cols.map { |c| h(:th, c) })),
          h(:tbody, @game.all_corporations.map do |corp|
            holders = @game.players.map do |player|
              count = share_count(num_shares_of(player, corp))
              corp.president?(player) ? "*#{count}" : count
            end
            operating_index = @game.operating_order.index(corp)
            cells = [corp.id, corp.full_name, *holders,
                     corp.respond_to?(:num_ipo_shares) ? corp.num_ipo_shares : '—',
                     share_count(num_shares_of(@game.share_pool, corp)),
                     corp.par_price ? currency(corp.par_price.price) : '—',
                     corp.share_price ? currency(corp.share_price.price) : '—',
                     currency(corp.cash),
                     corp.trains.map(&:name).join(','),
                     @game.token_string(corp),
                     operating_index ? operating_index + 1 : '—',
                     corp.owner&.name || '—']
            h(:tr, [
              h(:td, h('span.os-corp-chip', { style: { backgroundColor: corp.color,
                                                       color: corp.text_color } }, corp.id)),
              *cells.drop(1).map { |v| h(:td, v.to_s) },
            ])
          end),
        ])
      end

      def render_bank_and_phases
        [
          h('div.os-bank-summary', [
            h(:div, "Bank Cash: #{currency(@game.bank_cash)}"),
            h(:div, "Bank Broken: #{@game.bank.broken? ? 'YES' : 'No'}"),
            h(:div, "Discarded Trains: #{@game.depot.discarded.map(&:name).join(', ')}"),
          ]),
          h(GameInfo, game: @game),
        ]
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
