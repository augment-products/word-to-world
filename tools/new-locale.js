'use strict';
/**
 * Copy the English template into a draft locale. Does not overwrite.
 *   node tools/new-locale.js <id>
 * The draft is not shipped. locales/ stays for a finished language only.
 */
const path = require('path');
const { createLocale, canonicalLang, LANGS } = require('./locale-source.js');

function main(argv) {
  const id = argv[2];
  if (!id || id === '--help') {
    console.error('usage: node tools/new-locale.js <id>\nids: ' + LANGS.join(' '));
    return 2;
  }
  try {
    const dest = createLocale(id);
    const lang = canonicalLang(id);
    console.log('Wrote ' + path.relative(process.cwd(), dest));
    console.log('Draft only. Not shipped until every translation is filled and a maintainer moves it to locales/' + lang + '.json.');
    console.log('Next: translate the empty values, then');
    console.log('  node tools/pack.js validate drafts/' + lang + '.json');
    console.log('  node tools/sync-locale.js ' + lang + ' --check');
    return 0;
  } catch (e) {
    console.error(e.message);
    return e.code || 1;
  }
}
if (require.main === module) process.exit(main(process.argv));
module.exports = { main };
