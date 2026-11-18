'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { makeChecker } = require('./lib');
const src = require('../tools/locale-source.js');
const T = makeChecker();
const check = T.check;
const schema = src.readJson(path.join(src.ROOT, 'schema', 'locale-pack.schema.json'));
const template = src.readJson(src.templatePath());
const ja = src.readJson(path.join(src.ROOT, 'locales', 'ja.json'));

const templateErrors = [];
src.checkSchema(template, schema, 'template', templateErrors, { allowEmpty: true });
check('template validates against the schema (empty values allowed)', templateErrors.length === 0, templateErrors.slice(0, 3).join(' | '));
const strict = [];
src.checkSchema(template, schema, 'template', strict, { allowEmpty: false });
check('empty values are not allowed outside the template', strict.some(e => /empty/.test(e)));
const jaErrors = [];
src.checkSchema(ja, schema, 'ja', jaErrors, { allowEmpty: false });
check('ja.json validates against the schema', jaErrors.length === 0, jaErrors.slice(0, 3).join(' | '));

const drift = src.diffPack(template, ja);
check('ja.json has no missing or stale keys against the template', drift.missing.length === 0 && drift.stale.length === 0 && drift.placeholder.length === 0 && drift.structure.length === 0, 'missing ' + drift.missing.length + ' stale ' + drift.stale.length);
check('ja.json records the template Cursor version', ja.meta.cursorVersion === template.meta.cursorVersion && drift.versionOk);

const mini = {
  schemaVersion: 1,
  meta: { lang: 'en', name: 'English (source)', nativeName: 'English', packVersion: '0.0.0', cursorVersion: '9.9.9', updated: '2026-11-17', scope: 'all', notes: 'source' },
  exact: { Hello: '' },
  patterns: { 'Open {0}': '' },
  scoped: [{ id: 'g', selector: 'a', exact: { Zoom: '' } }],
};
const old = {
  schemaVersion: 1,
  meta: { lang: 'ja', name: 'Japanese', nativeName: '日本語', packVersion: '0.1.0', cursorVersion: '1.0.0', updated: '2026-11-17', scope: 'all' },
  exact: { Hello: 'こんにちは', Gone: '消えた' },
  patterns: { 'Open {0}': '開く' },
  scoped: [{ id: 'g', selector: 'a', exact: { Zoom: '拡大' } }, { id: 'old', selector: 'b', exact: { Bye: 'さよなら' } }],
};
mini.exact.New = '';
const d = src.diffPack(mini, old);
check('sync reports a missing key, a stale key, a placeholder mismatch, and the Cursor version', d.missing.some(e => e.key === 'New') && d.stale.some(e => e.key === 'Gone' && e.value === '消えた') && d.placeholder.some(e => e.key === 'Open {0}') && d.versionOk === false);
const applied = src.applyDiff(mini, old);
check('apply keeps an existing translation and parks the stale one', applied.locale.exact.Hello === 'こんにちは' && applied.locale.exact.New === '' && applied.locale.exact.Gone === undefined && applied.stale.some(e => e.key === 'Gone' && e.value === '消えた') && applied.locale.patterns['Open {0}'] === '開く');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'wtw-locale-'));
fs.mkdirSync(path.join(tmp, 'templates'), { recursive: true });
fs.copyFileSync(src.templatePath(), path.join(tmp, 'templates', 'locale-template.json'));
const made = src.createLocale('zh-CN', { root: tmp });
check('new-locale accepts zh-CN and writes a draft, not locales/', made.endsWith('/drafts/zh-cn.json') && !fs.existsSync(path.join(tmp, 'locales', 'zh-cn.json')));
const draft = src.readJson(made);
const sample = Object.keys(template.exact)[0];
check('draft is marked not shipped, copies the template keys, and records its Cursor version', /DRAFT/.test(draft.meta.notes) && /not shipped/i.test(draft.meta.notes) && draft.meta.cursorVersion === template.meta.cursorVersion && draft.exact[sample] === '' && draft.meta.lang === 'zh-cn');
check('display name is brand, target, and the language layer from meta.name', src.displayName('Japanese') === 'Word to World for Cursor | Japanese Language Layer' && src.displayName(draft.meta.name) === 'Word to World for Cursor | Simplified Chinese Language Layer' && draft.meta.name === 'Simplified Chinese');
const tw = src.createLocale('zh-HK', { root: tmp });
check('zh-HK is accepted as zh-tw', tw.endsWith(path.join('drafts', 'zh-tw.json')));
let refused = false;
try { src.createLocale('ZH-TW', { root: tmp }); } catch (e) { refused = /overwrite/.test(e.message); }
check('new-locale refuses to overwrite an existing draft', refused);
let unknown = false;
try { src.createLocale('xx', { root: tmp }); } catch (e) { unknown = e.code === 2; }
check('new-locale rejects an id outside the vscode-loc list', unknown);
const node = process.execPath;
const cli = execFileSync(node, [path.join(src.ROOT, 'tools', 'sync-locale.js'), '--check'], { encoding: 'utf8' });
check('sync-locale --check exits 0 for ja', /ja: in sync/.test(cli));

function bytes(p) { return fs.existsSync(p) ? fs.readFileSync(p) : null; }
function sameBytes(a, b) {
  if (a === null || b === null) return a === b;
  return a.equals(b);
}
function syncRoot(locale) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wtw-sync-'));
  const templatePack = {
    schemaVersion: 1,
    meta: { lang: 'en', name: 'English (source)', nativeName: 'English', packVersion: '0.0.0', cursorVersion: '9.9.9', updated: '2026-11-17', scope: 'all', notes: 'source' },
    exact: { Hello: '' },
    patterns: {},
    scoped: [{ id: 'g', selector: 'a', exact: { Zoom: '' } }],
  };
  fs.mkdirSync(path.join(dir, 'templates'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'locales'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'templates', 'locale-template.json'), JSON.stringify(templatePack, null, 2) + '\n');
  fs.writeFileSync(path.join(dir, 'locales', 'ja.json'), JSON.stringify(locale, null, 2) + '\n');
  return dir;
}
const syncMain = require('../tools/sync-locale.js').main;
const baseLocale = {
  schemaVersion: 1,
  meta: { lang: 'ja', name: 'Japanese', nativeName: '日本語', packVersion: '0.1.0', cursorVersion: '9.9.9', updated: '2026-11-17', scope: 'all' },
  exact: { Hello: 'こんにちは' },
  patterns: {},
  scoped: [{ id: 'g', selector: 'a', exact: { Zoom: '拡大' } }],
};
function refusedUnchanged(name, dir, staleText) {
  const localePath = path.join(dir, 'locales', 'ja.json');
  const stalePath = path.join(dir, 'drafts', 'stale', 'ja.json');
  const templatePath = path.join(dir, 'templates', 'locale-template.json');
  if (staleText !== undefined) {
    fs.mkdirSync(path.dirname(stalePath), { recursive: true });
    fs.writeFileSync(stalePath, staleText);
  }
  const before = { locale: bytes(localePath), stale: bytes(stalePath), template: bytes(templatePath) };
  const code = syncMain(['node', 'sync-locale.js', 'ja', '--apply'], dir);
  const after = { locale: bytes(localePath), stale: bytes(stalePath), template: bytes(templatePath) };
  check(name, code !== 0 && sameBytes(before.locale, after.locale) && sameBytes(before.stale, after.stale) && sameBytes(before.template, after.template), 'exit ' + code);
}
refusedUnchanged('corrupt stale JSON: apply exits non-zero and leaves every input byte-identical', syncRoot(baseLocale), '{not json');
refusedUnchanged('stale entries that are not an array: apply exits non-zero and leaves every input byte-identical', syncRoot(baseLocale), '{"entries":{"bad":true}}\n');
const dupLocale = JSON.parse(JSON.stringify(baseLocale));
dupLocale.scoped.push({ id: 'g', selector: 'b', exact: { Lost: '失われた' } });
refusedUnchanged('duplicate group ids: apply exits non-zero and does not park the lost translation', syncRoot(dupLocale), undefined);
const dupDir = syncRoot(dupLocale);
syncMain(['node', 'sync-locale.js', 'ja', '--apply'], dupDir);
check('duplicate group ids leave no stale file', !fs.existsSync(path.join(dupDir, 'drafts', 'stale', 'ja.json')));

function capture(fn) {
  const lines = [];
  const orig = console.error;
  console.error = function (m) { lines.push(String(m)); };
  let code = 0;
  try { code = fn(); }
  finally { console.error = orig; }
  return { code, lines };
}
const brokenDir = syncRoot(baseLocale);
fs.writeFileSync(path.join(brokenDir, 'locales', 'ja.json'), '{not json');
const bulk = capture(() => syncMain(['node', 'sync-locale.js', '--check'], brokenDir));
const single = capture(() => syncMain(['node', 'sync-locale.js', 'ja', '--check'], brokenDir));
check('bulk --check names the file on one line and exits non-zero', bulk.code !== 0 && bulk.lines.length === 1 && bulk.lines[0].indexOf('ja.json: ') === 0 && bulk.lines[0].indexOf('\n') < 0 && bulk.lines[0].indexOf('.js:') < 0, bulk.lines.join(' | '));
check('single --check uses that same one-line error, including the file name', single.code !== 0 && single.lines.length === 1 && single.lines[0] === bulk.lines[0] && single.lines[0].indexOf('ja.json: ') === 0);
const hidden = JSON.parse(JSON.stringify(baseLocale));
hidden.scoped = [
  { id: 'g', selector: 'b', exact: { Zoom: '失われた', Extra: '消える' } },
  { id: 'g', selector: 'a', exact: { Zoom: '拡大' } },
];
const hiddenDir = syncRoot(hidden);
const hiddenCheck = capture(() => syncMain(['node', 'sync-locale.js', 'ja', '--check'], hiddenDir));
check('check refuses duplicate group ids that a map would hide', hiddenCheck.code !== 0 && /duplicate group id/.test(hiddenCheck.lines.join('\n')));
const drifted = JSON.parse(JSON.stringify(baseLocale));
drifted.exact.Old = '古い';
const driftDir = syncRoot(drifted);
const localePath = path.join(driftDir, 'locales', 'ja.json');
const localeBefore = fs.readFileSync(localePath);
const rename = fs.renameSync;
fs.renameSync = function (from, to) {
  if (String(to) === localePath) throw new Error('disk full');
  return rename.call(fs, from, to);
};
let second;
try { second = capture(() => syncMain(['node', 'sync-locale.js', 'ja', '--apply'], driftDir)); }
finally { fs.renameSync = rename; }
check('a failed locale write after the stale write asks for another sync and leaves the locale', second.code !== 0 && /run sync again/.test(second.lines.join('\n')) && fs.readFileSync(localePath).equals(localeBefore) && fs.existsSync(path.join(driftDir, 'drafts', 'stale', 'ja.json')));

console.log('RESULT locale-source: ' + T.pass + ' passed, ' + T.fail + ' failed');
process.exit(T.fail ? 1 : 0);
