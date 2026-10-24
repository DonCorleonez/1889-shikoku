# frozen_string_literal: true

require './spec/spec_helper'

# auto_router.rb embeds the browser auto-router as inline JavaScript, which MRI
# hands to the shell on load; silence that noise while requiring it.
begin
  stderr = $stderr.dup
  $stderr.reopen(File::NULL)
  require './lib/engine/ai/driver'
ensure
  $stderr.reopen(stderr)
end

module Engine
  describe AI::Driver do
    def play(title, players: 4, seed: 1, max_actions: 5_000, level: :normal)
      srand(seed)
      game = Engine.game_by_title(title).new((1..players).map { |i| "Bot #{i}" }, seed: seed)
      ids = game.players.map(&:id)
      levels = ids.to_h { |id| [id, level] }
      count = 0
      while !game.finished && count < max_actions
        game, action = described_class.act(game, ids, levels: levels)
        break unless action

        count += 1
      end
      [game, count]
    end

    it 'plays a full game of 1882 with only AI players' do
      game, = play('1882')
      expect(game.finished).to be(true)
      expect(game.exception).to be_nil
    end

    it 'plays a full game of 18MS with only AI players' do
      game, = play('18MS')
      expect(game.finished).to be(true)
    end

    it 'plays deep into 1889 without getting stuck' do
      game, count = play('1889', max_actions: 250)
      expect(count).to eq(250)
      expect(game.exception).to be_nil
      expect(game.corporations.count(&:floated?)).to be > 0
    end

    it 'plays deep into 1889 at every difficulty without getting stuck' do
      %i[easy hard].each do |level|
        game, count = play('1889', max_actions: 250, level: level)
        expect(count).to eq(250), "#{level} bot got stuck"
        expect(game.exception).to be_nil
      end
    end

    it 'parses difficulty levels, defaulting to normal' do
      expect(AI::Bot.level('hard')).to eq(:hard)
      expect(AI::Bot.level(:easy)).to eq(:easy)
      expect(AI::Bot.level(nil)).to eq(:normal)
      expect(AI::Bot.level('impossible')).to eq(:normal)
    end

    it 'only acts for AI seats' do
      game = Engine.game_by_title('1889').new(%w[Human Bot], seed: 1)
      human, bot = game.players
      expect(described_class.bot_turn?(game, [bot.id])).to be(false)

      same_game, action = described_class.act(game, [bot.id])
      expect(action).to be_nil
      expect(same_game.raw_actions).to be_empty

      game.process_action(Engine::Action::Pass.new(human))
      expect(described_class.bot_turn?(game, [bot.id])).to be(true)
      _, action = described_class.act(game, [bot.id])
      expect(action.entity).to eq(bot)
    end
  end
end
