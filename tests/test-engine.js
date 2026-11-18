'use strict';
// Engine end-to-end on headless Chrome with hand-written fixtures (Agents-window settings + classic settings).
const path = require('path'), fs = require('fs'), os = require('os');
const { spawn } = require('child_process');
const { ROOT, sleep, findChrome, makeChecker, startChrome, run, SNAP, INJ } = require('./lib');
const T = makeChecker(), check = T.check;
const fx = n => 'file://' + path.join(__dirname, 'fixtures', n);

async function glass() {
  console.log('--- Agents-window (glass) settings fixture');
  const PORT = 9445; const b = await startChrome(PORT, fx('workbench-glass.html')); const c = b.cdp;
  const P = ['--port', String(PORT)];
  const q = () => c.eval(`(() => { const g=id=>document.getElementById(id), cs=e=>getComputedStyle(e), bef=e=>getComputedStyle(e,'::before');
    return { back:g('sb-back').textContent, sbGeneral:g('sb-general').textContent, sbPlan:g('sb-plan').textContent, sbAgents:g('sb-agents').textContent,
      h1:g('tab-h1').textContent, outside:g('outside-title').textContent,
      appBack:g('app-back-label').textContent, appNew:g('app-new').textContent, appOtherBack:g('app-other-back').textContent,
      searchPh:g('sb-search').placeholder, searchAria:g('sb-search').getAttribute('aria-label'), searchVal:g('sb-search').value,
      lbl1:g('lbl1').textContent, lbl1ov:g('lbl1').getAttribute('data-i18n-ov'), lbl1fs:cs(g('lbl1')).fontSize, lbl1before:bef(g('lbl1')).content, lbl1beforeFs:bef(g('lbl1')).fontSize,
      lbl1title:g('lbl1').getAttribute('title'), desc1:g('desc1').textContent, desc1title:g('desc1').getAttribute('title'),
      btnOff:g('btn-off').textContent, btnOffTitle:g('btn-off').title,
      lbl2ov:g('lbl2').getAttribute('data-i18n-ov'), badgeov:g('badge').getAttribute('data-i18n-ov'), badgeFs:bef(g('badge')).fontSize, desc2:g('desc2').textContent,
      lbl3s:g('lbl3s').textContent, lbl3sov:g('lbl3s').getAttribute('data-i18n-ov'), sec:g('sec').textContent, secov:g('sec').getAttribute('data-i18n-ov'),
      alias1:g('row1').getAttribute('data-search-aliases'), alias3:g('row3').getAttribute('data-search-aliases'), alias2:g('row2').hasAttribute('data-search-aliases'),
      tip:g('tooltip-host').textContent, tipTitle:g('tooltip-host').title,
      find1:findLabel('Window Restoration'), find3:findLabel('Reduce Motion'), findSec:findLabel('Layout') }; })()`);
  const before = await c.eval(SNAP);
  let r = run(['apply', '--once', '--lang', 'ja', ...P, '--url-filter', 'workbench-glass']);
  check('apply --lang ja --once exits 0', r.code === 0, r.out.split('\n')[0]);
  let s = await q();
  check('sidebar: Back / General / Plan & Usage / Agents', s.back === '戻る' && s.sbGeneral === '一般' && s.sbPlan === 'プランと使用量' && s.sbAgents === 'エージェント', [s.back, s.sbGeneral, s.sbPlan, s.sbAgents].join('|'));
  check('tab header h1', s.h1 === '一般');
  check('scoped: app sidebar Back button (outside settings panel) translated', s.appBack === '戻る', s.appBack);
  check('scoped only: other "Back" text and other sidebar buttons outside settings untouched', s.appOtherBack === 'Back' && s.appNew === 'New Agent');
  check('settings search box: placeholder + aria-label translated, value untouched', s.searchPh === '設定を検索' && s.searchAria === '設定を検索' && s.searchVal === '');
  check('outside settings scope untouched', s.outside === 'Projects');
  check('label overlay: textContent stays English, ::before shows translation at 13px', s.lbl1 === 'Window Restoration' && s.lbl1ov === 'ウィンドウの復元' && s.lbl1before === '"ウィンドウの復元"' && s.lbl1fs === '0px' && s.lbl1beforeFs === '13px');
  check('settings search "jump to row" (finds label by English text) still works', s.find1 === 'lbl1' && s.find3 === 'lbl3' && s.findSec === 'sec');
  check('label with inner span / section title overlaid', s.lbl3sov === 'モーションを減らす' && s.secov === 'レイアウト' && s.sec === 'Layout');
  check('label text + badge: both overlaid, badge keeps 13px', s.lbl2ov === '会話の表示密度' && s.badgeov === 'ベータ' && s.badgeFs === '13px', `${s.lbl2ov}/${s.badgeov}/${s.badgeFs}`);
  check('row description translated as text', s.desc1 === '起動時に Cursor が復元するウィンドウを設定', s.desc1);
  check('common word "General" translated inside settings', s.desc2 === '一般');
  check('button text + title', s.btnOff === 'オフ' && s.btnOffTitle === 'オフ');
  check('defaults: no tooltip, aliases untouched, foreign title kept', s.lbl1title === null && s.alias1 === 'restore windows' && s.tipTitle === 'keep me' && s.tip === '色相');
  const badge0 = await c.eval(`(() => {
    const n = document.getElementById('word-to-world-notice');
    if (!n) return null;
    const cs = getComputedStyle(n);
    return { text: n.textContent, z: cs.zIndex, vis: cs.visibility, title: n.title };
  })()`);
  check('unofficial badge is visible in normal use and stays under overlay layers',
    badge0 && badge0.text === 'Word to World · unofficial, not affiliated with Cursor' &&
    /not affiliated with, endorsed by, or sponsored by/.test(badge0.title) &&
    badge0.vis !== 'hidden' && Number(badge0.z) > 0 && Number(badge0.z) < 1000, JSON.stringify(badge0));
  await c.eval(`(() => {
    const empty = document.createElement('div');
    empty.className = 'notifications-center'; empty.id = 't-empty-center';
    empty.style.cssText = 'display:none';
    document.body.appendChild(empty);
  })()`);
  await sleep(30);
  const still = await c.eval(`getComputedStyle(document.getElementById('word-to-world-notice')).visibility`);
  check('badge stays visible when the notification center is only an empty hidden shell', still !== 'hidden', still);
  await c.eval(`(() => {
    const wrap = document.createElement('div');
    wrap.className = 'notifications-toasts'; wrap.id = 't-toasts';
    const toast = document.createElement('div');
    toast.className = 'notification-toast'; toast.id = 't-toast';
    toast.style.cssText = 'display:block;width:240px;height:48px';
    toast.textContent = 'Saved';
    wrap.appendChild(toast);
    document.body.appendChild(wrap);
  })()`);
  await sleep(30);
  const hiddenToast = await c.eval(`getComputedStyle(document.getElementById('word-to-world-notice')).visibility`);
  check('badge hides while a notification toast is visible', hiddenToast === 'hidden', hiddenToast);
  await c.eval(`document.getElementById('t-toast').remove()`);
  await sleep(30);
  await c.eval(`(() => {
    const el = document.getElementById('t-empty-center');
    el.style.cssText = 'display:block;width:280px;height:120px';
    el.textContent = 'No new notifications';
  })()`);
  await sleep(30);
  const center = await c.eval(`getComputedStyle(document.getElementById('word-to-world-notice')).visibility`);
  check('badge hides while the notification center is open', center === 'hidden', center);
  await c.eval(`(() => {
    document.getElementById('t-empty-center').style.display = 'none';
    const d = document.createElement('div');
    d.className = 'monaco-dialog-box'; d.id = 't-dlg'; d.setAttribute('role', 'alertdialog');
    d.style.cssText = 'display:block;width:320px;height:140px';
    d.textContent = 'Quit Cursor?';
    document.body.appendChild(d);
  })()`);
  await sleep(30);
  const dlg = await c.eval(`getComputedStyle(document.getElementById('word-to-world-notice')).visibility`);
  check('badge hides while a dialog is visible', dlg === 'hidden', dlg);
  await c.eval(`['t-empty-center','t-toasts','t-dlg'].forEach(id => { const e = document.getElementById(id); if (e) e.remove(); })`);
  await sleep(30);
  const back = await c.eval(`getComputedStyle(document.getElementById('word-to-world-notice')).visibility`);
  check('badge returns when the toast, center, and dialog are gone', back !== 'hidden', back);
  run(['revert', ...P, '--url-filter', 'workbench-glass']);
  check('revert: DOM identical to before (text, attributes, styles)', (await c.eval(SNAP)) === before);

  r = run(['apply', '--once', '--lang', 'ja', '--show-original', '--search-aliases', ...P, '--url-filter', 'workbench-glass']);
  s = await q();
  check('--show-original: English tooltip on label and description', s.lbl1title === 'Window Restoration' && s.desc1title === 'Controls which windows Cursor restores on startup');
  check('--search-aliases: label/description appended, buttons not, no new attributes', s.alias1.startsWith('restore windows\n') && s.alias1.includes('ウィンドウの復元') && !s.alias1.includes('オフ') && s.alias3 === 'モーションを減らす' && s.alias2 === false);
  await c.eval(`document.getElementById('lbl1').firstChild.data = 'Conversation Density'`); await sleep(150);
  check('app re-renders label to another known string: overlay follows', (await c.eval(`document.getElementById('lbl1').getAttribute('data-i18n-ov')`)) === '会話の表示密度');
  await c.eval(`document.getElementById('lbl1').firstChild.data = 'Unknown Label'`); await sleep(150);
  check('app re-renders label to unknown text: overlay removed (visible English)', (await c.eval(`String(document.getElementById('lbl1').getAttribute('data-i18n-ov'))+getComputedStyle(document.getElementById('lbl1')).fontSize`)) === 'null13px');
  await c.eval(`document.getElementById('lbl1').firstChild.data = 'Window Restoration'`); await sleep(150);
  run(['revert', ...P, '--url-filter', 'workbench-glass']);
  check('revert (all options): DOM identical, titles removed, aliases restored', (await c.eval(SNAP)) === before);

  // re-injection / switching: applying twice must not stack (second install reverts the first)
  run(['apply', '--once', '--lang', 'ja', ...P, '--url-filter', 'workbench-glass']);
  r = run(['apply', '--once', '--verbose', '--lang', 'ja', '--no-label-overlay', ...P, '--url-filter', 'workbench-glass']);
  s = await q();
  check('second apply replaces the first ("replaced"), no double state', /\(replaced\)/.test(r.out) && /\[i18n\] dictionary:/.test(r.out) && s.lbl1 === 'ウィンドウの復元' && s.lbl1ov === null, s.lbl1);
  check('--no-label-overlay documents the hazard: search cannot find the label', s.find1 === null);
  run(['revert', ...P, '--url-filter', 'workbench-glass']);
  check('revert after replace: DOM identical', (await c.eval(SNAP)) === before);

  // capture mode (capture-only: no pack)
  const cap = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'cursor-i18n-test-')), 'capture.json');
  r = run(['apply', '--once', '--capture', cap, ...P, '--url-filter', 'workbench-glass']);
  let doc = JSON.parse(fs.readFileSync(cap, 'utf8')); let texts = doc.strings.map(x => x.text);
  check('capture-only run records visible English strings in scope', texts.includes('Window Restoration') && texts.includes('General') && texts.includes('Brand New Setting'), `${texts.length} strings`);
  check('capture skips outside-scope, hidden, e-mail and path strings', !texts.includes('Projects') && !texts.includes('Hidden Thing') && !texts.some(t => t.includes('@')) && !texts.some(t => t.startsWith('/')));
  check('capture records attributes with their name', doc.strings.some(x => x.text === 'Frobnicate Widgets' && x.render === 'attr' && x.attr === 'aria-label'));
  run(['revert', ...P, '--url-filter', 'workbench-glass']);
  fs.unlinkSync(cap);
  r = run(['apply', '--once', '--lang', 'ja', '--capture', cap, ...P, '--url-filter', 'workbench-glass']);
  doc = JSON.parse(fs.readFileSync(cap, 'utf8')); texts = doc.strings.map(x => x.text);
  check('capture with ja pack: only UNtranslated strings recorded', texts.includes('Brand New Setting') && !texts.includes('Window Restoration') && !texts.includes('General'), texts.join(' | '));
  run(['revert', ...P, '--url-filter', 'workbench-glass']);
  check('revert after capture: DOM identical', (await c.eval(SNAP)) === before);
  fs.rmSync(path.dirname(cap), { recursive: true, force: true });
  b.stop();
}

async function classic() {
  console.log('--- classic settings fixture + long-running mode');
  const PORT = 9444; const b = await startChrome(PORT, fx('workbench-classic.html')); const c = b.cdp;
  const q = () => c.eval(`(() => { const g = id => document.getElementById(id); return {
      plan: g('tab-plan').textContent, general: g('tab-general').textContent, h: JSON.stringify(g('h-layout').textContent),
      cell: g('cell-label').textContent, cellov: g('cell-label').getAttribute('data-i18n-ov'),
      density: g('lbl-density').textContent, densityTitle: g('lbl-density').title, btnAria: g('btn').getAttribute('aria-label'),
      searchPh: g('search').placeholder, searchVal: g('search').value, ta: g('ta').value, taPh: g('ta').placeholder, inp: g('inp').value, inpTitle: g('inp').title,
      ce: g('ce-p').textContent, monaco: g('monaco').textContent, xterm: g('xterm').textContent, msg: g('msg').textContent,
      chatin: g('chatin').textContent, code: g('code').textContent, outside: g('outside').textContent,
      added: g('added') ? g('added').textContent : null, api: typeof window.__cursorI18n }; })()`);
  const before = await c.eval(SNAP);
  const inj = spawn(process.execPath, [INJ, 'apply', '--lang', 'ja', '--port', String(PORT), '--url-filter', 'workbench-classic'], { stdio: ['ignore', 'pipe', 'pipe'] });
  let out = ''; inj.stdout.on('data', d => (out += d)); inj.stderr.on('data', d => (out += d));
  for (let i = 0; i < 50 && !/running\./.test(out); i++) await sleep(100);
  let s = await q();
  check('classic: sidebar + heading (whitespace kept)', s.plan === 'プランと使用量' && s.general === '一般' && s.h === JSON.stringify('  レイアウト  '), s.h);
  check('classic: .cursor-settings-cell-label uses overlay', s.cell === 'Window Restoration' && s.cellov === 'ウィンドウの復元');
  check('classic: plain text / title / aria-label / placeholder', s.density === '会話の表示密度' && s.densityTitle === '会話の表示密度' && s.btnAria === 'モーションを減らす' && s.searchPh === 'タイポグラフィ');
  check('deny-list: input/textarea values, contenteditable, Monaco, terminal, chat, <code> untouched',
    s.searchVal === 'Typography' && s.ta === 'Privacy' && s.inp === 'Privacy' && s.ce === 'Privacy' && s.monaco === 'Privacy' && s.xterm === 'Privacy' && s.msg === 'Privacy' && s.chatin === 'Privacy' && s.code === 'Privacy');
  check('placeholder/title on input/textarea translated', s.taPh === 'プライバシー' && s.inpTitle === 'プライバシー');
  check('outside settings untouched', s.outside === 'Privacy');
  await c.eval(`(() => { const d = document.createElement('div'); d.id = 'added'; d.textContent = 'Window Restoration'; document.getElementById('pane').appendChild(d);
                         document.getElementById('lbl-density').firstChild.data = 'Conversation Density'; })()`);
  await sleep(150); s = await q();
  check('MutationObserver: new node + re-render translated', s.added === 'ウィンドウの復元' && s.density === '会話の表示密度');
  await c.eval(`document.getElementById('added').remove()`); await sleep(50);
  await c.send('Page.enable'); await c.send('Page.reload'); await sleep(1200);
  s = await q();
  check('page reload: re-injected automatically', s.plan === 'プランと使用量' && s.api === 'object');
  const afterReloadBefore = before; // reload restored the original file
  inj.kill('SIGINT'); await new Promise(r => inj.on('exit', r)); await sleep(150);
  check('Ctrl+C (SIGINT): DOM identical to the original', (await c.eval(SNAP)) === afterReloadBefore);
  await c.send('Page.reload'); await sleep(1000);
  check('after stop + reload: nothing injected any more', (await q()).api === 'undefined');
  b.stop();
}

async function agents() {
  console.log('--- Agents-window chrome / menus / welcome fixture (scope all + settings)');
  const PORT = 9446; const b = await startChrome(PORT, fx('workbench-agents.html')); const c = b.cdp;
  const P = ['--port', String(PORT), '--url-filter', 'workbench-agents'];
  const q = () => c.eval(`(() => { const o = {}; for (const e of document.querySelectorAll('[id]')) { o[e.id] = e.textContent;
      if (e.hasAttribute('title')) o[e.id + '@title'] = e.getAttribute('title'); if (e.hasAttribute('aria-label')) o[e.id + '@aria'] = e.getAttribute('aria-label');
      if (e.hasAttribute('placeholder')) o[e.id + '@ph'] = e.getAttribute('placeholder'); if (e.hasAttribute('data-placeholder')) o[e.id + '@dph'] = e.getAttribute('data-placeholder');
      if ('value' in e && e.tagName !== 'BUTTON') o[e.id + '@val'] = e.value; } return o; })()`);
  const before = await c.eval(SNAP); const orig = await q();
  let r = run(['apply', '--once', '--lang', 'ja', ...P]);
  check('agents: apply (default scope all) exits 0', r.code === 0, r.out.split('\n')[0]);
  let s = await q();
  const t = id => (s[id] || '').trim();
  check('sidebar actions: New Chat / Automations / Customize', t('a-newchat') === '新しいチャット' && t('a-auto') === '自動化' && t('a-cust') === 'カスタマイズ', [t('a-newchat'), t('a-auto'), t('a-cust')].join('|'));
  check('sidebar collection headers: Projects / Repositories', t('h-projects') === 'プロジェクト' && t('h-repos') === 'リポジトリ');
  check('sidebar fixed group "No Repo" + "New Project" action row', t('g-norepo') === 'リポジトリなし' && t('r-newproject') === '新しいプロジェクト');
  check('USER DATA untouched: chat rows titled "New Chat"/"Automations"/"Cursor greeting", subagent row, project row "New Project"',
    t('r-chat1') === 'New Chat' && s['r-chat1@title'] === 'New Chat' && t('r-chat2') === 'Automations' && t('r-chat3') === 'Cursor greeting' && t('r-sub') === 'Status' && t('r-project-default') === 'New Project');
  check('USER DATA untouched: a repository group named "Projects", a folder section head named "New Project"', t('g-userrepo') === 'Projects' && t('s-userfolder') === 'New Project');
  check('filter menu: Grouping / Ordering / Show / Filters / Status / PR / Environment / Source / Archived / Mark All as Read',
    s['m-grouping'].startsWith('グループ分け') && t('m-grouping-val') === 'リポジトリ' && t('m-ordering') === '並び順' && t('m-show') === '表示' && t('m-filters') === '絞り込み' &&
    t('m-status') === '状態' && t('m-pr') === 'プルリクエスト' && t('m-env') === '実行環境' && t('m-source') === '作成元' && t('m-archived') === 'アーカイブ済み' && t('m-markall') === 'すべて既読にする');
  check('submenus: options translated, aria-labels of menus left in English', t('m-r-repo') === 'リポジトリ' && t('m-e-cloud') === 'クラウド' &&
    s['menu-sub@aria'] === 'Grouping' && s['menu-main@aria'] === 'Sidebar filters' && s['filter-trigger@aria'] === 'Customize Sidebar');
  check('USER DATA untouched in menus: host name, model names, branch, menu search value', t('m-e-host') === 'my-mac.local' && t('m-model-auto') === 'Auto' &&
    t('m-model-x') === 'claude-4.5-sonnet' && t('m-branch') === 'main' && s['m-model-search@val'] === 'Status' && s['m-model-search@ph'] === 'Search models');
  check('CHAT untouched: message bodies (incl. a button inside a message), tab title, project title', t('msg-user') === 'New Chat' && s['msg-ai'] === orig['msg-ai'] &&
    t('tab-title') === 'Cursor greeting' && t('proj-title') === 'New Project');
  check('COMPOSER untouched: contenteditable placeholder, textarea value + placeholder', s['composer-p@dph'] === 'Send follow-up' && s['composer-ta@val'] === 'Mark All as Read' && s['composer-ta@ph'] === 'Send follow-up');
  check('chip "Create Repo" translated; loose "Cloud"/"Show" text outside the defined areas untouched', t('chip-create') === 'リポジトリを作成' && t('env-label') === 'Cloud' && t('plain-show') === 'Show');
  check('editor welcome: Open project / Clone repo / Connect via SSH / Recent projects', t('w-open') === 'プロジェクトを開く' && t('w-clone') === 'リポジトリをクローン' && t('w-ssh') === 'SSH で接続' && t('w-recent') === '最近のプロジェクト');
  check('USER DATA untouched: recent project names (even if they look like UI words)', s['w-item1'] === orig['w-item1'] && s['w-item2'] === orig['w-item2']);
  r = run(['revert', ...P]);
  check('agents: revert -> DOM identical', r.code === 0 && (await c.eval(SNAP)) === before);
  r = run(['apply', '--once', '--lang', 'ja', '--scope', 'settings', ...P]);
  s = await q();
  check('--scope settings: Agents-window chrome and welcome screen stay English', (s['a-newchat'] || '').trim() === 'New Chat' && (s['m-markall'] || '').trim() === 'Mark All as Read' && (s['w-open'] || '').trim() === 'Open project');
  run(['revert', ...P]);
  check('agents: revert after --scope settings -> DOM identical', (await c.eval(SNAP)) === before);
  b.stop();
}

async function real() {
  console.log('--- 0.3.3: real-DOM chrome (Agents + editor window), bypassDeny, CSS placeholder, shadow menu, capture-scope all');
  const PORT = 9447; const b = await startChrome(PORT, fx('workbench-real.html')); const c = b.cdp;
  const P = ['--port', String(PORT), '--url-filter', 'workbench-real'];
  const q = () => c.eval(`(() => { const o = {}; for (const e of document.querySelectorAll('[id]')) { o[e.id] = e.textContent;
      for (const a of e.getAttributeNames()) o[e.id + '@' + a] = e.getAttribute(a); }
    const ph = id => { const el = document.getElementById(id); return el ? getComputedStyle(el, '::before').content : ''; };
    const ed = document.getElementById('editor'); const ed2 = document.getElementById('editor2');
    o.ph1 = ph('editor-p'); o.ph2 = ph('editor2-p'); o.editorHTML = (ed ? ed.outerHTML : '') + (ed2 ? ed2.outerHTML : '');
    o.menu = typeof window.menuText === 'function' ? window.menuText() : ''; return o; })()`);
  const before = await c.eval(SNAP); const orig = await q();
  check('fixture sanity: Cursor-style placeholder shows the English text', orig.ph1 === '"Plan, Build, / for skills, @ for context"', orig.ph1);
  let r = run(['apply', '--once', '--lang', 'ja', ...P]);
  check('real: apply exits 0', r.code === 0, r.out.split('\n')[0]);
  await c.eval('window.openMenu(), 1'); await sleep(300); await c.eval('window.addMenuItem(), 1'); await sleep(300);
  let s = await q();
  const t = id => (s[id] || '').trim();
  check('Projects header (real path) translated; a user group that is also named "Projects" stays', t('h-projects') === 'プロジェクト' && t('h-userws') === 'Projects', t('h-projects') + '|' + t('h-userws'));
  check('"No Repo" sidebar row translated; repository row name stays', t('row-norepo') === 'リポジトリなし' && t('row-repo') === 'cursor-i18n');
  check('relative times in chat rows translated (3h, 1mo)', t('t-3h') === '3時間' && t('t-1mo') === '1か月', t('t-3h') + '|' + t('t-1mo'));
  check('USER DATA untouched: chat titles in the same rows (one is literally "3h")', t('chat-title') === '3h' && t('chat-title2') === 'Mac data greeting');
  check('sidebar icon aria-labels: Hide Sidebar / Go Back / Customize Sidebar / Settings / Resize sidebar / New Project',
    s['i-hide@aria-label'] === 'サイドバーを隠す' && s['i-back@aria-label'] === '戻る' && s['i-custom@aria-label'] === 'サイドバーのカスタマイズ' &&
    s['i-settings@aria-label'] === '設定' && s['resize@aria-label'] === 'サイドバーの幅を変更' && s['np-trigger@aria-label'] === '新しいプロジェクト' && t('np-trigger') === '新しいプロジェクト');
  check('chat-row icons (inside the denied row): Pin / Archive / Completed', s['a-pin@aria-label'] === 'ピン留め' && s['a-arch@aria-label'] === 'アーカイブ' && s['st-done@aria-label'] === '完了');
  check('USER DATA untouched: account name in the footer (text + aria-label)', t('user-name') === 'USER NAME' && s['user-name@id'] === 'user-name' && orig['user-name'] === s['user-name']);
  check('composer pickers: No Repo / Cloud labels + aria-labels', t('pk-project-label') === 'リポジトリなし' && t('pk-env-label') === 'クラウド' &&
    s['pk-project@aria-label'] === 'リポジトリなし、プロジェクトを選択' && s['pk-env@aria-label'] === 'クラウド、実行環境を選択', s['pk-project@aria-label']);
  check('USER DATA untouched: branch "main" + machine name (aria patterns keep them)', t('pk-branch-label') === 'main' && s['pk-branch@aria-label'] === 'ブランチ main、ブランチのメニューを開く' &&
    t('pk-env2-label') === 'my-mac' && s['pk-env2@aria-label'] === 'my-mac、実行環境を選択');
  check('toolbar / top bar aria-labels: Add agents… / voice input / voice chat / Chat actions', s['tb-add@aria-label'] === 'エージェント・コンテキスト・ツールを追加' &&
    s['tb-voice@aria-label'] === '音声入力を開始' && s['tb-vchat@aria-label'] === '音声チャットを開始' && s['chat-actions@aria-label'] === 'チャットの操作');
  check('USER DATA untouched: model name "Auto"', t('model') === 'Auto');
  check('Plan New Idea chip translated, key hint kept', t('pill-label') === '新しいアイデアを計画' && t('pill-hint') === '⇧Tab');
  check('Claude Code import banner + Dismiss', t('cc1') === 'Claude Code の会話をインポート' && t('cc2') === 'チャットを同期して、Cursor で続けられます' && s['cc-dismiss@aria-label'] === '閉じる');
  check('composer placeholder drawn in Japanese by CSS', s.ph1 === '"計画・作成（/ でスキル、@ でコンテキスト）"', s.ph1);
  check('COMPOSER untouched: editor DOM/attributes identical (incl. aria-label "Prompt"), typed text stays, no placeholder on a non-empty paragraph',
    s.editorHTML === orig.editorHTML && t('editor2-p') === 'Plan New Idea' && s.ph2 === orig.ph2);
  check('editor window: Cursor Settings tab (text + aria) / Agents Window / title-bar aria (with shortcut)', t('tab-settings-label') === 'Cursor の設定' && s['tab-settings@aria-label'] === 'Cursor の設定' &&
    t('aw-label') === 'エージェント画面' && s['tt-toggle@aria-label'] === 'プライマリ サイドバーの切り替え (⌘B)' && s['tt-settings@aria-label'] === 'Cursor の設定を開く');
  check('USER DATA untouched: a file tab that happens to be named "Cursor Settings", window title', t('tab-file-label') === 'Cursor Settings' && s['tab-file@aria-label'] === 'Cursor Settings' && t('win-title') === 'my-project — Cursor');
  check('status bar: Tab Stats / No commit scored / Cursor Tab + aria-labels; Claude Code item untouched',
    t('sb-tab') === 'Tab 補完の統計: 3/7（42%）' && t('sb-commit') === '集計済みのコミットなし' && t('sb-ct') === 'Cursor Tab 補完' &&
    s['aiCodeTracking.stats.tab@aria-label'] === 'Tab 補完の AI 統計: 提案 7 件のうち 3 件を採用、採用率 42%' && t('sb-claude') === '✻ Claude Code' &&
    s['Anthropic.claude-code@aria-label'] === '✻ Claude Code, Open Claude Code', t('sb-tab'));
  check('"…" menu in a shadow root (opened after apply, item added later): Open Browser / Configure Icon Visibility; "Claude Code: Open" kept', s.menu === 'Claude Code: Open|ブラウザーを開く|アイコンの表示を設定|ブラウザーを開く', s.menu);
  check('editor agent pane: default title "New Agent", placeholder line, Log in, Upgrade translated; aria-label kept',
    t('ap-h2') === '新しいエージェント' && t('ap-title') === '新しいエージェント' && t('ap-ph') === '計画・作成（/ でスキル、@ でコンテキスト）' && t('ap-login') === 'ログイン' &&
    t('up-text') === 'アップグレード' && s['up-btn@aria-label'] === 'Upgrade', t('ap-title') + '|' + t('ap-ph') + '|' + t('ap-login'));
  check('USER DATA untouched: a real chat title, the composer text, the model name', t('ap-title2') === 'Fix login bug' && t('ap-input') === 'Log in' && t('ap-model') === 'Auto');
  check('0.3.5: Customize editor tab label, Browse Marketplace button (aria kept); plain "Browse" elsewhere in Customize stays 参照',
    t('tab-cust-label') === 'カスタマイズ' && s['tab-cust@aria-label'] === 'Customize' && (s['browse-btn'] || '').startsWith('探す') && t('browse-mk') === '（マーケットプレイス）' &&
    s['browse-btn@aria-label'] === 'Browse Marketplace' && t('cust-browse2') === '参照', s['browse-btn'] + '|' + t('cust-browse2'));
  check('0.3.5: model picker options + settings trigger translated through the markdown deny; model name and chat markdown untouched',
    t('mp-default') === 'デフォルト' && t('mp-inherit') === '親から引き継ぐ' && t('mp-trigger-p') === 'デフォルト' && t('mp-model') === 'gpt-5' && t('chat-md-p') === 'Default',
    [t('mp-default'), t('mp-trigger-p'), t('chat-md-p')].join('|'));
  // 0.3.7 groups (Cursor 3.28.7 screenshots)
  check('0.3.7 VS Code Settings editor: Cursor descriptions translated; titles, enum values, input values, other descriptions untouched',
    t('vsc-desc1') === 'エージェントのチャットのコードブロックで長い行を折り返します。' && t('vsc-title') === 'Cursor › Composer: Code Block Word Wrap' && t('vsc-desc2') === 'Status chimes' &&
    t('vsc-desc3') === 'Allow setting breakpoints in any file.' && t('vsc-opt') === 'Compact' && (await c.eval("document.getElementById('vsc-input').value")) === 'Show rotating tips on the empty screen.', [t('vsc-desc1'), t('vsc-desc2'), t('vsc-opt')].join('|'));
  check('0.3.7 tab title "VS Code Settings" translated only on the settings tab (a file tab with the same name stays)', t('vsc-tab') === 'VS Code の設定' && t('file-tab') === 'VS Code Settings', t('vsc-tab') + '|' + t('file-tab'));
  check('0.3.7 project picker: headings/rows + search placeholder translated; repo name, search value and the same word outside untouched',
    t('picker-recents') === '最近使った項目' && t('picker-mac') === 'この Mac' && t('picker-remote') === 'リモート' && t('picker-existing') === '既存のフォルダーを使う...' &&
    s['picker-search@placeholder'] === 'リポジトリ、クラウド実行環境を検索...' && t('picker-repo') === 'sui-archive' && t('outside-recents') === 'Recents' && (await c.eval("document.getElementById('picker-search').value")) === '',
    [t('picker-recents'), s['picker-search@placeholder'], t('outside-recents')].join('|'));
  r = run(['revert', ...P]);
  s = await q();
  check('real: revert -> DOM identical, placeholder back to English, shadow menu back to English', r.code === 0 && (await c.eval(SNAP)) === before && s.ph1 === orig.ph1 && s.menu === 'Claude Code: Open|Open Browser|Configure Icon Visibility|Open Browser', s.menu);
  r = run(['apply', '--once', '--lang', 'ja', '--scope', 'settings', ...P]);
  s = await q();
  check('--scope settings: everything outside Settings stays English (sidebar, times, pickers, placeholder, editor window, menu)',
    t('h-projects') === 'Projects' && t('t-3h') === '3h' && s['pk-env@aria-label'] === 'Cloud, select environment' && s.ph1 === orig.ph1 && t('sb-tab') === 'Tab Stats: 3/7 (42%)' && s.menu === 'Claude Code: Open|Open Browser|Configure Icon Visibility|Open Browser');
  run(['revert', ...P]);
  check('real: revert after --scope settings -> DOM identical', (await c.eval(SNAP)) === before);
  // built-in capture (opt-in, outside Settings)
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'cursor-i18n-cap-'));
  const capA = path.join(tmp, 'a.json'), capS = path.join(tmp, 's.json');
  r = run(['apply', '--once', '--capture', capS, ...P]); run(['revert', ...P]);
  const docS = fs.existsSync(capS) ? JSON.parse(fs.readFileSync(capS, 'utf8')) : { strings: [] };
  check('--capture (default scope settings) records nothing outside Settings', r.code === 0 && docS.strings.length === 0, docS.strings.length);
  r = run(['apply', '--once', '--capture', capA, '--capture-scope', 'all', ...P]); run(['revert', ...P]);
  const doc = JSON.parse(fs.readFileSync(capA, 'utf8')); const by = new Map(doc.strings.map(x => [x.text, x]));
  check('--capture-scope all: records outside UI strings with tier + DOM path', r.code === 0 && by.has('Plan New Idea') && by.get('Plan New Idea').tier === 'outside' &&
    /ui-pill/.test(by.get('Plan New Idea').path || '') && by.has('Hide Sidebar') && by.get('Hide Sidebar').attr === 'aria-label', [...by.keys()].slice(0, 8).join('|'));
  check('--capture-scope all skips user data: chat titles, account name, typed text, "Prompt" on the editor, editor placeholder',
    !by.has('Mac data greeting') && !by.has('USER NAME') && !by.has('Prompt') && !by.has('Send follow-up') && ![...by.values()].some(x => /contenteditable|ProseMirror/.test(x.path || '')));
  r = run(['apply', '--once', '--lang', 'ja', '--capture', path.join(tmp, 'j.json'), '--capture-scope', 'all', ...P]); run(['revert', ...P]);
  const docJ = JSON.parse(fs.readFileSync(path.join(tmp, 'j.json'), 'utf8')); const byJ = new Set(docJ.strings.map(x => x.text));
  check('--capture-scope all with --lang: translated strings are not recorded (only what is still English)', !byJ.has('Plan New Idea') && !byJ.has('Hide Sidebar') && byJ.size < by.size, byJ.size + '<' + by.size);
  r = run(['apply', '--once', '--capture', capA, '--capture-scope', 'everything', ...P]);
  check('--capture-scope with an unknown value -> exit 2', r.code === 2, r.out.trim().split('\n').pop());
  check('real: DOM identical after the capture runs', (await c.eval(SNAP)) === before);
  fs.rmSync(tmp, { recursive: true, force: true });
  b.stop();
}

async function popups() {
  console.log('--- 0.3.4: menus / tooltips / dialogs / toasts / empty states, watch mode + coverage report');
  const PORT = 9448; const b = await startChrome(PORT, fx('workbench-popups.html')); const c = b.cdp;
  const P = ['--port', String(PORT), '--url-filter', 'workbench-popups'];
  const q = () => c.eval(`(() => { const o = {}; for (const e of document.querySelectorAll('[id]')) { o[e.id] = e.textContent;
      for (const a of e.getAttributeNames()) o[e.id + '@' + a] = e.getAttribute(a); }
    const search = document.getElementById('menu-search'); const ed = document.getElementById('ed-p');
    o['menu-search@val'] = search ? search.value : ''; o.ph = ed ? getComputedStyle(ed, '::before').content : ''; return o; })()`);
  const before = await c.eval(SNAP); const orig = await q();
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'cursor-i18n-watch-'));
  // 1) watch (read-only) while "clicking around": a tooltip appears after start
  const capW = path.join(tmp, 'watch.json');
  const inj = spawn(process.execPath, [INJ, 'watch', '--lang', 'ja', '--out', capW, ...P], { stdio: ['ignore', 'pipe', 'pipe'] });
  let out = ''; inj.stdout.on('data', d => (out += d)); inj.stderr.on('data', d => (out += d));
  for (let i = 0; i < 50 && !/running\./.test(out); i++) await sleep(100);
  await c.eval('window.addTooltip(), 1'); await sleep(300);
  const during = await c.eval(SNAP);
  inj.kill('SIGINT'); await new Promise(r => inj.on('exit', r));
  await c.eval(`['tip2','tip3'].forEach(i => document.getElementById(i).remove()), 1`);
  check('watch: read-only (DOM identical while it runs, incl. a tooltip that appeared later; no CSS added)', /read-only/.test(out) && during.replace(/\n<DIV [^\n]*id="tip[23]"[^\n]*\n#[^\n]*/g, '') === before, out.split('\n')[0]);
  const W = JSON.parse(fs.readFileSync(capW, 'utf8')); const wb = new Map(W.strings.map(x => [x.text, x])); const cov = W.covered || {};
  check('watch: untranslated strings recorded with popup kind + DOM path (menu item, dialog text, late tooltip)',
    wb.has('Zorblex the frobnicator') && wb.get('Zorblex the frobnicator').popup === 'menu' && /menu-popup/.test(wb.get('Zorblex the frobnicator').path) &&
    wb.has('Quantum flux capacitor warmed up') && wb.get('Quantum flux capacitor warmed up').popup === 'dialog' && wb.has('Frobnicate the widget') && wb.get('Frobnicate the widget').popup === 'tooltip', [...wb.keys()].join('|'));
  check('watch: translatable strings counted as covered (menu, tooltip, toast, dialog)', cov['Mark as Unread'] && cov['Copied to clipboard'] && cov['Copied to clipboard'].popup === 'tooltip' && cov['Something went wrong'] && cov['Cancel'] && cov['Fork Chat'], Object.keys(cov).join('|'));
  check('watch: never records user data (chat row title, message body, menu search value, editor)',
    !wb.has('Fork Chat') && ![...wb.values()].some(x => /data-message-role|ProseMirror|contenteditable|selectable-agent/.test(x.path || '')) && !Object.values(cov).some(x => x.path));
  // 2) coverage report (offline)
  const rep = path.join(tmp, 'report.md');
  const vf = path.join(tmp, 'v.json'); fs.writeFileSync(vf, JSON.stringify({ entries: [{ english: 'Mark as Unread', verifiedOnScreen: false }, { english: 'Never shown', verifiedOnScreen: false }] }));
  let r = run(['coverage', '--in', capW, '--lang', 'ja', '--out', rep, '--verify', vf]);
  const md = fs.existsSync(rep) ? fs.readFileSync(rep, 'utf8') : ''; const V = JSON.parse(fs.readFileSync(vf, 'utf8'));
  check('coverage: report lists untranslated strings by place with DOM path; marks bundle entries seen on screen',
    r.code === 0 && /## menu/.test(md) && /Zorblex the frobnicator \| text \| no \| `.*menu-popup/.test(md) && V.entries[0].verifiedOnScreen === true && V.entries[1].verifiedOnScreen === false, r.out.trim().split('\n').pop());
  check('coverage: "in the pack but not applied here" shown (selector gap)', /Discard changes \| text \| yes: /.test(md) && /selector gap/.test(md));
  // 3) apply
  r = run(['apply', '--once', '--lang', 'ja', ...P]);
  let s = await q(); const t = id => (s[id] || '').trim();
  check('popups: menu items (single words OK inside a menu), empty state', t('mi1-t') === '名前を変更' && t('mi2-t') === '未読にする' && t('mi3-t') === '削除', [t('mi1-t'), t('mi2-t'), t('mi3-t'), t('m-empty')].join('|'));
  check('popups: tooltip / toast / dialog title + buttons', t('tip') === 'クリップボードにコピーしました' && t('toast-t') === '問題が発生しました' && t('dlg-t') === '変更を破棄' && t('dlg-c') === 'キャンセル' && t('dlg-ok') === '削除');
  check('aria-labels left in English (Cursor finds some elements by them); menu search value + unknown text kept',
    s['mi1@aria-label'] === 'Rename' && s['menu@aria-label'] === 'Chat actions' && s['menu-search@val'] === 'Delete' && s['ap-btn@aria-label'] === 'Export Chat' && t('mi4-t') === 'Zorblex the frobnicator' && t('dlg-d') === 'Quantum flux capacitor warmed up');
  check('agents chrome: multi-word button text + title translated; single word / chat row / message body / loose text untouched',
    t('ap-btn-l') === 'チャットを書き出す' && s['ap-btn@title'] === 'チャットを書き出す' && t('sb-cta') === 'まだエージェントはありません' && t('sb-single') === 'Delete' &&
    t('row-title') === 'Fork Chat' && t('msg') === 'Something went wrong' && t('msg-btn') === 'Discard changes' && t('loose-1') === 'Discard changes');
  check('ProseMirror placeholder drawn by CSS only (editor DOM unchanged)', s.ph === '"変更を計画"' && s['ed-p@data-placeholder'] === 'Plan changes', s.ph);
  // 4) 0.3.7: watch while apply is active must NOT revert/replace the translator (bug found on 3.28.7, 2026-11-04)
  const capA = path.join(tmp, 'watch-alongside.json');
  const inj2 = spawn(process.execPath, [INJ, 'watch', '--lang', 'ja', '--out', capA, ...P], { stdio: ['ignore', 'pipe', 'pipe'] });
  let out2 = ''; inj2.stdout.on('data', d => (out2 += d)); inj2.stderr.on('data', d => (out2 += d));
  for (let i = 0; i < 50 && !/running\./.test(out2); i++) await sleep(100);
  await c.eval('window.addTooltip(), 1'); await sleep(300);
  s = await q();
  const live = await c.eval('({ t: window.__cursorI18n && window.__cursorI18n.stats().active, ro: window.__cursorI18n && window.__cursorI18n.readOnly, w: !!(window.__cursorI18nWatch && window.__cursorI18nWatch.readOnly) })');
  check('watch + apply: translation keeps running (text stays Japanese, translator still active, watcher in its own global)',
    t('mi1-t') === '名前を変更' && t('tip') === 'クリップボードにコピーしました' && live.t === true && live.ro === false && live.w === true, JSON.stringify(live) + ' ' + t('mi1-t'));
  check('watch + apply: a tooltip that appears later is still translated by the translator', t('tip2') === '分岐チャット' || (t('tip2') !== 'Fork Chat' && /[\u3040-\u30ff\u4e00-\u9fff]/.test(t('tip2'))), t('tip2'));
  check('watch + apply: Japanese notice that it records alongside, without the English line', /止めずに/.test(out2) && !/recording alongside it/.test(out2), out2.split('\n').filter(x => /止めずに|recording alongside|watch:/.test(x)).join(' / '));
  inj2.kill('SIGINT'); await new Promise(r => inj2.on('exit', r));
  s = await q();
  check('watch + apply: stopping the watcher (Ctrl+C) leaves the translation in place', t('mi1-t') === '名前を変更' && (await c.eval('window.__cursorI18n.stats().active')) === true && (await c.eval('typeof window.__cursorI18nWatch')) === 'object');
  const WA = JSON.parse(fs.readFileSync(capA, 'utf8')); const wa = new Set(WA.strings.map(x => x.text)); const covA = WA.covered || {};
  check('watch + apply: untranslated English recorded; already-translated strings counted as covered under their English key',
    wa.has('Zorblex the frobnicator') && wa.has('Frobnicate the widget') && !WA.strings.some(x => x.render === 'text' && /^(Rename|Mark as Unread|Copied to clipboard)$/.test(x.text)) && covA['Rename'] && covA['Copied to clipboard'] && !Object.keys(covA).some(k => /[\u3040-\u30ff]/.test(k)), [...wa].join('|') + ' || ' + Object.keys(covA).join('|'));
  await c.eval(`['tip2','tip3'].forEach(i => document.getElementById(i).remove()), 1`);
  await c.eval(`(() => {
    const menu = document.getElementById('menu');
    const item = document.createElement('div');
    item.id = 'mi-quit'; item.setAttribute('role', 'menuitem'); item.textContent = 'Quit';
    menu.appendChild(item);
    const box = document.createElement('div');
    box.id = 'quit-box'; box.setAttribute('role', 'dialog'); box.setAttribute('data-component', 'dialog');
    const add = (tag, id, text) => { const e = document.createElement(tag); e.id = id; if (text) e.textContent = text; box.appendChild(e); return e; };
    add('div', 'quit-title', 'Quit Cursor?');
    add('div', 'quit-body', 'Are you sure you want to quit?');
    const ask = add('label', 'quit-ask');
    ask.appendChild(document.createElement('input')).type = 'checkbox';
    ask.appendChild(document.createTextNode("Don't ask again"));
    add('button', 'quit-cancel', 'Cancel (esc)');
    const btn = add('button', 'quit-btn');
    const label = document.createElement('span'); label.id = 'quit-label'; label.textContent = 'Quit'; btn.appendChild(label);
    const kbd = document.createElement('span'); kbd.id = 'quit-kbd'; kbd.setAttribute('data-component', 'keybinding'); kbd.textContent = '\\u21B5'; btn.appendChild(kbd);
    add('button', 'quit-flat', 'Quit \\u21B5');
    document.body.appendChild(box);
  })()`);
  await sleep(50);
  s = await q();
  check('quit dialog: title, body, Quit label, checkbox, and cancel; the ↵ node stays; a menu Quit stays English',
    t('quit-title') === 'Cursor を終了しますか？' && t('quit-body') === '終了してもよろしいですか？' && t('quit-label') === '終了' && t('quit-kbd') === '↵' &&
    t('quit-flat') === '終了 ↵' && t('quit-ask') === '今後は確認しない' && t('quit-cancel') === 'キャンセル（Esc）' && t('mi-quit') === 'Quit',
    [t('quit-title'), t('quit-body'), t('quit-label'), t('quit-kbd'), t('quit-flat'), t('quit-ask'), t('quit-cancel'), t('mi-quit')].join('|'));
  await c.eval(`['quit-box','mi-quit'].forEach(id => { const e = document.getElementById(id); if (e) e.remove(); })`);
  run(['revert', ...P]);
  check('popups: revert -> DOM identical', (await c.eval(SNAP)) === before);
  fs.rmSync(tmp, { recursive: true, force: true });
  b.stop();
}

async function cli() {
  console.log('--- CLI errors / exit codes');
  let r = run(['apply', '--lang', 'xx', '--once']);
  check('unknown language -> exit 3 with list of languages', r.code === 3 && /ja/.test(r.out), r.out.trim().split('\n').pop());
  r = run(['apply', '--lang', '../etc/passwd', '--once']);
  check('path tricks in --lang refused (exit 3)', r.code === 3);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'cursor-i18n-test-'));
  fs.writeFileSync(path.join(tmp, 'ja.json'), JSON.stringify({ schemaVersion: 1, meta: { lang: 'ja' }, exact: { A: 'x' } }));
  r = run(['apply', '--lang', 'ja', '--locales-dir', tmp, '--once']);
  check('invalid pack refused before connecting (exit 3)', r.code === 3 && /meta\.name/.test(r.out));
  r = run(['apply', '--lang', 'ja', '--once', '--port', '9499']);
  check('debug port not reachable -> exit 4', r.code === 4, r.out.trim().split('\n').pop());
  let refused = false; try { new (require('../tools/inject.js').WS)('ws://192.168.1.10:9444/x'); } catch { refused = true; }
  check('WebSocket client refuses non-127.0.0.1 hosts', refused);
  fs.rmSync(tmp, { recursive: true, force: true });
}

(async () => {
  if (!findChrome()) { console.log('SKIP: Chrome/Chromium が見つからないためブラウザーテストを省略（CHROME=パス で指定可）'); await cli(); }
  else { await glass(); await agents(); await real(); await popups(); await classic(); await cli(); }
  console.log(`RESULT engine: ${T.pass} passed, ${T.fail} failed`);
  process.exit(T.fail ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
