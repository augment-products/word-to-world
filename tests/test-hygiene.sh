#!/usr/bin/env bash
# Repository hygiene: no Cursor code, no bundle extraction or file-patching tools, required notices present.
# Scans distinguish match / no match / read error. They do not pipe a file scan into grep -q:
# under pipefail, grep -q closing the pipe (SIGPIPE) makes `! scan | grep -q` look like a pass.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"; cd "$ROOT"
PASS=0; FAIL=0
# vscode-loc ids, same list everywhere. ja ships; the rest are planned and must not be in locales/.
PLANNED_LANGS="zh-cn zh-tw ko fr de es it ru pt-br cs tr pl"
LANG_LIST="ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl"
check() { if eval "$2"; then PASS=$((PASS+1)); echo "PASS  $1"; else FAIL=$((FAIL+1)); echo "FAIL  $1"; fi; }
FILES="$(find . -type f -not -path './.git/*' -not -path './work/*' -not -path './dist/*' -not -name '*.png')"
HYG_ERR="$(mktemp)"
HYG_LIST="$(mktemp)"
trap 'rm -f "${HYG_ERR}" "${HYG_LIST}"' EXIT

# 0 = no remaining hit, 1 = hit, 2 = grep could not read. $1 is an ERE of lines to ignore (empty = ignore nothing).
grep_clean() {
  local drop="$1" rc
  shift
  GREP_OUT="$(grep "$@" 2>"${HYG_ERR}")" && rc=0 || rc=$?
  if [ "${rc}" -gt 1 ]; then return 2; fi
  if [ "${rc}" -eq 1 ]; then return 0; fi
  if [ -n "${drop}" ]; then
    GREP_OUT="$(printf '%s\n' "${GREP_OUT}" | grep -E -v "${drop}" || true)"
  fi
  if [ -n "${GREP_OUT}" ]; then return 1; fi
  return 0
}
# 0 = every file is short enough, 1 = a line over 400 columns, 2 = a file could not be read.
# The result is the accumulated flags, not the status of the last file.
long_lines_clean() {
  local f ec found=0 err=0
  for f in "$@"; do
    if [ ! -f "${f}" ]; then err=1; continue; fi
    awk 'length > 400 { found=1; exit } END { exit found ? 0 : 1 }' "${f}"
    ec=$?
    if [ "${ec}" -eq 0 ]; then found=1
    elif [ "${ec}" -ne 1 ]; then err=1
    fi
  done
  if [ "${err}" = 1 ]; then return 2; fi
  if [ "${found}" = 1 ]; then return 1; fi
  return 0
}
long_lines_repo() {
  local f ec found=0 err=0
  while IFS= read -r f; do
    case "${f}" in *.json) continue ;; esac
    # README.md is prose in Japanese and English. A 400-column cut splits a
    # sentence in the middle, so this scan skips it. Code and other docs stay limited.
    case "${f}" in ./README.md) continue ;; esac
    long_lines_clean "${f}"
    ec=$?
    if [ "${ec}" -eq 1 ]; then found=1
    elif [ "${ec}" -eq 2 ]; then err=1
    fi
  done <<EOF
$(find . -type f -not -path './.git/*' -not -path './work/*' -not -path './dist/*' -not -name '*.png' -not -name '*.json')
EOF
  if [ "${err}" = 1 ]; then return 2; fi
  if [ "${found}" = 1 ]; then return 1; fi
  return 0
}

printf '%s\n' ${FILES} > "${HYG_LIST}"
check "no bundle-extraction or JS-patching tools shipped" 'grep_clean "" -Ei "extract_strings|patch_|patcher|\.orig$|workbench\.(desktop|glass)\.main\.js" "${HYG_LIST}"; [ $? -eq 0 ]'
check "no minified-bundle signatures in any file" 'grep_clean "tests/test-hygiene.sh" -RIlE "\\b[A-Za-z_\$]{1,3}\\(\\{\"[a-zA-Z0-9_.-]+\\.js\"\\(\\)|__decorate\\(\\[|sourceMappingURL=workbench" ${FILES}; [ $? -eq 0 ]'
check "no very long lines outside language layers (code dumps)" 'long_lines_repo; [ $? -eq 0 ]'
check "language layers contain only string translations" 'node tools/pack.js validate >/dev/null'
check "README: unofficial / not affiliated / own risk / no Cursor code / takedown (ja + en)" 'grep -q "非公式" README.md && grep -qi "not affiliated" README.md && grep -q "自己責任" README.md && grep -qi "own risk" README.md && grep -qi "contains no Cursor code" README.md && grep -q "削除" README.md && grep -qi "take.*down" README.md'
check "README discloses the debug-port access to the default profile (ja + en)" \
  'grep -q "標準プロファイルのデータを含む" README.md && grep -qi "including your default profile" README.md'
check "debug-port text names an agent command and npm install" \
  'grep -q "AI エージェント" README.md && grep -q "npm install" README.md && grep -q "AI agent" README.md && grep -q "npm install" SECURITY.md && grep -q "AI エージェント" lab/messages/ui.ja.sh && grep -q "npm install" lab/messages/ui.ja.sh && grep -q "npm install" lab/messages/ui.en.sh'
check "product name is not \"Cursor\" (title is the language layer display name)" 'head -1 README.md | grep -qx "# Word to World for Cursor | Japanese Language Layer" && grep -c "^# Word to World for Cursor | Japanese Language Layer$" README.md | grep -qx 2'
check "old name (UI Translator for Cursor) not in user-facing docs" 'grep_clean "tests/test-hygiene.sh" -RiE "(UI Translator for Cursor|~/ui-translator-for-cursor)" README.md CONTRIBUTING.md CONTRIBUTING-AI.md docs/ schema/ lab/messages/ .github/ISSUE_TEMPLATE/; [ $? -eq 0 ]'
check "CONTRIBUTING-AI.md present with validation command" 'grep -q "node tools/pack.js validate" CONTRIBUTING-AI.md'
check "planned languages are not shipped in locales/" '( for l in ${PLANNED_LANGS}; do [ ! -e "locales/${l}.json" ] || exit 1; done )'
check "debug address option never used" 'grep_clean "case|fail|never|付けない|address flag" -RIn -- "--remote-debugging-address=" lab tools; [ $? -eq 0 ]'
check "no internal identifiers of Cursor bundles in docs/code" 'grep_clean "tests/test-hygiene.sh" -RIEn "\\b(uTc|i4C|io_)\\b|settingsCatalog|getOrBuildGlass" ${FILES}; [ $? -eq 0 ]'
check "LICENSE (MIT) present with AUGMENT PRODUCTS" 'grep -q "MIT License" LICENSE && grep -q "AUGMENT PRODUCTS" LICENSE'
check "README: trademark used descriptively, terms-of-service note, no warranty (ja + en)" 'grep -q "商標" README.md && grep -qi "used here only descriptively" README.md && grep -q "利用規約" README.md && grep -qi "terms of service" README.md && grep -q "無保証" README.md && grep -qi "no warranty" README.md'
check "issue forms present (translation fix with required fields, config)" '[ -f .github/ISSUE_TEMPLATE/config.yml ] && ( for k in lang location english current proposed reason screenshot cursor_version; do grep -q "id: ${k}\$" .github/ISSUE_TEMPLATE/translation-fix.yml || exit 1; done )'
check "locales/ holds only language layers (*.json); no code, no draft languages" '[ -z "$(find locales -type f ! -name "*.json")" ] && [ -z "$(find locales -name "zh-*")" ]'
check "translations live only in locales/drafts (no translation tables in tools/ or lab/)" 'grep_clean "" -RlE "\"(Window Restoration|Privacy Mode)\"[[:space:]]*:" tools lab; [ $? -eq 0 ]'
check "no app bundle / raw string dumps in the repo; bundle-ref/ is git-ignored" 'grep_clean "" -Ei "(^|/)bundle-ref/|\\.deb$|\\.asar$|candidates\\.json|selected2?\\.json|nls\\.messages" "${HYG_LIST}"; [ $? -eq 0 ] && grep -qx "bundle-ref/" .gitignore'
bundle_derived_ok() {
  [ -f verification/ja.bundle-derived.json ] || return 0
  node <<'JS'
const d = require("./verification/ja.bundle-derived.json");
const keys = ["english", "ja", "source", "contexts", "verifiedOnScreen", "verifiedVersion", "inGroups"];
const ok = d.entries.length > 0 && d.entries.every(e =>
  typeof e.english === "string" && typeof e.ja === "string" && /^bundle:/.test(e.source) &&
  typeof e.verifiedOnScreen === "boolean" && Object.keys(e).every(k => keys.includes(k)));
process.exit(ok ? 0 : 1);
JS
}
check "bundle-derived verification file format (if present)" 'bundle_derived_ok'
check "capture checklist (ja) present and points to the read-only watch mode" 'grep -q "inject.js watch" docs/capture-checklist-ja.md && grep -q "読み取り専用" docs/capture-checklist-ja.md'
check "draft packs (if present) are marked not shipped and match the english template" 'node tools/sync-locale.js --check-drafts'
check "roadmap present (ja + en) and linked from README" 'grep -q "ROADMAP" README.md && grep -q "^## 日本語" docs/ROADMAP.md && grep -q "^## English" docs/ROADMAP.md'
check "language list is the lowercase vscode-loc ids everywhere" \
  'grep -F "${LANG_LIST}" docs/ROADMAP.md >/dev/null && grep -F "${LANG_LIST}" drafts/README.md >/dev/null && grep -F "${LANG_LIST}" CONTRIBUTING.md >/dev/null && { grep_clean "" -RInE "zh-hk|zh-HK|zh-CN|zh-TW|drafts/zh-" docs/ROADMAP.md drafts/README.md CONTRIBUTING.md CONTRIBUTING-AI.md README.md .github/ISSUE_TEMPLATE/translation-fix.yml; [ $? -eq 0 ]; }'
check "fixtures do not contain the substring taiji" 'grep_clean "" -RIni "taiji" tests/fixtures; [ $? -eq 0 ]'
roadmap_public() {
  grep -q "この公開版に含まれます" docs/ROADMAP.md &&
    grep -q "included in this public release" docs/ROADMAP.md &&
    grep -q "| 公開 |" docs/ROADMAP.md &&
    grep -q "| Public release |" docs/ROADMAP.md &&
    ! grep -q "公開リリースの前" docs/ROADMAP.md &&
    ! grep -q "not a public release yet" docs/ROADMAP.md &&
    ! grep -q "リリース準備中" docs/ROADMAP.md &&
    ! grep -q "Preparing for release" docs/ROADMAP.md
}
check "roadmap marks Japanese as included in the public release" 'roadmap_public'
check "on-screen notice says unofficial and not affiliated" 'grep -q "unofficial, not affiliated with Cursor" tools/inject.js && grep -q "not affiliated with, endorsed by, or sponsored by" tools/inject.js'
check "contributor docs do not point at files this repository leaves out" 'grep_clean "not included|含まれていません|このリポジトリに無い" -RInE "docs/tour\\.md\\)|\\(docs/tour\\.md\\)|verification/ja\\.|drafts/<lang>\\.json" CONTRIBUTING.md CONTRIBUTING-AI.md tools/tour.js; [ $? -eq 0 ]'
check "tools/tour.js: throwaway-profile only (if present)" '[ ! -f tools/tour.js ] || { grep -q "THROWAWAY" tools/tour.js && { [ ! -f docs/tour.md ] || grep -q "使い捨てのプロフィール専用" docs/tour.md; } && ! node tools/tour.js --port 1 >/dev/null 2>&1 && ! node tools/tour.js --throwaway-profile --port 9333 >/dev/null 2>&1 && ! grep -q "remote-debugging-address" tools/tour.js; }'

# The scanner itself: one hit, a flood of hits, and a path it cannot read must all be failures (not a pass).
SELF="$(mktemp -d)"
printf 'FORBIDDEN-STRING\n' > "${SELF}/one"
awk 'BEGIN { for (i = 0; i < 20000; i++) print "FORBIDDEN-STRING" }' > "${SELF}/many"
awk 'BEGIN { s = ""; for (i = 0; i < 501; i++) s = s "x"; print s }' > "${SELF}/long"
printf 'short\n' > "${SELF}/short"
check "self-test: one violation is a failure" 'grep_clean "" -F FORBIDDEN-STRING "${SELF}/one"; [ $? -eq 1 ]'
check "self-test: many violations are a failure" 'grep_clean "" -F FORBIDDEN-STRING "${SELF}/many"; [ $? -eq 1 ]'
check "self-test: a missing path is a scan error" 'grep_clean "" -F FORBIDDEN-STRING "${SELF}/missing"; [ $? -eq 2 ]'
check "self-test: a long line before short files is still a failure" 'long_lines_clean "${SELF}/long" "${SELF}/short" "${SELF}/short"; [ $? -eq 1 ]'
check "self-test: a missing path is a long-line scan error" 'long_lines_clean "${SELF}/missing"; [ $? -eq 2 ]'
rm -rf "${SELF}"

echo "RESULT hygiene: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
