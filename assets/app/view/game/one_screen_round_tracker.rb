# frozen_string_literal: true

# Round tracker for the opt-in Shikoku one-screen view. Display-only.
# No mutation, caching, cloning or new save fields.
module View
  module Game
    class OneScreenRoundTracker < Snabberb::Component
      needs :game

      def render
        items = history_items
        items << current_item unless @game.finished
        items.concat(future_items) unless @game.finished
        items << { label: 'Game Over', status: 'current' } if @game.finished

        h('nav.os-timeline', { attrs: { 'aria-label': 'Game round progress' } },
          items.map do |item|
            status = item[:status]
            h('span.os-round.os-round--' + status, {
                attrs: { title: item[:title] || item[:label], 'aria-current': status == 'current' ? 'step' : nil },
              }, [
                h('span.os-round-indicator', status == 'complete' ? '✓' : '•'),
                h(:span, item[:label]),
                status == 'projected' ? h('small.os-round-projected', 'Projected') : nil,
              ].compact)
          end)
      end

      # The source game.round_history contains action IDs, not round metadata.
      # Completed round labels come from PlayerInfo history, which records
      # (short_name, turn, round_no) at round completion. It also holds the
      # final OR when the game ends before round_history gains a new marker.
      def history_items
        player = @game.players.first
        seen = {}
        Array(player&.history).each_with_object([]) do |info, result|
          key = [info.round_name, info.turn, info.round_no]
          next if seen[key]

          seen[key] = true
          result << { label: round_name(info.round_name, info.turn, info.round_no),
                      status: 'complete' }
        end
      end

      def current_item
        round = @game.round
        type = round.class.short_name
        { label: round_name(type, @game.turn, round.round_num), status: 'current' }
      end

      def future_items
        round = @game.round
        turn = @game.turn
        type = round.class.short_name
        count = if type == 'OR'
                  @game.operating_rounds.to_i # fixed at Stock Round end
                else
                  @game.phase.operating_rounds.to_i # estimate for NEXT set
                end
        count = [[count, 1].max, 3].min
        result = []
        if type == 'OR'
          ((round.round_num + 1)..count).each do |num|
            result << { label: round_name('OR', turn, num), status: 'projected' }
          end
          if @game.bank.broken?
            result << { label: 'Game End (bank broken)', status: 'projected' }
          else
            result << { label: "SR #{turn + 1}", status: 'projected' }
            result << { label: "OR #{turn + 1}.1", status: 'projected' }
          end
        elsif type == 'SR'
          result << { label: "OR #{turn}.1", status: 'projected' }
          result << { label: "OR #{turn}.2", status: 'projected' } if count >= 2
          result << { label: "OR #{turn}.3", status: 'projected' } if count >= 3
          result << { label: "SR #{turn + 1}", status: 'projected' }
        else
          next_turn = [turn, 1].max
          result << { label: "SR #{next_turn}", status: 'projected' }
          result << { label: "OR #{next_turn}.1", status: 'projected' }
        end
        result.first(4)
      end

      def round_name(short, turn, num)
        case short
        when 'OR', 'AR', 'MR', 'DEV', 'BUST'
          "#{short} #{turn}.#{num}"
        when 'SR'
          "SR #{turn}"
        else
          "#{short} #{turn}"
        end
      end
    end
  end
end
