# frozen_string_literal: true

# Site-wide look for the 1889 Shikoku build: design tokens, the top bar and
# the home page. Rendered once by View::Navigation (present on every page).
# The game screen's own rules live in view/game/one_screen_style.rb.
module View
  SHIKOKU_SHELL_STYLE = <<~CSS
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+JP:wght@600&family=Space+Grotesk:wght@500;600;700&display=swap');
    :root {
      --sk-ground: #EEF1F5; --sk-card: #FFFFFF; --sk-line: #DCE1E8; --sk-line-2: #C9D0DA;
      --sk-ink: #18202B; --sk-muted: #556070; --sk-faint: #F2F4F7; --sk-soft: #F7F8FA;
      --sk-accent: #2B4ACB; --sk-accent-ink: #FFFFFF; --sk-accent-soft: #E8ECF6;
      --sk-warn: #A33A2E; --sk-good: #1F7A43; --sk-gold: #F2D457;
      --sk-sans: Inter, system-ui, -apple-system, 'Segoe UI', sans-serif;
      --sk-display: 'Space Grotesk', Inter, system-ui, sans-serif;
    }
    body { margin: 0; background: var(--sk-ground); color: var(--sk-ink); font-family: var(--sk-sans); }
    #app { font-family: var(--sk-sans); }
    #header.sk-topbar {
      display: flex; flex-wrap: wrap; align-items: center; gap: 12px 24px;
      margin: 0 -2vmin; padding: 12px 24px; background: var(--sk-card); border-bottom: 1px solid var(--sk-line);
    }
    .sk-brand { display: inline-flex; align-items: baseline; gap: 10px; color: var(--sk-ink); text-decoration: none; }
    .sk-brand-year { font: 700 22px/1 var(--sk-display); letter-spacing: -0.01em; }
    .sk-brand-kanji { font: 600 20px/1 'Noto Sans JP', var(--sk-sans); }
    .sk-brand-name { font: 500 14px/1 var(--sk-sans); color: var(--sk-muted); }
    .sk-nav { display: flex; flex-wrap: wrap; gap: 4px; margin-left: auto; }
    .sk-nav a {
      display: inline-flex; align-items: center; min-height: 40px; padding: 0 12px; border-radius: 10px;
      font: 600 14px/1 var(--sk-sans); color: var(--sk-ink); text-decoration: none;
    }
    .sk-nav a:hover { background: var(--sk-faint); }
    .sk-nav a:focus-visible, .sk-brand:focus-visible { outline: 2px solid var(--sk-accent); outline-offset: 2px; }

    /* ---- home ---- */
    #sk-home { max-width: 1240px; margin: 0 auto; padding: 28px 0 48px; display: flex; flex-wrap: wrap; gap: 24px; align-items: flex-start; }
    #sk-home .sk-main { flex: 999 1 560px; min-width: 0; display: flex; flex-direction: column; gap: 24px; }
    #sk-home .sk-panel { background: var(--sk-card); border: 1px solid var(--sk-line); border-radius: 18px; padding: 24px; box-sizing: border-box; }
    #sk-home .sk-hero { display: flex; flex-direction: column; gap: 14px; }
    #sk-home h1 { margin: 0; font: 700 40px/1.05 var(--sk-display); letter-spacing: -0.02em; }
    #sk-home h2 { margin: 0; font: 600 20px/1.2 var(--sk-display); }
    #sk-home p { margin: 0; }
    #sk-home .sk-lede { font: 500 16px/1.5 var(--sk-sans); color: var(--sk-muted); max-width: 46em; }
    #sk-home .sk-corps { display: flex; flex-wrap: wrap; gap: 8px; }
    #sk-home .sk-corp { display: inline-flex; align-items: center; gap: 8px; padding: 4px 10px 4px 4px; border-radius: 999px; background: var(--sk-faint); font: 500 13px/1.2 var(--sk-sans); }
    .sk-chip {
      display: inline-flex; align-items: center; justify-content: center; min-width: 30px; height: 30px; padding: 0 6px;
      box-sizing: border-box; border-radius: 7px; font: 700 12px/1 var(--sk-display); letter-spacing: .02em;
    }
    #sk-home .sk-actions { display: flex; flex-wrap: wrap; gap: 10px; }
    .sk-btn {
      display: inline-flex; align-items: center; justify-content: center; gap: 8px; min-height: 44px; padding: 0 18px;
      border-radius: 10px; border: 1px solid var(--sk-line-2); background: var(--sk-card); color: var(--sk-ink);
      font: 600 15px/1 var(--sk-sans); text-decoration: none; cursor: pointer; box-sizing: border-box;
    }
    .sk-btn:hover { background: var(--sk-soft); }
    .sk-btn--primary { background: var(--sk-accent); border-color: var(--sk-accent); color: var(--sk-accent-ink); }
    .sk-btn--primary:hover { background: #1F37A0; }
    .sk-btn--danger { color: var(--sk-warn); }
    .sk-btn--icon { width: 44px; padding: 0; }
    .sk-btn--wide { width: 100%; min-height: 52px; font-size: 16px; }
    .sk-btn:focus-visible { outline: 2px solid var(--sk-accent); outline-offset: 2px; }
    .sk-btn[disabled] { opacity: .5; cursor: not-allowed; }
    #sk-home .sk-section-head { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; }
    #sk-home .sk-muted { color: var(--sk-muted); font: 500 13px/1.4 var(--sk-sans); }
    #sk-home .sk-saves { display: flex; flex-direction: column; gap: 10px; }
    #sk-home .sk-save { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; padding: 14px; border: 1px solid var(--sk-line); border-radius: 12px; background: var(--sk-card); }
    #sk-home .sk-save-info { flex: 1 1 220px; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
    #sk-home .sk-save-title { font: 600 15px/1.25 var(--sk-sans); overflow-wrap: anywhere; }
    #sk-home .sk-save-buttons { display: flex; gap: 8px; flex-wrap: wrap; }
    #sk-home .sk-empty { padding: 18px; border: 1px dashed var(--sk-line-2); border-radius: 12px; color: var(--sk-muted); font: 500 14px/1.5 var(--sk-sans); }
    #sk-home .sk-new { flex: 1 1 380px; max-width: 460px; display: flex; flex-direction: column; gap: 16px; }
    #sk-home .sk-seat { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 10px; padding: 12px; border: 1px solid var(--sk-line); border-radius: 12px; }
    #sk-home .sk-seat-no { width: 34px; height: 34px; border-radius: 999px; background: var(--sk-faint); display: inline-flex; align-items: center; justify-content: center; font: 700 13px/1 var(--sk-sans); align-self: center; }
    #sk-home label.sk-field { display: flex; flex-direction: column; gap: 4px; font: 500 12px/1 var(--sk-sans); color: var(--sk-muted); }
    #sk-home .sk-field--grow { flex: 1 1 150px; }
    #sk-home input[type=text], #sk-home select {
      min-height: 42px; border: 1px solid var(--sk-line-2); border-radius: 8px; padding: 0 10px; box-sizing: border-box;
      font: 500 14px/1 var(--sk-sans); color: var(--sk-ink); background: var(--sk-card); width: 100%;
    }
    #sk-home input:focus-visible, #sk-home select:focus-visible { outline: 2px solid var(--sk-accent); outline-offset: 1px; }
    #sk-home .sk-seg { display: inline-flex; gap: 2px; padding: 3px; border-radius: 10px; background: var(--sk-ground); }
    #sk-home .sk-seg button {
      min-height: 38px; padding: 0 14px; border: 0; border-radius: 8px; background: transparent; color: var(--sk-muted);
      font: 600 13px/1 var(--sk-sans); cursor: pointer;
    }
    #sk-home .sk-seg button[aria-pressed=true] { background: var(--sk-card); color: var(--sk-ink); box-shadow: 0 1px 2px rgba(24,32,43,.14); }
    #sk-home .sk-seg button:focus-visible { outline: 2px solid var(--sk-accent); }
    #sk-home .sk-check { display: flex; align-items: flex-start; gap: 10px; padding: 12px; border-radius: 12px; background: var(--sk-soft); cursor: pointer; }
    #sk-home .sk-check input { width: 20px; height: 20px; margin: 0; accent-color: var(--sk-accent); }
    #sk-home .sk-check strong { display: block; font: 600 14px/1.3 var(--sk-sans); }
    #sk-home .sk-error { color: var(--sk-warn); font: 600 13px/1.4 var(--sk-sans); }
    @media (max-width: 640px) {
      #header.sk-topbar { padding: 10px 14px; }
      #sk-home { padding-top: 16px; }
      #sk-home h1 { font-size: 30px; }
      #sk-home .sk-panel { padding: 18px; }
    }
  CSS
end
