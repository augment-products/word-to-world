'use strict';
/**
 * Compare a locale to templates/locale-template.json.
 *   node tools/sync-locale.js --check                 # every locales/*.json
 *   node tools/sync-locale.js <id> --check            # locales/<id>.json, or drafts/<id>.json
 *   node tools/sync-locale.js <id> --apply            # add missing keys as "", park stale translations
 *   node tools/sync-locale.js --check-drafts          # drafts/*.json, if any
 * --check is the default. --apply does not delete a translation; it copies it to drafts/stale/<id>.json first.
 */
const fs = require('fs');
const path = require('path');
const {
  ROOT, readJson, templatePath, diffPack, reportText, resolvePack, applyLocale, assertPackStructure,
} = require('./locale-source.js');

function checkError(file, e) {
  const name = file ? path.basename(file) : '';
  console.error(name ? name + ': ' + e.message : e.message);
}
function checkFile(root, file) {
  const template = readJson(templatePath(root));
  const locale = readJson(file);
  assertPackStructure(template, 'template');
  assertPackStructure(locale, file);
  const id = path.basename(file, '.json');
  const report = diffPack(template, locale);
  console.log(reportText(id, report));
  return report.ok ? 0 : 1;
}
function applyFile(root, id) {
  const result = applyLocale(root, id);
  const applied = result.applied;
  console.log(result.lang + ': added ' + applied.before.missing.length + ' empty key(s), moved ' + applied.stale.length + ' stale translation(s) to drafts/stale/' + result.lang + '.json');
  return checkFile(root, result.file);
}
function localeFiles(root) {
  const dir = path.join(root, 'locales');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.json')).sort().map(f => path.join(dir, f));
}
function draftFiles(root) {
  const dir = path.join(root, 'drafts');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => /^[a-z0-9-]+\.json$/.test(f)).sort().map(f => path.join(dir, f));
}
function checkDrafts(root) {
  const files = draftFiles(root);
  let bad = 0;
  files.forEach(file => {
    try {
      const pack = readJson(file);
      const notes = (pack.meta && pack.meta.notes) || '';
      if (!/DRAFT/.test(notes) || !/not shipped/i.test(notes)) {
        console.error(path.basename(file) + ': meta.notes must say DRAFT and not shipped');
        bad = 1;
      }
      if (checkFile(root, file) !== 0) bad = 1;
    } catch (e) {
      checkError(file, e);
      bad = 1;
    }
  });
  if (!files.length) console.log('drafts: no locale files');
  return bad;
}
function main(argv, root) {
  root = root || ROOT;
  const args = argv.slice(2);
  const apply = args.indexOf('--apply') >= 0;
  const drafts = args.indexOf('--check-drafts') >= 0;
  const id = args.filter(a => a !== '--check' && a !== '--apply' && a !== '--check-drafts')[0];
  if (drafts) return checkDrafts(root);
  if (apply) {
    if (!id) { console.error('usage: node tools/sync-locale.js <id> --apply'); return 2; }
    try { return applyFile(root, id); } catch (e) { console.error(e.message); return e.code || 1; }
  }
  if (id) {
    let file = '';
    try { file = resolvePack(root, id); return checkFile(root, file); }
    catch (e) { checkError(file || id, e); return e.code || 1; }
  }
  const files = localeFiles(root);
  if (!files.length) { console.error('no locales/*.json'); return 2; }
  let bad = 0;
  files.forEach(f => {
    try { if (checkFile(root, f) !== 0) bad = 1; }
    catch (e) { checkError(f, e); bad = 1; }
  });
  return bad;
}
if (require.main === module) process.exit(main(process.argv));
module.exports = { main };
