#!/usr/bin/env node
'use strict';
const { scriptMessage, scriptLang } = require('./script-messages');
/*
 * Cursor UI runtime translator (lab experiment) — zero dependencies.
 *
 * Runs under plain Node or under the Cursor binary itself with ELECTRON_RUN_AS_NODE=1.
 * Connects ONLY to the Chrome DevTools Protocol on 127.0.0.1:<port>, finds workbench page
 * targets, and installs a MutationObserver translator into each page.
 * Nothing on disk inside Cursor.app is modified.
 *
 * Usage:
 *   node inject.js [apply] --lang <code> [options]     -> locales/<code>.json (validated; broken pack => exit 3)
 *   node inject.js [apply] --dict <file.json> [--extra <file.json>] [options]
 *   node inject.js revert [--port 9333] [--url-filter <regex>]
 *   node inject.js stats  [--port 9333] [--url-filter <regex>]
 *
 * Options:
 *   --port <n>            DevTools port on 127.0.0.1 (default 9333)
 *   --locales-dir <dir>   where <code>.json packs live (default ../locales)
 *   --scope settings|all  all (default) = Cursor Settings + the pack's "scoped" areas outside Settings (Agents-window
 *                         sidebar, sidebar filter menu, editor-window welcome screen, ...). Each scoped group carries an
 *                         "area"; settings = only Cursor Settings (classic pane + Agents-window settings) and groups whose
 *                         area is "settings". The full-page dictionary never applies outside Settings.
 *   --url-filter <regex>  which page targets to touch (default "workbench")
 *   --once                inject into current windows and exit (no auto re-inject on reload)
 *   --show-original       translated text gets a title tooltip with the original English (only if it had no title)
 *   --search-aliases      append the translation to the row's data-search-aliases attribute (in Cursor 3.27.22
 *                         the settings search does NOT read this attribute; kept as an experiment)
 *   --no-label-overlay    disable label overlay mode (see below)
 *   --capture <file.json> record untranslated strings that are actually shown in scope and merge them into
 *                         <file.json> (every 5 s and on exit). Review before sharing: a privacy filter skips
 *                         e-mails/paths/URLs/key-like tokens, but screens can still show personal names.
 *   --capture-scope settings|all  settings (default) = record only inside Cursor Settings; all = record visible
 *                         untranslated text anywhere in the window (still never inside inputs, contenteditable, editors,
 *                         terminals, chat messages, chat/project rows; max 120 characters). Each string gets a DOM
 *                         context "path" to help write selectors. Without --lang this is a read-only probe.
 *   watch --out <file.json> [--lang <code>]  READ-ONLY coverage probe: changes nothing on screen. Stays running while
 *                         you click around (menus, tooltips, dialogs, toasts appear and are recorded as they show up,
 *                         via the same MutationObserver). Records visible English that the pack would NOT translate there
 *                         ("strings", with DOM path and popup kind) and the pack strings that were seen and WOULD be
 *                         translated ("covered"). Same privacy rules as --capture-scope all (never inputs' values,
 *                         editors, terminals, chat bodies, chat/project rows). Merged into <file.json> every 5 s and on
 *                         Ctrl+C. --once = one snapshot of what is visible now. Since 0.3.7 the watcher uses its own
 *                         page global (window.__cursorI18nWatch), so it can run while `apply` is active: the translation
 *                         keeps working, strings the translator already wrote count as "covered" under their English key.
 *   coverage --in <file.json> --lang <code> [--out report.md] [--verify <file.json>]
 *                         offline: turn a watch/capture file into a coverage report (untranslated strings grouped by
 *                         place, with DOM path; "in the pack but not applied here" = selector gap). --verify marks the
 *                         dictionary entries that were seen on screen (verifiedOnScreen: true). No Cursor needed.
 *   --exit-after-unreachable <s>  long-running mode: exit (code 0) when the port has been unreachable for <s>
 *                         seconds after having been connected, i.e. Cursor was quit (default 10)
 *   --wait-start <s>      long-running mode: exit with code 4 if Cursor never becomes reachable (default 60)
 *   --cursor-pid <pid>    also exit as soon as this process (the Cursor we launched) is gone
 *   --verbose             print the dictionary / injected / reloaded lines (hidden by default)
 *
 *   apply  (default) stays running: watches for new windows / reloads and re-injects.
 *          Ctrl+C (SIGINT) or SIGTERM => revert in every window, then exit.
 *   Applying again in a window that already has a translator reverts the old one first (language switch).
 *
 *   Label overlay mode (default ON): settings search navigates to a row by comparing the row label's DOM text
 *   with the English label. For those label elements the English text node is kept and the translation is
 *   drawn with CSS (::before + data-i18n-ov attribute), so "jump to search result" keeps working.
 *
 * Exit codes: 0 ok / 2 usage error / 3 language layer missing or invalid / 4 debug port unreachable
 *
 * Dictionary JSON formats accepted:
 *   {"English": "訳"}                                   flat map
 *   {"exact": {...}, "patterns": {"Open {0}": "{0} を開く"},
 *    "scoped": [{"id": "...", "area": "settings|agents|editor", "selector": "<CSS>", "deny": "<CSS>",
 *                "attrs": ["placeholder"], "exact": {...}}]}
 *   A scoped group applies to an element inside `selector` and NOT inside `deny`; only text nodes plus the attributes
 *   listed in `attrs` (default: none for non-settings areas, aria-label/placeholder/title for settings).
 */

const http = require('http');
const net = require('net');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const PACK = require('./pack.js');

const HOST = '127.0.0.1'; // never anything else

// ---------------------------------------------------------------- CLI
function parseArgs(argv) {
  const o = { cmd: 'apply', port: 9333, dicts: [], lang: null, localesDir: null, scope: 'all', urlFilter: 'workbench', once: false, verbose: false,
    labelOverlay: true, showOriginal: false, searchAliases: false, capture: null, captureScope: 'settings', readOnly: false, input: null, out: null, verify: null,
    exitAfterUnreachable: 10, waitStart: 60, cursorPid: 0 };
  const a = argv.slice(2);
  if (a[0] && !a[0].startsWith('-')) o.cmd = a.shift();
  for (let i = 0; i < a.length; i++) {
    const k = a[i], v = () => { if (i + 1 >= a.length) die(`missing value for ${k}`); return a[++i]; };
    if (k === '--port') o.port = parseInt(v(), 10);
    else if (k === '--dict' || k === '--extra') o.dicts.push(v());
    else if (k === '--lang') o.lang = v();
    else if (k === '--locales-dir') o.localesDir = v();
    else if (k === '--scope') o.scope = v();
    else if (k === '--url-filter') o.urlFilter = v();
    else if (k === '--once') o.once = true;
    else if (k === '--no-label-overlay') o.labelOverlay = false;
    else if (k === '--show-original') o.showOriginal = true;
    else if (k === '--search-aliases') o.searchAliases = true;
    else if (k === '--capture') o.capture = v();
    else if (k === '--capture-scope') o.captureScope = v();
    else if (k === '--out') o.out = v();
    else if (k === '--in') o.input = v();
    else if (k === '--verify') o.verify = v();
    else if (k === '--exit-after-unreachable') o.exitAfterUnreachable = parseFloat(v());
    else if (k === '--wait-start') o.waitStart = parseFloat(v());
    else if (k === '--cursor-pid') o.cursorPid = parseInt(v(), 10);
    else if (k === '--verbose' || k === '-v') o.verbose = true;
    else if (k === '--help' || k === '-h') { console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]); process.exit(0); }
    else die(`unknown option ${k}`);
  }
  if (!['apply', 'revert', 'stats', 'watch', 'coverage'].includes(o.cmd)) die(`unknown command ${o.cmd}`);
  if (o.cmd === 'coverage') {
    if (!o.input || !o.lang) die('coverage needs --in <capture.json> --lang <code>');
    return o;
  }
  if (o.cmd === 'watch') {
    if (!o.out && !o.capture) die('watch needs --out <file.json>');
    o.capture = o.out || o.capture; o.readOnly = true;
    if (!a.includes('--capture-scope')) o.captureScope = 'all';
    o.cmd = 'apply';
  }
  if (!(o.port > 0 && o.port < 65536)) die('bad --port');
  if (!['settings', 'all'].includes(o.scope)) die('--scope must be settings or all');
  if (!['settings', 'all'].includes(o.captureScope)) die('--capture-scope must be settings or all');
  if (o.cmd === 'apply' && o.lang) {
    try { o.dicts.unshift(PACK.packPath(o.lang, o.localesDir || PACK.LOCALES_DIR)); } catch (e) { die(e.message, 3); }
  }
  if (o.cmd === 'apply' && o.dicts.length === 0 && !o.capture) die('apply needs --lang <code> (locales/<code>.json) or --dict <file.json>');
  return o;
}
// exit codes: 0 ok / 2 usage error / 3 language layer missing or invalid / 4 Cursor debug port unreachable
function die(m, code = 2) { console.error(`[i18n] error: ${m}`); process.exit(code); }
let VERBOSE = false;
const log = (...x) => console.log('[i18n]', ...x);
const vlog = (...x) => { if (VERBOSE) console.log('[i18n:v]', ...x); };
const detail = (...x) => { if (VERBOSE) log(...x); }; // dictionary / injected / reloaded: only with --verbose

function loadDicts(files) {
  const out = { exact: {}, patterns: {}, scoped: [] };
  for (const f of files) {
    let d;
    try {
      const raw = fs.readFileSync(f, 'utf8'); d = JSON.parse(raw);
      if (d && d.schemaVersion !== undefined) d = PACK.loadPackFile(f).pack;     // schema-v1 pack: must validate
    } catch (e) { die(e.message, 3); }
    const isStructured = d && (d.exact || d.patterns || d.scoped);
    const add = (dst, src) => { for (const [k, v] of Object.entries(src || {})) if (typeof v === 'string' && v && v !== k && !k.startsWith('_')) dst[k.trim()] = v; };
    if (isStructured) {
      add(out.exact, d.exact); add(out.patterns, d.patterns);
      for (const s of d.scoped || []) { const e = {}; add(e, s.exact);
        const pt = {}; add(pt, s.patterns);
        out.scoped.push({ id: s.id || null, area: s.area || 'settings', selector: s.selector, deny: s.deny || null,
          attrs: Array.isArray(s.attrs) ? s.attrs : null, bypassDeny: s.bypassDeny === true, via: s.via || null, exact: e, patterns: pt }); }
    } else add(out.exact, d);
  }
  return out;
}

// ---------------------------------------------------------------- HTTP /json/list
function getJSON(port, p) {
  return new Promise((res, rej) => {
    const req = http.get({ host: HOST, port, path: p, timeout: 3000 }, r => {
      let b = ''; r.setEncoding('utf8'); r.on('data', c => (b += c));
      r.on('end', () => { try { res(JSON.parse(b)); } catch (e) { rej(e); } });
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', rej);
  });
}

// ---------------------------------------------------------------- minimal WebSocket client (RFC 6455)
class WS {
  constructor(url) {
    const u = new URL(url);
    if (u.hostname !== HOST && u.hostname !== 'localhost') throw new Error(`refusing non-local websocket ${u.hostname}`);
    this.url = u; this.handlers = {}; this.buf = Buffer.alloc(0); this.frag = null; this.closed = false;
  }
  on(ev, fn) { this.handlers[ev] = fn; return this; }
  emit(ev, ...a) { if (this.handlers[ev]) this.handlers[ev](...a); }
  connect() {
    return new Promise((resolve, reject) => {
      const key = crypto.randomBytes(16).toString('base64');
      const req = http.request({
        host: HOST, port: this.url.port, path: this.url.pathname + this.url.search,
        headers: { Connection: 'Upgrade', Upgrade: 'websocket', 'Sec-WebSocket-Version': '13', 'Sec-WebSocket-Key': key },
      });
      req.on('upgrade', (res, sock, head) => {
        const expect = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
        if (res.headers['sec-websocket-accept'] !== expect) { sock.destroy(); return reject(new Error('bad websocket accept')); }
        this.sock = sock; sock.setNoDelay(true);
        if (head && head.length) this._data(head);
        sock.on('data', d => this._data(d));
        sock.on('close', () => { this.closed = true; this.emit('close'); });
        sock.on('error', e => this.emit('error', e));
        resolve(this);
      });
      req.on('response', r => reject(new Error(`websocket upgrade refused: HTTP ${r.statusCode}`)));
      req.on('error', reject);
      req.end();
    });
  }
  _data(d) {
    this.buf = Buffer.concat([this.buf, d]);
    for (;;) {
      const b = this.buf; if (b.length < 2) return;
      const fin = (b[0] & 0x80) !== 0, op = b[0] & 0x0f, masked = (b[1] & 0x80) !== 0;
      let len = b[1] & 0x7f, off = 2;
      if (len === 126) { if (b.length < 4) return; len = b.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (b.length < 10) return; len = Number(b.readBigUInt64BE(2)); off = 10; }
      let mask = null; if (masked) { if (b.length < off + 4) return; mask = b.slice(off, off + 4); off += 4; }
      if (b.length < off + len) return;
      let payload = b.slice(off, off + len); this.buf = b.slice(off + len);
      if (mask) { payload = Buffer.from(payload); for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3]; }
      if (op === 0x8) { this.close(); return; }
      if (op === 0x9) { this._send(0xA, payload); continue; }
      if (op === 0xA) continue;
      if (op === 0x1 || op === 0x2) this.frag = [payload]; else if (op === 0x0 && this.frag) this.frag.push(payload);
      if (fin && this.frag) { const m = Buffer.concat(this.frag); this.frag = null; this.emit('message', m.toString('utf8')); }
    }
  }
  _send(op, payload) {
    if (this.closed || !this.sock) return;
    const len = payload.length; let hdr;
    if (len < 126) { hdr = Buffer.alloc(2); hdr[1] = 0x80 | len; }
    else if (len < 65536) { hdr = Buffer.alloc(4); hdr[1] = 0x80 | 126; hdr.writeUInt16BE(len, 2); }
    else { hdr = Buffer.alloc(10); hdr[1] = 0x80 | 127; hdr.writeBigUInt64BE(BigInt(len), 2); }
    hdr[0] = 0x80 | op;
    const mask = crypto.randomBytes(4), body = Buffer.from(payload);
    for (let i = 0; i < body.length; i++) body[i] ^= mask[i & 3];
    this.sock.write(Buffer.concat([hdr, mask, body]));
  }
  send(text) { this._send(0x1, Buffer.from(text, 'utf8')); }
  close() { if (this.closed) return; try { this._send(0x8, Buffer.alloc(0)); this.sock.end(); } catch {} this.closed = true; }
}

class CDP {
  constructor(ws) { this.ws = ws; this.id = 0; this.pending = new Map(); this.events = {};
    ws.on('message', m => { let j; try { j = JSON.parse(m); } catch { return; }
      if (j.id && this.pending.has(j.id)) { const p = this.pending.get(j.id); this.pending.delete(j.id); j.error ? p.rej(new Error(j.error.message)) : p.res(j.result); }
      else if (j.method && this.events[j.method]) this.events[j.method](j.params); });
    ws.on('close', () => { for (const p of this.pending.values()) p.rej(new Error('closed')); this.pending.clear(); if (this.onclose) this.onclose(); });
  }
  send(method, params = {}, timeout = 8000) {
    const id = ++this.id;
    return new Promise((res, rej) => {
      const t = setTimeout(() => { this.pending.delete(id); rej(new Error(`timeout ${method}`)); }, timeout);
      this.pending.set(id, { res: v => { clearTimeout(t); res(v); }, rej: e => { clearTimeout(t); rej(e); } });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  on(ev, fn) { this.events[ev] = fn; }
  async eval(expr) {
    const r = await this.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  }
}

// ---------------------------------------------------------------- page-side translator (serialised into the page)
function pageTranslator(DICT, OPTS) {
  'use strict';
  // 0.3.7: the read-only watcher lives in its own global, so it never reverts/replaces an active translator
  // (before 0.3.7 `watch` while `apply` was running silently stopped the translation).
  const GLOBAL = OPTS.readOnly ? '__cursorI18nWatch' : '__cursorI18n';
  try { if (window[GLOBAL] && window[GLOBAL].revert) window[GLOBAL].revert(); } catch (e) {}
  // translator already running in this window (only looked at by the watcher; never modified)
  const peer = () => { try { const p = window.__cursorI18n; return (OPTS.readOnly && p && !p.readOnly && typeof p.originalOf === 'function') ? p : null; } catch (e) { return null; } };
  const ATTRS = ['aria-label', 'placeholder', 'title'];
  // Never translate inside these (text or attributes).
  const DENY = [
    'script', 'style', 'noscript', 'textarea', 'code', 'pre', 'kbd', 'samp',
    '[contenteditable]:not([contenteditable="false"])',
    '.monaco-editor', '.monaco-diff-editor', '.xterm', '.terminal-wrapper', '.integrated-terminal',
    // chat input / composer editor
    '.aislash-editor-input', '.aislash-editor-input-readonly', '.composer-input', '.chat-input', '[data-lexical-editor]',
    // chat transcript / message bodies
    '[data-react-transcript-root]', '[data-react-transcript]', '.composer-react-transcript-root', '.composer-messages-container',
    '.composer-rendered-message', '.composer-human-message-body', '.composer-human-message-content',
    '[data-message-role]', '[data-message-id]', '[data-agent-transcript-human-bubble]', '[data-sent-message-bubble]',
    '[data-sent-message-bubble-text]', '.markdown-editor-react', '.markdown-root', '.anysphere-markdown-container-root',
    '.rendered-markdown', '.monaco-workbench .webview', 'iframe', 'webview',
    // user data shown in chrome: chat / project rows in the Agents-window sidebar, recent projects, titles
    '[data-sidebar-selectable-agent-id]', '[data-sidebar-file-drop-agent-id]', '[data-sidebar-file-drop-parent-agent-id]',
    '[data-sidebar-agent-hover-timestamp]', '[data-sidebar-agent-preview-hover-card]', '[data-sidebar-row-drag-preview]',
    '[data-component="project-title"]', '[data-component="task-list-row-title"]', '[data-component="pr-title-static"]',
    '.empty-screen-recent-item',
  ].join(',');
  // input/textarea: never their value/text; only the placeholder/title/aria-label attribute.
  const ATTR_DENY = DENY.replace(/(^|,)textarea(?=,|$)/, '$1__none__');
  // Row-label elements whose textContent is read back by settings-search navigation (settings search reads their text back)
  const LABEL_SEL = '.cursor-settings-cell-label, .cursor-settings-section-header-title, .ui-field-group__entry-label, .ui-section__title, .mcp-server-item-main-content-name';
  const OV_ATTR = 'data-i18n-ov', OV_VAR = '--i18n-fs';
  const CSS = '[' + OV_ATTR + ']{font-size:0 !important}' +
    '[' + OV_ATTR + ']::before{content:attr(' + OV_ATTR + ');font-size:var(' + OV_VAR + ')}' +
    '[' + OV_ATTR + '] > *{font-size:var(' + OV_VAR + ')}';
  let sheet = null, styleEl = null;
  function ensureCss() {
    if (sheet || styleEl) return;
    const text = CSS + PH_CSS;
    try { sheet = new CSSStyleSheet(); sheet.replaceSync(text); document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]; }
    catch (e) { sheet = null; styleEl = document.createElement('style'); styleEl.textContent = text; (document.head || document.documentElement).appendChild(styleEl); }
  }
  function removeCss() {
    if (sheet) { document.adoptedStyleSheets = document.adoptedStyleSheets.filter(x => x !== sheet); sheet = null; }
    if (styleEl) { styleEl.remove(); styleEl = null; }
  }
  // The full dictionary (exact + patterns) applies only inside Cursor Settings (classic pane + Agents-window settings).
  // Everything else is opt-in per element through the pack's "scoped" groups (tight selectors + deny lists).
  const ROOTS = '[class*="cursor-settings-"], [data-component^="glass-settings"], [data-i18n-root]';
  const exact = new Map(Object.entries(DICT.exact || {}));
  const compile = obj => Object.entries(obj || {}).map(([en, tr]) => {
    const names = []; const re = new RegExp('^' + en.split(/(\{\d+\})/).map(p => { const m = /^\{(\d+)\}$/.exec(p); if (m) { names.push(m[1]); return '(.+?)'; } return p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }).join('') + '$', 's');
    return { re, names, tr };
  });
  const fill = (p, m) => { let out = p.tr; p.names.forEach((n, i) => { out = out.split('{' + n + '}').join(m[i + 1]); }); return out; };
  const pats = compile(DICT.patterns);
  const groupsAll = (DICT.scoped || []).filter(s => OPTS.scope === 'all' || (s.area || 'settings') === 'settings');
  // via "css-placeholder": the keys are data-placeholder values of an empty editor paragraph; the translation is drawn by
  // one extra CSS rule (::before content). Nothing inside the editor (DOM, attributes, text) is ever changed.
  const cssStr = v => '"' + String(v).replace(/[\\"]/g, '\\$&').replace(/\n/g, '\\a ') + '"';
  let PH_CSS = '';
  for (const s of groupsAll) if (s.via === 'css-placeholder') for (const [en, tr] of Object.entries(s.exact || {})) {
    for (const part of String(s.selector).split(',')) PH_CSS += part.trim() + ' p.is-editor-empty:first-child[data-placeholder=' + cssStr(en) + ']::before{content:' + cssStr(tr) + ' !important}';
  }
  const scoped = groupsAll.filter(s => s.via !== 'css-placeholder')
    .map(s => ({ id: s.id, area: s.area || 'settings', selector: s.selector, deny: s.deny || null, bypass: s.bypassDeny === true,
      attrs: new Set(s.attrs || ((s.area || 'settings') === 'settings' ? ATTRS : [])), map: new Map(Object.entries(s.exact || {})), pats: compile(s.patterns) }));
  const byKey = new Map();          // key -> scoped groups that know it (fast path: most text is in no group)
  for (const g of scoped) for (const k of g.map.keys()) { if (!byKey.has(k)) byKey.set(k, []); byKey.get(k).push(g); }
  const patGroups = scoped.filter(g => g.pats.length);
  // groups allowed to work inside the global deny list (e.g. the "3h" time stamp at the end of a chat row; never the title)
  const BYPASS = scoped.filter(g => g.bypass).map(g => g.selector).join(', ') || null;

  const origText = new WeakMap();   // Text -> {orig, written}
  const origAttr = new WeakMap();   // Element -> {attr: {orig, written}}  (orig === null => attribute did not exist)
  const origOv = new WeakMap();     // Element -> {tr, prevVar}  label overlay records
  const touched = new Set();        // WeakRef of touched nodes (for revert iteration)
  // ---- capture mode: remember untranslated visible strings in scope (to build/refresh language layers)
  // Privacy filter: skip things that look like personal data (e-mail, paths, URLs, keys, numbers, long text).
  const captured = new Map();   // text -> {render, where, count}
  const PRIVATE = [/[\w.+-]+@[\w-]+\.[\w.]+/, /^(~|\/|[A-Za-z]:\\)/, /:\/\//, /\b[A-Za-z0-9_-]{24,}\b/, /\b(sk|pk|key|ghp|gho|xox[abp])[-_][A-Za-z0-9]/i];
  function whereOf(el) {
    const c = el.closest('[class*="entry-label"],[class*="entry-description"],[class*="section__title"],[class*="cell-label"],button,[role="button"],[role="option"],[role="tab"],[role="menuitem"],h1,h2,h3,header,[data-component]');
    if (!c) return 'other';
    if (c.matches('[data-component]')) return 'component:' + c.getAttribute('data-component');
    const cls = (c.className && typeof c.className === 'string') ? (c.className.match(/[\w-]*(entry-label|entry-description|section__title|cell-label)/) || [])[0] : '';
    return cls || c.getAttribute('role') || c.tagName.toLowerCase();
  }
  // account name / e-mail areas are never recorded
  const CAPTURE_SKIP = '[data-component="glass-sidebar-footer"], .cursor-settings-sidebar-header-content, [aria-hidden="true"]';
  function pathOf(el) {               // short DOM context (like "nav[data-component=workspace-sidebar] > div.ui-sidebar-group > span")
    const parts = []; let e = el;
    for (let i = 0; e && e.nodeType === 1 && i < 6; i++, e = e.parentElement) {
      let p = e.tagName.toLowerCase();
      for (const a of ['data-component', 'role']) { const v = e.getAttribute(a); if (v) p += '[' + a + '=' + v + ']'; }
      for (const a of e.getAttributeNames()) if (/^data-sidebar-|^data-trailing-band$|^data-section-head$/.test(a)) p += '[' + a + (e.getAttribute(a) ? '=' + e.getAttribute(a) : '') + ']';
      if (e.id && e.id.length < 40 && !/^(base-ui-)?_r_/.test(e.id)) p += '#' + e.id;
      const cls = (typeof e.className === 'string') ? e.className.split(/\s+/).filter(c => c && !/^(ui|glass)-[0-9a-z]{5,7}$/.test(c)).slice(0, 3) : [];
      if (cls.length) p += '.' + cls.join('.');
      parts.unshift(p);
    }
    return parts.join(' > ');
  }
  // which kind of transient UI an element lives in (helps the checklist / coverage report)
  const POPUPS = [['tooltip', '[data-component="tooltip-popup"], [role="tooltip"], .monaco-hover'], ['menu', '[data-component="menu-popup"], [data-component="search-menu-popup"], .ui-menu, [role="menu"], [role="listbox"], .context-view .monaco-menu'],
    ['dialog', '.ui-dialog, [role="dialog"], [role="alertdialog"], .monaco-dialog-box'], ['toast', '[data-sonner-toast], .ui-toast-wrapper, .notifications-toasts, .notification-toast'],
    ['popover', '.ui-popover, [data-component$="popover"]'], ['empty-state', '[data-component$="empty-state"], .ui-menu__empty'], ['quick-input', '.quick-input-widget'], ['status-bar', '.statusbar, [id="workbench.parts.statusbar"]']];
  function popupOf(el) { for (const [k, sel] of POPUPS) { try { if (el.closest(sel)) return k; } catch (e) {} } return undefined; }
  const seen = new Map();       // read-only watch: pack strings that were shown and would be translated here
  function covered(key, el, root, render) {
    const c = seen.get(key); if (c) { c.count++; return; }
    seen.set(key, { render, tier: root ? 'settings' : 'outside', popup: popupOf(el), count: 1 });
  }
  function capture(key, render, el, root) {
    if (!OPTS.capture) return;
    if (!root && !OPTS.captureAll) return;
    if (key.length > (root ? 300 : 120) || !/[A-Za-z]{2}/.test(key)) return;
    if (/[\u3040-\u30ff\u4e00-\u9fff]/.test(key)) return;         // already Japanese (our own output or user text)
    if (PRIVATE.some(re => re.test(key))) { st.captureSkippedPrivate++; return; }
    try { if (el.closest(CAPTURE_SKIP)) return; } catch (e) {}
    if (!el.getClientRects().length) return;                          // not rendered (display:none)
    const c = captured.get(key);
    if (c) c.count++; else { captured.set(key, { render, where: whereOf(el), path: pathOf(el), tier: root ? 'settings' : 'outside', popup: popupOf(el), count: 1 }); st.captured++; }
  }
  const st = { captured: 0, captureSkippedPrivate: 0, text: 0, attr: 0, overlay: 0, overlaySkipped: 0, showOriginal: 0, aliases: 0, skippedDeny: 0, revertedText: 0, revertedAttr: 0, revertedOverlay: 0, passes: 0 };
  let active = false, obs = null, noticeObs = null, queued = new Set(), scheduled = false;

  function inGroup(g, el, attr, bypassOnly) {
    if (attr && !g.attrs.has(attr)) return false;
    if (bypassOnly && !g.bypass) return false;
    try { return !!el.closest(g.selector) && !(g.deny && el.closest(g.deny)); } catch (e) { return false; }
  }
  function groupLookup(key, el, attr, bypassOnly) {   // -> translation or null
    if (!el) return null;
    const gs = byKey.get(key);
    if (gs) for (const g of gs) if (inGroup(g, el, attr, bypassOnly)) return g.map.get(key);
    for (const g of patGroups) for (const p of g.pats) { const m = p.re.exec(key); if (m && inGroup(g, el, attr, bypassOnly)) return fill(p, m); }
    return null;
  }
  function lookup(key, el, attr) {
    const g = groupLookup(key, el, attr, false); if (g != null) return g;
    if (exact.has(key)) return exact.get(key);
    for (const p of pats) { const m = p.re.exec(key); if (m) return fill(p, m); }
    return null;
  }
  function inScope(el) { return !ROOTS || !!el.closest(ROOTS); }
  // Outside the settings roots only "scoped" entries apply (e.g. the app sidebar's Back button while Settings is open).
  function lookupScoped(key, el, attr, bypassOnly) { return groupLookup(key, el, attr, !!bypassOnly); }
  function resolve(key, el, inDeny) {
    if (inDeny) return { tr: lookupScoped(key, el, null, true), root: false };
    if (inScope(el)) return { tr: lookup(key, el), root: true };
    return { tr: scoped.length ? lookupScoped(key, el) : null, root: false };
  }
  // inside the global deny list only a bypassDeny group's own elements may be translated
  function denyState(el, sel) { if (!el.closest(sel)) return 0; return (BYPASS && el.closest(BYPASS)) ? 2 : 1; }   // 0 free, 1 denied, 2 bypass
  function setAttrTracked(el, a, value) {          // write an attribute and remember the original for revert
    const recs = origAttr.get(el) || {};
    if (!recs[a]) recs[a] = { orig: el.hasAttribute(a) ? el.getAttribute(a) : null, written: value };
    else recs[a].written = value;
    origAttr.set(el, recs); touched.add(new WeakRef(el));
    el.setAttribute(a, value);
  }
  function extras(el, original, tr) {
    if (OPTS.showOriginal && !el.hasAttribute('title')) { setAttrTracked(el, 'title', original); st.showOriginal++; }
    if (OPTS.searchAliases && el.closest(LABEL_SEL + ', .ui-field-group__entry-description')) {   // labels/descriptions only, not buttons
      const row = el.closest('[data-search-aliases]');
      if (row) { const cur = row.getAttribute('data-search-aliases') || '';
        if (!cur.split('\n').includes(tr)) { setAttrTracked(row, 'data-search-aliases', cur ? cur + '\n' + tr : tr); st.aliases++; } }
    }
  }
  function clearOverlay(p) {
    const r = origOv.get(p); if (!r) return false;
    if (p.getAttribute(OV_ATTR) === r.tr) p.removeAttribute(OV_ATTR);
    if (r.prevVar) p.style.setProperty(OV_VAR, r.prevVar); else p.style.removeProperty(OV_VAR);
    if (r.hadStyle === false && p.getAttribute('style') === '') p.removeAttribute('style');   // leave no empty style=""
    origOv.delete(p); return true;
  }
  function overlay(node, el, key, tr) {
    // only when the parent holds exactly one non-empty text node (this one): font-size:0 hides it, ::before shows tr
    let n = 0; for (const c of el.childNodes) if (c.nodeType === 3 && c.data.trim()) n++;
    if (n !== 1) { st.overlaySkipped++; return; }
    const r = origOv.get(el);
    if (r && r.tr === tr && el.getAttribute(OV_ATTR) === tr) return;
    ensureCss();
    const hadStyle = r ? r.hadStyle : el.hasAttribute('style');
    const prevVar = r ? r.prevVar : el.style.getPropertyValue(OV_VAR);
    if (!r) el.style.removeProperty(OV_VAR);
    // measured before font-size:0 applies; when re-targeting an existing overlay keep the stored size
    const fs = r ? el.style.getPropertyValue(OV_VAR) : getComputedStyle(el).fontSize;
    origOv.set(el, { tr, prevVar, hadStyle }); touched.add(new WeakRef(el));
    el.style.setProperty(OV_VAR, fs);
    el.setAttribute(OV_ATTR, tr); st.overlay++;
    extras(el, key, tr);
  }
  function translateText(node) {
    const el = node.parentElement; if (!el) return;
    const data = node.data; const rec = origText.get(node);
    if (rec && data === rec.written) return;                 // our own write
    if (OPTS.readOnly) { const p = peer(); const o = p && p.originalOf(node);   // written by the running translator
      if (o) { if (el.getClientRects().length) covered(o, el, inScope(el), 'text'); return; } }
    const key = data.trim(); if (!key || key.length > 500) return;
    const ds = denyState(el, DENY);
    if (ds === 1) { st.skippedDeny++; return; }
    const { tr, root } = resolve(key, el, ds === 2);
    if (tr == null) { if (origOv.has(el)) clearOverlay(el); if (ds === 0) capture(key, 'text', el, root); return; }   // unknown text (app changed it, or not in pack)
    if (OPTS.readOnly) { if (el.getClientRects().length) covered(key, el, root, 'text'); return; }   // watch: look, never write
    if (OPTS.labelOverlay && el.closest(LABEL_SEL)) { overlay(node, el, key, tr); return; }
    const lead = data.slice(0, data.indexOf(key)), trail = data.slice(data.indexOf(key) + key.length);
    const written = lead + tr + trail;
    origText.set(node, { orig: data, written });
    touched.add(new WeakRef(node));
    node.data = written; st.text++;
    extras(el, key, tr);
  }
  function translateAttrs(el) {
    const ds = denyState(el, ATTR_DENY);                     // textarea/input themselves may get placeholder/title/aria-label
    if (ds === 1) return;
    const root = ds === 0 && inScope(el);
    if (!root && !scoped.length && !OPTS.captureAll) return;
    for (const a of ATTRS) {
      if (!el.hasAttribute(a)) continue;
      const v = el.getAttribute(a); const recs = origAttr.get(el) || {}; const r = recs[a];
      if (r && v === r.written) continue;                    // our own write (translation or show-original tooltip)
      const key = v.trim(); if (!key) continue;
      if (OPTS.readOnly) { const p = peer(); const o = p && p.originalAttrOf(el, a); if (o) { covered(o, el, root, 'attr:' + a); continue; } }
      const tr = root ? lookup(key, el) : lookupScoped(key, el, a, ds === 2); if (tr == null) { if (ds === 0) capture(key, 'attr:' + a, el, root); continue; }
      if (OPTS.readOnly) { covered(key, el, root, 'attr:' + a); continue; }
      const written = v.replace(key, () => tr);
      if (r) delete recs[a];                                 // app rewrote it: forget the stale record
      origAttr.set(el, recs);
      setAttrTracked(el, a, written); st.attr++;
    }
  }
  const shadows = new WeakSet();     // open shadow roots we walk + observe (e.g. the editor window's "..." menu)
  function walkPlain(root) {         // whole subtree, no deny pruning (only used for bypassDeny elements)
    const tw = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    if (root.nodeType === 1) translateAttrs(root);
    let n; while ((n = tw.nextNode())) { if (n.nodeType === 3) translateText(n); else translateAttrs(n); }
  }
  function walkBypass(denied) {      // a denied subtree: only the bypassDeny groups' own elements inside it
    if (!BYPASS) return;
    let list = []; try { list = [...(denied.matches(BYPASS) ? [denied] : []), ...denied.querySelectorAll(BYPASS)]; } catch (e) {}
    for (const e of list) walkPlain(e);
  }
  function walk(root) {
    if (!root) return;
    if (root.nodeType === 3) { translateText(root); return; }
    if (root.nodeType !== 1 && root.nodeType !== 9 && root.nodeType !== 11) return;
    if (root.nodeType === 1) { if (root.closest(DENY) && !root.matches('input,textarea')) { st.skippedDeny++; walkBypass(root); return; } translateAttrs(root); }
    const denied = [], hosts = [];
    const tw = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
      acceptNode(n) { if (n.nodeType === 1 && n.matches(DENY) && !n.matches('input,textarea')) { denied.push(n); return NodeFilter.FILTER_REJECT; } return NodeFilter.FILTER_ACCEPT; },
    });
    if (root.nodeType === 1 && root.shadowRoot) hosts.push(root);
    let n; while ((n = tw.nextNode())) { if (n.nodeType === 3) translateText(n); else { translateAttrs(n); if (n.shadowRoot) hosts.push(n); } }
    for (const d of denied) walkBypass(d);
    for (const h of hosts) { const sr = h.shadowRoot; if (!sr) continue; if (!shadows.has(sr)) { shadows.add(sr); if (obs) obs.observe(sr, OBS_OPTS); } walk(sr); }
  }
  function flush() {
    scheduled = false; if (!active) { queued.clear(); return; }
    const items = [...queued]; queued.clear(); st.passes++;
    for (const n of items) if (n.isConnected) walk(n);
  }
  function enqueue(n) { queued.add(n); if (!scheduled) { scheduled = true; queueMicrotask(flush); } }
  const OBS_OPTS = { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS };
  function start() {
    if (active) return; active = true;
    obs = new MutationObserver(ms => { for (const m of ms) {
      if (m.type === 'characterData') enqueue(m.target);
      else if (m.type === 'attributes') enqueue(m.target);
      else for (const n of m.addedNodes) enqueue(n);
    } });
    walk(document.documentElement);
    obs.observe(document.documentElement, OBS_OPTS);
    if (PH_CSS && !OPTS.readOnly) ensureCss();
    if (!OPTS.readOnly) showUnofficialNotice();
  }
  function noticeBottom() {
    // Sit above the status bar so the badge does not cover the notification bell at the right end.
    // On a real Mac, confirm this against the live status bar (see the release checklist).
    const bar = document.querySelector('.part.statusbar, [id="workbench.parts.statusbar"]');
    let h = 22;
    if (bar) {
      const r = bar.getBoundingClientRect();
      if (r.height >= 16 && r.height <= 80) h = Math.round(r.height);
    }
    return (h + 8) + 'px';
  }
  // A visible toast, an open notification center, or a dialog. An empty shell
  // (display:none, or no box) does not count, so the badge stays in normal use.
  function overlayCoversNotice() {
    const sel = '.notifications-toasts .notification-toast, .notifications-toasts .notification-list-item, .notifications-center, .monaco-dialog-modal-block, .monaco-dialog-box, [role="dialog"], [role="alertdialog"]';
    let list = [];
    try { list = document.querySelectorAll(sel); } catch (e) { return false; }
    for (const el of list) {
      if (!el || el.id === 'word-to-world-notice') continue;
      const cs = getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden' || cs.visibility === 'collapse') continue;
      const op = parseFloat(cs.opacity);
      if (!isNaN(op) && op === 0) continue;
      const r = el.getBoundingClientRect();
      if (r.width >= 8 && r.height >= 8) return true;
    }
    return false;
  }
  function syncNotice() {
    const notice = document.getElementById('word-to-world-notice');
    if (!notice) return;
    const hide = overlayCoversNotice();
    const vis = hide ? 'hidden' : 'visible';
    const pe = hide ? 'none' : 'auto';
    if (notice.style.visibility !== vis) notice.style.visibility = vis;
    if (notice.style.pointerEvents !== pe) notice.style.pointerEvents = pe;
    if (hide) { if (notice.getAttribute('aria-hidden') !== 'true') notice.setAttribute('aria-hidden', 'true'); }
    else if (notice.hasAttribute('aria-hidden')) notice.removeAttribute('aria-hidden');
  }
  function armNoticeWatch() {
    syncNotice();
    if (noticeObs) return;
    noticeObs = new MutationObserver(() => syncNotice());
    noticeObs.observe(document.documentElement, {
      subtree: true, childList: true, attributes: true,
      attributeFilter: ['class', 'style', 'hidden', 'aria-hidden'],
    });
  }
  function showUnofficialNotice() {
    if (document.getElementById('word-to-world-notice')) { armNoticeWatch(); return; }
    const notice = document.createElement('div');
    notice.id = 'word-to-world-notice';
    notice.textContent = 'Word to World · unofficial, not affiliated with Cursor';
    // z-index stays under Cursor's toasts, notification center, and dialogs.
    // The badge also hides while one of those is visible, so it cannot show through.
    notice.style.cssText = 'position:fixed;bottom:' + noticeBottom() + ';right:8px;padding:4px 8px;font-size:10px;color:#888;background:rgba(0,0,0,0.05);border-radius:4px;z-index:20;cursor:pointer;opacity:0.6;transition:opacity 0.2s';
    notice.onmouseenter = () => notice.style.opacity = '1';
    notice.onmouseleave = () => notice.style.opacity = '0.6';
    notice.onclick = () => notice.remove();
    notice.title = 'Word to World is an unofficial community tool. It is not affiliated with, endorsed by, or sponsored by Cursor or Anysphere, Inc. It only changes text shown on screen. Click to dismiss.';
    document.body.appendChild(notice);
    armNoticeWatch();
  }
  function revert() {
    active = false; if (obs) { obs.disconnect(); obs = null; } if (noticeObs) { noticeObs.disconnect(); noticeObs = null; } queued.clear();
    let t = 0, a = 0, ov = 0;
    for (const ref of touched) {
      const n = ref.deref(); if (!n) continue;
      if (n.nodeType === 3) { const r = origText.get(n); if (r && n.data === r.written) { n.data = r.orig; t++; } origText.delete(n); continue; }
      if (clearOverlay(n)) ov++;
      const recs = origAttr.get(n) || {};
      for (const [k, r] of Object.entries(recs)) if (n.getAttribute(k) === r.written) { if (r.orig === null) n.removeAttribute(k); else n.setAttribute(k, r.orig); a++; }
      origAttr.delete(n);
    }
    touched.clear(); removeCss(); st.revertedText += t; st.revertedAttr += a; st.revertedOverlay += ov;
    const notice = document.getElementById('word-to-world-notice');
    if (notice) notice.remove();
    return { revertedText: t, revertedAttr: a, revertedOverlay: ov };
  }
  const api = {
    version: 1, lang: OPTS.lang, scope: OPTS.scope, readOnly: !!OPTS.readOnly,
    apply() { start(); return api.stats(); },
    revert,
    captured() { return [...captured].map(([text, v]) => Object.assign({ text }, v)); },
    seen() { return [...seen].map(([text, v]) => Object.assign({ text }, v)); },
    // read-only helpers for a watcher running next to this translator: the English behind our own writes (or null)
    originalOf(node) { const r = origText.get(node); return (r && node.data === r.written) ? r.orig.trim() : null; },
    originalAttrOf(el, a) { const r = (origAttr.get(el) || {})[a]; return (r && r.orig != null && el.getAttribute(a) === r.written) ? r.orig.trim() : null; },
    stats() { let live = 0; for (const r of touched) if (r.deref()) live++; return Object.assign({ active, entries: exact.size, patterns: pats.length, liveTouched: live }, st); },
  };
  let replaced = false;
  if (window[GLOBAL] && typeof window[GLOBAL].revert === 'function') { try { window[GLOBAL].revert(); replaced = true; } catch (e) {} }
  Object.defineProperty(window, GLOBAL, { value: api, configurable: true, writable: true });
  if (document.documentElement && document.readyState !== 'loading') start();
  else document.addEventListener('DOMContentLoaded', start, { once: true });
  const alongside = OPTS.readOnly && !!(window.__cursorI18n && !window.__cursorI18n.readOnly && window.__cursorI18n.stats && window.__cursorI18n.stats().active);
  return (replaced ? 'replaced' : 'installed') + (alongside ? ', alongside the running translator' : '');
}

// ---------------------------------------------------------------- injector
async function listTargets(o) {
  const list = await getJSON(o.port, '/json/list');
  const re = new RegExp(o.urlFilter);
  return list.filter(t => t.type === 'page' && t.webSocketDebuggerUrl && re.test(t.url || '') && !String(t.url).startsWith('devtools://'));
}
function wsUrlFor(t, port) { const u = new URL(t.webSocketDebuggerUrl); return `ws://${HOST}:${port}${u.pathname}`; }
async function connect(t, port) { const ws = new WS(wsUrlFor(t, port)); await ws.connect(); return new CDP(ws); }

// ---------------------------------------------------------------- capture file
function mergeCapture(file, items, version, seenItems) {
  let doc = { tool: 'ui-translator-capture', version: version || '', strings: [] };
  try { const d = JSON.parse(fs.readFileSync(file, 'utf8')); if (d && Array.isArray(d.strings)) doc = d; } catch {}
  if (version) doc.version = version;
  const byText = new Map(doc.strings.map(s => [s.text, s]));
  let added = 0;
  for (const it of items) {
    const s = byText.get(it.text);
    if (s) { s.count = Math.max(s.count || 0, it.count || 0); continue; }
    const n = { text: it.text, kind: /\{\d+\}/.test(it.text) ? 'pattern' : 'exact', render: it.render.startsWith('attr') ? 'attr' : 'text',
      attr: it.render.startsWith('attr:') ? it.render.slice(5) : undefined, tier: it.tier || 'settings', popup: it.popup, where: it.where, path: it.path, count: it.count };
    byText.set(it.text, n); doc.strings.push(n); added++;
  }
  doc.strings.sort((a, b) => a.text.localeCompare(b.text));
  if (seenItems && seenItems.length) {
    const cov = doc.covered && typeof doc.covered === 'object' ? doc.covered : {};
    for (const it of seenItems) { const c = cov[it.text]; if (c) c.count = Math.max(c.count || 0, it.count || 0); else cov[it.text] = { render: it.render.startsWith('attr') ? 'attr' : 'text', tier: it.tier, popup: it.popup, count: it.count }; }
    doc.covered = Object.fromEntries(Object.entries(cov).sort((a, b) => a[0].localeCompare(b[0])));
  }
  doc.updated = new Date().toISOString();
  fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(doc, null, 2) + '\n');
  return { added, total: doc.strings.length };
}

async function cmdApply(o) {
  const dict = loadDicts(o.dicts);
  let lang = o.lang;
  if (!lang && o.dicts.length) { try { const d = JSON.parse(fs.readFileSync(o.dicts[0], 'utf8')); lang = (d.meta && d.meta.lang) || null; } catch {} }
  if (!lang) lang = o.dicts.length ? ((path.basename(o.dicts[0]).match(/^([a-z]{2,3}(-[A-Za-z0-9]{2,4})?)\./) || [])[1] || '?') : 'capture-only';
  const src = `(${pageTranslator.toString()})(${JSON.stringify(dict)}, ${JSON.stringify({ scope: o.scope, lang, labelOverlay: o.labelOverlay, showOriginal: o.showOriginal, searchAliases: o.searchAliases, capture: !!o.capture, captureAll: o.captureScope === 'all', readOnly: o.readOnly })})`;
  if (o.readOnly) log(`watch (read-only, 0.3.7+: runs next to an active apply without stopping it): nothing on screen is changed. Recording to ${o.capture}. Click around; Ctrl+C to finish.`);
  detail(`dictionary: ${Object.keys(dict.exact).length} exact, ${Object.keys(dict.patterns).length} patterns, ${dict.scoped.length} scoped groups; scope=${o.scope}; lang=${lang}; labelOverlay=${o.labelOverlay}; showOriginal=${o.showOriginal}; searchAliases=${o.searchAliases}`);
  const G = o.readOnly ? 'window.__cursorI18nWatch' : 'window.__cursorI18n';   // watch never touches the translator's global
  const sessions = new Map(); // targetId -> {cdp, scriptId, title}
  let told = false;
  function tellStarted() {
    if (told || o.readOnly) return;
    told = true;
    console.log('');
    console.log(scriptMessage(scriptLang(o.lang), 'started'));
  }
  async function attach(t) {
    if (sessions.has(t.id)) return;
    sessions.set(t.id, { pending: true });
    try {
      const cdp = await connect(t, o.port);
      await cdp.send('Page.enable');
      await cdp.send('Runtime.enable');
      const { identifier } = await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: src });
      const r = await cdp.eval(src);
      sessions.set(t.id, { cdp, scriptId: identifier, title: t.title });
      cdp.onclose = () => { sessions.delete(t.id); vlog(`closed: ${t.title}`); };
      cdp.on('Page.loadEventFired', async () => { try { detail(`reloaded: ${t.title} ->`, JSON.stringify(await cdp.eval(`${G} && ${G}.stats()`))); } catch {} });
      const s = await cdp.eval(`${G}.stats()`);
      detail(`injected (${r}): "${t.title}" ${t.url.slice(0, 80)} ->`, JSON.stringify(s));
      tellStarted();
      if (o.readOnly && /alongside/.test(String(r))) {
        log(scriptMessage(scriptLang(o.lang), 'watch'));
      }
    } catch (e) { sessions.delete(t.id); log(`attach failed for "${t.title}": ${e.message}`); }
  }
  // Self-exit: never loop forever after Cursor is gone.
  const startedAt = Date.now(); let everConnected = false, failSince = 0, lastLog = 0;
  function pidGone() { if (!o.cursorPid) return false; try { process.kill(o.cursorPid, 0); return false; } catch (e) { return e.code === 'ESRCH'; } }
  async function scan() {
    let ts;
    try { ts = await listTargets(o); }
    catch (e) {
      const now = Date.now(); if (!failSince) failSince = now;
      if (now - lastLog > 10000) { detail(`cannot reach 127.0.0.1:${o.port}: ${e.message}`); lastLog = now; }
      if (!o.once && everConnected && now - failSince >= o.exitAfterUnreachable * 1000) quit(0, 'Cursor is gone (debug port closed). Exiting.');
      if (!o.once && !everConnected && now - startedAt >= o.waitStart * 1000) quit(4, `Cursor did not become reachable within ${o.waitStart}s. Exiting.`);
      return [];
    }
    everConnected = true; failSince = 0;
    if (!o.once && pidGone()) quit(0, `Cursor process ${o.cursorPid} is gone. Exiting.`);
    for (const t of ts) await attach(t); return ts;
  }
  let quitting = false;
  function tellStopped() {
    console.log(scriptMessage(scriptLang(o.lang), 'stopped'));
  }
  function quit(code, msg) {
    if (quitting) return; quitting = true;
    // 終了そのものは人向けの一文。接続拒否やプロセス消滅の生ログは --verbose だけ。
    // 待っても一度も繋がらなかった等の失敗は、今までどおり出す。
    if (code === 0 && /gone/.test(msg)) { tellStopped(); detail(msg); }
    else log(msg);
    for (const [, s] of sessions) { try { s.cdp && s.cdp.ws.close(); } catch {} }
    process.exit(code);
  }
  const first = await scan();
  if (o.once && !first.length) { try { await listTargets(o); } catch (e) { die(`cannot reach 127.0.0.1:${o.port}: ${e.message}`, 4); } }
  if (first.length === 0) log(`no matching page targets yet (url-filter=/${o.urlFilter}/)`);
  async function collect() {
    if (!o.capture) return;
    const items = [], seenItems = []; let version = '';
    for (const [, s] of sessions) { if (!s.cdp) continue;
      try { items.push(...(await s.cdp.eval(`${G} ? ${G}.captured() : []`)) || []);
            if (o.readOnly) seenItems.push(...(await s.cdp.eval(`${G} && ${G}.seen ? ${G}.seen() : []`)) || []);
            version = version || ((await s.cdp.eval('(navigator.userAgent.match(/Cursor\\/([\\d.]+)/) || [])[1] || ""')) || ''); } catch {} }
    const r = mergeCapture(o.capture, items, version, seenItems);
    if (r.added) log(`capture: +${r.added} new strings (total ${r.total}) -> ${o.capture}`);
  }
  if (o.once) { if (o.capture) { await new Promise(r => setTimeout(r, 300)); await collect(); } for (const s of sessions.values()) s.cdp && s.cdp.ws.close(); return; }
  const capTimer = o.capture ? setInterval(() => collect().catch(() => {}), 5000) : null;
  let stopping = false;
  const timer = setInterval(scan, 2000);
  const pidTimer = o.cursorPid ? setInterval(() => { if (pidGone()) quit(0, `Cursor process ${o.cursorPid} is gone. Exiting.`); }, 1000) : null;
  async function stop(sig) {
    if (stopping) return; stopping = true; clearInterval(timer); if (pidTimer) clearInterval(pidTimer); if (capTimer) clearInterval(capTimer);
    try { await collect(); } catch {}
    detail(`${sig}: reverting in ${sessions.size} window(s)...`);
    for (const [, s] of sessions) { if (!s.cdp) continue;
      try { log(o.readOnly ? '  watcher stopped:' : '  reverted:', JSON.stringify(await s.cdp.eval(`${G} ? ${G}.revert() : null`))); } catch (e) { log('  revert failed:', e.message); }
      try { await s.cdp.send('Page.removeScriptToEvaluateOnNewDocument', { identifier: s.scriptId }); } catch {}
      s.cdp.ws.close(); }
    process.exit(0);
  }
  process.on('SIGINT', () => stop('SIGINT'));
  process.on('SIGTERM', () => stop('SIGTERM'));
  detail('running. Ctrl+C to revert and stop.');
}

// ---------------------------------------------------------------- coverage report (offline)
function coverageReport(doc, pack, lang) {
  const inPack = new Map();   // english -> [where it is defined]
  const addK = (k, w) => { if (!inPack.has(k)) inPack.set(k, []); inPack.get(k).push(w); };
  for (const k of Object.keys(pack.exact || {})) addK(k, 'exact(Settings)');
  for (const g of pack.scoped || []) for (const k of Object.keys(g.exact || {})) addK(k, g.id);
  const strings = (doc.strings || []).slice();
  const covered = doc.covered || {};
  const placeOf = s => s.popup || (s.tier === 'settings' ? 'settings' : (s.where || 'other'));
  const groups = new Map();
  for (const s of strings) { const p = placeOf(s); if (!groups.has(p)) groups.set(p, []); groups.get(p).push(s); }
  const gap = strings.filter(s => inPack.has(s.text));
  const L = [];
  L.push(`# Coverage report (${lang})`, '', `- Cursor version: ${doc.version || '?'} / file updated: ${doc.updated || '?'}`,
    `- seen and translated by the pack: ${Object.keys(covered).length}`, `- seen and still English: ${strings.length}` +
    ` (of which ${gap.length} are in the pack but not applied at that place = selector gap)`, '',
    'Note: this list comes from the screen. Review it before sharing (it can contain names).', '');
  for (const [p, list] of [...groups].sort((a, b) => b[1].length - a[1].length)) {
    L.push(`## ${p} (${list.length})`, '', '| English | kind | in pack? | DOM path |', '|---|---|---|---|');
    for (const s of list.sort((a, b) => a.text.localeCompare(b.text))) {
      const esc = v => String(v == null ? '' : v).replace(/\|/g, '\\|').replace(/\n/g, ' ');
      L.push(`| ${esc(s.text)} | ${s.render === 'attr' ? 'attr:' + (s.attr || '') : 'text'} | ${inPack.has(s.text) ? 'yes: ' + inPack.get(s.text).join(', ') : 'no'} | \`${esc(s.path || '')}\` |`);
    }
    L.push('');
  }
  return { markdown: L.join('\n'), untranslated: strings.length, covered: Object.keys(covered).length, selectorGap: gap.length };
}
function cmdCoverage(o) {
  let doc, pack;
  try { doc = JSON.parse(fs.readFileSync(o.input, 'utf8')); } catch (e) { die(`cannot read ${o.input}: ${e.message}`); }
  try { pack = PACK.loadPackFile(PACK.packPath(o.lang, o.localesDir || PACK.LOCALES_DIR)).pack; } catch (e) { die(e.message, 3); }
  const r = coverageReport(doc, pack, o.lang);
  if (o.out) { fs.writeFileSync(o.out, r.markdown + '\n'); log(`coverage report -> ${o.out}`); } else console.log(r.markdown);
  log(`seen+translated ${r.covered} / still English ${r.untranslated} (selector gap ${r.selectorGap})`);
  if (o.verify) {
    let v; try { v = JSON.parse(fs.readFileSync(o.verify, 'utf8')); } catch (e) { die(`cannot read ${o.verify}: ${e.message}`); }
    const seenOnScreen = new Set([...Object.keys(doc.covered || {}), ...(doc.strings || []).map(s => s.text)]);
    let n = 0; for (const e of v.entries || []) if (!e.verifiedOnScreen && seenOnScreen.has(e.english)) { e.verifiedOnScreen = true; e.verifiedVersion = doc.version || undefined; n++; }
    fs.writeFileSync(o.verify, JSON.stringify(v, null, 1)); log(`verify: ${n} dictionary entries newly confirmed on screen -> ${o.verify}`);
  }
}

async function cmdEach(o, expr, label) {
  let ts; try { ts = await listTargets(o); } catch (e) { die(`cannot reach 127.0.0.1:${o.port}: ${e.message}`, 4); }
  if (!ts.length) log(`no matching page targets (url-filter=/${o.urlFilter}/)`);
  for (const t of ts) {
    try { const c = await connect(t, o.port); log(`${label} "${t.title}":`, JSON.stringify(await c.eval(expr))); c.ws.close(); }
    catch (e) { log(`${label} failed for "${t.title}": ${e.message}`); }
  }
}

async function main() {
  const o = parseArgs(process.argv); VERBOSE = o.verbose;
  if (o.cmd === 'coverage') return cmdCoverage(o);
  if (o.cmd === 'apply') return cmdApply(o);
  if (o.cmd === 'revert') return cmdEach(o, 'window.__cursorI18n ? window.__cursorI18n.revert() : "not installed"', 'revert');
  if (o.cmd === 'stats') return cmdEach(o, 'window.__cursorI18n ? window.__cursorI18n.stats() : "not installed"', 'stats');
}

module.exports = { WS, CDP, getJSON, pageTranslator, loadDicts, mergeCapture, coverageReport };
if (require.main === module) main().catch(e => die(e.stack || e.message));
