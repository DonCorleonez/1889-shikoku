// Screenshots of the running self-host stack, for reviewing the UI without a
// local browser. Usage: node screenshots.mjs <out-dir>  (playwright installed next to it)
import { chromium } from 'playwright';
import fs from 'fs';

const out = process.argv[2];
const base = process.env.BASE_URL || 'http://127.0.0.1:8189';
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const problems = [];

// Seed a hotseat save from the 1889 fixture, cut at `n` actions. AI seats are
// paused so the position stays put while the screenshot is taken.
async function seed(page, n, id) {
  await page.evaluate(async ([n, id]) => {
    const r = await fetch('/fixtures/1889/314.json');
    const d = await r.json();
    d.actions = d.actions.slice(0, n);
    d.id = id; d.mode = 'hotseat'; d.status = 'active';
    d.description = n > 240 ? 'Sunday game' : 'Practice vs Hard';
    delete d.result; delete d.game_end_reason;
    d.settings = Object.assign({}, d.settings, {
      ai_players: [639, 344], ai_levels: { '639': 'normal', '344': 'hard' }, ai_paused: true,
    });
    localStorage.setItem(id, JSON.stringify(d));
  }, [n, id]);
}

async function shot(name, path, { width = 1440, height = 1000, seeds = [], theme = 'light' } = {}) {
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
  await ctx.addInitScript((t) => { try { localStorage.setItem('sk_theme', t); } catch (e) {} }, theme);
  const page = await ctx.newPage();
  page.on('pageerror', (e) => problems.push(`${name}: pageerror: ${e.message}`));
  page.on('console', (m) => { if (m.type() === 'error') problems.push(`${name}: console: ${m.text()}`); });
  if (seeds.length) {
    await page.goto(base + '/new_game', { waitUntil: 'load' });
    for (const [n, id] of seeds) await seed(page, n, id);
  }
  await page.goto(base + path, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.screenshot({ path: `${out}/${name}.png`, fullPage: true });
  const text = await page.evaluate(() => document.body.innerText.slice(0, 4000));
  fs.writeFileSync(`${out}/${name}.txt`, text);
  await ctx.close();
}

const saves = [[262, 'hs_shotor_262'], [230, 'hs_shotsr_230']];
await shot('01-home-empty', '/');
await shot('02-home-saves', '/', { seeds: saves });
await shot('03-game-or', '/hotseat/hs_shotor_262', { seeds: saves });
await shot('04-game-sr', '/hotseat/hs_shotsr_230', { seeds: saves });
await shot('05-game-or-phone', '/hotseat/hs_shotor_262', { width: 390, height: 844, seeds: saves });
await shot('06-home-phone', '/', { width: 390, height: 844, seeds: saves });
await shot('07-game-classic', '/hotseat/hs_shotor_262?classic=1', { seeds: saves });
await shot('08-new-game-form', '/new_game');
await shot('09-game-or-dark', '/hotseat/hs_shotor_262', { seeds: saves, theme: 'dark' });
await shot('10-home-dark', '/', { seeds: saves, theme: 'dark' });
await shot('11-game-sr-dark', '/hotseat/hs_shotsr_230', { seeds: saves, theme: 'dark' });

fs.writeFileSync(`${out}/problems.txt`, problems.join('\n') + '\n');
console.log(problems.length ? problems.join('\n') : 'no page errors');
await browser.close();
