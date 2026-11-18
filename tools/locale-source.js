'use strict';
/**
 * English source for every locale. templates/locale-template.json is the source of truth.
 * Locales, including ja, are checked against it. Empty translation values are allowed only in the template.
 *
 *   node tools/sync-locale.js --check
 *   node tools/sync-locale.js <id> --apply
 *   node tools/new-locale.js <id>
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const LANGS = ['ja', 'zh-cn', 'zh-tw', 'ko', 'fr', 'de', 'es', 'it', 'ru', 'pt-br', 'cs', 'tr', 'pl'];
const NAMES = {
  ja: ['Japanese', '日本語'],
  'zh-cn': ['Simplified Chinese', '简体中文'],
  'zh-tw': ['Traditional Chinese', '繁體中文'],
  ko: ['Korean', '한국어'],
  fr: ['French', 'français'],
  de: ['German', 'Deutsch'],
  es: ['Spanish', 'español'],
  it: ['Italian', 'italiano'],
  ru: ['Russian', 'русский'],
  'pt-br': ['Portuguese (Brazil)', 'português (Brasil)'],
  cs: ['Czech', 'čeština'],
  tr: ['Turkish', 'Türkçe'],
  pl: ['Polish', 'polski'],
};
const STRUCT = ['selector', 'area', 'note', 'deny', 'attrs', 'bypassDeny', 'via'];

/** Product name. The language half is the English name in meta.name. */
function displayName(languageName) {
  const name = String(languageName || '').trim();
  if (!name) { const err = new Error('language name is empty'); err.code = 1; throw err; }
  return 'Word to World for Cursor | ' + name + ' Language Layer';
}
function canonicalLang(input) {
  const lower = String(input || '').trim().toLowerCase();
  const id = lower === 'zh-hk' ? 'zh-tw' : lower;
  return LANGS.indexOf(id) >= 0 ? id : null;
}
function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function templatePath(root) { return path.join(root || ROOT, 'templates', 'locale-template.json'); }
function placeholders(s) {
  return [...String(s).matchAll(/\{(\d+)\}/g)].map(m => m[1]).sort().join(',');
}
function groupKey(g, index) {
  if (g && typeof g.id === 'string' && g.id) return 'id:' + g.id;
  if (g && typeof g.selector === 'string' && g.selector) return 'sel:' + g.selector;
  return 'index:' + index;
}
function isPattern(where) { return where === 'patterns' || where.endsWith('.patterns'); }

/** Walk schema/locale-pack.schema.json. allowEmpty skips minLength only for "". */
function checkSchema(value, schema, at, errors, opts) {
  if (!schema || typeof schema !== 'object') return;
  if (schema.const !== undefined && value !== schema.const) errors.push(at + ': expected ' + JSON.stringify(schema.const));
  if (schema.enum && schema.enum.indexOf(value) < 0) errors.push(at + ': not an allowed value');
  if (schema.type === 'string') {
    if (typeof value !== 'string') { errors.push(at + ': expected a string'); return; }
    if (schema.minLength && value.length < schema.minLength && !(opts.allowEmpty && value === '')) errors.push(at + ': empty');
    if (schema.pattern && !(new RegExp(schema.pattern).test(value))) errors.push(at + ': does not match ' + schema.pattern);
    return;
  }
  if (schema.type === 'boolean') { if (typeof value !== 'boolean') errors.push(at + ': expected a boolean'); return; }
  if (schema.type === 'number' || schema.type === 'integer') { if (typeof value !== 'number') errors.push(at + ': expected a number'); return; }
  if (schema.type === 'array') {
    if (!Array.isArray(value)) { errors.push(at + ': expected an array'); return; }
    if (schema.items) value.forEach((item, i) => checkSchema(item, schema.items, at + '[' + i + ']', errors, opts));
    return;
  }
  if (schema.type === 'object') {
    if (!value || typeof value !== 'object' || Array.isArray(value)) { errors.push(at + ': expected an object'); return; }
    const props = schema.properties || {};
    (schema.required || []).forEach(k => { if (!Object.prototype.hasOwnProperty.call(value, k)) errors.push(at + '.' + k + ': required'); });
    Object.keys(value).forEach(k => {
      if (Object.prototype.hasOwnProperty.call(props, k)) checkSchema(value[k], props[k], at + '.' + k, errors, opts);
      else if (schema.additionalProperties === false) errors.push(at + '.' + k + ': not allowed');
      else if (schema.additionalProperties && typeof schema.additionalProperties === 'object') checkSchema(value[k], schema.additionalProperties, at + '.' + k, errors, opts);
    });
  }
}

function mapDiff(templateMap, localeMap, where, report) {
  const t = templateMap || {};
  const l = localeMap || {};
  Object.keys(t).forEach(k => {
    if (!Object.prototype.hasOwnProperty.call(l, k)) report.missing.push({ where, key: k });
    else if (isPattern(where) && typeof l[k] === 'string' && l[k].trim() && placeholders(k) !== placeholders(l[k])) {
      report.placeholder.push({ where, key: k, english: placeholders(k), translation: placeholders(l[k]) });
    }
  });
  Object.keys(l).forEach(k => {
    if (!Object.prototype.hasOwnProperty.call(t, k)) report.stale.push({ where, key: k, value: l[k] });
  });
}
function indexGroups(pack) {
  const out = new Map();
  (pack.scoped || []).forEach((g, i) => out.set(groupKey(g, i), g));
  return out;
}
function assertPackStructure(pack, label) {
  if (!pack || typeof pack !== 'object' || Array.isArray(pack)) {
    const err = new Error(label + ': pack must be an object'); err.code = 1; throw err;
  }
  ['exact', 'patterns'].forEach(field => {
    if (pack[field] === undefined) return;
    if (!pack[field] || typeof pack[field] !== 'object' || Array.isArray(pack[field])) {
      const err = new Error(label + ': ' + field + ' must be an object'); err.code = 1; throw err;
    }
  });
  if (pack.scoped === undefined) return;
  if (!Array.isArray(pack.scoped)) {
    const err = new Error(label + ': scoped must be an array'); err.code = 1; throw err;
  }
  const seen = new Set();
  pack.scoped.forEach((g, i) => {
    if (!g || typeof g !== 'object' || Array.isArray(g)) {
      const err = new Error(label + ': scoped[' + i + '] must be an object'); err.code = 1; throw err;
    }
    const key = groupKey(g, i);
    if (seen.has(key)) {
      const err = new Error(label + ': duplicate group id: ' + key); err.code = 1; throw err;
    }
    seen.add(key);
  });
}
function diffPack(template, locale) {
  const report = { missing: [], stale: [], placeholder: [], structure: [], templateVersion: template.meta && template.meta.cursorVersion, localeVersion: locale.meta && locale.meta.cursorVersion };
  mapDiff(template.exact, locale.exact, 'exact', report);
  mapDiff(template.patterns, locale.patterns, 'patterns', report);
  const tg = indexGroups(template);
  const lg = indexGroups(locale);
  tg.forEach((g, id) => {
    const loc = lg.get(id);
    const where = 'scoped[' + id + ']';
    if (!loc) {
      Object.keys(g.exact || {}).forEach(k => report.missing.push({ where: where + '.exact', key: k }));
      Object.keys(g.patterns || {}).forEach(k => report.missing.push({ where: where + '.patterns', key: k }));
      return;
    }
    STRUCT.forEach(field => {
      if (JSON.stringify(g[field]) !== JSON.stringify(loc[field])) report.structure.push({ where, field });
    });
    mapDiff(g.exact, loc.exact, where + '.exact', report);
    mapDiff(g.patterns, loc.patterns, where + '.patterns', report);
  });
  lg.forEach((g, id) => {
    if (tg.has(id)) return;
    const where = 'scoped[' + id + ']';
    Object.keys(g.exact || {}).forEach(k => report.stale.push({ where: where + '.exact', key: k, value: g.exact[k] }));
    Object.keys(g.patterns || {}).forEach(k => report.stale.push({ where: where + '.patterns', key: k, value: g.patterns[k] }));
  });
  report.versionOk = report.localeVersion === report.templateVersion;
  report.ok = !report.missing.length && !report.stale.length && !report.placeholder.length && !report.structure.length && report.versionOk;
  return report;
}
function blankMap(obj) {
  const out = {};
  Object.keys(obj || {}).forEach(k => { out[k] = ''; });
  return out;
}
function blankGroup(g) {
  const out = {};
  Object.keys(g).forEach(k => { out[k] = (k === 'exact' || k === 'patterns') ? blankMap(g[k]) : g[k]; });
  if (!out.exact) out.exact = {};
  return out;
}
function applyDiff(template, locale) {
  const next = JSON.parse(JSON.stringify(locale));
  const stale = [];
  const before = diffPack(template, locale);
  function fill(templateMap, localeMap) {
    const out = Object.assign({}, localeMap || {});
    Object.keys(templateMap || {}).forEach(k => { if (!Object.prototype.hasOwnProperty.call(out, k)) out[k] = ''; });
    return out;
  }
  function drop(templateMap, localeMap, where) {
    const out = {};
    Object.keys(localeMap || {}).forEach(k => {
      if (Object.prototype.hasOwnProperty.call(templateMap || {}, k)) out[k] = localeMap[k];
      else stale.push({ where, key: k, value: localeMap[k] });
    });
    return out;
  }
  next.exact = drop(template.exact, fill(template.exact, next.exact), 'exact');
  next.patterns = drop(template.patterns, fill(template.patterns, next.patterns), 'patterns');
  const lg = indexGroups(next);
  next.scoped = (template.scoped || []).map((g, i) => {
    const id = groupKey(g, i);
    const loc = lg.get(id);
    const where = 'scoped[' + id + ']';
    if (!loc) return blankGroup(g);
    const merged = Object.assign({}, loc);
    STRUCT.forEach(field => { if (g[field] === undefined) delete merged[field]; else merged[field] = JSON.parse(JSON.stringify(g[field])); });
    merged.exact = drop(g.exact, fill(g.exact, loc.exact), where + '.exact');
    if (g.patterns || loc.patterns) merged.patterns = drop(g.patterns, fill(g.patterns, loc.patterns), where + '.patterns');
    return merged;
  });
  lg.forEach((g, id) => {
    if (indexGroups(template).has(id)) return;
    const where = 'scoped[' + id + ']';
    Object.keys(g.exact || {}).forEach(k => stale.push({ where: where + '.exact', key: k, value: g.exact[k] }));
    Object.keys(g.patterns || {}).forEach(k => stale.push({ where: where + '.patterns', key: k, value: g.patterns[k] }));
  });
  return { locale: next, stale, before };
}
function reportText(id, report) {
  const lines = [id + ': ' + (report.ok ? 'in sync' : 'out of sync') + ' with the English template (Cursor ' + report.templateVersion + ')'];
  if (!report.versionOk) lines.push('  cursor version: locale ' + report.localeVersion + ', template ' + report.templateVersion);
  report.missing.forEach(e => lines.push('  missing  ' + e.where + '  ' + JSON.stringify(e.key)));
  report.stale.forEach(e => lines.push('  stale  ' + e.where + '  ' + JSON.stringify(e.key)));
  report.placeholder.forEach(e => lines.push('  placeholder  ' + e.where + '  ' + JSON.stringify(e.key) + '  template {' + e.english + '}  locale {' + e.translation + '}'));
  report.structure.forEach(e => lines.push('  structure  ' + e.where + '  ' + e.field));
  return lines.join('\n');
}
function resolvePack(root, id) {
  const lang = canonicalLang(id);
  if (!lang) { const err = new Error('unknown language id: ' + id + '\nexpected one of: ' + LANGS.join(' ')); err.code = 2; throw err; }
  const shipped = path.join(root, 'locales', lang + '.json');
  const draft = path.join(root, 'drafts', lang + '.json');
  if (fs.existsSync(shipped)) return shipped;
  if (fs.existsSync(draft)) return draft;
  const err = new Error('no pack for ' + lang + ' (looked in locales/ and drafts/)'); err.code = 2; throw err;
}
function writeJson(file, obj) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = file + '.tmp-' + process.pid;
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2) + '\n');
  fs.renameSync(tmp, file);
}
function readStale(file) {
  if (!fs.existsSync(file)) return [];
  let text;
  try { text = fs.readFileSync(file, 'utf8'); }
  catch (e) {
    const err = new Error('cannot read stale file (left unchanged): ' + file); err.code = 1; throw err;
  }
  let data;
  try { data = JSON.parse(text); }
  catch (e) {
    const err = new Error('corrupt stale file (left unchanged): ' + file); err.code = 1; throw err;
  }
  if (!data || typeof data !== 'object' || Array.isArray(data) || !Array.isArray(data.entries)) {
    const err = new Error('stale file entries must be an array (left unchanged): ' + file); err.code = 1; throw err;
  }
  return data.entries;
}
function mergeStale(file, entries, prev) {
  if (prev === undefined) prev = readStale(file);
  if (!Array.isArray(prev)) {
    const err = new Error('stale file entries must be an array (left unchanged): ' + file); err.code = 1; throw err;
  }
  if (!Array.isArray(entries)) {
    const err = new Error('stale entries must be an array'); err.code = 1; throw err;
  }
  const next = prev.slice();
  const seen = new Set(next.map(e => e.where + '\0' + e.key + '\0' + e.value));
  entries.forEach(e => { const k = e.where + '\0' + e.key + '\0' + e.value; if (!seen.has(k)) { next.push(e); seen.add(k); } });
  writeJson(file, { note: 'Translations whose English key left the template. Not deleted. Review before discarding.', entries: next });
}
function applyLocale(root, id) {
  const lang = canonicalLang(id);
  if (!lang) { const err = new Error('unknown language id: ' + id + '\nexpected one of: ' + LANGS.join(' ')); err.code = 2; throw err; }
  const file = resolvePack(root, lang);
  const template = readJson(templatePath(root));
  const locale = readJson(file);
  assertPackStructure(template, 'template');
  assertPackStructure(locale, file);
  const stalePath = path.join(root, 'drafts', 'stale', lang + '.json');
  const prev = readStale(stalePath);
  const applied = applyDiff(template, locale);
  // Stale first, then the locale. A rename is the write. If the locale rename fails,
  // the locale file is still the previous one and the stale file already has the
  // parked lines. Running sync again writes the same stale lines and then the locale.
  if (applied.stale.length) mergeStale(stalePath, applied.stale, prev);
  try {
    writeJson(file, applied.locale);
  } catch (e) {
    const err = new Error(e.message + ' (the stale file was saved; run sync again to finish the locale)');
    err.code = e.code || 1;
    throw err;
  }
  return { lang, file, applied };
}
function createLocale(id, opts) {
  const root = (opts && opts.root) || ROOT;
  const lang = canonicalLang(id);
  if (!lang) { const err = new Error('unknown language id: ' + id + '\nexpected one of: ' + LANGS.join(' ')); err.code = 2; throw err; }
  const dest = path.join(root, 'drafts', lang + '.json');
  const shipped = path.join(root, 'locales', lang + '.json');
  if (fs.existsSync(dest) || fs.existsSync(shipped)) {
    const err = new Error('refusing to overwrite ' + (fs.existsSync(shipped) ? shipped : dest)); err.code = 1; throw err;
  }
  const pack = readJson(templatePath(root));
  const names = NAMES[lang];
  pack.meta.lang = lang;
  pack.meta.name = names[0];
  pack.meta.nativeName = names[1];
  pack.meta.packVersion = '0.1.0';
  pack.meta.glossary = 'glossary/' + lang + '.md';
  pack.meta.maintainers = [];
  pack.meta.notes = 'DRAFT. Not shipped. Fill every empty translation. This file stays out of locales/ until it is complete. Empty values, placeholder mismatches, and surrounding whitespace are errors.';
  writeJson(dest, pack);
  return dest;
}

module.exports = {
  ROOT, LANGS, NAMES, displayName, canonicalLang, readJson, templatePath, checkSchema, diffPack, applyDiff, reportText,
  resolvePack, writeJson, mergeStale, readStale, assertPackStructure, applyLocale, createLocale, blankMap, blankGroup,
};
