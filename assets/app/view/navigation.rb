# frozen_string_literal: true

require 'view/shikoku_style'

module View
  # Top bar for the 1889 Shikoku build. The #header id is kept because
  # GamePage scrolls past it to the game menu.
  class Navigation < Snabberb::Component
    needs :app_route, default: nil, store: true
    needs :user, default: nil, store: true
    needs :sk_theme, default: nil, store: true

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
        h('nav.sk-nav', { attrs: { 'aria-label': 'Main' } }, [*links, theme_toggle]),
      ])
    end

    # The theme lives on <html data-theme> (set before first paint by Index)
    # and in localStorage 'sk_theme'; this button flips both.
    def current_theme
      return @sk_theme if @sk_theme

      # server-side rendering has a stub document without documentElement
      theme = `(typeof document !== 'undefined' && document.documentElement &&
                document.documentElement.getAttribute('data-theme')) || 'light'`
      theme == 'dark' ? 'dark' : 'light'
    end

    def theme_toggle
      dark = current_theme == 'dark'
      toggle = lambda do
        next_theme = current_theme == 'dark' ? 'light' : 'dark'
        `document.documentElement.setAttribute('data-theme', #{next_theme})`
        `try { localStorage.setItem('sk_theme', #{next_theme}); } catch (e) {}`
        store(:sk_theme, next_theme)
      end
      icon = lambda do |klass, paths|
        h("svg.#{klass}", {
            attrs: {
              width: 18,
              height: 18,
              viewBox: '0 0 24 24',
              fill: 'none',
              stroke: 'currentColor',
              'stroke-width': 2,
              'stroke-linecap': 'round',
              'stroke-linejoin': 'round',
              'aria-hidden': 'true',
            },
          }, paths.map { |d| h(:path, { attrs: { d: d } }) })
      end

      h('button.sk-theme-toggle', {
          attrs: { type: 'button', 'aria-pressed': dark.to_s, title: 'Switch between light and dark mode' },
          on: { click: toggle },
        }, [
        icon.call('sk-icon-moon', ['M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z']),
        icon.call('sk-icon-sun', ['M12 4V2M12 22v-2M4 12H2M22 12h-2M5 5L3.6 3.6M20.4 20.4L19 19M5 19l-1.4 1.4M20.4 3.6L19 5',
                                  'M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10z']),
        h(:span, 'Dark mode'),
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
