'use strict';
/**
 * Language-layer loader + validator (zero dependencies; runs on any Node >= 16, incl. Cursor's built-in Node
 * via ELECTRON_RUN_AS_NODE=1).
 *
 *   node tools/pack.js validate [locales/ja.json ...]     # no args = every locales/*.json
 *   exit code: 0 = OK (warnings allowed), 1 = errors found, 2 = usage error
 *
 * Pack format (schemaVersion 1) — see schema/locale-pack.schema.json and CONTRIBUTING-AI.md:
 *   { "schemaVersion": 1,
 *     "meta": { "lang": "ja", "name": "Japanese", "nativeName": "日本語", "packVersion": "0.2.0",
 *               "cursorVersion": "3.27.22", "updated": "YYYY-MM-DD", "scope": "settings", ... },
 *     "exact":    { "<English as rendered>": "<translation>" },
 *     "patterns": { "Open {0}": "{0} を開く" },
 *     "scoped":   [ { "selector": "<CSS selector>", "exact": { ... } } ] }
 * English is the base language and has no language layer.
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'locales');
const LANG_RE = /^[a-z]{2,3}(-[A-Za-z]{2,4}|-[0-9]{3})?$/;   // ja, zh-cn, pt-br, zh-Hant, es-419
const SCOPED_AREAS = ['settings', 'agents', 'editor'];   // where a scoped group applies (--scope settings keeps only 'settings')
const META_REQUIRED = ['lang', 'name', 'nativeName', 'packVersion', 'cursorVersion', 'updated', 'scope'];
const PH_RE = /\{(\d+)\}/g;

function readDnt() {
  try {
    return fs.readFileSync(path.join(__dirname, '..', 'glossary', 'do-not-translate.txt'), 'utf8')
      .split('\n').map(s => s.replace(/#.*/, '').trim()).filter(Boolean);
  } catch { return []; }
}
// "Cursor" in these keys is the text caret (VS Code), not the product name.
const DNT_SKIP = { 'Cursor position': { Cursor: true }, 'Multi Cursor Edit': { Cursor: true } };
const placeholders = s => [...String(s).matchAll(PH_RE)].map(m => m[1]).sort().join(',');

/** Duplicate-key detection (JSON.parse silently keeps the last one). Scans object keys at any depth. */
function duplicateKeys(text) {
  const dups = []; const stack = []; let i = 0;
  const str = () => { let j = i + 1, out = ''; while (j < text.length && text[j] !== '"') { if (text[j] === '\\') { out += text.slice(j, j + 2); j += 2; } else out += text[j++]; } i = j + 1; return out; };
  let expectKey = false;
  while (i < text.length) {
    const c = text[i];
    if (c === '{') { stack.push(new Set()); expectKey = true; i++; }
    else if (c === '[') { stack.push(null); i++; }
    else if (c === '}' || c === ']') { stack.pop(); i++; }
    else if (c === ',') { expectKey = stack.length && stack[stack.length - 1] !== null; i++; }
    else if (c === '"') { const s = str(); if (expectKey) { const set = stack[stack.length - 1]; if (set.has(s)) dups.push(s); else set.add(s); expectKey = false; } }
    else i++;
  }
  return dups;
}

/** Validate one pack. Returns {errors:[], warnings:[], pack}. `file` is used for the filename/lang check. */
function validatePack(text, file) {
  const errors = [], warnings = [];
  let p;
  try { p = JSON.parse(text); } catch (e) { return { errors: [`JSON の構文エラー: ${e.message}`], warnings, pack: null }; }
  for (const d of duplicateKeys(text)) errors.push(`同じキーが 2 回以上あります: ${JSON.stringify(d)}`);
  if (!p || typeof p !== 'object' || Array.isArray(p)) return { errors: ['最上位はオブジェクトである必要があります'], warnings, pack: null };
  const allowedTop = ['$schema', 'schemaVersion', 'meta', 'exact', 'patterns', 'scoped'];
  for (const k of Object.keys(p)) if (!allowedTop.includes(k)) errors.push(`未知の最上位キー: ${k}`);
  if (p.schemaVersion !== 1) errors.push(`schemaVersion は 1 である必要があります（現在: ${JSON.stringify(p.schemaVersion)}）`);
  const m = p.meta;
  if (!m || typeof m !== 'object') errors.push('meta がありません');
  else {
    for (const k of META_REQUIRED) if (typeof m[k] !== 'string' || !m[k].trim()) errors.push(`meta.${k} が必要です（文字列）`);
    if (m.lang && !LANG_RE.test(m.lang)) errors.push(`meta.lang の形式が不正です: ${m.lang}（例: ja, zh-cn, pt-br）`);
    if (m.lang === 'en' || /^en-/.test(m.lang || '')) errors.push('英語は基準言語なのでパックは不要です');
    if (file && m.lang && path.basename(file) !== `${m.lang}.json`) errors.push(`ファイル名は ${m.lang}.json にしてください（現在: ${path.basename(file)}）`);
    if (m.scope && !['settings', 'all'].includes(m.scope)) errors.push(`meta.scope は settings か all: ${m.scope}`);
    if (m.updated && !/^\d{4}-\d{2}-\d{2}$/.test(m.updated)) errors.push(`meta.updated は YYYY-MM-DD: ${m.updated}`);
    if (m.packVersion && !/^\d+\.\d+\.\d+$/.test(m.packVersion)) errors.push(`meta.packVersion は x.y.z: ${m.packVersion}`);
  }
  const dnt = readDnt();
  const checkMap = (obj, where, isPattern) => {
    if (obj === undefined) return 0;
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) { errors.push(`${where} はオブジェクトである必要があります`); return 0; }
    let n = 0;
    for (const [k, v] of Object.entries(obj)) {
      const at = `${where}[${JSON.stringify(k.length > 60 ? k.slice(0, 57) + '...' : k)}]`;
      if (typeof v !== 'string') { errors.push(`${at}: 訳は文字列である必要があります`); continue; }
      n++;
      if (k !== k.trim()) errors.push(`${at}: キーの前後に空白があります（表示文字は前後の空白を除いて照合します）`);
      if (!k.trim()) errors.push(`${where}: 空のキーがあります`);
      if (!v.trim()) errors.push(`${at}: 訳が空です（訳さない場合はキーごと消してください）`);
      if (v !== v.trim()) warnings.push(`${at}: 訳の前後に空白があります`);
      if (v === k) warnings.push(`${at}: 訳が英語と同じです（不要なので消せます）`);
      if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(v)) errors.push(`${at}: 制御文字が含まれています`);
      if (/<\/?[a-zA-Z][^>]*>/.test(v) && !/<\/?[a-zA-Z][^>]*>/.test(k)) errors.push(`${at}: 訳に HTML タグがあります（文字としてそのまま表示されます）`);
      const pk = placeholders(k), pv = placeholders(v);
      if (isPattern) {
        if (!pk) errors.push(`${at}: patterns のキーには {0} などのプレースホルダーが必要です`);
        if (pk !== pv) errors.push(`${at}: プレースホルダーが一致しません（英語: {${pk}} / 訳: {${pv}}）`);
      } else if (pk) warnings.push(`${at}: {n} を含むキーは patterns に置いてください`);
      for (const term of dnt) {
        if (DNT_SKIP[k] && DNT_SKIP[k][term]) continue;
        if (k.includes(term) && !v.includes(term)) warnings.push(`${at}: 訳さない語「${term}」が訳に残っていません`);
      }
    }
    return n;
  };
  const counts = { exact: checkMap(p.exact, 'exact', false), patterns: checkMap(p.patterns, 'patterns', true), scoped: 0 };
  if (p.scoped !== undefined) {
    if (!Array.isArray(p.scoped)) errors.push('scoped は配列である必要があります');
    else { const seenIds = new Set(); p.scoped.forEach((s, i) => {
      if (!s || typeof s.selector !== 'string' || !s.selector.trim()) errors.push(`scoped[${i}].selector が必要です`);
      else if (/[{};]|<\/?script/i.test(s.selector)) errors.push(`scoped[${i}].selector に使えない文字があります`);
      if (s && s.deny !== undefined && (typeof s.deny !== 'string' || /[{};]|<\/?script/i.test(s.deny))) errors.push(`scoped[${i}].deny が不正です`);
      if (s && s.area !== undefined && !SCOPED_AREAS.includes(s.area)) errors.push(`scoped[${i}].area は ${SCOPED_AREAS.join(' / ')} のどれか: ${s.area}`);
      if (s && s.attrs !== undefined && (!Array.isArray(s.attrs) || s.attrs.some(a => !['aria-label', 'placeholder', 'title'].includes(a)))) errors.push(`scoped[${i}].attrs は aria-label / placeholder / title だけ`);
      if (s) for (const k of Object.keys(s)) if (!['id', 'area', 'selector', 'deny', 'attrs', 'note', 'exact', 'patterns', 'bypassDeny', 'via'].includes(k)) errors.push(`scoped[${i}] に不明な項目: ${k}`);
      if (s && s.id !== undefined) { if (seenIds.has(s.id)) errors.push(`scoped[${i}].id が重複: ${s.id}`); seenIds.add(s.id); }
      if (s && s.bypassDeny !== undefined && typeof s.bypassDeny !== 'boolean') errors.push(`scoped[${i}].bypassDeny は true / false`);
      if (s && s.bypassDeny === true && (s.area || 'settings') === 'settings') errors.push(`scoped[${i}].bypassDeny は設定画面の外のグループだけ`);
      if (s && s.via !== undefined && s.via !== 'css-placeholder') errors.push(`scoped[${i}].via は css-placeholder だけ`);
      if (s && s.via === 'css-placeholder' && (s.patterns || s.attrs || s.bypassDeny)) errors.push(`scoped[${i}]: via css-placeholder では exact だけ使えます`);
      counts.scoped += checkMap(s.exact || {}, `scoped[${i}].exact`, false);
      if (s && s.patterns !== undefined) counts.scoped += checkMap(s.patterns, `scoped[${i}].patterns`, true);
    }); }
  }
  if (!counts.exact && !counts.patterns && !counts.scoped) errors.push('訳が 1 件もありません');
  return { errors, warnings, pack: p, counts };
}

/** Resolve --lang <code> to locales/<code>.json (no path tricks allowed). */
function packPath(lang, dir = LOCALES_DIR) {
  if (!LANG_RE.test(lang)) throw new Error(`言語コードが不正です: ${lang}（例: ja, zh-cn）`);
  const f = path.join(dir, `${lang}.json`);
  if (!fs.existsSync(f)) {
    const have = listPacks(dir).map(x => path.basename(x, '.json')).join(', ') || '(なし)';
    throw new Error(`言語レイヤーがありません: ${f}\n使える言語: ${have}`);
  }
  return f;
}
function listPacks(dir = LOCALES_DIR) {
  try { return fs.readdirSync(dir).filter(f => /\.json$/.test(f) && LANG_RE.test(f.replace(/\.json$/, ''))).sort().map(f => path.join(dir, f)); }
  catch { return []; }
}
/** Load + validate; throws with all errors joined (so the injector refuses broken packs). */
function loadPackFile(file) {
  const r = validatePack(fs.readFileSync(file, 'utf8'), file);
  if (r.errors.length) throw new Error(`言語レイヤー ${file} にエラーが ${r.errors.length} 件あります:\n  - ` + r.errors.slice(0, 20).join('\n  - '));
  return r;
}

module.exports = { validatePack, loadPackFile, packPath, listPacks, duplicateKeys, LANG_RE, LOCALES_DIR };

if (require.main === module) {
  const [cmd, ...files] = process.argv.slice(2);
  if (cmd !== 'validate') { console.error('使い方: node tools/pack.js validate [locales/<lang>.json ...]'); process.exit(2); }
  const targets = files.length ? files : listPacks();
  if (!targets.length) { console.error('言語レイヤーが見つかりません'); process.exit(2); }
  let bad = 0;
  for (const f of targets) {
    let r; try { r = validatePack(fs.readFileSync(f, 'utf8'), f); } catch (e) { r = { errors: [e.message], warnings: [] }; }
    const c = r.counts ? `exact ${r.counts.exact} / patterns ${r.counts.patterns} / scoped ${r.counts.scoped}` : '';
    console.log(`${r.errors.length ? 'NG' : 'OK'}  ${f}  ${c}  （エラー ${r.errors.length} / 警告 ${r.warnings.length}）`);
    for (const e of r.errors) console.log(`    エラー: ${e}`);
    for (const w of r.warnings.slice(0, process.env.SHOW_ALL_WARNINGS ? 1e9 : 15)) console.log(`    警告:   ${w}`);
    if (r.warnings.length > 15 && !process.env.SHOW_ALL_WARNINGS) console.log(`    …他 ${r.warnings.length - 15} 件（SHOW_ALL_WARNINGS=1 で全部表示）`);
    if (r.errors.length) bad++;
  }
  process.exit(bad ? 1 : 0);
}
