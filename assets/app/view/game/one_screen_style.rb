# frozen_string_literal: true

# Scoped stylesheet for the opt-in Shikoku one-screen view (?onescreen=1).
# Inlined (not under public/assets, which is git-ignored build output).
module View
  module Game
    ONE_SCREEN_STYLE = <<~'CSS'
      /* 1889 Shikoku, opt-in workspace (?onescreen=1). Scoped to #shikoku-one-screen. */
      #shikoku-one-screen {
        --forest: #133f33; --forest-2: #1b5546; --parchment: #f6f1e6;
        --paper: #fffaf0; --sand: #d8c8aa; --ink: #262e2a; --line: #d9cdb7;
        color: var(--ink); background: var(--parchment); font-family: system-ui, sans-serif;
        font-size: 12px; min-height: 90vh; width: 100%; overflow: hidden;
        box-sizing: border-box; contain: style;
      }
      #shikoku-one-screen *, #shikoku-one-screen *::before, #shikoku-one-screen *::after {box-sizing: border-box;}
      #shikoku-one-screen .os-main-header {display:flex; align-items:center; justify-content:space-between; gap:14px; padding:10px 16px; background:var(--forest); color:white; min-height:52px;}
      #shikoku-one-screen .os-brand {font-family:Georgia,serif; font-size:20px; letter-spacing:.07em; white-space:nowrap;}
      #shikoku-one-screen .os-timeline {display:flex; gap:5px; align-items:center; padding:8px 11px; overflow:auto hidden; white-space:nowrap; background:#fbf7ed; border-bottom:1px solid var(--line); scrollbar-width:thin;}
      #shikoku-one-screen .os-round {display:flex;align-items:center;gap:5px; padding:6px 9px; border-radius:6px; background:#eee7d9; color:#524d43;}
      #shikoku-one-screen .os-round--complete {color:#105c46;background:#dceee5;}
      #shikoku-one-screen .os-round--current {color:#fff;background:var(--forest);font-weight:700;}
      #shikoku-one-screen .os-round--projected {border:1px dashed #bcb09a;background:transparent;}
      #shikoku-one-screen .os-round-projected {font-size:9px;opacity:.8;}
      #shikoku-one-screen .os-round-indicator {font-weight:900;}
      #shikoku-one-screen .os-workspace {display:grid;grid-template-columns:minmax(285px,28%) minmax(350px,1fr) minmax(335px,31%); gap:8px; padding:8px; min-height:320px; height:calc((100dvh - 182px) * .62);}
      #shikoku-one-screen .os-financial-pane {display:grid; grid-template-rows: 47% minmax(0,1fr); gap:8px; min-width:0; min-height:0;}
      #shikoku-one-screen .os-card {background:var(--paper);border:1px solid var(--line);border-radius:7px;min-width:0;min-height:0;display:flex;flex-direction:column;overflow:hidden;}
      #shikoku-one-screen .os-card-heading {font:700 15px Georgia,serif;padding:8px 11px;border-bottom:1px solid var(--line); flex-shrink:0;}
      #shikoku-one-screen .os-card-body {padding:6px;overflow:auto;min-height:0;flex:1;scrollbar-width:thin;}
      #shikoku-one-screen .os-table {border-collapse:collapse;font-size:11px;min-width:100%;width:max-content;color:var(--ink);}
      #shikoku-one-screen .os-table td,#shikoku-one-screen .os-table th {border:1px solid #e1d6c4;padding:5px 6px;text-align:right;white-space:nowrap;}
      #shikoku-one-screen .os-table td:nth-child(1),#shikoku-one-screen .os-table th:nth-child(1),#shikoku-one-screen .os-table td:nth-child(2) {text-align:left;}
      #shikoku-one-screen .os-table th {background:#eee7da;position:sticky;top:0;z-index:1;}
      #shikoku-one-screen .os-table tbody tr:nth-child(2n) {background:#f4efe6;}
      #shikoku-one-screen .os-corp-chip {display:inline-block; min-width:25px; border-radius:3px; padding:3px; text-align:center; font-weight:bold;}
      #shikoku-one-screen .os-map-card .os-card-body {display:flex;align-items:center;justify-content:center; background:#e4ece7;}
      #shikoku-one-screen .os-map-card .os-card-body>div {max-width:none;}
      #shikoku-one-screen .os-action-card .os-card-body {padding:10px;}
      #shikoku-one-screen .os-current-round {padding:7px;border-radius:4px;background:#ebede3;color:var(--forest);font-weight:600;}
      #shikoku-one-screen .os-action-form {margin-top:10px; min-height:130px;}
      #shikoku-one-screen .os-tools {border-top:1px solid var(--line);margin-top:10px;padding-top:7px;}
      #shikoku-one-screen .os-data-strip {display:grid;grid-template-columns: minmax(260px,32%) minmax(220px,19%) minmax(260px,28%) minmax(185px,1fr);gap:8px;padding:0 8px 8px;height:calc((100dvh - 182px) * .38);min-height:190px;}
      #shikoku-one-screen .os-stock-zoom {width:750px;transform:scale(.55);transform-origin:top left; height:550px;}
      #shikoku-one-screen .os-market-card .os-card-body {overflow:auto;}
      #shikoku-one-screen .os-bank-summary {line-height:1.6;background:#f0eadf;padding:6px;margin-bottom:5px;}
      #shikoku-one-screen .os-tile-card .os-card-body {overflow:auto;}
      #shikoku-one-screen .os-tile-card #tile_manifest {margin:4px;display:flex;flex-flow:row wrap;}
      #shikoku-one-screen .os-log-card .os-card-body {font-size:11px;}
      #shikoku-one-screen a,#shikoku-one-screen button {cursor:pointer;}
      #shikoku-one-screen button:focus-visible,#shikoku-one-screen a:focus-visible {outline:2px solid #ec8b38;outline-offset:2px;}
      @media (max-width: 1380px) {
        #shikoku-one-screen .os-workspace {grid-template-columns:minmax(240px,27%) minmax(300px,1fr) minmax(300px,34%);height:calc((100dvh - 182px) * .62);}
        #shikoku-one-screen .os-data-strip {grid-template-columns:30% 20% 28% 22%;height:calc((100dvh - 182px) * .38);}
        #shikoku-one-screen .os-main-header {gap:8px;font-size:10px;}
      }
      @media (max-width: 1050px) {
        #shikoku-one-screen {overflow:visible;}
        #shikoku-one-screen .os-workspace {grid-template-columns:1fr 1fr;grid-template-rows:minmax(370px,50vh) minmax(270px,35vh);height:auto;}
        #shikoku-one-screen .os-financial-pane {grid-column:1/-1;grid-row:2;grid-template-columns:1fr 1fr;grid-template-rows:1fr;}
        #shikoku-one-screen .os-data-strip {grid-template-columns:1fr 1fr;height:auto;}
        #shikoku-one-screen .os-data-strip>.os-card {height:260px;}
      }
      @media (max-width: 650px) {
        #shikoku-one-screen .os-main-header {flex-wrap:wrap;}
        #shikoku-one-screen .os-workspace {display:flex;flex-direction:column;height:auto;}
        #shikoku-one-screen .os-map-card {height:45vh;min-height:320px;}
        #shikoku-one-screen .os-action-card {min-height:300px;max-height:calc((100dvh - 182px) * .62);}
        #shikoku-one-screen .os-financial-pane {display:grid;grid-template-columns:1fr;grid-template-rows:180px 220px;}
        #shikoku-one-screen .os-data-strip {grid-template-columns:1fr;}
        #shikoku-one-screen .os-data-strip>.os-card {height:240px;}
      }
      #shikoku-one-screen .os-market-heading {display:flex;justify-content:space-between;align-items:center;gap:8px;}
      #shikoku-one-screen .os-market-heading button {border:1px solid #d5c7ae;background:#fff8eb;padding:3px 8px;border-radius:4px;font-size:11px;}
      #shikoku-one-screen .os-market-card.os-market-expanded {position:fixed;inset:5vh 5vw;z-index:20000;border:2px solid #1b5546;box-shadow:0 0 0 100vmax rgba(15,35,29,.6);}
      #shikoku-one-screen .os-market-card.os-market-expanded .os-stock-zoom {transform:scale(1);width:770px;height:600px;}
    CSS
  end
end
