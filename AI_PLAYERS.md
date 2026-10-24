# AI players (solo play)

This fork of [tobymao/18xx](https://github.com/tobymao/18xx) adds computer
players to **hotseat** games. You can start a game by yourself and the
computer plays the other seats in your browser, so you don't have to wait for
other people.

## Playing

1. Open **Create New Game** and choose **Hotseat**.
2. Pick **Shikoku 1889** (currently the only title with AI support) and the
   number of players (2-6).
3. Each seat has an **AI** checkbox. By default seat 1 is you and every other
   seat is AI. Rename seats if you like.
4. Choose an **AI difficulty**: Easy, Normal (the default) or Hard.
5. Click **Create**. When it's an AI seat's turn, it moves on its own, about
   0.6 s per action.

In the game, an **AI players** bar sits under the menu:

- Tick or untick any seat at any time to hand it to the computer or take it back.
  This also works for older or imported hotseat games.
- Each AI seat has a difficulty dropdown, so you can mix levels or change
  them mid-game.
- **Pause AI** / **Resume AI** stops or restarts the bots. Undo and history
  still work as usual.
- If the bot can't find a legal move in some unusual situation, it pauses
  and asks you to make that one move for it. Then press **Resume AI**.

Everything runs in the browser. Hotseat games are saved in the browser's local
storage, as on 18xx.games, so no account is needed.

## How it works

| File | Purpose |
| --- | --- |
| `lib/engine/ai/bot.rb` | Heuristic player. Looks at the current step and returns an ordered list of candidate actions. |
| `lib/engine/ai/driver.rb` | Finds which AI seat must act and tries candidates until the engine accepts one. A rejected candidate makes the game rebuild from its action list before the next try. |
| `assets/app/view/game/ai_players.rb` | Hotseat bar (seat checkboxes, per-seat difficulty, pause) and the timer that runs the driver. |
| `assets/app/view/create_game.rb` | Per-seat **AI** checkboxes and an **AI difficulty** picker on the hotseat form; stored as `settings.ai_players` and `settings.ai_level`. |
| `spec/lib/engine/ai/driver_spec.rb` | Specs that play all-AI games in the engine at each difficulty. |
| `scripts/ai_tournament.rb` | Pits two levels against each other over many seeds to measure strength. |

The engine stays the only rules authority. The bot only proposes actions and
the engine validates them, so the bot can never make an illegal move.

### Difficulty levels

| | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Routes | Greedy, one train at a time | Branch-and-bound search for the best combination | Same as Normal |
| Track | Random legal tile | Revenue, upgrades, and exits pointing toward unreached revenue | Same, plus keeps cash for a needed train |
| Tokens | Skips half of the chances | Highest-revenue city | Also grabs last free slots to block rivals |
| Private auction | Spends up to 30% of cash | Up to 45% | Up to 55% |
| Starting companies | One, at the lowest affordable par | Two, at the highest par it can float alone | Two, picking the best home locations first |
| Buying shares | Mostly its own company | Its own companies, then floated ones | Expected dividend return over the remaining game; defends its presidencies and takes rivals' when in reach |
| Selling shares | Only when forced | Only when forced | Also dumps companies that look like losers |
| Dividends | Always pays out | Always pays out | Withholds when a rusting fleet needs replacing and the company can't afford it, except near the end |
| Trains | Only its first train | First train, then a newer one when affordable | Times purchases around rusting: rushes a new phase when that rusts rivals' trains more than its own, and upgrades before its own trains rust |
| Privates | Keeps them | Keeps them | Sells them to its own companies at the highest allowed price, moving company cash into its pocket |

Measured over 48 all-AI 4-player games of 1889, with seats alternating
between two levels and seat order rotated each game:

| Match-up | Games won | Average rank (1-4) |
| --- | --- | --- |
| Hard vs Normal | Hard 81%, Normal 19% | 1.85 vs 3.15 |
| Normal vs Easy | Normal 98%, Easy 2% | 1.73 vs 3.27 |
| Same level both sides (noise check) | 42% / 58% | 2.60 vs 2.40 |

Hard still can't look ahead: it doesn't simulate opponents' replies or
plan several turns out. An experienced 18xx player should still beat it,
but it punishes loose play.

### Title support

AI seats are offered only for **1889 (Shikoku)** for now. That list is
`Engine::AI::SUPPORTED_TITLES` in `lib/engine/ai/driver.rb`. All-AI 1889
games with 3, 4 and 5 players play through to the end of the game in the
engine. The bot code is generic, so adding a title means adding it to that
list after testing it.

## Running it locally

The original [DEVELOPMENT.md](DEVELOPMENT.md) covers Docker
(`docker compose up`). Without Docker, you need Ruby 3.3+, PostgreSQL and Redis:

```bash
bundle install                      # needs libpq-dev for the pg gem
echo "127.0.0.1 redis" | sudo tee -a /etc/hosts   # the app expects a host named "redis"
redis-server --daemonize yes
createdb x18xx_dev
export DATABASE_URL=postgres://localhost/x18xx_dev RACK_ENV=development
bundle exec rake dev_up             # migrations
bundle exec rake compile            # build the Opal/JS frontend
bundle exec unicorn -p 9292         # then open http://localhost:9292/new_game
```

Run the AI specs with `bundle exec rspec spec/lib/engine/ai`. To compare two
levels, for example over seeds 1-24:
`bundle exec ruby scripts/ai_tournament.rb 1 24 hard normal`.

## License

The platform code is MIT-licensed (see [LICENSE](LICENSE)), and this fork
keeps that license. As LICENSE says, the individual game titles are published
on 18xx.games with permission from their designers/publishers. The MIT
License doesn't cover those rights, so use this fork for personal play.
