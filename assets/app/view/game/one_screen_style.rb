# frozen_string_literal: true

# Scoped stylesheet for the 1889 Shikoku one-screen game view.
# Inlined (not under public/assets, which is git-ignored build output).
# Colours and fonts come from the --sk-* tokens in view/shikoku_style.rb.
module View
  module Game
    ONE_SCREEN_STYLE = <<~CSS
      /* 1889 Shikoku one-screen workspace. Scoped to #shikoku-one-screen (plus the AI bar above it). */
      #shikoku-one-screen {
        color: var(--sk-ink); font-family: var(--sk-sans, system-ui, sans-serif); font-size: 13px;
        width: 100%; box-sizing: border-box; display: flex; flex-direction: column; gap: 12px;
      }
      #shikoku-one-screen *, #shikoku-one-screen *::before, #shikoku-one-screen *::after { box-sizing: border-box; }
      #shikoku-one-screen .os-num { font-variant-numeric: tabular-nums; }
      #shikoku-one-screen .os-muted { color: var(--sk-muted); font-size: 12px; }

      /* status bar */
      #shikoku-one-screen .os-status {
        display: flex; flex-wrap: wrap; align-items: center; gap: 12px 20px; padding: 12px 16px;
        background: var(--sk-card); border: 1px solid var(--sk-line); border-radius: 14px;
      }
      #shikoku-one-screen .os-status-pills { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; min-width: 0; }
      #shikoku-one-screen .os-pill { border-radius: 999px; padding: 7px 12px; background: var(--sk-faint); font: 600 13px/1 var(--sk-sans); white-space: nowrap; }
      #shikoku-one-screen .os-pill--round { background: var(--sk-accent); color: var(--sk-accent-ink); font-weight: 700; }
      #shikoku-one-screen .os-status-activity { color: var(--sk-muted); font: 500 13px/1.3 var(--sk-sans); }
      #shikoku-one-screen .os-bank { margin-left: auto; min-width: 160px; display: flex; flex-direction: column; gap: 5px; }
      #shikoku-one-screen .os-bank-row { display: flex; justify-content: space-between; font: 500 12px/1 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-bank-row strong { color: var(--sk-ink); }
      #shikoku-one-screen .os-meter { height: 6px; border-radius: 999px; background: var(--sk-track); overflow: hidden; }
      #shikoku-one-screen .os-meter-fill { height: 100%; background: var(--sk-strong); border-radius: 999px; }

      /* round tracker */
      #shikoku-one-screen .os-timeline { display: flex; gap: 8px; align-items: center; overflow-x: auto; padding: 2px 2px 6px; scrollbar-width: thin; }
      #shikoku-one-screen .os-round {
        display: inline-flex; align-items: center; gap: 7px; padding: 8px 12px; border-radius: 999px; white-space: nowrap;
        font: 600 13px/1 var(--sk-sans); background: var(--sk-card); color: var(--sk-muted); border: 1px solid var(--sk-line);
      }
      #shikoku-one-screen .os-round--complete .os-round-indicator { color: var(--sk-muted); }
      #shikoku-one-screen .os-round--current { background: var(--sk-ink); color: var(--sk-card); border-color: var(--sk-ink); }
      #shikoku-one-screen .os-round--current .os-round-indicator { color: var(--sk-accent); }
      #shikoku-one-screen .os-round--projected { background: transparent; border: 1px dashed var(--sk-line-2); }
      #shikoku-one-screen .os-round-projected { font: 600 10px/1 var(--sk-sans); letter-spacing: .06em; text-transform: uppercase; color: var(--sk-muted); }
      #shikoku-one-screen .os-round-indicator { font-weight: 900; }

      /* top band: players side by side + latest moves */
      #shikoku-one-screen .os-band { display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start; }
      #shikoku-one-screen .os-players-card { flex: 999 1 640px; }
      #shikoku-one-screen .os-latest-card { flex: 1 1 360px; max-width: 520px; }
      #shikoku-one-screen .os-players-card .os-players { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 10px; }
      #shikoku-one-screen .os-card-link { font: 600 13px/1 var(--sk-sans); color: var(--sk-accent); text-decoration: none; }
      #shikoku-one-screen .os-card-link:hover { text-decoration: underline; }
      #shikoku-one-screen .os-latest { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; }
      #shikoku-one-screen .os-latest-item { display: flex; align-items: flex-start; gap: 10px; padding: 7px 0; border-top: 1px solid var(--sk-divider); font: 500 13px/1.45 var(--sk-sans); color: var(--sk-ink); }
      #shikoku-one-screen .os-latest-item:first-child { border-top: 0; }
      #shikoku-one-screen .os-latest-item:first-child .os-latest-text { font-weight: 600; }
      #shikoku-one-screen .os-latest-item .os-chip, #shikoku-one-screen .os-latest-item .os-avatar { margin-top: 1px; }
      #shikoku-one-screen .os-latest-text { min-width: 0; overflow-wrap: anywhere; }
      #shikoku-one-screen .os-latest-text strong { font-weight: 700; }
      #shikoku-one-screen .os-latest-round { padding: 8px 0 4px; font: 700 11px/1.2 var(--sk-sans); letter-spacing: .06em; text-transform: uppercase; color: var(--sk-muted); }
      #shikoku-one-screen .os-latest-dot { width: 22px; height: 20px; flex: none; display: inline-flex; align-items: center; justify-content: center; }
      #shikoku-one-screen .os-latest-dot::before { content: ''; width: 6px; height: 6px; border-radius: 999px; background: var(--sk-line-2); }
      #shikoku-one-screen .os-avatar--xs { width: 22px; height: 20px; border-radius: 6px; font-size: 9px; }

      /* layout */
      #shikoku-one-screen .os-workspace { display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start; }
      #shikoku-one-screen .os-col { display: flex; flex-direction: column; gap: 16px; min-width: 0; }
      #shikoku-one-screen .os-col-left { flex: 1 1 290px; max-width: 360px; }
      #shikoku-one-screen .os-col-center { flex: 999 1 520px; }
      #shikoku-one-screen .os-col-right { flex: 1 1 320px; max-width: 400px; position: sticky; top: 12px; }
      #shikoku-one-screen .os-row { display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start; }
      #shikoku-one-screen .os-market-card { flex: 999 1 420px; }
      #shikoku-one-screen .os-trains-card { flex: 1 1 230px; }

      /* cards */
      #shikoku-one-screen .os-card {
        background: var(--sk-card); border: 1px solid var(--sk-line); border-radius: 14px; padding: 16px;
        display: flex; flex-direction: column; gap: 12px; min-width: 0;
      }
      #shikoku-one-screen .os-card-heading { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
      #shikoku-one-screen .os-card-title { margin: 0; font: 600 13px/1.2 var(--sk-display); letter-spacing: .08em; text-transform: uppercase; color: var(--sk-muted); }
      #shikoku-one-screen .os-card-hint { font: 500 12px/1 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-card-body { min-width: 0; }
      #shikoku-one-screen .os-btn {
        min-height: 36px; padding: 0 12px; border-radius: 8px; border: 1px solid var(--sk-line-2); background: var(--sk-card);
        color: var(--sk-ink); font: 600 13px/1 var(--sk-sans); cursor: pointer;
      }

      /* players */
      #shikoku-one-screen .os-players { display: flex; flex-direction: column; gap: 10px; }
      #shikoku-one-screen .os-player { border: 1px solid var(--sk-line); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 10px; }
      #shikoku-one-screen .os-player--active { border: 2px solid var(--sk-accent); padding: 11px; }
      #shikoku-one-screen .os-player-head { display: flex; align-items: center; gap: 10px; }
      #shikoku-one-screen .os-avatar {
        width: 32px; height: 32px; flex: none; border-radius: 999px; display: inline-flex; align-items: center;
        justify-content: center; font: 700 12px/1 var(--sk-sans);
      }
      #shikoku-one-screen .os-avatar--lg { width: 40px; height: 40px; font-size: 14px; }
      #shikoku-one-screen .os-player-name { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
      #shikoku-one-screen .os-player-name strong { font: 600 15px/1.1 var(--sk-sans); overflow-wrap: anywhere; }
      #shikoku-one-screen .os-badges { display: inline-flex; flex-wrap: wrap; gap: 6px; }
      #shikoku-one-screen .os-badge { border-radius: 999px; padding: 3px 7px; font: 600 11px/1 var(--sk-sans); background: var(--sk-faint); color: var(--sk-muted); white-space: nowrap; }
      #shikoku-one-screen .os-badge--human { background: var(--sk-accent-soft); color: var(--sk-accent); }
      #shikoku-one-screen .os-badge--priority { background: var(--sk-gold); color: var(--sk-gold-ink); }
      #shikoku-one-screen .os-badge--active { background: var(--sk-accent); color: var(--sk-accent-ink); }
      #shikoku-one-screen .os-player-cash { text-align: right; display: flex; flex-direction: column; gap: 2px; font: 500 12px/1.2 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-player-cash strong { font: 700 18px/1 var(--sk-display); color: var(--sk-ink); }
      #shikoku-one-screen .os-player-stats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
      #shikoku-one-screen .os-stat { display: flex; flex-direction: column; gap: 3px; font: 500 12px/1.2 var(--sk-sans); color: var(--sk-muted); min-width: 0; }
      #shikoku-one-screen .os-stat strong { font: 600 14px/1.2 var(--sk-sans); color: var(--sk-ink); }
      #shikoku-one-screen .os-holds { display: flex; flex-wrap: wrap; gap: 4px; }

      /* corporations */
      #shikoku-one-screen .os-chip {
        display: inline-flex; align-items: center; justify-content: center; min-width: 28px; height: 28px; padding: 0 5px; flex: none;
        border-radius: 7px; font: 700 11px/1 var(--sk-display); letter-spacing: .02em;
      }
      #shikoku-one-screen .os-chip--sm { min-width: 22px; height: 20px; font-size: 9px; border-radius: 5px; padding: 0 3px; }
      #shikoku-one-screen .os-chip--lg { min-width: 42px; height: 42px; font-size: 15px; border-radius: 10px; }
      #shikoku-one-screen .os-legend { display: flex; flex-wrap: wrap; gap: 10px; font: 500 12px/1.2 var(--sk-sans); color: var(--sk-muted); margin-bottom: 8px; }
      #shikoku-one-screen .os-legend-item { display: inline-flex; align-items: center; gap: 4px; }
      #shikoku-one-screen .os-swatch { width: 12px; height: 12px; border-radius: 3px; border: 1px solid var(--sk-line-2); display: inline-block; }
      #shikoku-one-screen .os-corps { display: flex; flex-direction: column; gap: 4px; }
      #shikoku-one-screen .os-corp { display: flex; flex-direction: column; gap: 8px; padding: 10px; border-radius: 10px; }
      #shikoku-one-screen .os-corp--active { background: var(--sk-soft); outline: 2px solid var(--sk-accent); }
      #shikoku-one-screen .os-corp--unstarted .os-corp-name span { color: var(--sk-ink); }
      #shikoku-one-screen .os-corp-head { display: flex; align-items: center; gap: 10px; }
      #shikoku-one-screen .os-corp-name { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; font: 500 12px/1.2 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-corp-name strong { font: 600 13px/1.2 var(--sk-sans); color: var(--sk-ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      #shikoku-one-screen .os-order { font: 600 12px/1 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-corp-money { display: flex; align-items: baseline; gap: 10px; font: 500 12px/1 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-price { font: 700 16px/1 var(--sk-display); color: var(--sk-ink); }
      #shikoku-one-screen .os-trend { color: var(--sk-good); font-weight: 600; }
      #shikoku-one-screen .os-trend--down { color: var(--sk-warn); }
      #shikoku-one-screen .os-corp-cash { margin-left: auto; }
      #shikoku-one-screen .os-corp-cash strong { color: var(--sk-ink); }
      #shikoku-one-screen .os-sharebar { display: flex; gap: 2px; height: 8px; border-radius: 999px; overflow: hidden; background: var(--sk-ground); }
      #shikoku-one-screen .os-share { flex-basis: 0; height: 100%; }
      #shikoku-one-screen .os-corp-assets { display: flex; align-items: center; gap: 6px; }
      #shikoku-one-screen .os-trains { display: inline-flex; flex-wrap: wrap; gap: 4px; }
      #shikoku-one-screen .os-train { border: 1px solid var(--sk-line-2); border-radius: 5px; padding: 3px 6px; font: 700 11px/1 var(--sk-sans); }
      #shikoku-one-screen .os-train--big { min-width: 34px; height: 26px; display: inline-flex; align-items: center; justify-content: center; background: var(--sk-strong); color: var(--sk-card); border: 0; font: 700 13px/1 var(--sk-display); }
      #shikoku-one-screen .os-no-train { color: var(--sk-warn); font: 500 12px/1 var(--sk-sans); }
      #shikoku-one-screen .os-tokens { margin-left: auto; display: inline-flex; gap: 4px; align-items: center; }
      #shikoku-one-screen .os-token { width: 10px; height: 10px; border-radius: 999px; border: 1.5px solid; display: inline-block; }

      /* map */
      #shikoku-one-screen .os-map-card .os-card-body { background: var(--sk-sea); border-radius: 12px; overflow: auto; max-height: 78vh; }
      /* margin:auto (not flex centering) keeps an oversized map scrollable to its top-left edge. */
      #shikoku-one-screen .os-map { display: flex; }
      #shikoku-one-screen .os-map > div { max-width: none; margin: auto; }

      #shikoku-one-screen #map_controls { display: flex; flex-wrap: wrap; gap: 6px; padding: 8px; }

      /* flat board: softer flat tile colours and a thin, even hex grid.
         Hexes are <g fill=... stroke="black"> groups; CSS beats SVG presentation
         attributes, and the selected hex (stroke-width="5") keeps its outline. */
      #shikoku-one-screen svg#map g[fill="#EAE0C8"] { fill: #F2EEE3; }
      #shikoku-one-screen svg#map g[fill="#fde900"] { fill: #F5D547; }
      #shikoku-one-screen svg#map g[fill="#71bf44"] { fill: #7CC283; }
      #shikoku-one-screen svg#map g[fill="#cb7745"] { fill: #C99067; }
      #shikoku-one-screen svg#map g[fill="#bcbdc0"] { fill: #C8CDD4; }
      #shikoku-one-screen svg#map g[fill="#ec232a"] { fill: #DE5A50; }
      #shikoku-one-screen svg#map #map-hexes > g[stroke="black"]:not([stroke-width]) { stroke: #7F8A99; stroke-width: 1.5; }
      #shikoku-one-screen svg#map #map-hexes > g[stroke="black"]:not([stroke-width]) > polygon:first-of-type { stroke-linejoin: round; }
      #shikoku-one-screen svg#map text { font-family: var(--sk-sans); }
      #shikoku-one-screen #map_zoom { padding: 8px 8px 0; }

      /* market */
      #shikoku-one-screen .os-market-heading { display: inline-flex; align-items: center; gap: 10px; }
      #shikoku-one-screen .os-market-card .os-card-body { overflow: auto; }
      /* zoom (unlike transform) shrinks the layout box too, so nothing is clipped */
      #shikoku-one-screen .os-stock-zoom { zoom: .85; width: max-content; }
      #shikoku-one-screen .os-market-card .os-card-body { max-height: 460px; }
      #shikoku-one-screen .os-market-expanded .os-card-body { max-height: none; }
      #shikoku-one-screen .os-market-expanded .os-stock-zoom { zoom: 1; }

      /* trains & phase */
      #shikoku-one-screen .os-phases { display: flex; gap: 4px; }
      #shikoku-one-screen .os-phase { flex: 1; text-align: center; padding: 8px 0; border-radius: 8px; font: 700 13px/1 var(--sk-sans); }
      #shikoku-one-screen .os-phase--past { background: var(--sk-track); color: var(--sk-muted); }
      #shikoku-one-screen .os-phase--now { background: var(--sk-ink); color: var(--sk-card); }
      #shikoku-one-screen .os-phase--next { background: var(--sk-card); border: 1px solid var(--sk-line-2); }
      #shikoku-one-screen .os-note { margin: 8px 0 0; font: 500 12px/1.5 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-note--alert { color: var(--sk-warn); font-weight: 600; }
      #shikoku-one-screen .os-depot { display: flex; flex-direction: column; margin-top: 8px; }
      #shikoku-one-screen .os-depot-row { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid var(--sk-divider); }
      #shikoku-one-screen .os-depot-row .os-muted { margin-left: auto; }

      /* action */
      #shikoku-one-screen .os-action-card { border: 2px solid var(--sk-accent); }
      #shikoku-one-screen .os-action-intro { display: flex; flex-direction: column; gap: 14px; }
      #shikoku-one-screen .os-action-head { display: flex; align-items: center; gap: 12px; }
      #shikoku-one-screen .os-action-title { display: flex; flex-direction: column; gap: 4px; min-width: 0; font: 500 13px/1.3 var(--sk-sans); color: var(--sk-muted); }
      #shikoku-one-screen .os-action-title strong { font: 700 18px/1.15 var(--sk-display); color: var(--sk-ink); }
      #shikoku-one-screen .os-steps { margin: 0; padding: 0; display: flex; list-style: none; }
      #shikoku-one-screen .os-step { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 6px; font: 500 12px/1 var(--sk-sans); color: var(--sk-soft-ink); }
      #shikoku-one-screen .os-step-dot { width: 10px; height: 10px; border-radius: 999px; background: var(--sk-line-2); }
      #shikoku-one-screen .os-step--done { color: var(--sk-muted); }
      #shikoku-one-screen .os-step--done .os-step-dot { background: var(--sk-muted); }
      #shikoku-one-screen .os-step--now { color: var(--sk-ink); font-weight: 700; }
      #shikoku-one-screen .os-step--now .os-step-dot { background: var(--sk-accent); box-shadow: 0 0 0 4px var(--sk-accent-ring); }
      #shikoku-one-screen .os-current-round { padding: 10px 12px; border-radius: 10px; background: var(--sk-soft); color: var(--sk-ink); font: 600 13px/1.4 var(--sk-sans); }
      #shikoku-one-screen .os-current-round h3, #shikoku-one-screen .os-current-round div { margin: 0; font: inherit; }
      #shikoku-one-screen .os-action-form { min-height: 80px; overflow-x: auto; }
      #shikoku-one-screen .os-action-form button, #shikoku-one-screen .os-tools button {
        min-height: 40px; padding: 0 14px; border-radius: 10px; border: 1px solid var(--sk-line-2); background: var(--sk-card);
        color: var(--sk-ink); font: 600 14px/1 var(--sk-sans); cursor: pointer; margin: 3px 4px 3px 0;
      }
      #shikoku-one-screen .os-action-form button:hover, #shikoku-one-screen .os-tools button:hover { background: var(--sk-soft); }
      #shikoku-one-screen .os-tools { border-top: 1px solid var(--sk-divider); padding-top: 12px; }
      #shikoku-one-screen .os-log-card .os-card-body { max-height: 420px; overflow: auto; font: 500 13px/1.45 var(--sk-sans); }

      /* Engine-rendered panels set light backgrounds inline; keep them as light
         "paper" with dark text in both themes so nothing turns unreadable. */
      #shikoku-one-screen .os-action-form, #shikoku-one-screen .os-current-round,
      #shikoku-one-screen .os-stock-zoom, #shikoku-one-screen .os-log-card .os-card-body,
      #shikoku-one-screen .os-details-body, #shikoku-one-screen #map_controls, #shikoku-one-screen #map_zoom {
        color: var(--sk-paper-ink);
      }
      html[data-theme=dark] #shikoku-one-screen .os-action-form,
      html[data-theme=dark] #shikoku-one-screen .os-log-card .os-card-body,
      html[data-theme=dark] #shikoku-one-screen .os-details-body,
      html[data-theme=dark] #shikoku-one-screen .os-market-card .os-card-body {
        background: var(--sk-paper); border-radius: 10px; padding: 10px;
      }
      html[data-theme=dark] #shikoku-one-screen .os-current-round { background: var(--sk-paper); }
      html[data-theme=dark] #shikoku-one-screen .os-action-form button, html[data-theme=dark] #shikoku-one-screen .os-tools button,
      html[data-theme=dark] #shikoku-one-screen #map_controls button, html[data-theme=dark] #shikoku-one-screen #map_zoom button {
        background: #FFFFFF; color: #141A24; border-color: #B9C2CF;
      }
      html[data-theme=dark] #shikoku-one-screen .os-tools { color: var(--sk-ink); }

      /* extras */
      #shikoku-one-screen .os-extra { display: flex; flex-direction: column; gap: 10px; }
      #shikoku-one-screen .os-details { background: var(--sk-card); border: 1px solid var(--sk-line); border-radius: 14px; padding: 0 16px; }
      #shikoku-one-screen .os-details > summary { cursor: pointer; padding: 14px 0; font: 600 13px/1.2 var(--sk-display); letter-spacing: .08em; text-transform: uppercase; color: var(--sk-muted); }
      #shikoku-one-screen .os-details-body { padding-bottom: 16px; overflow-x: auto; }
      #shikoku-one-screen .os-details #tile_manifest { display: flex; flex-flow: row wrap; }

      #shikoku-one-screen a, #shikoku-one-screen button { cursor: pointer; }
      #shikoku-one-screen button:focus-visible, #shikoku-one-screen a:focus-visible, #shikoku-one-screen summary:focus-visible {
        outline: 2px solid var(--sk-accent); outline-offset: 2px;
      }

      /* the game tab bar (Game, Entities, Map, ...) rendered by GamePage above this view */
      #game [aria-label="Game"] {
        background: var(--sk-card) !important; color: var(--sk-ink) !important; box-shadow: none !important;
        border-top: 0 !important; border-bottom: 1px solid var(--sk-line) !important; font: 600 15px/1 var(--sk-sans) !important;
        margin-bottom: 12px !important;
      }
      #game [aria-label="Game"] a, #game [aria-label="Game"] span { color: var(--sk-ink) !important; }
      #game #ai_players, #game #ai_players * { color: var(--sk-ink); }
      #game #ai_players select { background: var(--sk-card); }

      /* the AI seat bar, mounted once by GamePage just above this view */
      #game #ai_players {
        display: flex; flex-wrap: wrap; align-items: center; gap: 8px 12px; margin: 0 0 12px !important; padding: 10px 14px !important;
        background: var(--sk-card); border: 1px solid var(--sk-line) !important; border-radius: 14px !important; font: 500 13px/1.4 var(--sk-sans);
      }
      #game #ai_players button { min-height: 36px; padding: 0 12px; border-radius: 8px; border: 1px solid var(--sk-line-2); background: var(--sk-card); font: 600 13px/1 var(--sk-sans); cursor: pointer; }
      #game #ai_players select { min-height: 32px; border-radius: 6px; border: 1px solid var(--sk-line-2); }

      @media (max-width: 760px) {
        #shikoku-one-screen .os-col-left, #shikoku-one-screen .os-col-right { max-width: none; }
        #shikoku-one-screen .os-col-right { position: static; }
        #shikoku-one-screen .os-latest-card { max-width: none; }
        #shikoku-one-screen .os-bank { margin-left: 0; width: 100%; }
      }
    CSS
  end
end
