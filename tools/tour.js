#!/usr/bin/env node
'use strict';
/**
 * tour.js — contributor aid: walk through as many Cursor UI places as possible over the DevTools port, so that
 * `inject.js watch` (read-only coverage) or `inject.js apply` (translated screenshots) sees menus, tooltips, dialogs
 * and settings panes that only appear on interaction.
 *
 * ⚠️  ONLY USE WITH A THROWAWAY CURSOR PROFILE (a fresh --user-data-dir and --extensions-dir, not signed in),
 *     never with your default profile. The tour clicks, hovers, presses keys and opens menus/dialogs. It avoids
 *     destructive words (Delete, Remove, Reset, Sign out, Install, Archive, Discard, ...) and never types into
 *     editors or chats, but it is still UI automation. It refuses to run without --throwaway-profile.
 *     使い捨てのプロファイル専用。標準プロファイルで動かさないこと。
 *     Even in a throwaway profile, opening dropdowns can leave harmless setting values changed (seen on 3.27.22:
 *     queue behaviour, color scheme detection). Delete the throwaway profile afterwards.
 *
 * Usage (example on Linux under Xvfb). docs/tour.md is not included in this repository.
 *   cursor --user-data-dir=/tmp/t/ud --extensions-dir=/tmp/t/ext --remote-debugging-port=9555 /tmp/t/ws &
 *   node tools/inject.js watch --lang ja --port 9555 --out work/tour-watch.json &     # or: apply --lang ja
 *   node tools/tour.js --port 9555 --throwaway-profile --shots work/tour [--phases editor,settings,palette,agents,hover]
 *
 * Options:
 *   --port <n>             DevTools port (127.0.0.1 only; default 9555; 9333 = the normal launcher port is refused)
 *   --throwaway-profile    required: you confirm the Cursor on this port uses a throwaway profile
 *   --shots <dir>          save screenshots (PNG) of key screens there
 *   --prefix <s>           screenshot file name prefix (default "tour")
 *   --phases <list>        subset of: editor,settings,palette,agents,hover (default: all)
 *   --hide-onboarding      hide the login/onboarding overlay of a signed-out profile (style only) so the UI behind it
 *                          can be toured; its texts are seen (recorded) before hiding
 *   --report <file.json>   write what was opened / skipped (default: none)
 *   --window <regex>       only windows whose title matches (default: every Cursor window)
 * Exit codes: 0 ok / 2 usage error / 4 debug port unreachable
 */
const fs = require('fs');
const path = require('path');
const { WS, CDP, getJSON } = require('./inject.js');

const NEVER = new RegExp('\\b(delete|remove|reset|sign ?out|sign ?in|log ?out|log ?in|sign ?up|upgrade to|install|uninstall|' +
  'archive|discard|revoke|disconnect|unregister|unlink|merge|push|commit|publish|upgrade|buy|purchase|pay|restart|quit|' +
  'exit|reload|update|clear|import|export|revert|undo|apply|accept|approve|reject|send|run|start|stop|enable|disable|' +
  'create|new window|close window|share|invite|checkout|clone|download|upload|rebuild|reindex|forget|kill|terminate|' +
  'cancel subscription)\\b', 'i');

// The same safety words in translated UIs (a pass with `inject.js apply` shows Japanese/Chinese labels, so the English
// list alone would not match). Deliberately broad: a skipped harmless control costs nothing.
const NEVER_LOCAL = new RegExp(
  '(削除|除去|消去|リセット|サインアウト|サインイン|ログアウト|ログイン|新規登録|インストール|アンインストール|アーカイブ|破棄|取り消|取消|切断|解除|' +
  'マージ|コミット|公開|アップグレード|購入|支払|再起動|終了|再読み込み|更新|クリア|インポート|エクスポート|元に戻|適用|承認|拒否|送信|実行|' +
  '開始|停止|有効|無効|作成|新しいウィンドウ|共有|招待|チェックアウト|クローン|ダウンロード|アップロード|再構築|再インデックス|忘れ|確認|' +
  '删除|移除|重置|登出|登录|登入|安装|安裝|卸载|解除安裝|归档|封存|丢弃|捨棄|撤销|撤銷|断开|中斷|合并|合併|推送|提交|发布|發佈|' +
  '升级|升級|购买|購買|重启|重新啟動|退出|清除|导入|匯入|导出|匯出|还原|還原|应用|套用|接受|批准|拒绝|拒絕|发送|傳送|运行|執行|' +
  '开始|启用|啟用|禁用|停用|创建|建立|共享|分享|邀请|邀請|克隆|下载|下載|上传|上傳|确认)');

// Customize page pills in translated UIs (ja / zh-cn / zh-tw), so an apply pass opens the same tabs
const CUSTOMIZE_LOCAL = {
  Plugins: ['プラグイン', '插件', '外掛'], MCPs: ['MCP'], Skills: ['スキル', '技能'], Subagents: ['サブエージェント', '子 Agent', '子代理'],
  Rules: ['ルール', '规则', '規則'], Commands: ['コマンド', '命令', '指令'], Hooks: ['フック'],
};
const SIDEBAR_LOCAL = { Automations: ['自動化', '自动化'], Customize: ['カスタマイズ', '自定义', '自訂'] };
// file-name-safe part of a (possibly translated) label
const slug = s => (String(s).replace(/[^\p{L}\p{N}]+/gu, '_').replace(/^_+|_+$/g, '') || 'x').slice(0, 40);

function args(argv) {
  const o = { window: null, port: 9555, throwaway: false, shots: null, prefix: 'tour', phases: ['editor', 'settings', 'palette', 'agents', 'hover'], hideOnboarding: false, report: null };
  const a = argv.slice(2);
  for (let i = 0; i < a.length; i++) {
    const k = a[i], v = () => a[++i];
    if (k === '--port') o.port = parseInt(v(), 10);
    else if (k === '--throwaway-profile') o.throwaway = true;
    else if (k === '--shots') o.shots = v();
    else if (k === '--prefix') o.prefix = v();
    else if (k === '--phases') o.phases = v().split(',');
    else if (k === '--hide-onboarding') o.hideOnboarding = true;
    else if (k === '--report') o.report = v();
    else if (k === '--window') o.window = new RegExp(v(), 'i');
    else if (k === '-h' || k === '--help') { console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]); process.exit(0); }
    else { console.error(`[tour] unknown option ${k}`); process.exit(2); }
  }
  if (!o.throwaway) { console.error('[tour] refusing: pass --throwaway-profile to confirm this Cursor uses a THROWAWAY profile (never your normal one).'); process.exit(2); }
  if (o.port === 9333) { console.error('[tour] refusing port 9333 (the normal launcher port). Start a separate throwaway Cursor on another port.'); process.exit(2); }
  return o;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

// page-side helpers (installed once per page, read-only)
const HELPERS = `window.__tour = (window.__tour && window.__tour.v === 2) ? window.__tour : (() => {
  const vis = e => { if (!e || !e.getBoundingClientRect) return false; const r = e.getBoundingClientRect(); if (r.width < 2 || r.height < 2) return false;
    if (r.bottom < 0 || r.right < 0 || r.top > innerHeight || r.left > innerWidth) return false; const s = getComputedStyle(e); return s.visibility !== 'hidden' && s.display !== 'none'; };
  const label = e => ((e.getAttribute && (e.getAttribute('aria-label') || e.getAttribute('title'))) || e.textContent || '').trim().replace(/\\s+/g, ' ').slice(0, 120);
  const USER = '.monaco-editor, .xterm, [contenteditable]:not([contenteditable="false"]), input, textarea, [data-message-role], [data-react-transcript-root], [data-sidebar-selectable-agent-id] [class*="title"]';
  let seq = Date.now() % 100000; const ids = new WeakMap();
  const idOf = e => { if (!ids.has(e)) { const id = 't' + (++seq); ids.set(e, id); e.setAttribute('data-tour-id', id); } return ids.get(e); };
  return {
    v: 2, vis, label,
    list(sel, root) { const r = root ? document.querySelector(root) : document; if (!r) return [];
      return [...r.querySelectorAll(sel)].filter(e => vis(e) && !e.closest(USER)).map(e => ({ id: idOf(e), label: label(e), tag: e.tagName, popup: e.getAttribute('aria-haspopup') || '' })); },
    byText(sel, re, root) { const rx = new RegExp(re, 'i'); return this.list(sel, root).filter(x => rx.test(x.label)); },
    center(id) { const e = document.querySelector('[data-tour-id="' + id + '"]'); if (!e) return null; e.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      const r = e.getBoundingClientRect(); return r.width ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; },
    open() { return [...document.querySelectorAll('[data-component="menu-popup"], [data-component="list-popup-scroll"], [role="menu"], [role="listbox"], [role="dialog"], [role="alertdialog"], .ui-popover, .monaco-menu, .context-view .monaco-menu, .quick-input-widget')]
      .filter(e => { const r = e.getBoundingClientRect(); return r.width > 2 && r.height > 2 && getComputedStyle(e).display !== 'none'; }).length; },
  };
})(); 1`;

async function connectPage(port, t) { const u = new URL(t.webSocketDebuggerUrl); const ws = new WS(`ws://127.0.0.1:${port}${u.pathname}`); await ws.connect(); return new CDP(ws); }

class Tour {
  constructor(c, o) { this.c = c; this.o = o; this.log = []; this.n = 0; }
  note(kind, what, extra) { this.log.push({ kind, what, ...(extra || {}) }); console.log(`[tour] ${kind}: ${what}${extra && extra.why ? ' (' + extra.why + ')' : ''}`); }
  async ev(e) { return this.c.eval(e); }
  async helpers() { await this.ev(HELPERS); }
  async shot(name) { if (!this.o.shots) return; fs.mkdirSync(this.o.shots, { recursive: true });
    const r = await this.c.send('Page.captureScreenshot', { format: 'png' }); const f = path.join(this.o.shots, `${this.o.prefix}-${String(++this.n).padStart(2, '0')}-${name}.png`);
    fs.writeFileSync(f, Buffer.from(r.data, 'base64')); this.note('screenshot', f); }
  async key(name, mods = 0) {
    const K = { Escape: [27, 'Escape'], Enter: [13, 'Enter'], ArrowDown: [40, 'ArrowDown'], ArrowRight: [39, 'ArrowRight'], PageDown: [34, 'PageDown'], Home: [36, 'Home'] };
    const [code, keyName, codeName] = K[name] ? [K[name][0], K[name][1], K[name][1]] : [name.toUpperCase().charCodeAt(0), mods & 8 ? name.toUpperCase() : name, 'Key' + name.toUpperCase()];
    await this.c.send('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: code, key: keyName, code: codeName, modifiers: mods });
    await this.c.send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: code, key: keyName, code: codeName, modifiers: mods });
  }
  async esc(n = 1) { for (let i = 0; i < n; i++) { await this.key('Escape'); await sleep(150); } }
  // Mouse events are sent without waiting for Chromium's input ack: under Xvfb without a GPU the ack can take 5 s
  // (no frames while idle). The events are still delivered in order.
  mouse(params) { this.c.send('Input.dispatchMouseEvent', params).catch(() => {}); }
  async move(p) { this.mouse({ type: 'mouseMoved', x: p.x, y: p.y }); await sleep(30); }
  async at(id) { await this.helpers(); return this.ev(`__tour.center(${JSON.stringify(id)})`); }
  async hover(id, ms = 600) { if (process.env.TOUR_DEBUG) console.log('[tour:d] hover', id, new Date().toISOString().slice(11, 19)); const p = await this.at(id); if (!p) return false; await this.move({ x: 1, y: 1 }); await sleep(60); await this.move(p); await sleep(ms); return true; }
  async click(id, button = 'left') { if (process.env.TOUR_DEBUG) console.log('[tour:d] click', id, button, new Date().toISOString().slice(11, 19)); const p = await this.at(id); if (!p) return false; await this.move(p);
    this.mouse({ type: 'mousePressed', x: p.x, y: p.y, button, clickCount: 1 }); await sleep(90);
    this.mouse({ type: 'mouseReleased', x: p.x, y: p.y, button, clickCount: 1 }); await sleep(450); return true; }
  safe(x) { return !NEVER.test(x.label) && !NEVER_LOCAL.test(x.label); }
  async list(sel, root) { await this.helpers(); return (await this.ev(`__tour.list(${JSON.stringify(sel)}, ${JSON.stringify(root || null)})`)) || []; }
  async byText(sel, re, root) { await this.helpers(); return (await this.ev(`__tour.byText(${JSON.stringify(sel)}, ${JSON.stringify(re)}, ${JSON.stringify(root || null)})`)) || []; }
  async openCount() { await this.helpers(); return this.ev('__tour.open()'); }
  // open a menu/dropdown, hover its items (and one level of submenus), screenshot, close
  async openMenu(x, name, shot) {
    if (!this.safe(x)) { this.note('skipped', x.label, { why: 'unsafe word' }); return; }
    if (!(await this.click(x.id))) return;
    await sleep(600);
    if (!(await this.openCount())) {   // keyboard fallback, select triggers only: focus + Enter opens the list without changing the value
      await this.esc();
      const isSelect = await this.ev(`(() => { const e = document.querySelector('[data-tour-id="${x.id}"]'); if (!e || !e.matches('[role=combobox], .ui-select-trigger')) return false; e.focus(); return true; })()`);
      if (isSelect) { await this.key('Enter'); await sleep(900); }
    }
    if (!(await this.openCount())) { this.note('no-popup', name || x.label); await this.esc(); return; }
    this.note('opened', name || x.label);
    if (shot) await this.shot(shot);
    const items = await this.list('[role="menuitem"], [role="menuitemcheckbox"], [role="menuitemradio"], [role="option"], .ui-menu__item, .action-item .action-label');
    for (const it of items.slice(0, 40)) { await this.hover(it.id, 250);
      if (it.popup && this.safe(it)) { await this.key('ArrowRight'); await sleep(350); this.note('submenu', it.label); } }
    await this.esc(3);
  }
  async hoverAll(sel, root, limit, why) {
    const xs = (await this.list(sel, root)).slice(0, limit); let n = 0;
    for (const x of xs) { if (await this.hover(x.id, 650)) n++; }
    this.note('hovered', `${n} elements`, { why }); await this.move({ x: 2, y: 2 });
  }
  async palette(query, shot) {
    await this.esc(2); await this.key('p', 2 | 8); await sleep(700);
    await this.c.send('Input.insertText', { text: '>' + query }); await sleep(900);
    if (shot) await this.shot(shot);
    for (let i = 0; i < 25; i++) { await this.key('PageDown'); await sleep(120); }
    this.note('palette', query); await this.esc(2);
  }
}

async function phaseEditor(t) {
  // title bar + status bar tooltips (hover), Cursor's own status bar items (click), editor "..." menus
  await t.hoverAll('.titlebar [aria-label], .titlebar [title], .statusbar-item', null, 60, 'title bar + status bar tooltips');
  for (const x of await t.byText('.statusbar-item a', '(Tab|Agent) (AI )?Stats|commit')) { await t.click(x.id); await sleep(500); if (await t.openCount()) { t.note('opened', 'status bar: ' + x.label); await t.shot('statusbar'); } await t.esc(2); }
  for (const x of await t.byText('a.action-label, [role="button"]', '^More Actions')) await t.openMenu(x, 'More Actions (' + x.label + ')', 'more-actions');
  // context menu on the status bar
  const sb = await t.list('.statusbar'); if (sb[0]) { await t.click(sb[0].id, 'right'); await sleep(400); t.note('context-menu', 'status bar'); await t.esc(2); }
}

async function phaseSettings(t) {
  await t.esc(2); await t.key('j', 2 | 8); await sleep(1500);
  const cells = await t.list('.cursor-settings-sidebar-cell');
  if (!cells.length) { t.note('blocked', 'Cursor Settings did not open'); return; }
  for (const cell of cells) {
    if (/↗/.test(cell.label) || /^(VS Code Settings|Docs|Customize|VS Code の設定|ドキュメント|カスタマイズ|VS Code 设置|VS Code 設定|文档|文件|自定义|自訂)$/i.test(cell.label)) { t.note('skipped', 'settings tab ' + cell.label, { why: 'opens another page/window' }); continue; }
    await t.click(cell.id); await sleep(900);
    t.note('settings-tab', cell.label); await t.shot('settings-' + slug(cell.label));
    // scroll the pane to the bottom in steps (lazy sections)
    for (let i = 0; i < 12; i++) { await t.ev(`(() => { const s = document.querySelector('.cursor-settings-pane-content-scroll'); if (s) s.scrollTop += 500; })()`); await sleep(120); }
    await t.ev(`(() => { const s = document.querySelector('.cursor-settings-pane-content-scroll'); if (s) s.scrollTop = 0; })()`);
    // expand collapsed sections / "show more"
    for (const x of (await t.list('.cursor-settings-pane-content [aria-expanded="false"]')).slice(0, 15)) if (t.safe(x) && !x.popup) { await t.click(x.id); }
    for (const x of (await t.byText('.cursor-settings-pane-content [role="button"], .cursor-settings-pane-content button, .cursor-settings-pane-content .cursor-button', '^(show more|show|view|view all|details|advanced|edit|manage|configure|learn more|more)$')).slice(0, 10)) {
      if (!t.safe(x)) continue; await t.click(x.id); await sleep(600); t.note('opened', `${cell.label}: ${x.label}`);
      if (await t.openCount()) { await t.shot('settings-dialog'); await t.esc(2); }
    }
    // dropdowns
    const dds = await t.list('.cursor-settings-pane-content :is(.ui-select-trigger, [role="combobox"], button[aria-haspopup], .cursor-settings-dropdown, [class*="dropdown-trigger"], select)');
    let first = true; for (const d of dds.slice(0, 25)) { await t.openMenu(d, `${cell.label}: dropdown ${d.label}`, first ? 'settings-dropdown' : null); first = false; }
    // tooltips on info icons / icon buttons
    await t.hoverAll('.cursor-settings-pane-content :is([title], [aria-label], [class*="info"], [class*="help"], .codicon)', null, 40, cell.label + ' tooltips');
  }
  await t.hoverAll('.cursor-settings-sidebar :is([title], [aria-label])', null, 20, 'settings sidebar');
}

async function phasePalette(t) {
  for (const q of ['Cursor', 'Agent', 'Chat', 'Composer']) await t.palette(q, q === 'Cursor' ? 'palette-cursor' : null);
}

async function phaseAgents(t) {
  await t.esc(2);
  const gate = await t.ev(`!!document.querySelector('[data-component="logged-out-glass-screen"]')`);
  if (gate) { t.note('blocked', 'Agents window shows the logged-out screen (sign-in required)'); await t.shot('agents-logged-out'); return; }
  // the editor window's agents side bar may be collapsed: show it
  if (!(await t.ev(`(() => { const s = document.querySelector('.unified-agents-sidebar'); return !!s && s.getBoundingClientRect().width > 0; })()`)))
    for (const x of await t.byText('[aria-label]', '^(Show Agents Side Bar)$')) { await t.click(x.id); await sleep(800); t.note('opened', 'agents side bar'); }
  // agent pane header: "+", "...", filter button, sidebar actions, composer pickers
  for (const x of await t.byText('a.action-label, button, [role="button"]', '^More Actions$')) await t.openMenu(x, 'agent pane: More Actions', 'agent-more');
  for (const x of await t.byText('button, [role="button"]', '^(Filter by Environment|Customize Sidebar|Sidebar filters|Filter)')) await t.openMenu(x, 'sidebar filter: ' + x.label, 'sidebar-filter');
  for (const x of await t.byText('.unified-agents-sidebar :is(button, [role="button"], a, .agent-sidebar-cell)', '^(Search|検索|搜索|搜尋)$')) { await t.click(x.id); await sleep(700); t.note('opened', 'sidebar Search'); await t.shot('sidebar-search'); await t.esc(2); }
  for (const name of ['Automations', 'Customize']) {
    for (const x of await t.byText('.unified-agents-sidebar :is(button, [role="button"], a, div[role="link"], [class*="menu-button"], .agent-sidebar-cell)', '^(' + [name, ...(SIDEBAR_LOCAL[name] || [])].join('|') + ')$')) {
      await t.click(x.id); await sleep(1500); t.note('opened', 'sidebar ' + name); await t.shot('agents-' + name.toLowerCase());
      // tabs / segmented controls inside the page
      for (const tab of (await t.list(':is([role="tab"], [role="radio"], .ui-tabs__tab, [class*="tab-button"]):not(.tabs-container *, .tabs-and-actions-container *)')).slice(0, 15)) { if (!t.safe(tab)) continue; await t.click(tab.id); await sleep(700); t.note('tab', `${name}: ${tab.label}`); }
      for (const d of (await t.list('button[aria-haspopup], [role="combobox"], .ui-select-trigger')).slice(0, 12)) await t.openMenu(d, `${name}: ${d.label}`);
      if (name === 'Customize') for (const lab of ['Plugins', 'MCPs', 'Skills', 'Subagents', 'Rules', 'Commands', 'Hooks']) {
        // the pills may already be translated (apply pass): match the English label or a known translation
        const re = '^(' + [lab, ...(CUSTOMIZE_LOCAL[lab] || [])].join('|') + ')$';
        for (const p of (await t.byText('button, [role="button"], [role="tab"], [role="radio"]', re)).slice(0, 1)) {
          await t.click(p.id); await sleep(900); t.note('tab', 'Customize: ' + lab); await t.shot('customize-' + lab.toLowerCase());
          for (const d of (await t.byText('button, [role="button"]', '^(Add|New|All|Manage scope)')).slice(0, 4)) await t.openMenu(d, `Customize ${lab}: ${d.label}`);
        }
      }
      await t.hoverAll('[data-component] :is(button[aria-label], [role="button"][aria-label], [title])', null, 40, name + ' tooltips');
      break;
    }
  }
  // composer pickers / buttons (no typing)
  for (const d of (await t.list(':is(.ui-select-trigger, button[aria-haspopup], [role="combobox"])')).slice(0, 15)) await t.openMenu(d, 'picker: ' + d.label, null);
  // context menus on sidebar rows (right click), on the composer area
  for (const x of (await t.list('.unified-agents-sidebar :is([role="button"], [class*="menu-button"])')).slice(0, 6)) {
    if (!t.safe(x)) continue; await t.click(x.id, 'right'); await sleep(400);
    if (await t.openCount()) { t.note('context-menu', 'sidebar: ' + x.label); await t.shot('sidebar-context'); }
    await t.esc(2);
  }
}

async function phaseHover(t) {
  await t.esc(2);
  await t.hoverAll(':is(button, [role="button"], a, [role="tab"], .action-label)[aria-label], [title]', null, 150, 'all labelled controls (tooltips)');
}

async function main() {
  const o = args(process.argv);
  let list; try { list = await getJSON(o.port, '/json/list'); } catch (e) { console.error(`[tour] cannot reach 127.0.0.1:${o.port}: ${e.message}`); process.exit(4); }
  const pages = list.filter(t => t.type === 'page' && /workbench/.test(t.url || '') && (!o.window || o.window.test(t.title || '')));
  if (!pages.length) { console.error('[tour] no Cursor window found'); process.exit(4); }
  const report = { started: new Date().toISOString(), port: o.port, windows: [], log: [] };
  for (const p of pages) {
    const c = await connectPage(o.port, p); await c.send('Page.enable'); const t = new Tour(c, o);
    report.windows.push(p.title);
    await t.helpers();
    const onboarding = await t.ev(`(() => { const e = document.querySelector('.onboarding-v2-overlay'); return e && __tour.vis(e) ? e.innerText.replace(/\\s+/g, ' ').slice(0, 200) : null; })()`);
    if (onboarding) {
      t.note('blocked', 'onboarding / login screen is shown (not signed in): ' + onboarding); await t.shot('onboarding'); await sleep(1500);
      if (o.hideOnboarding) { await t.ev(`document.querySelector('.onboarding-v2-overlay').style.display = 'none'`); t.note('hidden', 'onboarding overlay (style only)'); }
    }
    await t.shot('start');
    const phases = { editor: phaseEditor, settings: phaseSettings, palette: phasePalette, agents: phaseAgents, hover: phaseHover };
    for (const ph of o.phases) {
      if (!phases[ph]) { console.error(`[tour] unknown phase ${ph}`); process.exit(2); }
      try { await phases[ph](t); } catch (e) { t.note('error', `${ph}: ${e.message}`); }
      await t.esc(3);
    }
    report.log.push(...t.log); c.ws.close();
  }
  report.finished = new Date().toISOString();
  if (o.report) fs.writeFileSync(o.report, JSON.stringify(report, null, 1));
  console.log(`[tour] done: ${report.log.filter(x => x.kind === 'opened' || x.kind === 'settings-tab' || x.kind === 'submenu').length} places opened, ${report.log.filter(x => x.kind === 'blocked').length} blocked`);
}
if (require.main === module) main().catch(e => { console.error(e); process.exit(1); });
