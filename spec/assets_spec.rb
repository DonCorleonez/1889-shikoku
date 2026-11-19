# frozen_string_literal: true

require 'spec_helper'
require 'assets'

TEST_CASES = [
  ['1889',
   314,
   [[6, 'stock_round', 'Pass (Share)'],
    [13, 'float', 'KO receives ¥700'],
    [21, 'lay_track', '1889: Phase 2 - Operating Round 1.1 (of 1) - Lay/Upgrade Track'],
    [23, 'buy_train',
     ['KO must buy an available train',
      '!!Player 1 must contribute']],
    [48, 'run_routes', '1889: Phase 2 - Operating Round 2.1 (of 1) - Run Routes'],
    [49, 'dividends', '1889: Phase 2 - Operating Round 2.1 (of 1) - Pay or Withhold Dividends'],
    [80,
     'buy_company',
     ['1889: Phase 3 - Operating Round 3.1 (of 1) - Buy Companies',
      'Owning corporation may ignore building cost for mountain hexes']],
    [83,
     'track_and_buy_company',
     ['1889: Phase 3 - Operating Round 3.1 (of 1) - Lay/Upgrade Track',
      'Show companies from other players']],
    [89,
     'special_track',
     ['1889: Phase 3 - Operating Round 3.1 (of 1) - Lay Track for Ehime Railway',
      'Blocks C4 while owned by a player.']],
    [338, 'discard_train', 'Discard Trains'],
    [349, 'buy_train_emr', 'TR must buy an available train'],
    [448,
     'buy_train_emr_shares',
     ['KO has ¥582',
      'Player 1 must contribute ¥518 for KO to afford a train from the Depot',
      'Player 1 has ¥74 in cash',
      'Player 1 has ¥650 in sellable shares',
      'Player 1 must sell shares to raise at least ¥444',
      '!!Bankruptcy']],
    [nil, 'endgame', '1889: Phase D - Operating Round 7.1 (of 3) - Game Over - Bankruptcy']]],
].freeze

AUTO_ACTIONS_TEST_CASES = [
  ['1889',
   314,
   [[7, 'buy_to_float', [
    'Auto Buy Shares',
    'KO',
   ]]]],
].freeze

describe 'Assets' do
  before(:all) { @subject = Assets.new }

  subject { @subject }

  def render(**needs)
    subject.html('assets/app/app.rb', **needs)
  end

  describe '#html' do
    it 'renders the 1889 home page' do
      html = render
      expect(html).to include('四国', 'Build the railways of Shikoku.', 'Saved games', 'New game',
                              'Start game · 3 players', 'Tutorial', 'Import save')
      expect(html).not_to include('Signup', 'Login')
    end

    it 'renders home logged in' do
      expect(render(user: { name: 'toby', settings: { consent: true } })).to include('Saved games')
    end

    it 'consent logged in' do
      expect(render(user: { name: 'toby' })).to include('I agree to the privacy policy')
    end

    it 'renders about' do
      expect(render(app_route: '/about')).to include('created and maintained')
    end

    it 'renders tiles' do
      expect(render(app_route: '/tiles/all')).to include('Generic Map Hexes')

      expect(render(app_route: '/tiles/57')).to include('57')

      expect(render(app_route: '/tiles/1889/K4')).to include('K4')
      i2_k4 = render(app_route: '/tiles/1889/I2+K4')
      expect(i2_k4).to include('I2')
      expect(i2_k4).to include('K4')

      aggregate_failures 'location names' do
        with_loc_names = render(app_route: '/tiles/1889/K4+I2+F3')
        %w[K4 Takamatsu I2 Marugame F3 Saijou].each do |str|
          expect(with_loc_names).to include(str)
        end
      end

      rendered = render(app_route: '/tiles/1889/all')
      expect(rendered).to include('1889 Map Hexes')
      expect(rendered).to include('1889 Tile Manifest')
      expect(rendered).not_to include('TODO')
    end

    it 'renders login' do
      expect(render(app_route: '/login')).to include('Login')
    end

    it 'renders signup' do
      expect(render(app_route: '/signup')).to include('Signup')
    end

    context '/map' do
      {
        # games with full implementation; verify every string on the map
        '1889' => %w[
          1 10 11 12 13 14 2 20 3 30 4 40 5 6 60 7 8 80 9 A AR Anan Awaji B C D
          D100 D80 E ER F G H I IR Ikeda Imabari J K KO Komatsujima Kotohira
          Kouchi Kouen KU Kubokawa L Marugame Matsuyama Muki Muroto Nahari
          Nakamura Nangoku Naruto Niihama Ohzu Okayama Ritsurin SR Saijou
          Sakaide Sukumo T TR Takamatsu Tokushima UR Uwajima Yawatahama
        ],
      }.each do |game_title, expected_strings|
        context game_title do
          it 'renders map' do
            rendered = render(app_route: "/map/#{game_title}")

            aggregate_failures 'expected strings' do
              expected_strings.each { |s| expect(rendered).to include(s) }
            end
          end
        end
      end
    end

    it 'renders new_game' do
      expect(render(app_route: '/new_game')).to include('Create New Game')
      expect(render(app_route: '/new_game', title: '1889')).to include('Shikoku 1889')
    end

    it 'renders game' do
      needs = {
        game_data: {
          id: 1,
          user: { id: 1, name: 'Player 1' },
          players: [{ id: 1, name: 'Player 1' }, { id: 2, name: 'Player 2' }],
          title: '1889',
          actions: [],
          loaded: true,
        },
        user: {
          id: 1,
          name: 'Player 1',
          settings: { consent: true },
        },
      }

      expect(render(app_route: '/game/1', **needs)).to include('Takamatsu E-Railroad')
      expect(render(app_route: '/game/1#entities', **needs)).to include('entities', 'Player 1', 'Awa Railroad')
      expect(render(app_route: '/game/1#map', **needs)).to include('Kotohira')
      expect(render(app_route: '/game/1#market', **needs)).to include('The Bank', 'Cash', 'Par value')
      expect(render(app_route: '/game/1#info', **needs)).to include('Trains', 'Game Phases', 'Shikoku 1889')
      expect(render(app_route: '/game/1#tiles', **needs)).to include('492')
      expect(render(app_route: '/game/1#spreadsheet', **needs)).to include('Value')
      expect(render(app_route: '/game/1#tools', **needs)).to include('Clone Game')
      expect(render(app_route: '/game/1#auto', **needs)).to include('Auto Actions')
    end

    def render_game_at_action(data, action_count, string, suffix = '')
      data['actions'] = data['actions'].take(action_count) if action_count
      data[:loaded] = true
      needs = {
        game_data: data,
        user: data['user'].merge(settings: { consent: true }),
      }

      html = render(app_route: "/game/#{needs[:game_data]['id']}#{suffix}", **needs)
      strings = Array(string)
      strings.each do |str|
        if /^!!/.match?(str)
          expect(html).not_to include(str.slice(2..))
        else
          expect(html).to include(str)
        end
      end
    end

    def render_game(jsonfile, action_count, string)
      data = JSON.parse(File.read(jsonfile))
      render_game_at_action(data, action_count, string)
    end

    TEST_CASES.each do |game, game_id, actions|
      dir = Engine.meta_by_title(game).fixture_dir_name
      data = JSON.parse(File.read("spec/fixtures/#{dir}/#{game_id}.json"))
      actions.each do |action_config|
        action, step, string = action_config
        describe "#{game} #{game_id}" do
          it "renders #{step} #{action}" do
            render_game_at_action(data.dup, action, string)
          end
        end
      end
    end

    AUTO_ACTIONS_TEST_CASES.each do |game, game_id, actions|
      data = JSON.parse(File.read("spec/fixtures/#{game}/#{game_id}.json"))
      actions.each do |action_config|
        action, step, string = action_config
        describe "#{game} #{game_id}" do
          it "renders auto #{step} #{action}" do
            render_game_at_action(data.dup, action, string, '#auto')
          end
        end
      end
    end

    it 'renders tutorial to the end' do
      render_game('public/assets/tutorial.json', nil, 'Good luck and have fun!')
    end
  end
end
