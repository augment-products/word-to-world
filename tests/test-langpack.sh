#!/usr/bin/env bash
# Optional Microsoft language pack + argv.json "locale" (lab/_langpack.sh, setup-lab.sh, uninstall.sh) with a FAKE Cursor CLI
# and a temporary HOME. Never touches a real Cursor. Set BASH32=/path/to/bash-3.2 to run the lab scripts with bash 3.2.
set -uo pipefail
# 本体は日本語。英語の確認は末尾。
export UI_TR_LANG=ja
HERE="$(cd "$(dirname "$0")" && pwd -P)"; ROOT="$(cd "${HERE}/.." && pwd -P)"
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); echo "PASS  ${1}"; else FAIL=$((FAIL+1)); echo "FAIL  ${1}"; fi; }
command -v lsof >/dev/null 2>&1 || export PATH="${HERE}/bin:${PATH}"
NODE="$(command -v node)"
T="$(mktemp -d "${TMPDIR:-/tmp}/uitr-lptest.XXXXXX")"
if [ -n "${BASH32:-}" ]; then mkdir -p "${T}/b32"; ln -s "${BASH32}" "${T}/b32/bash"; export PATH="${T}/b32:${PATH}"; echo "(lab scripts run with $("${BASH32}" -c 'echo ${BASH_VERSION}'))"; fi
export HOME="${T}/home"; mkdir -p "${HOME}/.cursor"
KIT="${T}/kit"; mkdir -p "${KIT}"; cp -R "${ROOT}/lab" "${ROOT}/tools" "${ROOT}/locales" "${KIT}/"; : > "${KIT}/.word-to-world-kit"
export SRC_APP="${T}/Applications/Cursor.app"; SRC_BIN="${SRC_APP}/Contents/MacOS/Cursor"
CLI="${SRC_APP}/Contents/Resources/app/bin/cursor"; export FAKE_EXT="${T}/ext-list" FAKE_CLI_LOG="${T}/cli.log" FAKE_LIST_COUNT="${T}/list-count"
mkdir -p "${SRC_APP}/Contents/MacOS" "$(dirname "${CLI}")"
printf '#!/usr/bin/env bash\nif [ "${ELECTRON_RUN_AS_NODE:-}" = 1 ]; then exec "%s" "$@"; fi\nexit 0\n' "${NODE}" > "${SRC_BIN}"
cat > "${CLI}" <<'FAKE'
#!/usr/bin/env bash
# fake Cursor CLI: extensions are lines in ${FAKE_EXT} (or ${dir}/list with --extensions-dir)
echo "CLI: $*" >> "${FAKE_CLI_LOG}"
list="${FAKE_EXT}"
while [ $# -gt 0 ]; do
  case "$1" in
    --extensions-dir) list="$2/list"; mkdir -p "$2"; shift 2 ;;
    --user-data-dir) shift 2 ;;
    --list-extensions)
      n=0; [ -f "${FAKE_LIST_COUNT}" ] && n="$(cat "${FAKE_LIST_COUNT}")"
      n=$((n + 1)); printf '%s\n' "${n}" > "${FAKE_LIST_COUNT}"
      if [ "${FAKE_LIST_FAIL:-}" = 1 ]; then echo "list failed" >&2; exit 1; fi
      if [ -n "${FAKE_LIST_FAIL_ON:-}" ] && [ "${n}" = "${FAKE_LIST_FAIL_ON}" ]; then echo "list failed" >&2; exit 1; fi
      touch "${list}"; cat "${list}"; shift ;;
    --install-extension) [ "${FAKE_INSTALL_FAIL:-}" = 1 ] && { echo "network error" >&2; exit 1; }; echo "$2" >> "${list}"; echo "Extension '$2' was successfully installed."; shift 2 ;;
    --uninstall-extension)
      if [ "${FAKE_UNINSTALL_FAIL:-}" = 1 ]; then echo "uninstall failed" >&2; exit 1; fi
      if [ -n "${FAKE_UNINSTALL_FAIL_LIST:-}" ] && [ "${list}" = "${FAKE_UNINSTALL_FAIL_LIST}" ]; then echo "uninstall failed" >&2; exit 1; fi
      grep -vxF "$2" "${list}" > "${list}.n"; mv "${list}.n" "${list}"; shift 2 ;;
    *) shift ;;
  esac
done
FAKE
chmod +x "${SRC_BIN}" "${CLI}"
cp "${CLI}" "${T}/cli.saved"
L="${KIT}/lab"; W="${HOME}/Library/Application Support/word-to-world"; A="${HOME}/.cursor/argv.json"; ID=MS-CEINTL.vscode-language-pack-ja
reset() { rm -rf "${W}"; : > "${FAKE_EXT}"; : > "${FAKE_CLI_LOG}"; : > "${FAKE_LIST_COUNT}"; unset FAKE_LIST_FAIL FAKE_LIST_FAIL_ON FAKE_UNINSTALL_FAIL FAKE_UNINSTALL_FAIL_LIST; }
locale_of() { "${NODE}" "${KIT}/tools/argv-locale.js" get "$1"; }
VSARGV='// This configuration file allows you to pass permanent command line arguments to VS Code.
// NOTE: Changing this file requires a restart of VS Code.
{
	// Use software rendering instead of hardware accelerated rendering.
	// "disable-hardware-acceleration": true,

	// Allows to disable crash reporting.
	"enable-crash-reporter": true,

	// Unique id used for correlating crash reports sent from this instance.
	"crash-reporter-id": "11111111-2222-3333-4444-555555555555"
}'
printf '%s\n' "${VSARGV}" > "${A}"; cp "${A}" "${T}/argv.orig"

# 1) no terminal, no flag -> nothing installed, argv.json untouched
reset; "${L}/setup-lab.sh" < /dev/null > "${T}/s1.log" 2>&1; rc=$?
check "no terminal + no flag: exit 0, pack NOT installed, argv.json byte-identical, ja+en note" '[ ${rc} = 0 ] && [ ! -s "${FAKE_EXT}" ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "with-langpack を付けて" "${T}/s1.log" && ! grep -q "Run again with --with-langpack" "${T}/s1.log" && ! grep -q -- "--install-extension" "${FAKE_CLI_LOG}"'
# 2) asked once in a terminal: "n" -> not installed; a later run does not ask again
reset; echo n | UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" > "${T}/s2.log" 2>&1; rc=$?
check "terminal, answer n: names the VS Code Japanese language pack, nothing installed" \
  '[ ${rc} = 0 ] && grep -q "VS Code の日本語言語パック（Microsoft 公式、${ID}）" "${T}/s2.log" && ! grep -q "The VS Code Japanese language pack (by Microsoft, ${ID})" "${T}/s2.log" && [ ! -s "${FAKE_EXT}" ] && cmp -s "${A}" "${T}/argv.orig"'
check "terminal, answer n: license and restart notes, ja+en" \
  'grep -q "Microsoft のライセンス" "${T}/s2.log" && grep -q "再起動が 1 回必要" "${T}/s2.log" && ! grep -q "under its own license" "${T}/s2.log"'
echo y | UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" > "${T}/s2b.log" 2>&1
check "asks only once: second setup run does not ask and keeps the earlier answer" '! grep -q "y/N" "${T}/s2b.log" && [ ! -s "${FAKE_EXT}" ]'
# 3) terminal, Enter (default NO) leaves argv.json alone; explicit y installs
reset; echo "" | UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" > "${T}/s3n.log" 2>&1; rc=$?
check "terminal, Enter: default is overlay only, argv.json untouched, prompt says the locale change persists" '[ ${rc} = 0 ] && [ ! -s "${FAKE_EXT}" ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "argv.json" "${T}/s3n.log" && grep -q "アンインストールするまで" "${T}/s3n.log" && ! grep -q "until you uninstall" "${T}/s3n.log" && [ "$(cat "${W}/state/langpack-choice")" = no ]'
reset; echo y | UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" > "${T}/s3.log" 2>&1; rc=$?
check "terminal, y: installs ${ID} with cursor --install-extension and records it as ours" '[ ${rc} = 0 ] && grep -qxF "${ID}" "${FAKE_EXT}" && grep -q -- "--install-extension ${ID}" "${FAKE_CLI_LOG}" && [ "$(cut -f1 "${W}/state/langpack-installed")" = "${ID}" ]'
check "argv.json: locale ja added, comments kept, restart note ja+en" \
  '[ "$(locale_of "${A}")" = "{\"exists\":true,\"has\":true,\"value\":\"ja\"}" ] && [ "$(grep -vF "\"locale\"" "${A}" | sed "s/\"crash-reporter-id\": \"\(.*\)\",\$/\"crash-reporter-id\": \"\1\"/")" = "${VSARGV}" ] && grep -q "再起動すると反映" "${T}/s3.log" && ! grep -q "Restart Cursor once" "${T}/s3.log" && cmp -s "${W}/state/argv.json.orig" "${T}/argv.orig"'
"${L}/uninstall.sh" --dry-run --keep-kit > "${T}/d3.log" 2>&1; rc=$?
check "uninstall --dry-run lists the VS Code Japanese pack, changes nothing" \
  '[ ${rc} = 0 ] && grep -q "VS Code の日本語言語パック（Microsoft 公式、${ID}）を外します（このツールが入れたもの）" "${T}/d3.log" && grep -qxF "${ID}" "${FAKE_EXT}" && [ -d "${W}" ]'
check "uninstall --dry-run names the pack in English and the locale restore" \
  'grep -q "元々無かったので消します" "${T}/d3.log" && ! grep -q "it was not there before" "${T}/d3.log"'
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u3.log" 2>&1; rc=$?
check "uninstall --yes: pack removed, argv.json byte-identical to the original, verified (exit 0)" '[ ${rc} = 0 ] && [ ! -s "${FAKE_EXT}" ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "を外しました" "${T}/u3.log" && grep -q "元の状態" "${T}/u3.log" && ! grep -q "Removed the VS Code Japanese language pack" "${T}/u3.log" && [ ! -e "${W}" ]'
# 4) the user's own pack is never removed; an existing locale is restored exactly even after later edits
reset; echo "${ID}" > "${FAKE_EXT}"
printf '{\n\t"enable-crash-reporter": true, // keep me\n\t"locale": "en"\n}\n' > "${A}"; cp "${A}" "${T}/argv2.orig"
"${L}/setup-lab.sh" --with-langpack > "${T}/s4.log" 2>&1; rc=$?
check "user's own pack is not recorded; locale en is changed to ja" \
  '[ ${rc} = 0 ] && ! grep -q -- "--install-extension" "${FAKE_CLI_LOG}" && [ ! -f "${W}/state/langpack-installed" ] && grep -q "既に入っています" "${T}/s4.log" && [ "$(locale_of "${A}")" = "{\"exists\":true,\"has\":true,\"value\":\"ja\"}" ] && grep -qx "prev=en" "${W}/state/argv-locale.state"'
"${NODE}" -e 'const f=process.argv[1],fs=require("fs");fs.writeFileSync(f,fs.readFileSync(f,"utf8").replace("\"enable-crash-reporter\": true","\"enable-crash-reporter\": false"))' "${A}"   # the user edits another setting later
"${L}/uninstall.sh" --dry-run --keep-kit > "${T}/d4.log" 2>&1
check "dry-run: the user's own pack is listed as NOT removed (ja + en), locale back to \"en\" announced" 'grep -q "記録がありませんので、外しません" "${T}/d4.log" && ! grep -q "you installed it yourself" "${T}/d4.log" && grep -q "元の値 \"en\" に戻します" "${T}/d4.log"'
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u4.log" 2>&1; rc=$?
check "uninstall: user pack kept, locale back to en, the later edit and the comment kept" '[ ${rc} = 0 ] && grep -qxF "${ID}" "${FAKE_EXT}" && [ "$(locale_of "${A}")" = "{\"exists\":true,\"has\":true,\"value\":\"en\"}" ] && grep -q "\"enable-crash-reporter\": false, // keep me" "${A}"'
# 5) argv.json missing -> created; uninstall removes it again
reset; rm -f "${A}"
"${L}/setup-lab.sh" --with-langpack > "${T}/s5.log" 2>&1
check "argv.json missing: created with locale ja" '[ "$(locale_of "${A}")" = "{\"exists\":true,\"has\":true,\"value\":\"ja\"}" ] && grep -qx "existed=0" "${W}/state/argv-locale.state"'
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u5.log" 2>&1; rc=$?
check "uninstall: the argv.json we created is removed again, pack removed" '[ ${rc} = 0 ] && [ ! -e "${A}" ] && [ ! -s "${FAKE_EXT}" ]'
# 6) install failure / unparseable argv.json / separate profile
reset; printf '%s\n' "${VSARGV}" > "${A}"
FAKE_INSTALL_FAIL=1 "${L}/setup-lab.sh" --with-langpack > "${T}/s6.log" 2>&1; rc=$?
check "install fails (network): setup still exit 0, warning ja+en, nothing recorded, argv.json untouched" '[ ${rc} = 0 ] && grep -q "言語パックを入れられませんでした" "${T}/s6.log" && ! grep -q "could not install the language pack" "${T}/s6.log" && [ ! -f "${W}/state/langpack-installed" ] && [ ! -f "${W}/state/argv-locale.state" ] && cmp -s "${A}" "${T}/argv.orig"'
reset; printf '{ "a": 1, oops }\n' > "${A}"; cp "${A}" "${T}/bad.orig"
"${L}/setup-lab.sh" --with-langpack > "${T}/s7.log" 2>&1; rc=$?
check "argv.json that cannot be parsed safely: left byte-identical, warning (Configure Display Language)" '[ ${rc} = 0 ] && cmp -s "${A}" "${T}/bad.orig" && grep -q "Configure Display Language" "${T}/s7.log"'
"${L}/uninstall.sh" --yes --keep-kit > /dev/null 2>&1
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --separate-profile --with-langpack > "${T}/s8.log" 2>&1; rc=$?
check "separate profile: pack goes into the lab extensions folder, normal list and argv.json untouched" '[ ${rc} = 0 ] && grep -q -- "--extensions-dir ${W}/lab-extensions --install-extension ${ID}" "${FAKE_CLI_LOG}" && [ ! -s "${FAKE_EXT}" ] && cmp -s "${A}" "${T}/argv.orig" && [ ! -f "${W}/state/argv-locale.state" ]'
"${L}/uninstall.sh" --dry-run --keep-kit > "${T}/d8.log" 2>&1; rc=$?
check "separate profile dry-run: the pack goes away with the work folder" \
  '[ ${rc} = 0 ] && grep -q "作業フォルダーごと削除されます" "${T}/d8.log" && ! grep -q "言語パックも残します" "${T}/d8.log"'
"${L}/uninstall.sh" --dry-run --keep-kit --keep "${W}/lab-extensions" > "${T}/d8k.log" 2>&1; rc=$?
check "separate profile --keep: the plan says the pack stays" \
  '[ ${rc} = 0 ] && grep -q "言語パックも残します" "${T}/d8k.log" && ! grep -q "作業フォルダーごと削除されます" "${T}/d8k.log" && grep -qxF "${ID}" "${W}/lab-extensions/list"'
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u8.log" 2>&1; rc=$?
check "uninstall (separate profile): the recorded pack is removed and the work folder goes with it" \
  '[ ${rc} = 0 ] && grep -q -- "--uninstall-extension ${ID}" "${FAKE_CLI_LOG}" && [ ! -e "${W}" ]'
# 7) other languages map to the right packs; unknown languages do nothing
listed_ids() {
  (
    set +u
    SRC_APP=x
    STATE_DIR=x
    source "${L}/_common.sh" >/dev/null 2>&1
    source "${L}/_langpack.sh"
    for l in "$@"; do
      id="$(langpack_id "${l}" | sed 's/MS-CEINTL.vscode-language-pack-//')"
      loc="$(langpack_locale "${l}")"
      printf '%s=%s/%s ' "${l}" "${id}" "${loc}"
    done
  )
}
got="$(listed_ids ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl xx)"
check "language ids match vscode-loc" '[ "${got}" = "ja=ja/ja zh-cn=zh-hans/zh-cn zh-tw=zh-hant/zh-tw ko=ko/ko fr=fr/fr de=de/de es=es/es it=it/it ru=ru/ru pt-br=pt-BR/pt-br cs=cs/cs tr=tr/tr pl=pl/pl xx=/ " ]'
got="$(listed_ids zh-CN zh-TW zh-HK pt-BR)"
check "legacy spellings still map (zh-CN zh-TW zh-HK pt-BR)" '[ "${got}" = "zh-CN=zh-hans/zh-cn zh-TW=zh-hant/zh-tw zh-HK=zh-hant/zh-tw pt-BR=pt-BR/pt-br " ]'
# 8) argv-locale.js round trips (comments, trailing commas, nested "locale" keys ignored)
check "argv-locale.js: set + remove round trip keeps the file byte-identical (comments, trailing comma, nested locale)" '"${NODE}" -e "
const a=require(\"${KIT}/tools/argv-locale.js\");
const cs=[process.argv[1], \"{\\n  \\\"a\\\": 1, // c\\n  \\\"b\\\": [1, {\\\"locale\\\": \\\"x\\\"}],\\n}\\n\", \"{\\n\\t\\\"x\\\": 1 /* c */\\n}\"];
for (const t of cs) { const s=a.set(t,\"ja\"); if (a.get(s).value!==\"ja\" || a.remove(s)!==t) process.exit(1); }
if (a.get(cs[1]).has) process.exit(1);" "${VSARGV}"'
# 9) missing argv.json backup must not delete the user's file
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
rm -f "${W}/state/argv.json.orig"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u9.log" 2>&1; rc=$?
check "missing argv.json backup: uninstall does not delete the user's argv.json" '[ -f "${A}" ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "削除しません" "${T}/u9.log" && ! grep -q "was not deleted" "${T}/u9.log"'
# 10) empty or symlink backup must not delete the user's file
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
: > "${W}/state/argv.json.orig"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-empty.log" 2>&1; rc=$?
check "empty argv.json backup: uninstall does not delete the user's argv.json" '[ -f "${A}" ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "削除しません" "${T}/u-empty.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
rm -f "${W}/state/argv.json.orig"
ln -s "${T}/argv.orig" "${W}/state/argv.json.orig"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-link.log" 2>&1; rc=$?
check "symlink argv.json backup: uninstall does not delete the user's argv.json" '[ -f "${A}" ] && [ ! -L "${A}" ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "削除しません" "${T}/u-link.log"'
# 11) a restore failure stops before the work folder is deleted
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
printf '{ this is not json\n' > "${A}"
cp "${A}" "${T}/broken.argv"
cp "${W}/state/argv.json.orig" "${T}/backup.before"
cp "${W}/state/argv-locale.state" "${T}/state.before"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-broken.log" 2>&1; rc=$?
check "broken argv.json after install: uninstall stops and leaves the file, backup, and state" '[ ${rc} != 0 ] && cmp -s "${A}" "${T}/broken.argv" && cmp -s "${W}/state/argv.json.orig" "${T}/backup.before" && cmp -s "${W}/state/argv-locale.state" "${T}/state.before" && [ -d "${W}" ] && grep -q "ファイルはそのまま" "${T}/u-broken.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
cp "${W}/state/argv.json.orig" "${T}/backup2.before"
FAKE_UNINSTALL_FAIL=1 "${L}/uninstall.sh" --yes --keep-kit > "${T}/u-pack.log" 2>&1; rc=$?
check "langpack removal failure: uninstall stops and leaves the pack, backup, and state" '[ ${rc} != 0 ] && grep -qxF "${ID}" "${FAKE_EXT}" && [ -d "${W}" ] && cmp -s "${W}/state/argv.json.orig" "${T}/backup2.before" && [ -f "${W}/state/argv-locale.state" ] && grep -q "アンインストールを中止します" "${T}/u-pack.log"'
unset FAKE_UNINSTALL_FAIL
# 12) listing extensions is not the same as "not installed", and a missing Cursor is not a failed list
reset; echo "${ID}" > "${FAKE_EXT}"
"${L}/setup-lab.sh" --with-langpack > "${T}/s-own.log" 2>&1; rc=$?
check "list says already installed: do not install again and do not record ownership" \
  '[ ${rc} = 0 ] && [ ! -f "${W}/state/langpack-installed" ] && ! grep -q -- "--install-extension" "${FAKE_CLI_LOG}" && grep -q "既に入っています" "${T}/s-own.log"'
reset
"${L}/setup-lab.sh" --with-langpack > "${T}/s-new.log" 2>&1; rc=$?
check "list says not installed: install and record ownership" \
  '[ ${rc} = 0 ] && grep -qxF "${ID}" "${FAKE_EXT}" && [ "$(cut -f1 "${W}/state/langpack-installed")" = "${ID}" ]'
reset; printf '%s\n' "${VSARGV}" > "${A}"
FAKE_LIST_FAIL=1 "${L}/setup-lab.sh" --with-langpack > "${T}/s-list.log" 2>&1; rc=$?
check "first list failure: setup exits 1, does not install, and does not record ownership" \
  '[ ${rc} = 1 ] && [ ! -s "${FAKE_EXT}" ] && [ ! -f "${W}/state/langpack-installed" ] && ! grep -q -- "--install-extension" "${FAKE_CLI_LOG}" && cmp -s "${A}" "${T}/argv.orig" && grep -q "記録もしません" "${T}/s-list.log" && ! grep -q "not recording this tool as the owner" "${T}/s-list.log" && ! grep -q "準備完了" "${T}/s-list.log"'
reset; echo "${ID}" > "${FAKE_EXT}"; cp "${FAKE_EXT}" "${T}/ext.before"
FAKE_LIST_FAIL=1 "${L}/setup-lab.sh" --with-langpack > "${T}/s-list-own.log" 2>&1; rc=$?
check "first list failure with an existing pack: exit 1 and do not record it as ours" \
  '[ ${rc} = 1 ] && cmp -s "${FAKE_EXT}" "${T}/ext.before" && [ ! -f "${W}/state/langpack-installed" ] && ! grep -q -- "--install-extension" "${FAKE_CLI_LOG}"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
: > "${FAKE_LIST_COUNT}"
FAKE_LIST_FAIL_ON=2 "${L}/setup-lab.sh" --with-langpack > "${T}/s-after-install.log" 2>&1; rc=$?
check "list failure after install: exit 1, no ownership record, and the message says to check Extensions" \
  '[ ${rc} = 1 ] && grep -qxF "${ID}" "${FAKE_EXT}" && [ ! -f "${W}/state/langpack-installed" ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "入っているかもしれません。Cursor の拡張機能の一覧で確認してください" "${T}/s-after-install.log" && ! grep -q "準備完了" "${T}/s-after-install.log"'
unset FAKE_LIST_FAIL_ON
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
cp "${W}/state/argv.json.orig" "${T}/backup-list.before"
cp "${W}/state/argv-locale.state" "${T}/state-list.before"
: > "${FAKE_CLI_LOG}"
FAKE_LIST_FAIL=1 "${L}/uninstall.sh" --yes --keep-kit > "${T}/u-list.log" 2>&1; rc=$?
check "list failure before uninstall: stop, and leave the pack, backup, and state" \
  '[ ${rc} = 1 ] && grep -qxF "${ID}" "${FAKE_EXT}" && ! grep -q -- "--uninstall-extension" "${FAKE_CLI_LOG}" && [ -d "${W}" ] && cmp -s "${W}/state/argv.json.orig" "${T}/backup-list.before" && cmp -s "${W}/state/argv-locale.state" "${T}/state-list.before" && ! grep -q "を外しました" "${T}/u-list.log"'
check "list failure before uninstall: the stop summary comes after the locale result" \
  'awk "BEGIN{ok=0} /元の状態/{seen=1} /アンインストールを中止/ && seen{ok=1} END{exit ok?0:1}" "${T}/u-list.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
cp "${W}/state/argv.json.orig" "${T}/backup-after.before"
: > "${FAKE_LIST_COUNT}"
FAKE_LIST_FAIL_ON=2 "${L}/uninstall.sh" --yes --keep-kit > "${T}/u-after.log" 2>&1; rc=$?
check "list failure after uninstall: do not treat the pack as removed, keep backup and state" \
  '[ ${rc} != 0 ] && [ -d "${W}" ] && cmp -s "${W}/state/argv.json.orig" "${T}/backup-after.before" && [ -f "${W}/state/argv-locale.state" ] && grep -q "削除できたとは扱いません" "${T}/u-after.log" && ! grep -q "を外しました" "${T}/u-after.log"'
unset FAKE_LIST_FAIL_ON
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
"${L}/uninstall.sh" --yes --keep-kit --skip-langpack > "${T}/u-skip.log" 2>&1; rc=$?
check "--skip-langpack leaves the pack installed, restores argv.json, and does not say nothing remains" \
  '[ ${rc} = 0 ] && grep -qxF "${ID}" "${FAKE_EXT}" && cmp -s "${A}" "${T}/argv.orig" && [ ! -e "${W}" ] && grep -q "確認と削除は省きます" "${T}/u-skip.log" && grep -q "残っている場合があります" "${T}/u-skip.log" && ! grep -q "何も残っていません" "${T}/u-skip.log" && ! grep -q "nothing this tool created remains" "${T}/u-skip.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
rm -f "${CLI}"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-nocli.log" 2>&1; rc=$?
check "CLI missing but Cursor.app remains: uninstall stops and keeps state" \
  '[ ${rc} = 1 ] && [ -d "${W}" ] && [ -f "${W}/state/langpack-installed" ] && [ -f "${W}/state/argv.json.orig" ] && grep -q "CLI がありません" "${T}/u-nocli.log" && ! grep -q "=== 確認 ===" "${T}/u-nocli.log"'
mkdir -p "$(dirname "${CLI}")"
cp "${T}/cli.saved" "${CLI}"; chmod +x "${CLI}"
# Extensions live outside Cursor.app. Removing the app leaves ~/.cursor/extensions.
# https://forum.cursor.com/t/unable-to-update-cursor-to-latest-version-both-nightly-and-stable/167614/7
# https://forum.cursor.com/t/cursor-shortcut-suddenly-program-not-found/82868/5
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
mkdir -p "${HOME}/.cursor/extensions"
cp "${FAKE_EXT}" "${HOME}/.cursor/extensions/installed.txt"
cp "${HOME}/.cursor/extensions/installed.txt" "${T}/ext-outside.before"
rm -rf "${SRC_APP}"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-outside.log" 2>&1; rc=$?
check "app and CLI gone, extension data outside the app: non-zero, ownership and extension data remain" \
  '[ ${rc} != 0 ] && [ -f "${W}/state/langpack-installed" ] && [ "$(cut -f1 "${W}/state/langpack-installed")" = "${ID}" ] && cmp -s "${HOME}/.cursor/extensions/installed.txt" "${T}/ext-outside.before" && grep -qxF "${ID}" "${HOME}/.cursor/extensions/installed.txt"'
check "that run does not reach deletion and does not call the pack already gone" \
  'grep -q "作業フォルダーは削除しません" "${T}/u-outside.log" && ! grep -q "=== 確認 ===" "${T}/u-outside.log" && ! grep -q "^Deleted:" "${T}/u-outside.log" && ! grep -q "もう無い" "${T}/u-outside.log" && ! grep -q "already gone" "${T}/u-outside.log"'
"${L}/uninstall.sh" --yes --keep-kit --skip-langpack > "${T}/u-outside-skip.log" 2>&1; rc=$?
check "--skip-langpack is the only way forward when the app and CLI are gone, and the outside extension data stays" \
  '[ ${rc} = 0 ] && [ ! -e "${W}" ] && cmp -s "${HOME}/.cursor/extensions/installed.txt" "${T}/ext-outside.before" && grep -q "確認と削除は省きます" "${T}/u-outside-skip.log" && grep -q "残っている場合があります" "${T}/u-outside-skip.log" && ! grep -q "何も残っていません" "${T}/u-outside-skip.log" && ! grep -q "already gone" "${T}/u-outside-skip.log"'
mkdir -p "${SRC_APP}/Contents/MacOS" "$(dirname "${CLI}")"
printf '#!/usr/bin/env bash\nif [ "${ELECTRON_RUN_AS_NODE:-}" = 1 ]; then exec "%s" "$@"; fi\nexit 0\n' "${NODE}" > "${SRC_BIN}"
cp "${T}/cli.saved" "${CLI}"; chmod +x "${SRC_BIN}" "${CLI}"
# 標準プロファイルのあと別プロファイルにすると、所有記録は場所ごとに残る。
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
"${L}/setup-lab.sh" --separate-profile > "${T}/s-switch.log" 2>&1; rc=$?
check "mode switch keeps one ownership line per extensions folder" \
  '[ ${rc} = 0 ] && [ "$(grep -c . "${W}/state/langpack-installed")" = 2 ] && grep -qxF "${ID}" "${FAKE_EXT}" && grep -qxF "${ID}" "${W}/lab-extensions/list"'
check "mode switch record: default profile and the lab extensions folder" \
  'grep -qxF "$(printf "%s\t" "${ID}")" "${W}/state/langpack-installed" && grep -qxF "$(printf "%s\t%s" "${ID}" "${W}/lab-extensions")" "${W}/state/langpack-installed"'
: > "${FAKE_CLI_LOG}"
"${L}/setup-lab.sh" --with-langpack > "${T}/s-again.log" 2>&1; rc=$?
check "a later setup of a recorded pack says uninstall will remove it and does not add a line" \
  '[ ${rc} = 0 ] && [ "$(grep -c . "${W}/state/langpack-installed")" = 2 ] && ! grep -q -- "--install-extension" "${FAKE_CLI_LOG}"'
check "that later setup names this tool as the owner" \
  'grep -q "このツールが入れたものです" "${T}/s-again.log" && grep -q "アンインストールで外します" "${T}/s-again.log" && ! grep -q "Uninstall will remove it" "${T}/s-again.log" && ! grep -q "外しません" "${T}/s-again.log"'
: > "${FAKE_CLI_LOG}"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-both.log" 2>&1; rc=$?
check "after the mode switch, uninstall removes both packs and leaves no record" \
  '[ ${rc} = 0 ] && [ ! -s "${FAKE_EXT}" ] && [ ! -e "${W}" ] && [ "$(grep -c -- "--uninstall-extension" "${FAKE_CLI_LOG}")" -ge 2 ] && grep -q "何も残っていません" "${T}/u-both.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
"${L}/setup-lab.sh" --separate-profile > /dev/null 2>&1
FAKE_UNINSTALL_FAIL_LIST="${FAKE_EXT}" "${L}/uninstall.sh" --yes --keep-kit > "${T}/u-one.log" 2>&1; rc=$?
check "if only the normal pack cannot be removed: non-zero, and only that ownership line remains" \
  '[ ${rc} != 0 ] && [ -d "${W}" ] && [ "$(grep -c . "${W}/state/langpack-installed")" = 1 ] && grep -qxF "${ID}" "${FAKE_EXT}" && ! grep -qxF "${ID}" "${W}/lab-extensions/list" && ! grep -q "何も残っていません" "${T}/u-one.log"'
check "the remaining ownership line is the default profile" \
  'grep -qxF "$(printf "%s\t" "${ID}")" "${W}/state/langpack-installed"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
"${L}/setup-lab.sh" --separate-profile > /dev/null 2>&1
FAKE_UNINSTALL_FAIL_LIST="${W}/lab-extensions/list" "${L}/uninstall.sh" --yes --keep-kit > "${T}/u-lab.log" 2>&1; rc=$?
check "if only the separate-profile pack cannot be removed: non-zero, and only that line remains" \
  '[ ${rc} != 0 ] && [ ! -s "${FAKE_EXT}" ] && grep -qxF "${ID}" "${W}/lab-extensions/list" && [ "$(grep -c . "${W}/state/langpack-installed")" = 1 ] && ! grep -q "何も残っていません" "${T}/u-lab.log"'
check "the remaining ownership line is the lab extensions folder" \
  'grep -qxF "$(printf "%s\t%s" "${ID}" "${W}/lab-extensions")" "${W}/state/langpack-installed"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
printf '%s\n' "${ID}" > "${W}/state/langpack-installed"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-old.log" 2>&1; rc=$?
check "an old one-line ownership record with no tab is still removed" \
  '[ ${rc} = 0 ] && [ ! -s "${FAKE_EXT}" ] && [ ! -e "${W}" ]'
reset; printf '%s\n' "${VSARGV}" > "${A}"
mkdir -p "${T}/block"; ln -s /dev/full "${T}/block/backup"
LP_ARGV_BACKUP="${T}/block/backup" "${L}/setup-lab.sh" --with-langpack > "${T}/s-bak.log" 2>&1; rc=$?
check "backup creation failure: argv.json unchanged, non-zero, and not ready" \
  '[ ${rc} != 0 ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "バックアップを書けませんでした" "${T}/s-bak.log" && ! grep -q "was not changed" "${T}/s-bak.log" && ! grep -q "準備完了" "${T}/s-bak.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
mkdir -p "${T}/block/record"
LP_ARGV_FILE="${T}/block/record" "${L}/setup-lab.sh" --with-langpack > "${T}/s-rec.log" 2>&1; rc=$?
check "restore-record creation failure: argv.json unchanged, non-zero, and not ready" \
  '[ ${rc} != 0 ] && cmp -s "${A}" "${T}/argv.orig" && grep -q "復元記録を書けませんでした" "${T}/s-rec.log" && ! grep -q "was not changed" "${T}/s-rec.log" && ! grep -q "準備完了" "${T}/s-rec.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
printf 'ms-ceintl.vscode-language-pack-ja@1.128.0\n' > "${FAKE_EXT}"
UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" < /dev/null > "${T}/s-ask.log" 2>&1; rc=$?
check "already installed (lowercase id@version): no prompt, no ownership, argv.json untouched" \
  '[ ${rc} = 0 ] && ! grep -q "y/N" "${T}/s-ask.log" && grep -q "既に入っています" "${T}/s-ask.log" && grep -q "記録にはしません" "${T}/s-ask.log" && ! grep -q "not recorded as ours" "${T}/s-ask.log" && [ ! -f "${W}/state/langpack-installed" ] && [ ! -f "${W}/state/langpack-choice" ] && cmp -s "${A}" "${T}/argv.orig" && ! grep -q -- "--install-extension" "${FAKE_CLI_LOG}"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
mkdir -p "${HOME}/.cursor/extensions/ms-ceintl.vscode-language-pack-ja-1.128.0-universal"
UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" < /dev/null > "${T}/s-disk.log" 2>&1; rc=$?
check "already installed as a lowercase extensions folder: no prompt and no ownership record" \
  '[ ${rc} = 0 ] && ! grep -q "y/N" "${T}/s-disk.log" && grep -q "既に入っています" "${T}/s-disk.log" && grep -q "外しません" "${T}/s-disk.log" && [ ! -f "${W}/state/langpack-installed" ] && cmp -s "${A}" "${T}/argv.orig"'
rm -rf "${HOME}/.cursor/extensions/ms-ceintl.vscode-language-pack-ja-1.128.0-universal"
echo n | UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" > "${T}/s-ask2.log" 2>&1; rc=$?
check "once that folder is gone, setup asks again" '[ ${rc} = 0 ] && grep -q "y/N" "${T}/s-ask2.log"'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --separate-profile --with-langpack > /dev/null 2>&1
rm -f "${CLI}"
"${L}/uninstall.sh" --dry-run --keep-kit > "${T}/d-sep-nocli.log" 2>&1; rc=$?
check "separate profile, CLI gone, dry-run: the pack goes with the work folder" \
  '[ ${rc} = 0 ] && grep -q "作業フォルダーごと削除されます" "${T}/d-sep-nocli.log" && ! grep -q "CLI がありません" "${T}/d-sep-nocli.log" && ! grep -q "CLI is missing" "${T}/d-sep-nocli.log" && ! grep -q "~/.cursor/extensions" "${T}/d-sep-nocli.log"'
"${L}/uninstall.sh" --dry-run --keep-kit --keep "${W}/lab-extensions" > "${T}/d-sep-keep.log" 2>&1; rc=$?
check "separate profile, CLI gone, --keep: the plan still keeps the pack" \
  '[ ${rc} = 0 ] && grep -q "言語パックも残します" "${T}/d-sep-keep.log" && ! grep -q "CLI がありません" "${T}/d-sep-keep.log" && ! grep -q "~/.cursor/extensions" "${T}/d-sep-keep.log"'
"${L}/uninstall.sh" --yes --keep-kit --keep "${W}/lab-extensions" > "${T}/u-sep-keep.log" 2>&1; rc=$?
check "separate profile, CLI gone, --keep: real run keeps the pack and does not stop" \
  '[ ${rc} = 0 ] && grep -qxF "${ID}" "${W}/lab-extensions/list" && ! grep -q "CLI がありません" "${T}/u-sep-keep.log" && ! grep -q "CLI is missing" "${T}/u-sep-keep.log" && ! grep -q "~/.cursor/extensions" "${T}/u-sep-keep.log"'
mkdir -p "$(dirname "${CLI}")"
cp "${T}/cli.saved" "${CLI}"; chmod +x "${CLI}"
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --separate-profile --with-langpack > /dev/null 2>&1
rm -f "${CLI}"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-sep-nocli.log" 2>&1; rc=$?
check "separate profile, CLI gone: real run removes the work folder and does not point at ~/.cursor/extensions" \
  '[ ${rc} = 0 ] && [ ! -e "${W}" ] && grep -q "作業フォルダーごと削除されます" "${T}/u-sep-nocli.log" && ! grep -q "CLI がありません" "${T}/u-sep-nocli.log" && ! grep -q "CLI is missing" "${T}/u-sep-nocli.log" && ! grep -q "~/.cursor/extensions" "${T}/u-sep-nocli.log"'
mkdir -p "$(dirname "${CLI}")"
cp "${T}/cli.saved" "${CLI}"; chmod +x "${CLI}"
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
"${L}/setup-lab.sh" --separate-profile > /dev/null 2>&1
rm -f "${CLI}"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-mix-nocli.log" 2>&1; rc=$?
check "normal-profile line with no CLI still stops, and the separate-profile line is kept" \
  '[ ${rc} != 0 ] && [ -d "${W}" ] && grep -q "CLI がありません" "${T}/u-mix-nocli.log" && grep -qxF "$(printf "%s\t" "${ID}")" "${W}/state/langpack-installed" && grep -qxF "$(printf "%s\t%s" "${ID}" "${W}/lab-extensions")" "${W}/state/langpack-installed"'
mkdir -p "$(dirname "${CLI}")"
cp "${T}/cli.saved" "${CLI}"; chmod +x "${CLI}"
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
line="$(head -1 "${W}/state/langpack-installed")"
printf '%s\n%s\n' "${line}" "${line}" > "${W}/state/langpack-installed"
: > "${FAKE_CLI_LOG}"; : > "${FAKE_LIST_COUNT}"
"${L}/uninstall.sh" --yes --keep-kit > "${T}/u-dup.log" 2>&1; rc=$?
check "duplicate ledger lines are uninstalled once" \
  '[ ${rc} = 0 ] && [ ! -s "${FAKE_EXT}" ] && [ ! -e "${W}" ] && [ "$(grep -c -- "--uninstall-extension" "${FAKE_CLI_LOG}")" = 1 ] && [ "$(cat "${FAKE_LIST_COUNT}")" = 2 ]'
reset; printf '%s\n' "${VSARGV}" > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
printf '%s\n' "${VSARGV}" > "${A}"
printf '\n\t"locale": "ja"\n' >> "${A}"
cp "${A}" "${T}/argv.hand"
rm -rf "${SRC_APP}"
PATH="/usr/bin:/bin" "${L}/uninstall.sh" --yes --keep-kit > "${T}/u-nonode.log" 2>&1; rc=$?
check "no Cursor binary and no node: uninstall tells you how to restore locale by hand and keeps the backup" \
  '[ ${rc} != 0 ] && cmp -s "${A}" "${T}/argv.hand" && [ -f "${W}/state/argv.json.orig" ] && [ -f "${W}/state/langpack-installed" ] && grep -q "argv.json.orig" "${T}/u-nonode.log" && grep -q "locale\" の行を消してください" "${T}/u-nonode.log" && ! grep -q "delete the \"locale\" line" "${T}/u-nonode.log"'
check "that hand-restore note says a full backup also restores later setting changes" \
  'grep -q "他の設定も戻ります" "${T}/u-nonode.log" && ! grep -q "other settings changed after install" "${T}/u-nonode.log"'
mkdir -p "${SRC_APP}/Contents/MacOS" "$(dirname "${CLI}")"
printf '#!/usr/bin/env bash\nif [ "${ELECTRON_RUN_AS_NODE:-}" = 1 ]; then exec "%s" "$@"; fi\nexit 0\n' "${NODE}" > "${SRC_BIN}"
cp "${T}/cli.saved" "${CLI}"; chmod +x "${SRC_BIN}" "${CLI}"
reset; printf '{\n\t"enable-crash-reporter": true,\n\t"locale": "en"\n}\n' > "${A}"
"${L}/setup-lab.sh" --with-langpack > /dev/null 2>&1
printf '\n' >> "${A}"; cp "${A}" "${T}/argv.had"
rm -rf "${SRC_APP}"
PATH="/usr/bin:/bin" "${L}/uninstall.sh" --yes --keep-kit > "${T}/u-had.log" 2>&1; rc=$?
check "hand restore when locale existed: say the previous value, and that a full backup restores later edits" \
  '[ ${rc} != 0 ] && cmp -s "${A}" "${T}/argv.had" && grep -q "元の値 \"en\" に戻します" "${T}/u-had.log" && ! grep -q "set \"locale\" back to" "${T}/u-had.log" && grep -q "他の設定も戻ります" "${T}/u-had.log" && ! grep -q "行を消す" "${T}/u-had.log"'
mkdir -p "${SRC_APP}/Contents/MacOS" "$(dirname "${CLI}")"
printf '#!/usr/bin/env bash\nif [ "${ELECTRON_RUN_AS_NODE:-}" = 1 ]; then exec "%s" "$@"; fi\nexit 0\n' "${NODE}" > "${SRC_BIN}"
cp "${T}/cli.saved" "${CLI}"; chmod +x "${SRC_BIN}" "${CLI}"
reset
printf '%s\n' "${VSARGV}" > "${A}"
echo n | UI_TR_LANG=en UI_TR_ASSUME_TTY=1 "${L}/setup-lab.sh" > "${T}/en-ask.log" 2>&1; rc=$?
check "English UI: the language-pack prompt is English only" \
  '[ ${rc} = 0 ] && grep -q "under its own license" "${T}/en-ask.log" && grep -q "Press y to install" "${T}/en-ask.log" && ! grep -q "Microsoft のライセンス" "${T}/en-ask.log"'
rm -rf "${T}"
echo "RESULT langpack: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" = 0 ]
