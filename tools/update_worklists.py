#!/usr/bin/env python3
"""Per-language worklists for a Cursor version upgrade — for ALL language layers at once.

    python3 tools/update_worklists.py [OLD.json] NEW.json [--locales locales] [--out work/worklists]
                                      [--threshold 0.75] [--backlog]

OLD.json / NEW.json : capture files written by `inject.js apply --capture <file>` (strings actually shown on
                      screen) for the old and the new Cursor version. With only NEW.json, every captured string
                      that a pack does not translate yet is listed as "new" (removed/changed need OLD.json).
                      Capture files are local work files; review them before sharing (they come from your screen).
For every locales/<lang>.json it writes
    <out>/<lang>.worklist.json   machine-readable (for an AI or a script, see CONTRIBUTING-AI.md)
    <out>/<lang>.worklist.csv    for people (status, english, current_translation, suggestion_from, ...)
and <out>/SUMMARY.md with counts per language.

Statuses (only English UI text and translations are written, no Cursor code):
    new        string appears in NEW, not in OLD, not in the pack           -> translate it
    changed    a pack key disappeared and a similar NEW string appeared     -> re-key + review translation
               (previous English / translation given as a starting point)
    removed    pack key no longer exists in NEW (and nothing similar)       -> delete it from the pack
    backlog    in both versions, never translated (only with --backlog)      -> optional
    unverified pack key the extractor never saw in either version             -> check on a real screen
               Every item gets source = "screen".
Strings are filtered to the tiers matching the pack's meta.scope (settings -> settings tiers; all -> also
strings recorded outside Settings with `inject.js --capture-scope all`).
Exit code: 0 = no work, 10 = there is work (useful in CI), 2 = usage error.
"""
import argparse, csv, difflib, json, os, re, sys

TIERS = {'settings': {'settings', 'settings-customize'}, 'all': {'settings', 'settings-customize', 'agent', 'other', 'outside'}}   # 'outside' = inject.js --capture-scope all
PH = re.compile(r'\{\d+\}')


def load_extract(path, tiers):
    """-> (strings in the pack's tiers, every extracted text of any tier, version)"""
    d = json.load(open(path, encoding='utf-8'))
    if not (isinstance(d, dict) and 'strings' in d):
        sys.exit(f'{path}: キャプチャファイル（"strings" を含む JSON）を指定してください')
    out, every = {}, set(r['text'].strip() for r in d['strings'])
    every |= set(k.strip() for k in (d.get('covered') or {}))     # `inject.js watch`: seen and already translated
    for r in d['strings']:
        if r.get('tier', 'settings') not in tiers or r.get('fragment'):
            continue
        t = r['text'].strip()
        if t:
            out.setdefault(t, {'kind': r.get('kind', 'exact'), 'tier': r.get('tier'), 'render': r.get('render', 'text'),
                               'risky': bool(r.get('risky'))})
    return out, every, d.get('version', '')


def pack_entries(p):
    e = {}
    for k, v in (p.get('exact') or {}).items(): e[k] = ('exact', v)
    for k, v in (p.get('patterns') or {}).items(): e[k] = ('patterns', v)
    for i, s in enumerate(p.get('scoped') or []):
        for k, v in (s.get('exact') or {}).items(): e.setdefault(k, (f'scoped[{i}]', v))
        for k, v in (s.get('patterns') or {}).items(): e.setdefault(k, (f'scoped[{i}]', v))
    return e


def best_match(text, candidates, threshold):
    best, score = None, 0.0
    for c in difflib.get_close_matches(text, candidates, n=3, cutoff=threshold):
        r = difflib.SequenceMatcher(None, text, c).ratio()
        if r > score and bool(PH.search(c)) == bool(PH.search(text)):
            best, score = c, r
    return best, score


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('files', nargs='+', metavar='[OLD.json] NEW.json')
    ap.add_argument('--locales', default=os.path.join(os.path.dirname(__file__), '..', 'locales'))
    ap.add_argument('--out', default='work/worklists')
    ap.add_argument('--threshold', type=float, default=0.75)
    ap.add_argument('--backlog', action='store_true', help='also list never-translated strings present in both versions')
    a = ap.parse_args()
    if len(a.files) > 2: ap.error('ファイルは最大 2 つ（OLD NEW）')
    a.old, a.new = (a.files if len(a.files) == 2 else [None, a.files[0]])
    packs = sorted(f for f in os.listdir(a.locales) if f.endswith('.json'))
    if not packs:
        print('言語レイヤーがありません', file=sys.stderr); return 2
    os.makedirs(a.out, exist_ok=True)
    summary, total = [], 0
    cache = {}
    for f in packs:
        p = json.load(open(os.path.join(a.locales, f), encoding='utf-8'))
        lang = (p.get('meta') or {}).get('lang') or f[:-5]
        scope = (p.get('meta') or {}).get('scope', 'settings')
        if scope not in cache:
            new, new_all, nv = load_extract(a.new, TIERS[scope])
            old, old_all, ov = load_extract(a.old, TIERS[scope]) if a.old else ({}, set(new_all), '')
            cache[scope] = (old, new, ov, nv, old_all, new_all)
        old, new, ov, nv, old_all, new_all = cache[scope]
        entries = pack_entries(p)
        appeared = [t for t in new if t not in old]
        appeared_untr = [t for t in appeared if t not in entries]
        items, used = [], set()
        # removed/changed only when the key existed in OLD (any tier) and is gone from NEW (any tier).
        # Keys absent from both captures (e.g. added after checking a real screen) are 'unverified': no action.
        gone = [k for k in entries if k in old_all and k not in new_all]
        for k in (sorted(k for k in entries if k not in old_all and k not in new_all) if a.old else []):
            items.append({'status': 'unverified', 'english': k, 'previous_translation': entries[k][1], 'section': entries[k][0],
                          'action': '画面の記録には無い（実画面で確認して追加した語など）。新しい版の画面で残っているか確認'})
        for k in sorted(gone):
            sect, tr = entries[k]
            m, sc = best_match(k, appeared_untr, a.threshold)
            if m and m not in used:
                used.add(m)
                items.append({'status': 'changed', 'english': m, 'previous_english': k, 'previous_translation': tr,
                              'similarity': round(sc, 3), 'section': 'patterns' if PH.search(m) else 'exact',
                              'action': 'キーを新しい英語に置き換え、訳を見直す'})
            else:
                items.append({'status': 'removed', 'english': k, 'previous_translation': tr, 'section': sect,
                              'action': 'パックから削除する（新しい版に無い）'})
        for t in sorted(appeared_untr):
            if t in used: continue
            meta = new[t]
            items.append({'status': 'new', 'english': t, 'section': 'patterns' if PH.search(t) else 'exact',
                          'render': meta['render'], 'risky': meta['risky'], 'action': '訳を追加する'})
        if a.backlog:
            for t in sorted(t for t in new if t in old and t not in entries):
                items.append({'status': 'backlog', 'english': t, 'section': 'patterns' if PH.search(t) else 'exact',
                              'render': new[t]['render'], 'risky': new[t]['risky'], 'action': '（任意）訳を追加する'})
        for i in items:
            i['source'] = 'screen'
        counts = {s: sum(1 for i in items if i['status'] == s) for s in ('new', 'changed', 'removed', 'backlog', 'unverified')}
        doc = {'lang': lang, 'pack': f, 'fromVersion': ov, 'toVersion': nv, 'scope': scope, 'counts': counts, 'items': items}
        json.dump(doc, open(os.path.join(a.out, f'{lang}.worklist.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
        cols = ['status', 'english', 'previous_english', 'previous_translation', 'similarity', 'section', 'render', 'risky', 'source', 'action', 'translation']
        with open(os.path.join(a.out, f'{lang}.worklist.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
            w = csv.DictWriter(fh, fieldnames=cols, extrasaction='ignore'); w.writeheader()
            for i in items: w.writerow(i)
        summary.append((lang, counts)); total += counts['new'] + counts['changed'] + counts['removed']
    with open(os.path.join(a.out, 'SUMMARY.md'), 'w', encoding='utf-8') as fh:
        fh.write(f'# 更新作業リスト {cache[next(iter(cache))][2]} → {cache[next(iter(cache))][3]}\n\n| 言語 | new | changed | removed | backlog | unverified |\n|---|---|---|---|---|---|\n')
        for lang, c in summary:
            fh.write(f"| {lang} | {c['new']} | {c['changed']} | {c['removed']} | {c['backlog']} | {c['unverified']} |\n")
    for lang, c in summary:
        print(f"{lang}: new {c['new']} / changed {c['changed']} / removed {c['removed']}" + (f" / backlog {c['backlog']}" if a.backlog else '') + f" / unverified {c['unverified']}")
    print(f'書き出し先: {a.out}')
    return 10 if total else 0


if __name__ == '__main__':
    sys.exit(main())
