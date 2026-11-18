# frozen_string_literal: true

require 'spec_helper'

module Engine
  describe Round::Operating do
    let(:players) { %w[a b c] }
    let(:game) { Game::G1889::Game.new(players) }
    let(:hex_j3) { game.hex_by_id('J3') }
    let(:hex_j5) { game.hex_by_id('J5') }
    let(:hex_k4) { game.hex_by_id('K4') }
    let(:hex_k6) { game.hex_by_id('K6') }
    let(:hex_k8) { game.hex_by_id('K8') }
    let(:hex_l7) { game.hex_by_id('L7') }

    let(:hex_e8) { game.hex_by_id('E8') }
    let(:hex_f7) { game.hex_by_id('F7') }
    let(:hex_f9) { game.hex_by_id('F9') }
    let(:hex_g8) { game.hex_by_id('G8') }
    let(:hex_g10) { game.hex_by_id('G10') }
    let(:hex_g12) { game.hex_by_id('G12') }
    let(:hex_g14) { game.hex_by_id('G14') }
    let(:hex_h11) { game.hex_by_id('H11') }
    let(:hex_h13) { game.hex_by_id('H13') }
    let(:hex_i12) { game.hex_by_id('I12') }
    let(:hex_c13) { game.hex_by_id('C13') }
    let(:player) { game.players.first }
    let(:player2) { game.players[1] }

    subject { move_to_or! }

    def next_round!
      game.send(:next_round!)
      game.round.setup
    end

    def move_to_or!
      # Move the game into an OR

      next_round! until game.round.is_a?(Round::Operating)

      game.round
    end

    def goto_new_or!
      next_round!
      move_to_or!
    end

    def goto_train_step!
      # skip past non train-buying actions
      until subject.active_step.is_a?(Engine::Step::Train)
        action = Action::Pass.new(subject.current_entity)
        subject.process_action(action)
      end
    end

    def fake_buy_train(train, corp)
      corp.trains.slice!(2)
      source = train.owner
      game.depot.remove_train(train)
      game.bank.spend(train.price, corp)
      game.phase.buying_train!(corp, train, source)
      game.buy_train(corp, train, train.price)
    end

    def real_buy_depot_train(corporation, variant)
      train = subject.active_step
                .buyable_trains(corporation)
                .find(&:from_depot?)
      price = train.variants[variant][:price]
      action = Action::BuyTrain.new(corporation, train: train, price: price, variant: variant)
      subject.process_action(action)
    end

    def remove_trains_until!(train)
      until (t = game.depot.depot_trains.first).name == train
        game.depot.remove_train(t)
      end
      t
    end

    before :each do
      game.par_corporation(corporation, game.stock_market.par_prices[0])
      corporation.set_cash(100, game.bank)
      corporation.owner = game.players.first
      allow(corporation).to receive(:floated?) { true }
    end

    context '#1889' do
      let(:corporation) { game.corporation_by_id('AR') }
      let(:corporation2) { game.corporation_by_id('SR') }
      let(:ehime) { game.company_by_id('ER') }
      subject { move_to_or! }

      before :each do
        game.par_corporation(corporation, game.stock_market.par_prices[0])
        game.par_corporation(corporation2, game.stock_market.par_prices[0])
        next_round!

        corporation.set_cash(1000, game.bank)
        corporation.owner = player
        corporation2.set_cash(1000, game.bank)
        corporation2.owner = player
        player.set_cash(2000, game.bank)
        player2.set_cash(2000, game.bank)
        # Make player 1 president of two companies, player 2 have the same amount of shares
        4.times { game.share_pool.buy_shares(player, corporation.shares.first) }
        5.times { game.share_pool.buy_shares(player2, corporation.shares.first) }
        3.times { game.share_pool.buy_shares(player, corporation2.shares.first) }
        4.times { game.share_pool.buy_shares(player2, corporation2.shares.first) }
        player.set_cash(2000, game.bank)
        player2.set_cash(2000, game.bank)
        subject.process_action(Action::LayTile.new(corporation, tile: Tile.for('5'), hex: hex_k8, rotation: 3))
      end

      describe 'sellable_bundles' do
        it 'should not return bundles that cause a president change' do
          player.set_cash(1, game.bank)
          corporation.set_cash(1, game.bank)
          bundles = game.sellable_bundles(player, corporation)
          # Player is president of corp 1, but cannot sell any shares without a president change
          expect(bundles.size).to eq(0)
          bundles = game.sellable_bundles(player, corporation2)
          # Player is president of corp 2, but cannot sell any shares without a president change
          expect(bundles.size).to eq(0)
        end
      end

      describe 'buyable_trains' do
        it 'returns 2 trains in the depot at start' do
          available = subject.active_step.buyable_trains(corporation)
          expect(available.size).to eq(1)
        end

        it 'returns a 2 train in the discard if discarded' do
          train = subject.active_step.buyable_trains(corporation).first
          fake_buy_train(train, corporation)
          game.depot.reclaim_train(train)

          available = subject.active_step.buyable_trains(corporation)
          expect(available.size).to eq(2)
        end

        it 'returns trains owned by other corporations' do
          train = subject.active_step.buyable_trains(corporation).first
          fake_buy_train(train, corporation2)

          available = subject.active_step.buyable_trains(corporation)
          expect(available.size).to eq(2)
        end

        it 'returns only returns trains in the depot if the corp cannot afford and the player has sold shares' do
          train = subject.active_step.buyable_trains(corporation).first
          fake_buy_train(train, corporation2)
          # Ensure we can sell shares.
          game.share_pool.buy_shares(player, corporation2.shares.first)
          corporation.set_cash(1, game.bank)
          player.set_cash(1, game.bank)

          bundle = game.bundles_for_corporation(player, corporation2).first
          subject.process_action(Action::SellShares.new(
            player,
            shares: bundle.shares,
            share_price: bundle.price_per_share,
            percent: bundle.percent,
          ))
          available = subject.active_step.buyable_trains(corporation)
          expect(available.size).to eq(1)
        end

        it 'returns only returns cheapest trains available if the corp cannot afford any' do
          while (train = subject.active_step.buyable_trains(corporation).first).name == '2'
            game.depot.remove_train(train)
            game.buy_train(corporation2, train, train.price)
          end
          game.depot.reclaim_train(corporation2.trains.first) while corporation2.trains.any?

          available = subject.active_step.buyable_trains(corporation)
          expect(available.size).to eq(2)

          corporation.set_cash(1, game.bank)
          available = subject.active_step.buyable_trains(corporation)
          expect(available.size).to eq(1)
        end

        describe 'buy_train' do
          it 'allows purchasing with emergency funds if must buy' do
            expect(subject.active_step.must_buy_train?(corporation)).to be true
            corporation.set_cash(1, game.bank)
            train = subject.active_step.buyable_trains(corporation).first
            subject.process_action(Action::BuyTrain.new(corporation, train: train, price: train.price))
          end
          it 'does not allow purchasing with emergency funds if no need to buy' do
            train = subject.active_step.buyable_trains(corporation).first
            subject.process_action(Action::BuyTrain.new(corporation, train: train, price: train.price))
            expect(subject.active_step.must_buy_train?(corporation)).to be false
            corporation.set_cash(1, game.bank)
            train = subject.active_step.buyable_trains(corporation).first
            action = Action::BuyTrain.new(corporation, train: train, price: train.price)
            expect { subject.process_action(action) }.to raise_error GameError
          end
          it 'causes a rust event when buying the first 4' do
            train = subject.active_step.buyable_trains(corporation).first
            subject.process_action(Action::BuyTrain.new(corporation, train: train, price: train.price))
            expect(subject.active_step.must_buy_train?(corporation)).to be false

            # Move to 4 trains to cause a rust event
            while (train = subject.active_step.buyable_trains(corporation).first).name != '4'
              fake_buy_train(train, corporation2)
            end

            corporation.set_cash(1000, game.bank)
            train = subject.active_step.buyable_trains(corporation).first
            action = Action::BuyTrain.new(corporation, train: train, price: train.price)
            subject.process_action(action)
            expect(corporation.trains.size).to eq(1)
          end

          it 'does not allow purchasing with emergency funds if no need to buy even if it causes a rusting' do
            train = subject.active_step.buyable_trains(corporation).first
            subject.process_action(Action::BuyTrain.new(corporation, train: train, price: train.price))
            expect(subject.active_step.must_buy_train?(corporation)).to be false

            # Move to 4 trains to cause a rust event
            while (train = subject.active_step.buyable_trains(corporation).first).name != '4'
              fake_buy_train(train, corporation2)
            end

            train = subject.active_step.buyable_trains(corporation).first
            game.buy_train(corporation2, train, train.price)

            corporation.set_cash(1, game.bank)
            train = subject.active_step.buyable_trains(corporation).first
            action = Action::BuyTrain.new(corporation, train: train, price: train.price)
            fake_buy_train(train, corporation)
            expect { subject.process_action(action) }.to raise_error GameError
          end

          it 'does not allow EMR purchasing diesel when it can afford a 6' do
            # Allow diesels to be purchased
            while (train = subject.active_step.buyable_trains(corporation).first).name != '6'
              fake_buy_train(train, corporation2)
            end
            fake_buy_train(subject.active_step.buyable_trains(corporation).first, corporation2)

            corporation.set_cash(subject.active_step.buyable_trains(corporation).first.price, game.bank)
            train = subject.active_step.buyable_trains(corporation).find { |t| t.name == 'D' }
            action = Action::BuyTrain.new(corporation, train: train, price: train.price)
            fake_buy_train(train, corporation)
            expect { subject.process_action(action) }.to raise_error GameError
          end

          describe 'bankruptcy' do
            let(:corporation3) { game.corporation_by_id('TR') }

            before :each do
              # give corporation a route so that a train must be bought
              hex = game.hex_by_id(corporation.coordinates)
              tile = game.tile_by_id('6-0')
              hex.lay(tile.rotate!(2))

              game.par_corporation(corporation3, game.stock_market.par_prices[0])
              corporation3.set_cash(1000, game.bank)
              corporation3.ipoed = true

              next_round! # get past turn 1 so shares are sellable

              # skip past non train-buying actions
              until game.active_step.is_a?(Engine::Step::Train)
                action = Action::Pass.new(game.current_entity)
                game.process_action(action)
              end
            end

            it 'does not allow declaring bankruptcy when president has enough cash to buy a train' do
              train = remove_trains_until!('6')

              corporation.set_cash(train.price - 1, game.bank)
              corporation.player.set_cash(1, game.bank)

              action = Action::Bankrupt.new(corporation)
              expect { subject.process_action(action) }.to raise_error GameError, /Cannot go bankrupt/
            end

            it 'does not allow declaring bankruptcy when president has enough sellable shares to buy a train' do
              # buy another share of corporation2 for some liquidity; other
              # player has same number of shares and corporation2s cannot be
              # dumped during 1889 EMR
              game.share_pool.buy_shares(corporation.player, corporation2.shares.first)

              # get to the right operating corporation
              game.round.next_entity! until game.current_entity == corporation

              # 6T, cost is $630
              remove_trains_until!('6')

              corporation.set_cash(600, game.bank)
              corporation.player.set_cash(29, game.bank)

              expect(game.liquidity(player, emergency: true)).to eq(119)

              action = Action::Bankrupt.new(corporation)
              expect { subject.process_action(action) }.to raise_error GameError, /Cannot go bankrupt/
            end

            it 'does allow declaring bankruptcy when president does not have enough liquidity to buy a train' do
              # buy another share of corporation2 for some liquidity; other
              # player has same number of shares and corporation2s cannot be
              # dumped during 1889 EMR
              game.share_pool.buy_shares(corporation.player, corporation2.shares.first)

              # get to the right operating corporation
              game.round.next_entity! until game.current_entity == corporation

              # 6T, cost is $630
              remove_trains_until!('6')

              corporation.set_cash(530, game.bank)
              corporation.player.set_cash(9, game.bank)

              expect(game.liquidity(player, emergency: true)).to eq(99)

              action = Action::Bankrupt.new(corporation)
              subject.process_action(action)
              expect(game.send(:bankruptcy_limit_reached?)).to be true
            end
          end
        end
      end

      describe 'blocking for Ehime Railway' do
        before :each do
          ehime.owner = game.players[1]
          game.phase.next!
        end

        it 'can lay a tile' do
          expect(subject.active_step).to be_a Engine::Step::BuyTrain

          expect(game.active_players).to eq([game.players[0]])

          subject.process_action(
            Action::BuyCompany.new(
              corporation,
              company: ehime,
              price: 40,
            )
          )

          expect(game.active_players).to eq([game.players[1]])
          expect(subject.active_step).to be_a Engine::Game::G1889::Step::SpecialTrack

          action = Action::LayTile.new(ehime, tile: game.tile_by_id('14-0'), hex: game.hex_by_id('C4'), rotation: 1)
          subject.process_action(action)

          expect(subject.active_step).to be_a Engine::Step::BuyTrain
          expect(game.active_players).to eq([game.players[0]])
          expect(subject.active_entities).to eq([corporation])
        end

        it 'requires a pass action if not laying' do
          expect(subject.active_step).to be_a Engine::Step::BuyTrain

          train = subject.active_step.buyable_trains(corporation).first

          expect(game.active_players).to eq([game.players[0]])

          subject.process_action(
            Action::BuyCompany.new(
              corporation,
              company: ehime,
              price: 40,
            )
          )

          expect(game.active_players).to eq([game.players[1]])
          expect(subject.active_step).to be_a Engine::Game::G1889::Step::SpecialTrack

          action = Action::BuyTrain.new(corporation, train: train, price: train.price)
          expect { subject.process_action(action) }.to raise_error(GameError)

          action = Action::Pass.new(ehime)
          subject.process_action(action)

          expect(subject.active_step).to be_a Engine::Step::BuyTrain
          expect(game.active_players).to eq([game.players[0]])
          expect(subject.active_entities).to eq([corporation])
        end
      end
    end

    describe '#available_hex' do
      context 'with awa' do
        let(:corporation) { game.corporation_by_id('AR') }

        it 'returns the layable hexes' do
          hexes = {
            hex_k8 => [1, 2, 3, 4],
          }
          hexes.each { |k, v| expect(subject.active_step.available_hex(corporation, k)).to eq(v) }

          subject.process_action(Action::LayTile.new(corporation, tile: Tile.for('5'), hex: hex_k8, rotation: 3))

          hexes = {
            hex_k6 => [0],
            hex_k8 => [1, 2, 3, 4],
            hex_l7 => [1],
          }
          subject = goto_new_or!
          hexes.each { |k, v| expect(subject.active_step.available_hex(corporation, k)).to eq(v) }

          subject.process_action(Action::LayTile.new(corporation, tile: Tile.for('9'), hex: hex_k6, rotation: 0))
          subject = goto_new_or!
          hexes = {
            hex_j3 => [5],
            hex_j5 => [4],
            hex_k6 => [0, 3],
            hex_k8 => [1, 2, 3, 4],
            hex_l7 => [1],
          }
          hexes.each { |k, v| expect(subject.active_step.available_hex(corporation, k)).to eq(v) }
        end
      end

      context 'with tse' do
        let(:corporation) { game.corporation_by_id('TR') }

        it 'can handle forks' do
          subject.process_action(Action::LayTile.new(corporation, tile: Tile.for('58'), hex: hex_g10, rotation: 0))
          goto_new_or!.process_action(Action::LayTile.new(corporation, tile: Tile.for('57'), hex: hex_g12, rotation: 0))

          game.phase.next!
          goto_new_or!.process_action(Action::LayTile.new(corporation, tile: Tile.for('15'), hex: hex_g12, rotation: 3))
          goto_new_or!.process_action(Action::LayTile.new(corporation, tile: Tile.for('9'), hex: hex_h13, rotation: 1))

          subject = goto_new_or!
          hexes = {
            hex_e8 => [5],
            hex_f7 => [0],
            hex_f9 => [2, 3, 4, 5],
            hex_g8 => [1],
            hex_g10 => [2, 0],
            hex_g12 => [3, 4, 5, 0],
            hex_g14 => [3, 4],
            hex_h11 => [1],
            hex_h13 => [2, 1, 4],
            hex_i12 => [1],
          }
          hexes.each { |k, v| expect(subject.active_step.available_hex(corporation, k)).to eq(v) }
        end
      end

      context 'with ko' do
        let(:corporation) { game.corporation_by_id('KO') }
        let(:company) { game.company_by_id('TR') }
        let(:player) { game.player_by_id('a') }

        it 'errors when upgrading K4 if Takumatsu is owned by player' do
          company.owner = player
          player.companies << company

          action = Action::LayTile.new(corporation, tile: Tile.for('440'), hex: hex_k4, rotation: 0)
          expect { subject.process_action(action) }.to raise_error(GameError)
        end

        it 'allows upgrading K4 if Takumatsu is owned by any corporation' do
          company.owner = corporation
          corporation.companies << company
          game.phase.next!
          subject.process_action(Action::LayTile.new(corporation, tile: Tile.for('440'), hex: hex_k4, rotation: 0))
        end
      end
    end
  end
end
