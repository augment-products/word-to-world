'use strict';
// Shared helpers for the headless-Chrome tests (no dependencies).
const { spawn, execFileSync } = require('child_process');
const fs = require('fs'), os = require('os'), path = require('path');
const { WS, CDP, getJSON } = require('../tools/inject.js');
const ROOT = path.resolve(__dirname, '..');
const sleep = ms => new Promise(r => setTimeout(r, ms));
function findChrome() {
  for (const c of [process.env.CHROME, 'google-chrome', 'chromium', 'chromium-browser', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome']) {
    if (!c) continue;
    try { execFileSync(c.includes('/') ? 'test' : 'which', c.includes('/') ? ['-x', c] : [c], { stdio: 'ignore' }); return c; } catch {}
  }
  return null;
}
function makeChecker() {
  const r = { pass: 0, fail: 0 };
  r.check = (n, c, x = '') => { c ? r.pass++ : r.fail++; console.log(`${c ? 'PASS' : 'FAIL'}  ${n}${x ? '  ' + x : ''}`); };
  return r;
}
const BROWSERS = new Set();   // every Chrome we start is killed when the test process exits, even after an exception
process.on('exit', () => { for (const p of BROWSERS) try { p.kill('SIGKILL'); } catch {} });
async function portBusy(port) {
  try { await getJSON(port, '/json/version'); return true; } catch { return false; }
}
async function startChrome(port, url) {
  const chrome = findChrome(); if (!chrome) return null;
  if (await portBusy(port)) throw new Error(`port ${port} is already in use (a Chrome left over from an earlier run?). Stop it and retry.`);
  const prof = fs.mkdtempSync(path.join(os.tmpdir(), 'i18n-chrome-'));
  const proc = spawn(chrome, ['--headless=new', '--no-sandbox', '--disable-gpu', `--remote-debugging-port=${port}`, `--user-data-dir=${prof}`, '--no-first-run', url], { stdio: 'ignore' });
  BROWSERS.add(proc); proc.on('exit', () => BROWSERS.delete(proc));
  // wait (up to 30 s) until the fixture page itself is listed, then until it has finished loading (slow first start of Chrome)
  let t = [];
  for (let i = 0; i < 150 && !t.length; i++) { await sleep(200); try { t = (await getJSON(port, '/json/list')).filter(x => x.type === 'page' && x.url === url); } catch {} }
  if (!t.length) { proc.kill('SIGKILL'); throw new Error(`Chrome did not open ${url} on port ${port} within 30 s`); }
  const ws = new WS(`ws://127.0.0.1:${port}${new URL(t[0].webSocketDebuggerUrl).pathname}`); await ws.connect();
  const cdp = new CDP(ws);
  // The target URL can match while the document is still the blank page, whose
  // readyState is already "complete". Wait until the fixture document has a body,
  // and see that twice so a navigation in between is not treated as ready.
  let ready = false;
  for (let i = 0; i < 100 && !ready; i++) {
    try {
      const once = await cdp.eval('document.readyState==="complete"&&!!(document.body&&document.body.childElementCount)');
      if (once) { await sleep(50); ready = await cdp.eval('document.readyState==="complete"&&!!(document.body&&document.body.childElementCount)'); }
    } catch {}
    if (!ready) await sleep(100);
  }
  if (!ready) { try { ws.close(); } catch {} proc.kill('SIGKILL'); throw new Error(`Chrome opened ${url} but the document was not ready`); }
  return { cdp, ws, stop() { try { ws.close(); } catch {} proc.kill('SIGTERM'); setTimeout(() => fs.rmSync(prof, { recursive: true, force: true }), 500); } };
}
const INJ = path.join(ROOT, 'tools', 'inject.js');
function run(args, opts = {}) {
  try { return { code: 0, out: execFileSync(process.execPath, [INJ, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...opts }) }; }
  catch (e) { return { code: e.status, out: String(e.stdout || '') + String(e.stderr || '') }; }
}
// full DOM snapshot (every text node + every attribute + stylesheet counts) to prove revert is exact
const SNAP = `(() => { const out=[]; const w=document.createTreeWalker(document.body, 5);
  for (let n=w.currentNode; n; n=w.nextNode()) { if (n.nodeType===3) out.push('#'+n.data); else out.push('<'+n.tagName+' '+[...n.attributes].map(a=>a.name+'='+JSON.stringify(a.value)).join(' ')); }
  return out.join('\\n') + '\\nSHEETS=' + document.adoptedStyleSheets.length + ' STYLES=' + document.querySelectorAll('style').length; })()`;
module.exports = { ROOT, sleep, findChrome, makeChecker, startChrome, run, SNAP, INJ };
