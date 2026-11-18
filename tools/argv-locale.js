#!/usr/bin/env node
'use strict';
/**
 * argv-locale.js — read / set / remove the top-level "locale" key of Cursor's argv.json (~/.cursor/argv.json).
 * argv.json is JSONC (comments, maybe trailing commas). This tool changes ONLY the "locale" value (or inserts / removes
 * that one key) and keeps every other byte — comments, order, indentation — as it was. No other key is touched.
 * Used by lab/_langpack.sh (setup + uninstall). Run with Cursor's own Node (ELECTRON_RUN_AS_NODE=1) or any Node 16+.
 *
 *   node tools/argv-locale.js get <argv.json>             -> {"exists":true,"has":true,"value":"ja"} (exit 0)
 *   node tools/argv-locale.js set <argv.json> <locale>    -> writes (creates the file if missing)
 *   node tools/argv-locale.js remove <argv.json>          -> removes the key (no-op if absent)
 * Exit codes: 0 ok / 1 the file could not be parsed safely (nothing written) / 2 usage error
 */
const fs = require('fs');

// Strict check: comments removed and trailing commas dropped, the text must be valid JSON whose top level is an object.
function strictCheck(text) {
  let out = '', i = 0, pendingComma = '';
  while (i < text.length) {
    const ch = text[i];
    if (ch === '"') { let j = i + 1; while (j < text.length && text[j] !== '"') { if (text[j] === '\\') j++; j++; } out += pendingComma + text.slice(i, j + 1); pendingComma = ''; i = j + 1; continue; }
    if (text.startsWith('//', i)) { const n = text.indexOf('\n', i); i = n < 0 ? text.length : n; continue; }
    if (text.startsWith('/*', i)) { const n = text.indexOf('*/', i + 2); if (n < 0) throw new Error('unterminated comment'); i = n + 2; continue; }
    if (/\s/.test(ch)) { i++; continue; }
    if (ch === ',') { out += pendingComma; pendingComma = ','; i++; continue; }
    if ((ch === '}' || ch === ']')) pendingComma = '';
    out += pendingComma + ch; pendingComma = ''; i++;
  }
  let v; try { v = JSON.parse(out + pendingComma); } catch (e) { throw new Error('not valid JSON(C)'); }
  if (!v || typeof v !== 'object' || Array.isArray(v)) throw new Error('top level is not an object');
}

// Scan JSONC and return the top-level members: [{key, keyStart, valStart, valEnd, end}] plus the object's braces.
function scan(text) {
  strictCheck(text);
  let i = 0, depth = 0, open = -1, close = -1;
  const members = []; let cur = null, expectKey = false, lastSig = -1;
  const skipWsComments = () => {
    for (;;) {
      if (/\s/.test(text[i] || '')) { i++; continue; }
      if (text.startsWith('//', i)) { const n = text.indexOf('\n', i); i = n < 0 ? text.length : n + 1; continue; }
      if (text.startsWith('/*', i)) { const n = text.indexOf('*/', i + 2); if (n < 0) throw new Error('unterminated comment'); i = n + 2; continue; }
      return;
    }
  };
  const readString = () => { const s = i; i++; while (i < text.length && text[i] !== '"') { if (text[i] === '\\') i++; i++; } if (i >= text.length) throw new Error('unterminated string'); i++; return [s, i]; };
  while (true) {
    skipWsComments();
    if (i >= text.length) break;
    const ch = text[i];
    if (ch === '"') {
      const [s, e] = readString();
      if (depth === 1 && expectKey) { cur = { key: JSON.parse(text.slice(s, e)), keyStart: s }; expectKey = false; }
      else if (depth === 1 && cur && cur.valStart == null) { cur.valStart = s; cur.valEnd = e; }
      lastSig = e - 1; continue;
    }
    if (ch === '{' || ch === '[') {
      if (depth === 1 && cur && cur.valStart == null) cur.valStart = i;
      depth++; if (depth === 1) { if (open >= 0) throw new Error('more than one top-level value'); open = i; expectKey = true; }
      lastSig = i; i++; continue;
    }
    if (ch === '}' || ch === ']') {
      depth--; if (depth < 0) throw new Error('unbalanced');
      if (depth === 1 && cur && cur.valEnd == null) cur.valEnd = i + 1;
      if (depth === 0) { close = i; if (cur) { if (cur.valEnd == null) cur.valEnd = lastSig + 1; members.push(cur); cur = null; } }
      lastSig = i; i++; continue;
    }
    if (ch === ':') { lastSig = i; i++; continue; }
    if (ch === ',') {
      if (depth === 1) { if (cur) { if (cur.valEnd == null) cur.valEnd = lastSig + 1; cur.comma = i; members.push(cur); cur = null; } expectKey = true; }
      lastSig = i; i++; continue;
    }
    // literal (number, true, false, null)
    const m = /^[^\s,:{}\[\]"\/]+/.exec(text.slice(i)); if (!m) throw new Error('unexpected character at ' + i);
    if (depth === 1 && cur && cur.valStart == null) { cur.valStart = i; cur.valEnd = i + m[0].length; }
    lastSig = i + m[0].length - 1; i += m[0].length;
  }
  if (open < 0 || close < 0 || depth !== 0) throw new Error('not a JSON object');
  if (text.slice(close + 1).replace(/\/\/[^\n]*|\/\*[\s\S]*?\*\/|\s/g, '') !== '') throw new Error('trailing content');
  return { open, close, members };
}

function get(text) {
  const { members } = scan(text);
  const m = members.filter(x => x.key === 'locale');
  if (m.length > 1) throw new Error('"locale" appears more than once');
  if (!m.length) return { has: false };
  const raw = text.slice(m[0].valStart, m[0].valEnd); let value;
  try { value = JSON.parse(raw); } catch (e) { throw new Error('"locale" value is not plain JSON'); }
  return { has: true, value };
}
function set(text, value) {
  const s = scan(text); const v = JSON.stringify(String(value));
  const m = s.members.filter(x => x.key === 'locale');
  if (m.length > 1) throw new Error('"locale" appears more than once');
  if (m.length) return text.slice(0, m[0].valStart) + v + text.slice(m[0].valEnd);
  // insert as the last member, right before the closing brace, keeping comments in place
  const body = text.slice(s.open + 1, s.close);
  const indent = (/\n([ \t]+)"/.exec(body) || [, '\t'])[1];
  const last = s.members[s.members.length - 1];
  if (!last) return text.slice(0, s.open + 1) + '\n' + indent + '"locale": ' + v + '\n' + text.slice(s.close);
  if (last.comma != null)      // the file uses a trailing comma: keep that style (the new member gets one too)
    return text.slice(0, last.comma + 1) + '\n' + indent + '"locale": ' + v + ',' + text.slice(last.comma + 1);
  return text.slice(0, last.valEnd) + ',\n' + indent + '"locale": ' + v + text.slice(last.valEnd);
}
function remove(text) {
  const s = scan(text); const idx = s.members.findIndex(x => x.key === 'locale');
  if (idx < 0) return text;
  const m = s.members[idx];
  // from the start of the key's line (if only whitespace precedes it) to the end of the value / its comma
  let start = m.keyStart; while (start > 0 && (text[start - 1] === ' ' || text[start - 1] === '\t')) start--;
  if (start > 0 && text[start - 1] === '\n') start--; else start = m.keyStart;
  let end = m.comma != null ? m.comma + 1 : m.valEnd;
  if (m.comma == null && idx > 0) {          // last member: drop the previous member's comma instead
    const prev = s.members[idx - 1];
    if (prev.comma != null) { return text.slice(0, prev.comma) + text.slice(prev.comma + 1, start) + text.slice(end); }
  }
  return text.slice(0, start) + text.slice(end);
}

function main() {
  const [cmd, file, value] = process.argv.slice(2);
  if (!cmd || !file || (cmd === 'set' && !value) || !['get', 'set', 'remove'].includes(cmd)) { console.error('usage: argv-locale.js get|set|remove <argv.json> [locale]'); process.exit(2); }
  if (cmd === 'set' && !/^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$/.test(value)) { console.error('invalid locale: ' + value); process.exit(2); }
  const exists = fs.existsSync(file);
  const text = exists ? fs.readFileSync(file, 'utf8') : null;
  try {
    if (cmd === 'get') { const r = exists ? get(text) : { has: false }; process.stdout.write(JSON.stringify({ exists, ...r }) + '\n'); return; }
    let out;
    if (cmd === 'set') out = exists ? set(text, value) : '{\n\t"locale": ' + JSON.stringify(value) + '\n}\n';
    else { if (!exists) return; out = remove(text); }
    if (out === text) return;
    // self-check before writing: still parses, other members unchanged, locale as intended
    const before = exists ? scan(text).members.filter(x => x.key !== 'locale').map(x => text.slice(x.keyStart, x.valEnd)) : [];
    const after = scan(out).members.filter(x => x.key !== 'locale').map(x => out.slice(x.keyStart, x.valEnd));
    if (JSON.stringify(before) !== JSON.stringify(after)) throw new Error('self-check failed (other keys would change)');
    const g = get(out); if (cmd === 'set' ? !(g.has && g.value === value) : g.has) throw new Error('self-check failed (locale)');
    const tmp = file + '.uitr-tmp'; fs.writeFileSync(tmp, out); fs.renameSync(tmp, file);
  } catch (e) { console.error('argv.json: ' + e.message + ' (nothing written)'); process.exit(1); }
}
if (require.main === module) main();
module.exports = { scan, get, set, remove };
