# frozen_string_literal: true

require_relative 'bot'

module Engine
  module AI
    # Titles the AI has been tested on end to end; the UI only offers AI seats for these.
    SUPPORTED_TITLES = %w[1889].freeze

    def self.supported?(title)
      SUPPORTED_TITLES.include?(title)
    end

    # Plays one action for whichever AI-controlled seat is due to act.
    #
    # A rejected action can leave the engine half-mutated, so after a failure
    # the game is rebuilt from its action list (via the reload block, which
    # defaults to Game#clone) and the bot is asked again, skipping candidates
    # that already failed.
    module Driver
      MAX_ATTEMPTS = 10
      # Give up on an action type (e.g. lay_tile) after this many rejections and move on to the next option.
      MAX_FAILURES_PER_TYPE = 3

      def self.bot_entity(game, bot_ids)
        return if game.finished || game.exception

        return if bot_ids.empty?

        game.round.active_entities.find do |e|
          next false unless e

          pl = game.acting_for_player(e.player)
          # Ownerless entities (e.g. corporations in receivership) are run by the AI too.
          pl ? bot_ids.include?(pl.id) : !e.player?
        end
      end

      def self.bot_turn?(game, bot_ids)
        !bot_entity(game, bot_ids).nil?
      end

      # Returns [game, action]. action is nil when no seat controlled by the
      # AI is due to act or the bot could not find an acceptable action; game
      # may be a fresh instance if a candidate was rejected along the way.
      # levels maps player id => :easy / :normal / :hard (default :normal).
      def self.act(game, bot_ids, levels: {}, &reload)
        reload ||= ->(g, actions) { g.clone(actions) }
        base_actions = game.raw_actions.dup
        failed = []
        failures_by_type = Hash.new(0)

        MAX_ATTEMPTS.times do
          entity = bot_entity(game, bot_ids)
          return [game, nil] unless entity

          action = Bot.new(game, entity, level: level_for(game, entity, levels)).candidates.find do |a|
            failures_by_type[a.type] < MAX_FAILURES_PER_TYPE && !failed.include?(signature(a))
          end
          return [game, nil] unless action

          game.process_action(action, add_auto_actions: true)
          return [game, action] unless game.exception

          LOGGER.debug { "AI: #{action.type} rejected: #{game.exception.message}" }
          failed << signature(action)
          failures_by_type[action.type] += 1
          game = reload.call(game, base_actions)
        end

        [game, nil]
      end

      def self.level_for(game, entity, levels)
        pl = game.acting_for_player(entity.player)
        Bot.level(pl && (levels[pl.id] || levels[pl.id.to_s]))
      end

      def self.signature(action)
        sig = action.to_h.reject { |k, _| %w[id created_at auto_actions].include?(k) }
        # to_h is memoized; drop it so the engine re-serializes once it assigns the id
        action.clear_cache
        sig
      end
    end
  end
end
