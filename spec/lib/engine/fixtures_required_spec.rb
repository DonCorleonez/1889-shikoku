# frozen_string_literal: true

require 'spec_helper'

require 'json'

SKIP_ALPHA = [].freeze

SKIP_BETA_PROD = {}.freeze

def fixtures(meta)
  dir = "#{FIXTURES_DIR}/#{meta.fixture_dir_name}"
  return [] unless File.directory?(dir)

  Dir.glob("#{dir}/*.json")
end

module Engine
  describe 'fixtures' do
    metas = Engine::GAME_METAS.group_by { |m| m::DEV_STAGE }

    describe 'alpha games have at least one completed game' do
      metas[:alpha].each do |meta|
        next if SKIP_ALPHA.include?(meta.title)

        it meta.title do
          completed = fixtures(meta).count do |fixture|
            data = JSON.parse(File.read(fixture))
            data['game_end_reason'] != 'manually_ended'
          end
          expect(completed).to be >= 1
        end
      end
    end

    describe 'beta/production games have at least one completed game for each game_end_reason' do
      (metas[:beta] + metas[:production]).each do |meta|
        describe meta.title do
          game_end_counts = fixtures(meta).each_with_object(Hash.new(0)) do |fixture, counts|
            data = JSON.parse(File.read(fixture))
            counts[data['game_end_reason']&.to_sym] += 1
          end

          Engine.game_by_title(meta.title)::GAME_END_CHECK.each do |reason, _timing|
            next if (SKIP_BETA_PROD[meta.title] || []).include?(reason)

            it "has a fixture for :#{reason}" do
              expect(game_end_counts[reason]).to be >= 1
            end
          end
        end
      end
    end
  end
end
