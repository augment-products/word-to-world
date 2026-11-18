'use strict';
const { scriptMessage, scriptLang, normLang } = require('../tools/script-messages');
let pass = 0, fail = 0;
function check(name, ok) {
  if (ok) { pass++; console.log('PASS  ' + name); }
  else { fail++; console.log('FAIL  ' + name); }
}
check('ja started is one Japanese line', scriptMessage('ja', 'started') === '翻訳を開始しました。');
check('en started', scriptMessage('en', 'started') === 'Translation started.');
check('ja stopped', scriptMessage('ja', 'stopped') === 'Cursor が終了したので、翻訳を停止しました。');
check('en stopped', scriptMessage('en', 'stopped') === 'Cursor quit, so translation stopped.');
const jaWatch = scriptMessage('ja', 'watch');
const enWatch = scriptMessage('en', 'watch');
check('ja watch keeps 止めずに and drops the English line', /止めずに/.test(jaWatch) && !/alongside/.test(jaWatch));
check('en watch keeps alongside and drops the Japanese line', /alongside/.test(enWatch) && !/止めずに/.test(enWatch));
check('unknown language falls back to English', scriptMessage('zh-cn', 'started') === 'Translation started.');
check('ja-JP and zh-TW and ko-KR normalize', normLang('ja_JP.UTF-8') === 'ja' && normLang('zh_TW') === 'zh-tw' && normLang('ko-KR') === 'ko');
const saved = { UI_LANG: process.env.UI_LANG, UI_TR_LANG: process.env.UI_TR_LANG };
delete process.env.UI_LANG;
delete process.env.UI_TR_LANG;
check('explicit --lang when the env is empty', scriptLang('ja') === 'ja' && scriptLang('en') === 'en');
process.env.UI_TR_LANG = 'en';
check('UI_TR_LANG overrides an explicit language', scriptLang('ja') === 'en');
delete process.env.UI_TR_LANG;
process.env.UI_LANG = 'ja';
check('a resolved UI_LANG is used', scriptLang('en') === 'ja');
if (saved.UI_LANG === undefined) delete process.env.UI_LANG; else process.env.UI_LANG = saved.UI_LANG;
if (saved.UI_TR_LANG === undefined) delete process.env.UI_TR_LANG; else process.env.UI_TR_LANG = saved.UI_TR_LANG;
console.log('RESULT script-messages: ' + pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
