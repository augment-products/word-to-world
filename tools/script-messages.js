'use strict';
// Terminal lines printed by inject.js. One language.
// Add zh-cn, zh-tw, ko, and the other layer ids here. A missing language or key uses English.
function normLang(raw) {
  const s = String(raw || '').trim().toLowerCase().replace(/_/g, '-').replace(/\..*$/, '');
  if (!s || s === 'c' || s === 'posix' || s === 'en' || s.startsWith('en-')) return 'en';
  if (s === 'ja' || s.startsWith('ja-')) return 'ja';
  if (s === 'zh' || s === 'zh-cn' || s === 'zh-hans' || s === 'zh-sg') return 'zh-cn';
  if (s === 'zh-tw' || s === 'zh-hk' || s === 'zh-mo' || s === 'zh-hant') return 'zh-tw';
  if (s === 'ko' || s.startsWith('ko-')) return 'ko';
  if (s === 'pt' || s === 'pt-br' || s.startsWith('pt-')) return 'pt-br';
  const known = ['fr', 'de', 'es', 'it', 'ru', 'cs', 'tr', 'pl'];
  const hit = known.find(k => s === k || s.startsWith(k + '-'));
  return hit || 'en';
}

const MESSAGES = {
  en: {
    started: 'Translation started.',
    stopped: 'Cursor quit, so translation stopped.',
    watch: 'watch: the translator in this window keeps running; recording alongside it.',
  },
  ja: {
    started: '翻訳を開始しました。',
    stopped: 'Cursor が終了したので、翻訳を停止しました。',
    watch: 'watch: このウィンドウの翻訳は動いたまま、止めずに横で記録します。',
  },
};

function scriptMessage(lang, key) {
  const id = normLang(lang);
  const pack = MESSAGES[id] || MESSAGES.en;
  return pack[key] != null ? pack[key] : MESSAGES.en[key];
}

// UI_LANG is the language the shell already resolved. UI_TR_LANG overrides --lang.
function scriptLang(explicit) {
  if (process.env.UI_LANG) return normLang(process.env.UI_LANG);
  if (process.env.UI_TR_LANG) return normLang(process.env.UI_TR_LANG);
  return normLang(explicit || 'en');
}

module.exports = { scriptMessage, scriptLang, normLang, MESSAGES };
