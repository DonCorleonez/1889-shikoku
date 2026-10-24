# frozen_string_literal: true

# backtick_javascript: true

require 'engine/ai/driver'
require 'lib/params'
require 'lib/storage'

module View
  module Game
    # Hotseat-only bar for choosing which seats the computer plays, and the
    # timer that makes those seats move. Settings live in the hotseat game's
    # local storage under settings.ai_players / settings.ai_paused.
    class AiPlayers < Snabberb::Component
      needs :game, store: true
      needs :game_data, store: true
      needs :flash_opts, default: {}, store: true

      DELAY_MS = 600

      def render
        return h(:span) if @game_data[:mode] != :hotseat || !Engine::AI.supported?(@game.class.title)

        ids = ai_ids(@game_data)
        thinking = !paused?(@game_data) && !@game.finished && !@game.exception && !Lib::Params['action'] &&
                   Engine::AI::Driver.bot_turn?(@game, ids)
        schedule if thinking

        seats = @game.players.map do |player|
          ai = ids.include?(player.id)
          children = [
            h(:input, {
                attrs: { type: 'checkbox', checked: ai },
                style: { marginRight: '0.2rem' },
                on: { change: ->(event) { toggle_seat(player.id, Native(event).target.checked) } },
              }),
            player.name,
          ]
          children << render_level_select(player) if ai
          h(:label, { style: { marginRight: '0.8rem', whiteSpace: 'nowrap' } }, children)
        end

        status =
          if ids.empty?
            'Tick a seat to let the computer play it.'
          elsif paused?(@game_data)
            'Paused.'
          elsif thinking
            "Thinking for #{@game.active_players.map(&:name).join(', ')}..."
          else
            'Waiting for you.'
          end

        pause_button = h(:button, {
                           style: { margin: '0 0.5rem 0 0' },
                           on: { click: -> { toggle_pause } },
                         }, paused?(@game_data) ? 'Resume AI' : 'Pause AI')

        h('div#ai_players', {
            style: {
              margin: '0.5rem 0',
              padding: '0.4rem 0.6rem',
              border: '1px dashed currentColor',
              borderRadius: '0.3rem',
            },
          }, [
          h(:strong, { style: { marginRight: '0.6rem' } }, 'AI players:'),
          *seats,
          (ids.empty? ? '' : pause_button),
          h(:span, { style: { fontStyle: 'italic' } }, status),
        ])
      end

      private

      def render_level_select(player)
        current = level_for(@game_data, player.id)
        options = Engine::AI::Bot::LEVELS.map do |level|
          h(:option, { attrs: { value: level, selected: level == current } }, level.capitalize)
        end
        h(:select, {
            style: { marginLeft: '0.3rem' },
            attrs: { title: 'AI difficulty' },
            on: { change: ->(event) { set_level(player.id, Native(event).target.value) } },
          }, options)
      end

      # Per-seat level, falling back to the level picked when the game was created.
      def level_for(game_data, id)
        Engine::AI::Bot.level(game_data.dig('settings', 'ai_levels', id.to_s) || game_data.dig('settings', 'ai_level'))
      end

      def levels(game_data)
        ai_ids(game_data).to_h { |id| [id, level_for(game_data, id)] }
      end

      def set_level(id, level)
        all = (@game_data.dig('settings', 'ai_levels') || {}).dup
        all[id.to_s] = Engine::AI::Bot.level(level)
        update_settings(ai_levels: all)
      end

      def ai_ids(game_data)
        Array(game_data.dig('settings', 'ai_players'))
      end

      def paused?(game_data)
        !!game_data.dig('settings', 'ai_paused')
      end

      def update_settings(**changes)
        @game_data['settings'] ||= {}
        changes.each { |k, v| @game_data['settings'][k] = v }
        Lib::Storage[@game_data['id']] = @game_data
        store(:game_data, @game_data)
      end

      def toggle_seat(id, on)
        ids = ai_ids(@game_data) - [id]
        ids << id if on
        update_settings(ai_players: ids)
      end

      def toggle_pause
        update_settings(ai_paused: !paused?(@game_data))
      end

      # Only one pending bot move at a time, however often we re-render.
      def schedule
        return if timer_pending?

        callback = lambda do
          `window.__ai_timer = null`
          play
        end
        `window.__ai_timer = setTimeout(#{callback}, #{DELAY_MS})`
      end

      def timer_pending?
        `!!window.__ai_timer`
      end

      def play
        # Re-read the store: this view instance may be stale by the time the timer fires.
        game = store['game']
        game_data = store['game_data']
        return if !game || !game_data || game_data[:mode] != :hotseat || game_data['id'] != game.id
        return if paused?(game_data) || game.finished || game.exception || Lib::Params['action']
        return unless Engine::AI.supported?(game.class.title)

        ids = ai_ids(game_data)
        return unless Engine::AI::Driver.bot_turn?(game, ids)

        game, action = Engine::AI::Driver.act(game, ids, levels: levels(game_data))
        unless action
          game_data['settings'] ||= {}
          game_data['settings']['ai_paused'] = true
          Lib::Storage[game_data['id']] = game_data
          store(:game_data, game_data, skip: true)
          store(:flash_opts, "The AI couldn't find a move for #{game.active_players.map(&:name).join(', ')}. "\
                             'Make this move yourself, then press Resume AI.')
          store(:game, game)
          return
        end

        game_data['actions'] << game.raw_actions.last
        game_data['turn'] = game.turn
        game_data['round'] = game.round.name
        game_data['acting'] = game.active_players_id
        game_data['updated_at'] = Time.now.to_i
        if game.finished
          game_data['result'] = game.result
          game_data['status'] = 'finished'
          game_data['game_end_reason'] = game.game_end_reason
        end
        Lib::Storage[game_data['id']] = game_data
        store(:game_data, game_data, skip: true)
        store(:game, game)
      rescue StandardError => e
        LOGGER.error(e)
        store(:flash_opts, "AI error: #{e.message}")
      end
    end
  end
end
