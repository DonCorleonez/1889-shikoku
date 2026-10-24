# frozen_string_literal: true

# Pits two AI difficulty levels against each other in all-AI games of 1889.
#
#   bundle exec ruby scripts/ai_tournament.rb FIRST_SEED LAST_SEED LEVEL_A LEVEL_B [PLAYERS]
#
# Seats alternate between the two levels and the pattern flips every seed, so
# neither level always sits first in turn order.

# auto_router.rb embeds JavaScript that MRI hands to the shell on load; hide that noise.
stderr = $stderr.dup
$stderr.reopen(File::NULL)
require_relative '../lib/engine'
require_relative '../lib/engine/ai/driver'
$stderr.reopen(stderr)
Engine::Logger.set_level(Logger::FATAL)

first, last, level_a, level_b = ARGV
players = (ARGV[4] || 4).to_i
abort 'usage: ai_tournament.rb FIRST_SEED LAST_SEED LEVEL_A LEVEL_B [PLAYERS]' unless level_b

stats = Hash.new { |h, k| h[k] = { seats: 0, wins: 0, rank: 0, value: 0 } }
finished = 0

(first.to_i..last.to_i).each do |seed|
  srand(seed)
  seat_levels = (0...players).map { |i| (i + seed).even? ? level_a : level_b }
  game = Engine.game_by_title('1889').new(seat_levels.each_with_index.map { |l, i| "#{l} #{i + 1}" }, seed: seed)
  ids = game.players.map(&:id)
  levels = game.players.to_h { |p| [p.id, p.name.split.first] }

  actions = 0
  while !game.finished && actions < 3_000
    game, action = Engine::AI::Driver.act(game, ids, levels: levels)
    break unless action

    actions += 1
  end

  unless game.finished
    puts "seed #{seed}: did not finish (#{actions} actions)"
    next
  end

  finished += 1
  game.result.each_with_index do |(id, value), rank|
    s = stats[levels[id]]
    s[:seats] += 1
    s[:rank] += rank + 1
    s[:value] += value
    s[:wins] += 1 if rank.zero?
  end
  puts "seed #{seed}: #{game.result.map { |id, v| "#{id}=#{v}" }.join(' ')}"
end

puts
stats.each do |level, s|
  puts format('%-7<level>s won %<won>5.1f%% of games, average rank %<rank>.2f, average value %<value>d',
              level: level, won: 100.0 * s[:wins] / [finished, 1].max,
              rank: s[:rank].to_f / s[:seats], value: s[:value] / s[:seats])
end
