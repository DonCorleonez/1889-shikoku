# frozen_string_literal: true

require './spec/spec_helper'

require 'json'

module Engine
  AUTO_FIXTURES = [
    '1889/hs_lhglbbiz_17502.json', # Auto-buy from market
    '1889/hs_jmmljkbw_17502.json', # Auto-buy multiple from IPO
  ].freeze

  AUTO_FIXTURES.each do |fixture_name|
    fixture_name, max_action = fixture_name if fixture_name.is_a?(Array)
    fixture = FIXTURES_DIR + '/' + fixture_name
    game_title = File.basename(File.dirname(fixture))
    filename = File.basename(fixture)
    game_id = filename.split('.json').first
    describe game_title do
      context game_id do
        it 'should generate the same auto actions' do
          data = JSON.parse(File.read(fixture))
          rungame = Engine::Game.load(data, strict: true).maybe_raise!

          actions = rungame.class.filtered_actions(data['actions']).first
          # Find all the auto_actions
          actions.compact.each do |action|
            next unless action['auto_actions']

            break if max_action && action['id'] >= max_action

            # Run game as per the spec
            spec_game = Game.load(data, at_action: action['id'])

            # Process game to previous action
            auto_game = Game.load(data, at_action: action['id'] - 1)

            # Add the action but without the auto actions
            clone = action.dup
            clone.delete('auto_actions')
            auto_game.process_action(clone, add_auto_actions: true)

            # Remove time the actions were created at
            spec_last = spec_game.actions.last.to_h
            spec_last['auto_actions']&.each { |a| a.delete('created_at') }
            auto_last = auto_game.actions.last.to_h
            auto_last['auto_actions']&.each { |a| a.delete('created_at') }

            expect(spec_game.result).to eq(auto_game.result)
            expect(spec_last).to eq(auto_last)
          end
        end
      end
    end
  end
end
