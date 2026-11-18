# frozen_string_literal: true

require 'view/shikoku_style'

module View
  # Top bar for the 1889 Shikoku build. The #header id is kept because
  # GamePage scrolls past it to the game menu.
  class Navigation < Snabberb::Component
    needs :app_route, default: nil, store: true
    needs :user, default: nil, store: true

    def render
      links = [
        item('Tutorial', '/tutorial?action=1'),
        import_link,
      ]
      links << item('Admin', '/admin') if @user&.dig('settings', 'admin')

      brand = h('a.sk-brand', { attrs: { href: '/', title: '1889 Shikoku: home' } }, [
        h('span.sk-brand-year', '1889'),
        h('span.sk-brand-kanji', { attrs: { lang: 'ja' } }, '四国'),
        h('span.sk-brand-name', 'Shikoku'),
      ])

      h('header#header.sk-topbar', [
        h(:style, SHIKOKU_SHELL_STYLE),
        brand,
        h('nav.sk-nav', { attrs: { 'aria-label': 'Main' } }, links),
      ])
    end

    # Opens the create-game form on its JSON tab, where a save file is pasted
    # or uploaded.
    def import_link
      open_import = lambda do |event|
        Native(event).preventDefault
        store(:mode, :json, skip: true)
        store(:app_route, '/new_game')
      end
      h(:a, { attrs: { href: '/new_game' }, on: { click: open_import } }, 'Import save')
    end

    def item(name, href)
      h(:a, { attrs: { href: href } }, name)
    end
  end
end
