# frozen_string_literal: true

# backtick_javascript: true

require 'game_manager'
require 'lib/storage'
require 'view/shikoku_style'

module View
  # Home page of the 1889 Shikoku build: saved hotseat games and a one-panel
  # form that starts a new hotseat game where any seat can be an AI.
  class ShikokuHome < Snabberb::Component
    include GameManager

    needs :user, default: nil
    needs :sk_seats, default: nil, store: true
    needs :sk_beginner, default: false, store: true
    needs :sk_error, default: nil, store: true
    needs :sk_confirm_delete, default: nil, store: true

    TITLE = '1889'
    MIN_SEATS = 2
    MAX_SEATS = 6
    LEVELS = %w[easy normal hard].freeze
    # id, name, colour, text colour (chosen for 4.5:1 contrast)
    CORPORATIONS = [
      ['AR', 'Awa Railroad', '#37383a', '#FFFFFF'],
      ['IR', 'Iyo Railway', '#f48221', '#18202B'],
      ['SR', 'Sanuki Railway', '#76a042', '#18202B'],
      ['KO', 'Takamatsu & Kotohira Electric Railway', '#d81e3e', '#FFFFFF'],
      ['TR', 'Tosa Electric Railway', '#00a993', '#18202B'],
      ['KU', 'Tosa Kuroshio Railway', '#0189d1', '#18202B'],
      ['UR', 'Uwajima Railway', '#6f533e', '#FFFFFF'],
    ].freeze

    def render
      `document.title = '1889 Shikoku'`
      saves = hotseat_saves

      h('div#sk-home', { key: 'sk_home' }, [
        h('div.sk-main', [
          render_hero(saves.first),
          render_saves(saves),
        ]),
        render_new_game,
      ])
    end

    # ---- hero ----

    def render_hero(latest)
      actions = []
      if latest
        actions << h('a.sk-btn.sk-btn--primary', { attrs: { href: "/hotseat/#{latest['id']}" } }, 'Continue last game')
      end
      actions << h('a.sk-btn', { attrs: { href: '#sk-new' } }, 'New game')
      actions << h('a.sk-btn', { attrs: { href: '/tutorial?action=1' } }, 'Play the tutorial')

      h('section.sk-panel.sk-hero', [
        h(:h1, 'Build the railways of Shikoku.'),
        h('p.sk-lede', '1889 for 2 to 6 players on one screen. Any seat can be played by the computer ' \
                       'at Easy, Normal or Hard.'),
        h('div.sk-corps', CORPORATIONS.map do |id, name, color, text|
          h('span.sk-corp', [h('span.sk-chip', { style: { background: color, color: text } }, id), name])
        end),
        h('div.sk-actions', actions),
      ])
    end

    # ---- saved games ----

    def hotseat_saves
      now = Time.now.to_i
      Lib::Storage
        .all_keys
        .select { |k| k.start_with?('hs_') }
        .map { |k| Lib::Storage[k] }
        .compact
        .sort_by { |gd| [-(gd['updated_at'] || gd['created_ts'] || now), gd['id'].to_s] }
    end

    def render_saves(saves)
      body = if saves.empty?
               [h('p.sk-empty', 'No saved games in this browser yet. Start one with the form, or import a save file.')]
             else
               saves.map { |gd| render_save(gd) }
             end

      h('section.sk-saves', { attrs: { 'aria-labelledby': 'sk-saves-title' } }, [
        h('div.sk-section-head', [
          h('h2#sk-saves-title', 'Saved games'),
          h('span.sk-muted', 'Stored in this browser'),
        ]),
        *body,
      ])
    end

    def render_save(game_data)
      id = game_data['id']
      players = Array(game_data['players'])
      ai = Array(game_data.dig('settings', 'ai_players')).size
      humans = players.size - ai
      who = [("#{humans} human#{humans == 1 ? '' : 's'}" if humans.positive?),
             ("#{ai} AI" if ai.positive?)].compact.join(', ')
      count = Array(game_data['actions']).size
      title = game_data['description'].to_s.strip
      title = players.map { |p| p['name'] }.join(', ') if title.empty?
      details = ["#{players.size} players", who, "#{count} action#{count == 1 ? '' : 's'}"]
      details << "started #{game_data['created_at']}" if game_data['created_at']
      details << 'finished' if game_data['status'] == 'finished'

      confirming = @sk_confirm_delete == id
      delete_button = h("button.sk-btn#{confirming ? '.sk-btn--danger' : '.sk-btn--icon'}", {
                          attrs: { type: 'button', 'aria-label': confirming ? 'Confirm delete' : "Delete #{title}" },
                          on: { click: confirming ? -> { delete_save(id) } : -> { store(:sk_confirm_delete, id) } },
                        }, confirming ? 'Delete?' : [trash_icon])

      h('div.sk-save', { key: id }, [
        h('div.sk-save-info', [
          h('span.sk-save-title', title),
          h('span.sk-muted', details.join(' · ')),
        ]),
        h('div.sk-save-buttons', [
          h('a.sk-btn.sk-btn--primary', { attrs: { href: "/hotseat/#{id}" } }, 'Resume'),
          h('button.sk-btn.sk-btn--icon', {
              attrs: { type: 'button', 'aria-label': "Export #{title} as a file" },
              on: { click: -> { export_save(game_data) } },
            }, [download_icon]),
          delete_button,
        ]),
      ])
    end

    def export_save(game_data)
      json = JSON.dump(game_data)
      name = "#{game_data['id']}.json"
      %x{
        var blob = new Blob([#{json}], { type: 'application/json' });
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = #{name};
        document.body.appendChild(a);
        a.click();
        setTimeout(function() { URL.revokeObjectURL(a.href); a.remove(); }, 0);
      }
    end

    def delete_save(id)
      Lib::Storage.delete(id)
      store(:sk_confirm_delete, nil)
    end

    # ---- new game ----

    def default_seats
      [
        { 'name' => 'You', 'ai' => false, 'level' => 'normal' },
        { 'name' => 'AI 2', 'ai' => true, 'level' => 'normal' },
        { 'name' => 'AI 3', 'ai' => true, 'level' => 'hard' },
      ]
    end

    def seats
      @sk_seats || default_seats
    end

    def update_seat(index, changes, skip: false)
      updated = seats.map(&:dup)
      updated[index] = updated[index].merge(changes)
      store(:sk_seats, updated, skip: skip)
    end

    def render_new_game
      list = seats
      children = [
        h('h2#sk-new-title', 'New game'),
        h('div.sk-saves', list.each_with_index.map { |seat, i| render_seat(seat, i, list.size) }),
        h('div.sk-actions', [
          h('button.sk-btn', {
              attrs: { type: 'button', disabled: list.size >= MAX_SEATS },
              on: { click: -> { add_seat } },
            }, '+ Add seat'),
          h('button.sk-btn', { attrs: { type: 'button' }, on: { click: -> { shuffle_seats } } }, 'Shuffle seats'),
        ]),
        h('label.sk-check', [
          h(:input, {
              attrs: { type: 'checkbox', checked: @sk_beginner },
              on: { change: ->(e) { store(:sk_beginner, Native(e).target.checked, skip: true) } },
            }),
          h(:span, [h(:strong, 'Beginner game'), h('span.sk-muted', 'Simpler privates, more tiles available')]),
        ]),
      ]
      children << h('p.sk-error', { attrs: { role: 'alert' } }, @sk_error) if @sk_error
      children << h('button.sk-btn.sk-btn--primary.sk-btn--wide', {
                      attrs: { type: 'button' },
                      on: { click: -> { start_game } },
                    }, "Start game · #{list.size} players")
      children << h('p.sk-muted', 'Games save automatically in this browser. Export a file to move a game ' \
                                  'to another device.')

      h('section#sk-new.sk-panel.sk-new', { attrs: { 'aria-labelledby': 'sk-new-title' } }, children)
    end

    def render_seat(seat, index, total)
      n = index + 1
      segment = lambda do |label, ai|
        h(:button, {
            attrs: { type: 'button', 'aria-pressed': (seat['ai'] == ai).to_s },
            on: { click: -> { update_seat(index, 'ai' => ai) } },
          }, label)
      end

      children = [
        h('span.sk-seat-no', { attrs: { 'aria-hidden': 'true' } }, n.to_s),
        h('label.sk-field.sk-field--grow', [
          "Seat #{n} name",
          h(:input, {
              key: "sk_seat_name_#{index}",
              attrs: { type: 'text', value: seat['name'], maxlength: 30, autocomplete: 'off' },
              on: { input: ->(e) { update_seat(index, { 'name' => Native(e).target.value }, skip: true) } },
            }),
        ]),
        h('div.sk-seg', { attrs: { role: 'group', 'aria-label': "Seat #{n} is played by" } }, [
          segment.call('Human', false),
          segment.call('AI', true),
        ]),
      ]
      if seat['ai']
        children << h('label.sk-field', [
          'Level',
          h(:select, {
              on: { change: ->(e) { update_seat(index, 'level' => Native(e).target.value) } },
            }, LEVELS.map do |level|
              h(:option, { attrs: { value: level, selected: seat['level'] == level } }, level.capitalize)
            end),
        ])
      end
      if total > MIN_SEATS
        children << h('button.sk-btn.sk-btn--icon', {
                        attrs: { type: 'button', 'aria-label': "Remove seat #{n}" },
                        on: { click: -> { remove_seat(index) } },
                      }, [close_icon])
      end

      h('div.sk-seat', { key: "sk_seat_#{index}" }, children)
    end

    def add_seat
      list = seats.map(&:dup)
      return if list.size >= MAX_SEATS

      n = list.size + 1
      list << { 'name' => "AI #{n}", 'ai' => true, 'level' => 'normal' }
      store(:sk_seats, list)
    end

    def remove_seat(index)
      list = seats.map(&:dup)
      return if list.size <= MIN_SEATS

      list.delete_at(index)
      store(:sk_seats, list)
    end

    def shuffle_seats
      store(:sk_seats, seats.map(&:dup).shuffle)
    end

    def start_game
      list = seats
      names = list.map { |s| s['name'].to_s.gsub(/\s+/, ' ').strip }
      return store(:sk_error, 'Every seat needs a name.') if names.any?(&:empty?)
      return store(:sk_error, 'Seat names must be different.') if names.uniq.size != names.size

      store(:sk_error, nil, skip: true)
      # Player ids are their seat index, as in View::CreateGame.
      ai_ids = list.each_index.select { |i| list[i]['ai'] }
      levels = ai_ids.to_h { |i| [i.to_s, list[i]['level'] || 'normal'] }

      create_hotseat(
        id: Time.now.to_i,
        players: names.map.with_index { |name, i| { name: name, id: i } },
        title: TITLE,
        description: '',
        min_players: names.size,
        max_players: names.size,
        settings: {
          optional_rules: @sk_beginner ? [:beginner_game] : [],
          ai_players: ai_ids,
          ai_levels: levels,
        },
      )
    end

    # ---- icons (decorative; buttons carry aria-labels) ----

    def svg_icon(paths, color = 'currentColor')
      h(:svg, {
          attrs: {
            width: 18, height: 18, viewBox: '0 0 24 24', fill: 'none', stroke: color,
            'stroke-width': 2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true'
          },
        }, paths.map { |d| h(:path, { attrs: { d: d } }) })
    end

    def download_icon
      svg_icon(['M12 3v12', 'M7 10l5 5 5-5', 'M5 21h14'])
    end

    def trash_icon
      svg_icon(['M4 7h16', 'M10 11v6M14 11v6', 'M6 7l1 13h10l1-13', 'M9 7V4h6v3'], '#A33A2E')
    end

    def close_icon
      svg_icon(['M6 6l12 12', 'M18 6L6 18'])
    end
  end
end
