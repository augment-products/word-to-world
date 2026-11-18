#!/usr/bin/env python3
"""tools/update_worklists.py: per-language worklists across versions, for all packs at once."""
import json, os, subprocess, sys, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ok = fail = 0
def check(name, cond, extra=''):
    global ok, fail
    ok, fail = (ok + 1, fail) if cond else (ok, fail + 1)
    print(('PASS' if cond else 'FAIL') + '  ' + name + (('  ' + str(extra)) if extra else ''))
def cap(ver, texts):
    return {'tool': 'ui-translator-capture', 'version': ver, 'strings': [{'text': t, 'kind': 'pattern' if '{0}' in t else 'exact', 'render': 'text', 'tier': 'settings', 'count': 1} for t in texts]}
def pack(lang, exact, patterns=None):
    return {'schemaVersion': 1, 'meta': {'lang': lang, 'name': lang, 'nativeName': lang, 'packVersion': '0.1.0', 'cursorVersion': '1.0.0', 'updated': '2026-01-01', 'scope': 'settings'}, 'exact': exact, 'patterns': patterns or {}}
with tempfile.TemporaryDirectory() as d:
    loc = os.path.join(d, 'locales'); os.makedirs(loc); out = os.path.join(d, 'wl')
    old = cap('1.0.0', ['General', 'Show the old thing in the sidebar', 'Delete Me', 'Keep Me', 'Open {0}'])
    new = cap('1.1.0', ['General', 'Show the new thing in the sidebar', 'Keep Me', 'Brand New', 'Open {0}'])
    json.dump(old, open(os.path.join(d, 'old.json'), 'w')); json.dump(new, open(os.path.join(d, 'new.json'), 'w'))
    json.dump(pack('ja', {'General': '一般', 'Show the old thing in the sidebar': 'サイドバーに古い物を表示', 'Delete Me': '消して', 'Keep Me': '残して', 'Seen On Screen Only': '画面で確認'}, {'Open {0}': '{0} を開く'}), open(os.path.join(loc, 'ja.json'), 'w'), ensure_ascii=False)
    json.dump(pack('ko', {'General': '일반'}), open(os.path.join(loc, 'ko.json'), 'w'), ensure_ascii=False)
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'update_worklists.py'), os.path.join(d, 'old.json'), os.path.join(d, 'new.json'), '--locales', loc, '--out', out], capture_output=True, text=True)
    check('exit code 10 when there is work', r.returncode == 10, r.stdout + r.stderr)
    check('one worklist per pack (ja, ko) + SUMMARY.md', all(os.path.exists(os.path.join(out, f)) for f in ['ja.worklist.json', 'ja.worklist.csv', 'ko.worklist.json', 'ko.worklist.csv', 'SUMMARY.md']))
    ja = json.load(open(os.path.join(out, 'ja.worklist.json'), encoding='utf-8'))
    st = {(i['status'], i['english']) for i in ja['items']}
    check('ja: changed (old key -> similar new string, previous translation kept)', any(i['status'] == 'changed' and i['english'] == 'Show the new thing in the sidebar' and i['previous_translation'] == 'サイドバーに古い物を表示' for i in ja['items']))
    check('ja: removed', ('removed', 'Delete Me') in st)
    check('ja: new', ('new', 'Brand New') in st)
    check('ja: unverified (pack key never captured)', ('unverified', 'Seen On Screen Only') in st)
    check('ja: unchanged translated strings not listed', not any(e in ('General', 'Keep Me', 'Open {0}') for _, e in st))
    ko = json.load(open(os.path.join(out, 'ko.worklist.json'), encoding='utf-8'))
    kst = {(i['status'], i['english']) for i in ko['items']}
    check('ko: new strings include the changed one (ko never had the old)', ('new', 'Show the new thing in the sidebar') in kst and ('new', 'Brand New') in kst)
    check('versions recorded', ja['fromVersion'] == '1.0.0' and ja['toVersion'] == '1.1.0')
    check('worklists contain only text + translations (no code fields)', all(set(i) <= {'status', 'english', 'previous_english', 'previous_translation', 'similarity', 'section', 'render', 'risky', 'action', 'source'} for i in ja['items']))
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'update_worklists.py'), os.path.join(d, 'new.json'), '--locales', loc, '--out', out + '2'], capture_output=True, text=True)
    one = json.load(open(os.path.join(out + '2', 'ja.worklist.json'), encoding='utf-8'))
    check('single capture: lists untranslated as new, nothing removed', {i['status'] for i in one['items']} == {'new'} and any(i['english'] == 'Brand New' for i in one['items']))
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'update_worklists.py'), os.path.join(d, 'old.json'), os.path.join(d, 'old.json'), '--locales', loc, '--out', out + '3'], capture_output=True, text=True)
    check('no differences -> only "unverified"/backlog items, no new/changed/removed', 'new 0 / changed 0 / removed 0' in r.stdout, r.stdout.strip())
with tempfile.TemporaryDirectory() as d:   # capture made with inject.js --capture-scope all + a pack with scope "all" and scoped groups
    loc = os.path.join(d, 'locales'); os.makedirs(loc)
    c = cap('2.0.0', ['General']); c['strings'] += [{'text': t, 'kind': 'pattern' if '{0}' in t else 'exact', 'render': 'attr', 'attr': 'aria-label', 'tier': 'outside', 'path': 'nav > button', 'count': 1}
                                                   for t in ['Hide Sidebar', 'Branch {0}, open branch menu', 'Brand New Button']]
    json.dump(c, open(os.path.join(d, 'cap.json'), 'w'))
    p = pack('ja', {'General': '一般'}); p['meta']['scope'] = 'all'
    p['scoped'] = [{'id': 'g', 'area': 'agents', 'selector': 'nav button', 'attrs': ['aria-label'], 'exact': {'Hide Sidebar': 'サイドバーを隠す'}, 'patterns': {'Branch {0}, open branch menu': 'ブランチ {0}、ブランチのメニューを開く'}}]
    json.dump(p, open(os.path.join(loc, 'ja.json'), 'w'), ensure_ascii=False)
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'update_worklists.py'), os.path.join(d, 'cap.json'), '--locales', loc, '--out', os.path.join(d, 'wl')], capture_output=True, text=True)
    w = {i['english'] for i in json.load(open(os.path.join(d, 'wl', 'ja.worklist.json'), encoding='utf-8'))['items']}
    check('scope "all": strings captured outside Settings are listed; scoped exact + patterns count as translated', w == {'Brand New Button'}, w)
print(f'RESULT worklists: {ok} passed, {fail} failed')
sys.exit(1 if fail else 0)
