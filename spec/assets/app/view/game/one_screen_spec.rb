# frozen_string_literal: true

require './spec/spec_helper'
require 'assets'
require 'view/game/one_screen_round_tracker'

module View
  module Game
    describe OneScreenRoundTracker do
      before do
        # mock for Native.convert used in Snabberb::Component
        stub_const('Native', double('Class', convert: ''))
      end

      def tracker_at(action)
        data = JSON.parse(File.read('spec/fixtures/1889/314.json'))
        described_class.new(nil, game: Engine::Game.load(data, at_action: action))
      end

      def labels(items)
        items.map { |item| item[:label] }
      end

      it 'starts in the initial auction with SR 1 and OR 1.1 projected' do
        tracker = tracker_at(0)
        expect(tracker.history_items).to eq([])
        expect(tracker.current_item).to eq(label: 'ISR 1', status: 'current')
        expect(labels(tracker.future_items)).to eq(['SR 1', 'OR 1.1'])
      end

      it 'tracks the first Stock Round' do
        tracker = tracker_at(6)
        expect(labels(tracker.history_items)).to eq(['ISR 1'])
        expect(tracker.current_item).to eq(label: 'SR 1', status: 'current')
        expect(labels(tracker.future_items)).to eq(['OR 1.1', 'SR 2'])
      end

      it 'tracks the first Operating Round' do
        tracker = tracker_at(21)
        expect(labels(tracker.history_items)).to eq(['ISR 1', 'SR 1'])
        expect(tracker.current_item).to eq(label: 'OR 1.1', status: 'current')
        expect(labels(tracker.future_items)).to eq(['SR 2', 'OR 2.1'])
      end

      it 'marks exactly one round as aria-current' do
        tracker = tracker_at(21)
        allow(tracker).to receive(:h) { |*args| args }

        _sel, _props, rounds = tracker.render
        current = rounds.select { |_s, props, _c| props[:attrs].key?('aria-current') }
        expect(current.map(&:first)).to eq(['span.os-round.os-round--current'])
        expect(current.first[1][:attrs]['aria-current']).to eq('step')
      end

      it 'does not change the game while rendering' do
        tracker = tracker_at(21)
        game = tracker.instance_variable_get(:@game)
        allow(tracker).to receive(:h) { |*args| args }

        before = [game.actions.size, game.round.class, game.turn, game.round.round_num, game.players.first.history.size]
        tracker.render
        after = [game.actions.size, game.round.class, game.turn, game.round.round_num, game.players.first.history.size]
        expect(after).to eq(before)
      end
    end

    # Rendered through the real server-side Opal build; requiring the view here
    # would run its JavaScript backticks under MRI.
    describe 'View::Game::OneScreen' do
      let(:fixture) { 'spec/fixtures/1889/314.json' }

      # Lib::Params reads window.location through URLSearchParams, neither of
      # which exists in MiniRacer, so stub both to turn on ?onescreen=1.
      let(:one_screen_shim) do
        <<~JS
          var window = globalThis.window || globalThis;
          window.location = window.location || { search: '?onescreen=1', hash: '' };
          globalThis.URLSearchParams = function() {};
          globalThis.URLSearchParams.prototype.get = function(k) { return k === 'onescreen' ? '1' : null; };
          globalThis.URLSearchParams.prototype.getAll = function() { return []; };
        JS
      end

      before(:all) { @assets = Assets.new }

      def render_game(file, action_count, one_screen: true)
        data = JSON.parse(File.read(file))
        data['actions'] = data['actions'].take(action_count) if action_count
        data[:loaded] = true
        needs = {
          app_route: "/game/#{data['id']}",
          game_data: data,
          user: data['user'].merge(settings: { consent: true }),
        }
        script = Snabberb.html_script('assets/app/app.rb', **needs)
        script = one_screen_shim + script if one_screen
        @assets.context(:all).eval(script)
      end

      it 'is not rendered without ?onescreen=1' do
        html = render_game(fixture, 6, one_screen: false)
        expect(html).not_to include('shikoku-one-screen')
        expect(html).to include('1889: Phase 2 - Stock Round 1')
      end

      it 'renders the auction workspace' do
        html = render_game(fixture, 0)
        expect(html).to include('id="shikoku-one-screen"', '1889 SHIKOKU', 'ISR · Phase 2 · Turn 1',
                                'Players', 'Corporations', 'Shikoku Board', 'Current Action',
                                'Tile Manifest', 'Game Log', 'Takamatsu E-Railroad')
        expect(html).to include('os-round--current', 'ISR 1')
      end

      it 'renders the stock market dock with its expand button' do
        html = render_game(fixture, 6)
        expect(html).to include('id="os-market-dock"', 'Expand / Close', 'os-stock-zoom')
        expect(html).to include('SR · Phase 2 · Turn 1')
      end

      it 'renders an Operating Round with the corporation in the header' do
        html = render_game(fixture, 21)
        expect(html).to include('OR · Phase 2 · Turn 1', 'Corporation: KO', 'Lay/Upgrade Track')
        expect(html).to include('os-round--complete', 'OR 1.1')
      end

      it 'renders a finished game' do
        html = render_game(fixture, nil)
        expect(html).to include('id="shikoku-one-screen"', 'Game Over')
      end

      it 'renders an older hotseat save' do
        html = render_game('spec/fixtures/1889/hs_jmmljkbw_17502.json', nil)
        expect(html).to include('id="shikoku-one-screen"', 'Player 5')
      end
    end
  end
end
