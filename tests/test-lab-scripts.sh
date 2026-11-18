#!/usr/bin/env bash
# lab/*.sh end-to-end with a FAKE Cursor.app (headless Chrome + a fixture page) and a fake osascript, in a temporary HOME.
# Covers: normal mode (default; default profile, only --remote-debugging-port), the "Cursor already running" quit flow
# (no confirmation -> exit 5, refuses to quit -> exit 7 without force-kill, --quit-running), start.sh ending when Cursor
# quits, injector self-exit, separate-profile mode, stop.sh, uninstall (dry-run, cancel, unsafe manifest entries,
# --yes, verification, legacy folder, temp files), and that Cursor.app and the default profile are never written to.
# Set BASH32=/path/to/bash-3.2 to run every lab script with bash 3.2 (it is put first in PATH for "#!/usr/bin/env bash").
set -uo pipefail
# 本体は日本語。英語は末尾と UI_TR_LANG=en の確認。言語解決の確認は env -u でこの指定を外す。
export UI_TR_LANG=ja
HERE="$(cd "$(dirname "$0")" && pwd -P)"; ROOT="$(cd "${HERE}/.." && pwd -P)"
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); echo "PASS  ${1}"; else FAIL=$((FAIL+1)); echo "FAIL  ${1}"; fi; }
# 色は端末のときだけ。NO_COLOR（空でも）と TERM=dumb では付けない。パイプのログは無色。
color_out() { # $1 = plain | tty | nocolor | dumb
  python3 - "$1" "${ROOT}/lab/_common.sh" <<'PY'
import os, pty, select, subprocess, sys
mode, common = sys.argv[1], sys.argv[2]
script = (
    'source "$1"\n'
    'say "OK: probe"\n'
    'say "plain-marker"\n'
    'say_bold "ready-marker"\n'
    'say_hot "hot-marker"\n'
    'say_prompt "yes / no: "\n'
    'printf "\\n"\n'
)
env = os.environ.copy()
env.pop("NO_COLOR", None)
env["TERM"] = "xterm-256color"
if mode == "nocolor":
    env["NO_COLOR"] = ""
elif mode == "dumb":
    env["TERM"] = "dumb"
argv = ["bash", "-c", script, "bash", common]
if mode == "plain":
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    sys.stdout.buffer.write(p.stdout)
    sys.stderr.buffer.write(p.stderr)
    sys.exit(p.returncode)
master, slave = pty.openpty()
p = subprocess.Popen(argv, stdin=slave, stdout=slave, stderr=subprocess.PIPE, env=env)
os.close(slave)
chunks = []
while True:
    ready, _, _ = select.select([master], [], [], 5)
    if not ready:
        break
    try:
        data = os.read(master, 4096)
    except OSError:
        break
    if not data:
        break
    chunks.append(data)
os.close(master)
err = p.stderr.read()
p.wait()
sys.stderr.buffer.write(err)
sys.stdout.buffer.write(b"".join(chunks).replace(b"\r\n", b"\n").replace(b"\r", b"\n"))
sys.exit(p.returncode)
PY
}
CT="$(mktemp -d "${TMPDIR:-/tmp}/uitr-color.XXXXXX")"
color_out plain > "${CT}/plain.txt" 2>"${CT}/plain.err"; rc=$?
check "color off when stdout is not a TTY" \
  '[ ${rc} = 0 ] && grep -qxF "OK: probe" "${CT}/plain.txt" && grep -qxF "plain-marker" "${CT}/plain.txt" && grep -qxF "ready-marker" "${CT}/plain.txt" && grep -qxF "hot-marker" "${CT}/plain.txt" && grep -q "yes / no: " "${CT}/plain.txt" && ! grep -q "$(printf "\033")" "${CT}/plain.txt"'
color_out tty > "${CT}/tty.txt" 2>"${CT}/tty.err"; rc=$?
check "color on a TTY: OK bold green, bold, bold red" \
  '[ ${rc} = 0 ] && grep -qF "$(printf "\033[1;32mOK: probe\033[0m")" "${CT}/tty.txt" && grep -qF "$(printf "\033[1mready-marker\033[0m")" "${CT}/tty.txt"'
check "color on a TTY: hot lines are bold red and the prompt is bold" \
  'grep -qF "$(printf "\033[1;31mhot-marker\033[0m")" "${CT}/tty.txt" && grep -qF "$(printf "\033[1myes / no: \033[0m")" "${CT}/tty.txt"'
check "a TTY leaves ordinary lines uncolored" 'grep -qxF "plain-marker" "${CT}/tty.txt"'
color_out nocolor > "${CT}/nocolor.txt" 2>"${CT}/nocolor.err"; rc=$?
check "NO_COLOR set (even empty) disables color on a TTY" \
  '[ ${rc} = 0 ] && grep -qxF "OK: probe" "${CT}/nocolor.txt" && ! grep -q "$(printf "\033")" "${CT}/nocolor.txt"'
color_out dumb > "${CT}/dumb.txt" 2>"${CT}/dumb.err"; rc=$?
check "TERM=dumb disables color on a TTY" \
  '[ ${rc} = 0 ] && grep -qxF "hot-marker" "${CT}/dumb.txt" && ! grep -q "$(printf "\033")" "${CT}/dumb.txt"'
rm -rf "${CT}"

# 表示言語の決め方。Chrome は要らない。本体の UI_TR_LANG=ja はこの確認では外す。
LH="$(mktemp -d "${TMPDIR:-/tmp}/uitr-lang.XXXXXX")"
mkdir -p "${LH}/home" "${LH}/bin"
cat > "${LH}/bin/defaults" <<'DEF'
#!/bin/sh
printf '%s\n' '(' '    "ja-JP",' '    "en-US"' ')'
DEF
chmod +x "${LH}/bin/defaults"
env -u UI_TR_LANG -u UI_LANG -u UI_LANG_READY HOME="${LH}/home" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  "${ROOT}/lab/setup-lab.sh" --help > "${LH}/en-help.txt" 2>&1; rc=$?
check "system English: help is English only" '[ ${rc} = 0 ] && grep -q "Usage:" "${LH}/en-help.txt" && ! grep -q "使い方" "${LH}/en-help.txt"'
env -u UI_TR_LANG -u UI_LANG -u UI_LANG_READY HOME="${LH}/home" LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 \
  "${ROOT}/lab/start.sh" --help > "${LH}/ja-help.txt" 2>&1; rc=$?
check "LANG=ja: help is Japanese only" '[ ${rc} = 0 ] && grep -q "使い方" "${LH}/ja-help.txt" && ! grep -q "Usage:" "${LH}/ja-help.txt"'
env -u UI_TR_LANG -u UI_LANG -u UI_LANG_READY HOME="${LH}/home" LANG=en_US.UTF-8 LC_ALL=C \
  PATH="${LH}/bin:${PATH}" "${ROOT}/lab/uninstall.sh" --help > "${LH}/apple.txt" 2>&1; rc=$?
check "AppleLanguages ja wins over LANG=en" '[ ${rc} = 0 ] && grep -q "使い方" "${LH}/apple.txt" && ! grep -q "Usage:" "${LH}/apple.txt"'
mkdir -p "${LH}/home/Library/Application Support/word-to-world/state"
printf 'ja\n' > "${LH}/home/Library/Application Support/word-to-world/state/ui-lang"
env -u UI_TR_LANG -u UI_LANG -u UI_LANG_READY HOME="${LH}/home" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  "${ROOT}/lab/setup-lab.sh" --help > "${LH}/saved.txt" 2>&1; rc=$?
check "saved ui-lang=ja overrides an English locale" '[ ${rc} = 0 ] && grep -q "使い方" "${LH}/saved.txt" && ! grep -q "Usage:" "${LH}/saved.txt"'
printf 'en\n' > "${LH}/home/Library/Application Support/word-to-world/state/ui-lang"
env -u UI_TR_LANG -u UI_LANG -u UI_LANG_READY HOME="${LH}/home" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  "${ROOT}/lab/setup-lab.sh" --help --lang ja > "${LH}/flag.txt" 2>&1; rc=$?
check "--lang ja overrides a saved English UI language" '[ ${rc} = 0 ] && grep -q "使い方" "${LH}/flag.txt" && ! grep -q "Usage:" "${LH}/flag.txt"'
env -u UI_LANG -u UI_LANG_READY HOME="${LH}/home" UI_TR_LANG=en \
  "${ROOT}/lab/setup-lab.sh" --help --lang ja > "${LH}/override.txt" 2>&1; rc=$?
check "UI_TR_LANG=en overrides --lang ja" '[ ${rc} = 0 ] && grep -q "Usage:" "${LH}/override.txt" && ! grep -q "使い方" "${LH}/override.txt"'
env -u UI_TR_LANG HOME="${LH}/home" UI_LANG=en UI_LANG_READY=1 \
  "${ROOT}/lab/setup-lab.sh" --help --lang ja > "${LH}/ready.txt" 2>&1; rc=$?
check "a parent UI_LANG stays put when a child is passed --lang ja" '[ ${rc} = 0 ] && grep -q "Usage:" "${LH}/ready.txt" && ! grep -q "使い方" "${LH}/ready.txt"'
python3 - "${ROOT}/lab/messages" <<'PY'
import sys
from pathlib import Path
d = Path(sys.argv[1])
def keys(name):
    out = []
    for line in (d/name).read_text().splitlines():
        if not line or line.startswith("#") or "=" not in line: continue
        k, v = line.split("=", 1)
        if k.replace("_","").isalnum() and k.isupper():
            out.append((k, v.strip().strip("'")))
    return dict(out)
def same(a, b, label):
    ka, kb = keys(a), keys(b)
    missing = sorted(set(ka) ^ set(kb))
    bad = []
    for k in sorted(set(ka) & set(kb)):
        if ka[k].count("%s") != kb[k].count("%s"):
            bad.append(k)
    if missing or bad:
        print(label, "keys", missing, "percent", bad)
        sys.exit(1)
same("ui.en.sh", "ui.ja.sh", "ui")
same("uninstall.en.sh", "uninstall.ja.sh", "uninstall")
PY
check "ja and en catalogs have the same keys and %s counts" '[ $? = 0 ]'
rm -rf "${LH}"

CHROME="${CHROME:-$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)}"
if [ -z "${CHROME}" ]; then echo "SKIP: Chrome が無いため lab スクリプトのテストを省略"; echo "RESULT lab: ${PASS} passed, ${FAIL} failed"; [ "${FAIL}" = 0 ]; exit; fi
command -v lsof >/dev/null 2>&1 || export PATH="${HERE}/bin:${PATH}"
NODE="$(command -v node)"

T="$(mktemp -d "${TMPDIR:-/tmp}/uitr-labtest.XXXXXX")"
if [ -n "${BASH32:-}" ]; then mkdir -p "${T}/b32"; ln -s "${BASH32}" "${T}/b32/bash"; export PATH="${T}/b32:${PATH}"; echo "(lab scripts run with $("${BASH32}" -c 'echo ${BASH_VERSION}'))"; fi
export HOME="${T}/home"; mkdir -p "${HOME}"
KIT="${T}/kit"; mkdir -p "${KIT}"; cp -R "${ROOT}/lab" "${ROOT}/tools" "${ROOT}/locales" "${ROOT}/glossary" "${KIT}/"; : > "${KIT}/.word-to-world-kit"
export SRC_APP="${T}/Applications/Cursor.app"; SRC_BIN="${SRC_APP}/Contents/MacOS/Cursor"
export FAKE_LOG="${T}/fake-cursor.log" FAKE_CHROME_DIR="${T}/fake-chrome"
export QUIT_TIMEOUT=5
mkdir -p "${SRC_APP}/Contents/MacOS"
cat > "${SRC_BIN}" <<FAKE
#!/usr/bin/env bash
# fake Cursor: Node when ELECTRON_RUN_AS_NODE=1; otherwise a headless Chrome page (only when a debug port is given)
if [ "\${ELECTRON_RUN_AS_NODE:-}" = 1 ]; then exec "${NODE}" "\$@"; fi
ud=""; port=""
for a in "\$@"; do case "\$a" in --user-data-dir=*) ud="\${a#*=}" ;; --remote-debugging-port=*) port="\${a#*=}" ;; --remote-debugging-address*) echo "address flag must never be used" >&2; exit 9 ;; esac; done
echo "ARGS: \$*" >> "\${FAKE_LOG}"
trap 'kill \${c:-} 2>/dev/null; wait 2>/dev/null; exit 0' TERM INT
if [ -z "\${port}" ] || [ "\${FAKE_NO_PORT:-}" = 1 ]; then while :; do sleep 1; done; fi
mkdir -p "\${FAKE_CHROME_DIR}"
"${CHROME}" --headless=new --no-sandbox --disable-gpu --no-first-run --user-data-dir="\$(mktemp -d "\${FAKE_CHROME_DIR}/p.XXXXXX")" --remote-debugging-port="\${port}" "file://${ROOT}/tests/fixtures/workbench-glass.html" >/dev/null 2>&1 &
c=\$!
wait \$c
FAKE
chmod +x "${SRC_BIN}"
# fake osascript: 'tell application "Cursor" to quit' -> SIGTERM to Cursor main processes (FAKE_OSA_REFUSE=1: ignore, like a blocked save dialog)
mkdir -p "${T}/osa"; export OSASCRIPT="${T}/osa/osascript"
cat > "${OSASCRIPT}" <<'OSA'
#!/usr/bin/env bash
[ "${FAKE_OSA_REFUSE:-}" = 1 ] && exit 0
case "$*" in *quit*) for p in $(ps -axo pid=,command= | B="${SRC_APP}/Contents/MacOS/Cursor" awk '/inject\.js/||/awk/{next} {l=$0" "} index(l, ENVIRON["B"]" "){print $1}'); do kill -TERM "$p" 2>/dev/null; done ;; esac
OSA
chmod +x "${OSASCRIPT}"
sumdir() { (cd "$1" 2>/dev/null && find . -type f -exec cksum {} + | sort | cksum); }
REAL_SUM="$(sumdir "${SRC_APP}")"
NP="${HOME}/Library/Application Support/Cursor"; mkdir -p "${NP}/User" "${HOME}/.cursor/extensions"
echo '{"chat":"history"}' > "${NP}/User/settings.json"; echo keep > "${HOME}/.cursor/extensions/keep"; echo '{}' > "${HOME}/.cursor/argv.json"
NP_SUM="$(sumdir "${NP}")"; DOT_SUM="$(sumdir "${HOME}/.cursor")"
L="${KIT}/lab"; W="${HOME}/Library/Application Support/word-to-world"; PORT=9461
"${L}/setup-lab.sh" --help > "${T}/help-setup.log" 2>&1; rc=$?
check "setup-lab --help exits 0" '[ ${rc} = 0 ] && grep -q "使い方" "${T}/help-setup.log" && ! grep -q "不明なオプション" "${T}/help-setup.log"'
"${L}/start.sh" -h > "${T}/help-start.log" 2>&1; rc=$?
check "start.sh -h exits 0 and lists --verbose" '[ ${rc} = 0 ] && grep -q "使い方" "${T}/help-start.log" && grep -q -- "--verbose" "${T}/help-start.log" && ! grep -q "不明なオプション" "${T}/help-start.log"'
"${L}/uninstall.sh" --help > "${T}/help-un.log" 2>&1; rc=$?
check "uninstall.sh --help exits 0" '[ ${rc} = 0 ] && grep -q "使い方" "${T}/help-un.log"'
listening() { lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; }
cursor_main() { ps -axo pid=,command= | B="${SRC_BIN}" awk '/inject\.js/||/awk/{next} {l=$0" "} index(l, ENVIRON["B"]" "){print $1}'; }
wait_gone() { for _ in $(seq 1 30); do [ -z "$(cursor_main)" ] && return 0; sleep 0.3; done; return 1; }

# ---------------- normal mode (default)
"${L}/setup-lab.sh" > "${T}/setup.log" 2>&1; rc=$?
check "setup-lab (default) exit 0, mode=normal, no separate profile, no app copy" '[ ${rc} = 0 ] && [ "$(cat "${W}/state/mode")" = normal ] && [ ! -e "${W}/lab-profile" ] && [ ! -e "${W}/Cursor-Lab.app" ]'
check "setup names the usual Cursor" 'grep -qxF "普段の Cursor を、標準プロファイルのまま使います。" "${T}/setup.log" && ! grep -q "いつもの Cursor" "${T}/setup.log"'
check "setup writes the ownership marker into the runtime dir" '[ -f "${W}/.word-to-world-lab" ] && grep -q "owner=word-to-world" "${W}/.word-to-world-lab"'
"${L}/launch-lab.sh" --port ${PORT} < /dev/null > "${T}/consent-notty.log" 2>&1; rc=$?
check "default profile, no consent, no terminal: exit 5 and the debug-port explanation" \
  '[ ${rc} = 5 ] && grep -q "127.0.0.1:${PORT}" "${T}/consent-notty.log" && grep -q "npm install" "${T}/consent-notty.log" && grep -q "他のデバイスからは届きません" "${T}/consent-notty.log"'
check "consent names this device and says other devices cannot connect" \
  'grep -q "AI エージェント" "${T}/consent-notty.log" && grep -q "この端末上のほかのプログラム" "${T}/consent-notty.log" && grep -q "他のデバイスからは届きません" "${T}/consent-notty.log"'
check "redirected consent log has no ANSI color" '! grep -q "$(printf "\033")" "${T}/consent-notty.log"'
echo "" | UI_TR_ASSUME_TTY=1 "${L}/launch-lab.sh" --port ${PORT} > "${T}/consent-enter.log" 2>&1; rc=$?
check "default profile: Enter alone is not consent" '[ ${rc} = 5 ] && [ ! -f "${W}/state/debug-port-consent" ]'
echo yes | UI_TR_ASSUME_TTY=1 "${L}/launch-lab.sh" --port ${PORT} --quit-running > "${T}/consent-yes.log" 2>&1; rc=$?
check "default profile: typing yes records consent and launches" '[ ${rc} = 0 ] && [ "$(cat "${W}/state/debug-port-consent")" = yes ] && grep -q "OK: 127.0.0.1:${PORT}" "${T}/consent-yes.log" && grep -q "だけで待ち受けています" "${T}/consent-yes.log" && grep -q "続ける場合は yes" "${T}/consent-yes.log"'
"${L}/stop.sh" --port ${PORT} > /dev/null 2>&1 || true
wait_gone || true
printf 'yes\n' > "${W}/state/debug-port-consent"
"${SRC_BIN}" > /dev/null 2>&1 &      # the user's everyday Cursor, already running (no debug port)
sleep 0.5
"${L}/launch-lab.sh" --port ${PORT} < /dev/null > "${T}/l1.log" 2>&1; rc=$?
check "Cursor already running + no terminal + no --quit-running -> exit 5, Cursor left running (ja+en message)" '[ ${rc} = 5 ] && [ -n "$(cursor_main)" ] && grep -q "Cursor が起動しています" "${T}/l1.log"'
FAKE_OSA_REFUSE=1 "${L}/launch-lab.sh" --port ${PORT} --quit-running > "${T}/l2.log" 2>&1; rc=$?
check "Cursor refuses to quit -> exit 7, NOT force-killed" '[ ${rc} = 7 ] && [ -n "$(cursor_main)" ] && grep -q "強制終了はしません" "${T}/l2.log"'
: > "${FAKE_LOG}"
"${L}/launch-lab.sh" --port ${PORT} --quit-running > "${T}/l3.log" 2>&1; rc=$?
check "--quit-running: quits normally, relaunches with debug port on 127.0.0.1" '[ ${rc} = 0 ] && grep -q "OK: 127.0.0.1:${PORT}" "${T}/l3.log" && listening'
check "normal mode launches with ONLY --remote-debugging-port (no --user-data-dir/--extensions-dir)" '[ "$(cat "${FAKE_LOG}")" = "ARGS: --remote-debugging-port=${PORT}" ]'
"${L}/apply.sh" --lang xx --port ${PORT} > "${T}/a0.log" 2>&1; rc=$?
check "apply.sh unknown language -> exit 3 (Japanese message)" '[ ${rc} = 3 ] && grep -q "言語レイヤーがありません" "${T}/a0.log"'
"${L}/apply.sh" --lang ja --once --port ${PORT} > "${T}/a1.log" 2>&1; rc=$?
check "apply.sh --once exit 0, human line, no dictionary json" '[ ${rc} = 0 ] && grep -qxF "翻訳を開始しました。" "${T}/a1.log" && ! grep -q "\[i18n\] dictionary:" "${T}/a1.log" && ! grep -q "\[i18n\] injected" "${T}/a1.log"'
"${L}/apply.sh" --lang ja --once --port ${PORT} --verbose > "${T}/a1v.log" 2>&1; rc=$?
check "apply.sh --verbose prints dictionary and injected lines" '[ ${rc} = 0 ] && grep -q "\[i18n\] dictionary:" "${T}/a1v.log" && grep -q "\[i18n\] injected" "${T}/a1v.log"'
"${L}/stop.sh" --port ${PORT} > "${T}/stop.log" 2>&1; rc=$?
check "stop.sh: reverted, Cursor quit normally, port closed" '[ ${rc} = 0 ] && ! listening && wait_gone'
"${L}/apply.sh" --lang ja --once --port ${PORT} > /dev/null 2>&1; rc=$?
check "apply.sh when Cursor not running -> exit 4" '[ ${rc} = 4 ]'

# ---------------- start.sh: one step; ends by itself when the user quits Cursor
"${L}/start.sh" --lang ja --port ${PORT} > "${T}/start.log" 2>&1 &
SP=$!
for _ in $(seq 1 40); do grep -q "翻訳を開始しました。" "${T}/start.log" 2>/dev/null && break; sleep 0.5; done
check "start.sh: launches Cursor and injects" 'grep -qxF "翻訳を開始しました。" "${T}/start.log" && ! grep -q "\[i18n\] dictionary:" "${T}/start.log" && ! grep -q "\[i18n\] injected" "${T}/start.log" && [ -f "${W}/inject.pid" ]'
PID1="$(cat "${W}/inject.pid")"
"${L}/start.sh" --lang ja --port ${PORT} > "${T}/start-again.log" 2>&1; rc=$?
NINJ="$(ps -axo command= | grep -F "tools/inject.js apply" | grep -cvF grep || true)"
check "second start.sh: translator already running, exit 0, no second injector" \
  '[ ${rc} = 0 ] && grep -q "すでに動いています" "${T}/start-again.log" && [ "$(cat "${W}/inject.pid")" = "${PID1}" ] && [ "${NINJ}" = 1 ]'
kill -TERM "${PID1}" 2>/dev/null || true
for _ in $(seq 1 30); do kill -0 ${SP} 2>/dev/null || break; sleep 0.3; done
check "start.sh banner uses the display name from meta.name" 'grep -qxF -- "--- Word to World for Cursor | Japanese Language Layer ---" "${T}/start.log" && grep -qxF "非公式のコミュニティツールです" "${T}/start.log"'
check "start.sh stop hint is its own line, not joined with a slash" 'grep -qxF "終了する場合は、Cursor を終了してください（⌘Q、または Cursor メニューから終了）。" "${T}/start.log" && ! grep -q "非公式のコミュニティツールです / Unofficial" "${T}/start.log"'
echo 999999 > "${W}/inject.pid"
"${L}/start.sh" --verbose --lang ja --port ${PORT} > "${T}/start-stale.log" 2>&1 &
SP=$!
for _ in $(seq 1 40); do grep -q "翻訳を開始しました。" "${T}/start-stale.log" 2>/dev/null && break; sleep 0.5; done
PID2="$(cat "${W}/inject.pid" 2>/dev/null || true)"
check "stale injector pid does not block a new start" \
  'grep -q "翻訳を開始しました。" "${T}/start-stale.log" && grep -q "\[i18n\] dictionary:" "${T}/start-stale.log" && grep -q "\[i18n\] injected" "${T}/start-stale.log" && [ "${PID2}" != 999999 ] && [ -n "${PID2}" ] && kill -0 "${PID2}" 2>/dev/null && ! grep -q "すでに動いています" "${T}/start-stale.log"'
"${OSASCRIPT}" -e 'tell application "Cursor" to quit'      # the user quits Cursor
for _ in $(seq 1 30); do kill -0 ${SP} 2>/dev/null || break; sleep 0.5; done
check "after quitting Cursor: start.sh ended, injector gone, port closed, pid file removed" '! kill -0 ${SP} 2>/dev/null && ! listening && [ ! -f "${W}/inject.pid" ] && [ -z "$(ps -axo command= | grep "tools/inject.js apply" | grep -v grep)" ]'

# ---------------- injector self-exit (no infinite "cannot reach" loop)
"${L}/launch-lab.sh" --port ${PORT} > /dev/null 2>&1
ELECTRON_RUN_AS_NODE=1 "${SRC_BIN}" "${KIT}/tools/inject.js" apply --lang ja --port ${PORT} --exit-after-unreachable 2 > "${T}/inj1.log" 2>&1 &
IP=$!; sleep 2
"${OSASCRIPT}" -e 'tell application "Cursor" to quit'; wait_gone
for _ in $(seq 1 20); do kill -0 ${IP} 2>/dev/null || break; sleep 0.5; done
wait ${IP} 2>/dev/null; rc=$?
check "injector exits by itself (code 0) once the port stays closed" '! kill -0 ${IP} 2>/dev/null && [ ${rc} = 0 ] && grep -q "翻訳を停止しました。" "${T}/inj1.log" && ! grep -q "cannot reach" "${T}/inj1.log" && ! grep -q "Cursor is gone" "${T}/inj1.log"'
"${L}/launch-lab.sh" --port ${PORT} > /dev/null 2>&1
CP="$(cat "${W}/state/cursor.pid")"
ELECTRON_RUN_AS_NODE=1 "${SRC_BIN}" "${KIT}/tools/inject.js" apply --lang ja --port ${PORT} --cursor-pid "${CP}" --exit-after-unreachable 60 --verbose > "${T}/inj2.log" 2>&1 &
IP=$!; sleep 2
"${OSASCRIPT}" -e 'tell application "Cursor" to quit'; wait_gone
for _ in $(seq 1 10); do kill -0 ${IP} 2>/dev/null || break; sleep 0.5; done
check "injector exits as soon as the Cursor PID is gone (--cursor-pid)" '! kill -0 ${IP} 2>/dev/null && grep -q "翻訳を停止しました。" "${T}/inj2.log" && grep -q "Cursor process" "${T}/inj2.log" && grep -q "is gone" "${T}/inj2.log"'
ELECTRON_RUN_AS_NODE=1 "${SRC_BIN}" "${KIT}/tools/inject.js" apply --lang ja --port ${PORT} --wait-start 2 > "${T}/inj3.log" 2>&1; rc=$?
check "injector gives up with exit 4 if Cursor never appears (--wait-start)" \
  '[ ${rc} = 4 ] && grep -q "\[i18n\] Cursor did not become reachable" "${T}/inj3.log"'
ELECTRON_RUN_AS_NODE=1 "${SRC_BIN}" "${KIT}/tools/inject.js" apply --lang ja --port ${PORT} --wait-start 30 > "${T}/inj-term.log" 2>&1 &
IP=$!; sleep 0.4
kill -TERM "${IP}" 2>/dev/null || true
for _ in $(seq 1 20); do kill -0 ${IP} 2>/dev/null || break; sleep 0.2; done
wait ${IP} 2>/dev/null || true
check "SIGTERM revert line is hidden unless --verbose" '! grep -q "SIGTERM: reverting" "${T}/inj-term.log"'
ELECTRON_RUN_AS_NODE=1 "${SRC_BIN}" "${KIT}/tools/inject.js" apply --lang ja --port ${PORT} --wait-start 30 --verbose > "${T}/inj-term-v.log" 2>&1 &
IP=$!; sleep 0.4
kill -TERM "${IP}" 2>/dev/null || true
for _ in $(seq 1 20); do kill -0 ${IP} 2>/dev/null || break; sleep 0.2; done
wait ${IP} 2>/dev/null || true
check "SIGTERM revert line is shown with --verbose" 'grep -q "SIGTERM: reverting" "${T}/inj-term-v.log"'

# ---------------- separate-profile mode (optional)
"${SRC_BIN}" > /dev/null 2>&1 &       # everyday Cursor running: must NOT be quit in this mode
sleep 0.5; : > "${FAKE_LOG}"
"${L}/setup-lab.sh" --separate-profile > "${T}/setup2.log" 2>&1
check "separate-profile setup names the usual Cursor.app" 'grep -qxF "普段の Cursor.app を、別プロファイルで起動します。" "${T}/setup2.log"'
rm -f "${W}/state/debug-port-consent"
"${L}/launch-lab.sh" --port ${PORT} --lang ja > "${T}/l4.log" 2>&1; rc=$?
check "separate profile: launches next to the running Cursor with --user-data-dir/--extensions-dir/--locale=ja" '[ ${rc} = 0 ] && grep -q -- "--user-data-dir=${W}/lab-profile --extensions-dir=${W}/lab-extensions --remote-debugging-port=${PORT} --locale=ja" "${FAKE_LOG}" && [ "$(cursor_main | wc -l)" -ge 2 ]'
"${L}/stop.sh" --port ${PORT} > "${T}/stop2.log" 2>&1; rc=$?
check "separate profile: stop.sh quits only its own Cursor" '[ ${rc} = 0 ] && ! listening && [ "$(cursor_main | wc -l)" -eq 1 ]'
kill -TERM $(cursor_main) 2>/dev/null; wait_gone

# ---------------- uninstall
"${L}/setup-lab.sh" --normal > /dev/null 2>&1
printf 'yes\n' > "${W}/state/debug-port-consent"
"${L}/launch-lab.sh" --port ${PORT} > /dev/null 2>&1        # running, so uninstall has to quit it
printf '%s\t%s\n' "${SRC_APP}" "evil" "${HOME}/.cursor" "evil" "${HOME}" "evil" "${NP}" "evil" >> "${W}/install-manifest.txt"
PROBE="${TMPDIR:-/tmp}/i18n-probe-test-$$.js"; echo x > "${PROBE}"
STRAY="${TMPDIR:-/tmp}/i18n-probe-stray-$$.js"; echo stray > "${STRAY}"
printf '%s\trecorded probe\n' "${PROBE}" >> "${W}/install-manifest.txt"
mkdir -p "${HOME}/cursor-i18n-work/lab-profile"; echo x > "${HOME}/cursor-i18n-work/inject.pid"   # legacy prototype folder
mkdir -p "${HOME}/unrelated"; echo keep > "${HOME}/unrelated/keep"
BAK1="${HOME}/ui-translator-kit-0.3.1.bak"; mkdir -p "${BAK1}/lab"; : > "${BAK1}/.cursor-i18n-kit"          # backup of an older kit (marked with old marker)
BAK2="${HOME}/ui-translator-kit-mine.bak"; mkdir -p "${BAK2}"; echo mine > "${BAK2}/notes.txt"               # same name pattern, not a kit
ln -s "${TMPDIR:-/tmp}" "${T}/tmplink"     # a second name for the temp folder (like /tmp vs /private/tmp on macOS)
printf '%s\trecorded probe alias\n' "${T}/tmplink/$(basename "${PROBE}")" >> "${W}/install-manifest.txt"
TMPDIR="${T}/tmplink" "${L}/uninstall.sh" --dry-run --port ${PORT} > "${T}/dry.log" 2>&1; rc=$?
check "uninstall --dry-run exit 0, deletes and stops nothing" '[ ${rc} = 0 ] && [ -d "${W}" ] && [ -f "${PROBE}" ] && [ -f "${STRAY}" ] && listening'
check "uninstall title uses the display name from meta.name" 'grep -q "Word to World for Cursor | Japanese Language Layer（非公式）のアンインストール" "${T}/dry.log"'
check "dry-run lists work folder, kit, and the recorded probe only" 'grep -q "${W}" "${T}/dry.log" && grep -q -- "- ${KIT}" "${T}/dry.log" && grep -q "${PROBE}" "${T}/dry.log" && ! grep -q "${STRAY}" "${T}/dry.log"'
check "same recorded temp file under two names is listed once" '[ "$(grep -c "i18n-probe-test-$$" "${T}/dry.log")" = 1 ]'
check "legacy ~/cursor-i18n-work NOT in the delete list by default (ja + en note about --include-legacy-lab)" '! grep -q -- "  - ${HOME}/cursor-i18n-work" "${T}/dry.log" && grep -q "include-legacy-lab" "${T}/dry.log" && grep -q "削除しません" "${T}/dry.log"'
check "dry-run refuses unsafe manifest entries (app, ~/.cursor, HOME, default profile)" 'grep -q "× ${SRC_APP}" "${T}/dry.log" && grep -q "× ${HOME}/.cursor" "${T}/dry.log" && grep -q "× ${HOME}\$" "${T}/dry.log" && grep -q "× ${NP}" "${T}/dry.log"'
check "kit backups (~/ui-translator-kit*.bak) listed as NOT removed by default (ja + en), not in the delete list" 'grep -q "  · ${BAK1}" "${T}/dry.log" && grep -q "include-backups" "${T}/dry.log" && grep -q "退避フォルダー" "${T}/dry.log" && ! grep -q -- "  - ${BAK1}" "${T}/dry.log"'
check "uninstall messages are Japanese only" 'grep -q "削除するもの" "${T}/dry.log" && ! grep -q "Will delete" "${T}/dry.log"'
echo no | UNINSTALL_ASSUME_TTY=1 "${L}/uninstall.sh" --port ${PORT} > "${T}/cancel.log" 2>&1; rc=$?
check "answer other than yes -> cancelled (exit 5), nothing changed" '[ ${rc} = 5 ] && [ -d "${W}" ] && grep -q "取り消しました" "${T}/cancel.log"'
"${L}/uninstall.sh" --port ${PORT} < /dev/null > "${T}/notty.log" 2>&1; rc=$?
check "no terminal and no --yes -> refuses (exit 5)" '[ ${rc} = 5 ] && [ -d "${W}" ]'
echo yes | UNINSTALL_ASSUME_TTY=1 "${L}/uninstall.sh" --port ${PORT} > "${T}/un.log" 2>&1; rc=$?
check "typed yes: exit 0 with verification message (ja + en)" '[ ${rc} = 0 ] && grep -q "何も残っていません" "${T}/un.log" && ! grep -q "nothing this tool created remains" "${T}/un.log"'
check "work folder, kit, recorded probe removed; untracked probe and legacy folder kept" '[ ! -e "${W}" ] && [ ! -e "${KIT}" ] && [ ! -e "${PROBE}" ] && [ -f "${STRAY}" ] && [ -f "${HOME}/cursor-i18n-work/inject.pid" ] && [ -f "${BAK1}/.cursor-i18n-kit" ] && [ -f "${BAK2}/notes.txt" ]'
check "Cursor quit normally by uninstall, port closed" '! listening && wait_gone'
check "Cursor.app byte-identical" '[ "$(sumdir "${SRC_APP}")" = "${REAL_SUM}" ]'
check "default profile (Application Support/Cursor, ~/.cursor incl. argv.json) byte-identical; unrelated files kept" '[ "$(sumdir "${NP}")" = "${NP_SUM}" ] && [ "$(sumdir "${HOME}/.cursor")" = "${DOT_SUM}" ] && [ -f "${HOME}/unrelated/keep" ]'

KIT2="${T}/kit2"; mkdir -p "${KIT2}"; cp -R "${ROOT}/lab" "${ROOT}/tools" "${ROOT}/locales" "${KIT2}/"; : > "${KIT2}/.word-to-world-kit"
"${KIT2}/lab/setup-lab.sh" > /dev/null 2>&1
mkdir -p "${W}/logs"; echo log > "${W}/logs/keep.log"
"${KIT2}/lab/uninstall.sh" --yes --keep "${W}/logs/" > "${T}/un2.log" 2>&1; rc=$?
check "--yes works without a terminal; --keep keeps that path (and its parent folder), removes the rest" \
  '[ ${rc} = 0 ] && [ ! -e "${KIT2}" ] && [ -f "${W}/logs/keep.log" ] && [ ! -e "${W}/state" ] && [ ! -e "${W}/install-manifest.txt" ] && grep -Fq -- "= ${W}" "${T}/un2.log" && grep -q "残す指定をしたものを除き、削除が完了しました" "${T}/un2.log" && ! grep -q "何も残っていません" "${T}/un2.log"'
DEV="${T}/devrepo"; mkdir -p "${DEV}/.git"; cp -R "${ROOT}/lab" "${ROOT}/tools" "${ROOT}/locales" "${DEV}/"; : > "${DEV}/.word-to-world-kit"
"${DEV}/lab/setup-lab.sh" > "${T}/un3-setup.log" 2>&1; rc=$?
"${DEV}/lab/uninstall.sh" --yes > "${T}/un3.log" 2>&1
check "git working copy (developer checkout) is never deleted" '[ -d "${DEV}/lab" ] && [ -f "${W}/logs/keep.log" ]'
check "setup does not re-stamp a runtime dir left after --keep" '[ ${rc} = 6 ] && [ ! -f "${W}/.word-to-world-lab" ] && ! grep -q "  - ${W}" "${T}/un3.log"'
"${DEV}/lab/uninstall.sh" --yes --include-legacy-lab > "${T}/un4.log" 2>&1; rc=$?
check "--include-legacy-lab removes the legacy folder, with a warning (ja + en)" '[ ${rc} = 0 ] && [ ! -e "${HOME}/cursor-i18n-work" ] && grep -q "注意: --include-legacy-lab" "${T}/un4.log"'
"${DEV}/lab/uninstall.sh" --yes --include-backups > "${T}/un5.log" 2>&1; rc=$?
check "--include-backups removes the marked kit backup only; an unmarked *.bak folder is refused and kept" '[ ${rc} = 0 ] && [ ! -e "${BAK1}" ] && [ -f "${BAK2}/notes.txt" ] && grep -q "× ${BAK2}" "${T}/un5.log" && [ -d "${DEV}/lab" ]'
UI_TR_LANG=en "${DEV}/lab/uninstall.sh" --dry-run > "${T}/en.log" 2>&1
check "UI_TR_LANG=en prints English only" 'grep -q "Nothing to delete\|Will delete" "${T}/en.log" && ! grep -q "削除するもの" "${T}/en.log"'

# ---------------- a clone at the old default path (~/word-to-world) must survive
CLONE="${HOME}/word-to-world"
rm -rf "${CLONE}"
mkdir -p "${CLONE}"
cp -R "${ROOT}/lab" "${ROOT}/tools" "${ROOT}/locales" "${CLONE}/"
mkdir -p "${CLONE}/.git"
echo sentinel > "${CLONE}/KEEP_ME.txt"
: > "${CLONE}/.word-to-world-kit"
"${CLONE}/lab/uninstall.sh" --dry-run > "${T}/clone-dry.log" 2>&1; rc=$?
check "clone at old ~/word-to-world: dry-run does not list the clone for deletion" '[ ${rc} = 0 ] && ! grep -q "  - ${CLONE}" "${T}/clone-dry.log" && [ -f "${CLONE}/KEEP_ME.txt" ] && [ -d "${CLONE}/.git" ]'
"${CLONE}/lab/uninstall.sh" --yes > "${T}/clone-yes.log" 2>&1; rc=$?
check "clone at old ~/word-to-world: real uninstall leaves the clone in place" '[ -f "${CLONE}/KEEP_ME.txt" ] && [ -d "${CLONE}/.git" ] && [ -d "${CLONE}/lab" ]'
LAB_DIR="${CLONE}" "${CLONE}/lab/uninstall.sh" --dry-run > "${T}/clone-labdir-dry.log" 2>&1; rc=$?
check "LAB_DIR pointed at the clone: dry-run does not list the clone for deletion" '[ ${rc} = 0 ] && ! grep -q "  - ${CLONE}" "${T}/clone-labdir-dry.log" && [ -f "${CLONE}/KEEP_ME.txt" ]'
LAB_DIR="${CLONE}" "${CLONE}/lab/uninstall.sh" --yes > "${T}/clone-labdir-yes.log" 2>&1; rc=$?
check "LAB_DIR pointed at the clone: real uninstall leaves the clone in place" '[ -f "${CLONE}/KEEP_ME.txt" ] && [ -d "${CLONE}/.git" ] && [ -f "${CLONE}/lab/uninstall.sh" ]'
LAB_DIR="${CLONE}" "${CLONE}/lab/setup-lab.sh" > "${T}/clone-setup.log" 2>&1; rc=$?
check "setup refuses to create lab-profile, logs, state or Cursor-Lab.app inside a git work tree" '[ ${rc} = 6 ] && [ ! -e "${CLONE}/lab-profile" ] && [ ! -e "${CLONE}/logs" ] && [ ! -e "${CLONE}/state" ] && [ ! -e "${CLONE}/Cursor-Lab.app" ] && [ -f "${CLONE}/KEEP_ME.txt" ]'
UNMARKED="${HOME}/plain-folder"; mkdir -p "${UNMARKED}/logs"; echo mine > "${UNMARKED}/logs/mine.txt"
LAB_DIR="${UNMARKED}" "${CLONE}/lab/uninstall.sh" --dry-run --keep-kit > "${T}/unmarked-dry.log" 2>&1; rc=$?
check "a runtime path with no ownership marker is not listed for deletion" '[ ${rc} = 0 ] && ! grep -q "  - ${UNMARKED}" "${T}/unmarked-dry.log"'
LAB_DIR="${UNMARKED}" "${CLONE}/lab/uninstall.sh" --yes --keep-kit > "${T}/unmarked-yes.log" 2>&1; rc=$?
check "a runtime path with no ownership marker survives a real uninstall" '[ -f "${UNMARKED}/logs/mine.txt" ]'

# ---------------- ownership: pre-existing dirs, nested .git, ~/.git, missing paths, foreign port
rm -rf "${W}"
mkdir -p "${W}"; echo keep-default > "${W}/user-file.txt"
"${DEV}/lab/setup-lab.sh" > "${T}/pre-default.log" 2>&1; rc=$?
check "setup refuses a pre-existing non-empty default runtime dir" '[ ${rc} = 6 ] && [ -f "${W}/user-file.txt" ] && [ ! -f "${W}/.word-to-world-lab" ]'
rm -rf "${W}"
BUSY="${T}/busy-lab"; mkdir -p "${BUSY}"; echo mine > "${BUSY}/notes.txt"
LAB_DIR="${BUSY}" "${DEV}/lab/setup-lab.sh" > "${T}/pre-env.log" 2>&1; rc=$?
check "setup refuses a pre-existing non-empty LAB_DIR given by the environment" '[ ${rc} = 6 ] && [ -f "${BUSY}/notes.txt" ] && [ ! -f "${BUSY}/.word-to-world-lab" ]'
EMPTY="${T}/empty-lab"; mkdir -p "${EMPTY}"
LAB_DIR="${EMPTY}" "${DEV}/lab/setup-lab.sh" > "${T}/adopt.log" 2>&1; rc=$?
check "setup adopts a pre-existing empty dir and records created-by" '[ ${rc} = 0 ] && grep -q "created-by=lab/setup-lab.sh" "${EMPTY}/.word-to-world-lab" && grep -q "adopted-empty=1" "${EMPTY}/.word-to-world-lab" && grep -q "reason=pre-existing-empty" "${EMPTY}/state/adopted-empty-dir" && [ -d "${EMPTY}/logs" ]'
DANGLE="${T}/dangle-lab"; mkdir -p "${DANGLE}"; ln -s "${T}/missing-target" "${DANGLE}/gone"
LAB_DIR="${DANGLE}" "${DEV}/lab/setup-lab.sh" > "${T}/dangle.log" 2>&1; rc=$?
check "a directory with only a dangling symlink is not treated as empty" '[ ${rc} = 6 ] && [ ! -f "${DANGLE}/.word-to-world-lab" ] && [ -L "${DANGLE}/gone" ]'
echo photo > "${EMPTY}/photo.jpg"
LAB_DIR="${EMPTY}" "${DEV}/lab/uninstall.sh" --dry-run --keep-kit > "${T}/adopt-dry.log" 2>&1; rc=$?
check "an adopted empty dir is kept, and is not listed for full deletion" '[ ${rc} = 0 ] && ! grep -q "  - ${EMPTY}  " "${T}/adopt-dry.log" && grep -q "  = ${EMPTY}" "${T}/adopt-dry.log" && [ -f "${EMPTY}/photo.jpg" ]'
LAB_DIR="${EMPTY}" "${DEV}/lab/uninstall.sh" --yes --keep-kit > "${T}/adopt-yes.log" 2>&1; rc=$?
check "uninstall of an adopted dir removes only what setup created" '[ ${rc} = 0 ] && [ -d "${EMPTY}" ] && [ -f "${EMPTY}/photo.jpg" ] && [ ! -e "${EMPTY}/.word-to-world-lab" ] && [ ! -e "${EMPTY}/state" ] && [ ! -e "${EMPTY}/logs" ]'
NEST="${T}/nest-lab"; mkdir -p "${NEST}/project"; echo 'gitdir: /somewhere' > "${NEST}/project/.git"; echo keep > "${NEST}/project/KEEP"
printf 'owner=word-to-world\ncreated-by=lab/setup-lab.sh\n' > "${NEST}/.word-to-world-lab"
LAB_DIR="${NEST}" "${DEV}/lab/uninstall.sh" --dry-run --keep-kit > "${T}/nest-dry.log" 2>&1; rc=$?
check "uninstall dry-run does not list a runtime dir that contains a nested .git" '[ ${rc} = 0 ] && ! grep -q "  - ${NEST}  " "${T}/nest-dry.log" && [ -f "${NEST}/project/KEEP" ]'
LAB_DIR="${NEST}" "${DEV}/lab/uninstall.sh" --yes --keep-kit > "${T}/nest-yes.log" 2>&1; rc=$?
check "uninstall refuses a runtime dir that contains a nested .git file" '[ -f "${NEST}/project/.git" ] && [ -f "${NEST}/project/KEEP" ]'
DOTHOME="${T}/dothome"; mkdir -p "${DOTHOME}/.git"; echo dotfiles > "${DOTHOME}/.git/config"
HOME="${DOTHOME}" "${DEV}/lab/setup-lab.sh" > "${T}/dotgit.log" 2>&1; rc=$?
check "setup runs when HOME itself has .git" '[ ${rc} = 0 ] && [ -f "${DOTHOME}/Library/Application Support/word-to-world/.word-to-world-lab" ] && ! grep -q "git work tree" "${T}/dotgit.log"'
rm -rf "${W}"
"${DEV}/lab/uninstall.sh" --dry-run --keep-kit > "${T}/second-dry.log" 2>&1; rc=$?
check "second dry-run omits a runtime dir that does not exist" '[ ${rc} = 0 ] && ! grep -F "${W}" "${T}/second-dry.log"'

"${DEV}/lab/setup-lab.sh" > "${T}/foreign-setup.log" 2>&1
FOREIGN=9471
node -e 'require("net").createServer(function(){}).listen(Number(process.argv[1]), "127.0.0.1")' "${FOREIGN}" >/dev/null 2>&1 &
FP=$!
sleep 0.3
rm -f "${W}/state/debug-port-consent"
"${DEV}/lab/start.sh" --lang ja --port ${FOREIGN} < /dev/null > "${T}/foreign-consent.log" 2>&1; rc=$?
check "an open port does not skip normal-profile consent" '[ ${rc} = 5 ] && grep -q "127.0.0.1:${FOREIGN}" "${T}/foreign-consent.log" && grep -q "続ける場合は yes" "${T}/foreign-consent.log" && [ ! -f "${W}/state/debug-port-consent" ]'
printf 'yes\n' > "${W}/state/debug-port-consent"
"${DEV}/lab/launch-lab.sh" --port ${FOREIGN} > "${T}/foreign-own.log" 2>&1; rc=$?
check "a listener that is not the recorded Cursor is refused" '[ ${rc} = 6 ] && grep -q "接続しません" "${T}/foreign-own.log" && grep -q "Cursor を終了してください" "${T}/foreign-own.log" && ! grep -q "Not attaching" "${T}/foreign-own.log"'
"${DEV}/lab/apply.sh" --lang ja --once --port ${FOREIGN} > "${T}/foreign-apply.log" 2>&1; rc=$?
check "apply.sh refuses a listener that is not the recorded Cursor" '[ ${rc} = 6 ] && grep -q "接続しません" "${T}/foreign-apply.log" && ! grep -q "Please quit Cursor" "${T}/foreign-apply.log"'
kill "${FP}" 2>/dev/null || true
wait "${FP}" 2>/dev/null || true
printf 'yes\n' > "${W}/state/debug-port-consent"
"${DEV}/lab/launch-lab.sh" --port ${PORT} > "${T}/own1.log" 2>&1; rc=$?
check "first launch records a Cursor listening on 127.0.0.1" '[ ${rc} = 0 ] && grep -q "127.0.0.1:${PORT}" "${T}/own1.log"'
"${DEV}/lab/launch-lab.sh" --port ${PORT} > "${T}/own2.log" 2>&1; rc=$?
check "recorded Cursor on 127.0.0.1 is accepted on a second launch" '[ ${rc} = 0 ] && grep -q "既に起動しています" "${T}/own2.log"'
CHILD="$(lsof -nP -iTCP:${PORT} -sTCP:LISTEN | awk 'NR>1 { print $2; exit }')"
REC="$(tr -cd '0-9' < "${W}/state/cursor.pid")"
check "the listener is a child of the recorded Cursor" '[ -n "${CHILD}" ] && [ "${CHILD}" != "${REC}" ]'
cat > "${T}/lsof-child" <<EOF
#!/bin/sh
echo "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME"
echo "chrome ${CHILD} user 1u IPv4 TCP 127.0.0.1:${PORT} (LISTEN)"
exit 0
EOF
cat > "${T}/lsof-mixed" <<EOF
#!/bin/sh
echo "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME"
echo "chrome ${CHILD} user 1u IPv4 TCP 127.0.0.1:${PORT} (LISTEN)"
echo "other $$ user 1u IPv4 TCP 127.0.0.1:${PORT} (LISTEN)"
exit 0
EOF
cat > "${T}/lsof-public" <<EOF
#!/bin/sh
echo "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME"
echo "chrome ${CHILD} user 1u IPv4 TCP 0.0.0.0:${PORT} (LISTEN)"
exit 0
EOF
chmod +x "${T}/lsof-child" "${T}/lsof-mixed" "${T}/lsof-public"
LSOF="${T}/lsof-child" "${DEV}/lab/launch-lab.sh" --port ${PORT} > "${T}/own-child.log" 2>&1; rc=$?
check "a child-process listener on 127.0.0.1 is accepted" '[ ${rc} = 0 ] && grep -q "既に起動しています" "${T}/own-child.log"'
LSOF="${T}/lsof-mixed" "${DEV}/lab/launch-lab.sh" --port ${PORT} > "${T}/own-mixed.log" 2>&1; rc=$?
check "a mixed listener with an unrelated pid is refused" '[ ${rc} = 6 ] && grep -q "接続しません" "${T}/own-mixed.log"'
LSOF="${T}/lsof-public" "${DEV}/lab/launch-lab.sh" --port ${PORT} > "${T}/own-public.log" 2>&1; rc=$?
check "a listener that is not on 127.0.0.1 is refused" '[ ${rc} = 6 ] && grep -q "接続しません" "${T}/own-public.log"'
unset LSOF
listening || { echo "real listener disappeared"; }
"${DEV}/lab/setup-lab.sh" --separate-profile --no-langpack > "${T}/mode-switch.log" 2>&1
"${DEV}/lab/launch-lab.sh" --port ${PORT} > "${T}/mode-mismatch.log" 2>&1; rc=$?
check "a normal-profile session is not reused for --separate-profile" '[ ${rc} = 6 ] && grep -q "接続しません" "${T}/mode-mismatch.log" && listening && [ "$(cat "${W}/state/session" | sed -n "s/^mode=//p")" = normal ] && [ "$(cat "${W}/state/mode")" = separate ]'
FAKE_OSA_REFUSE=1 "${DEV}/lab/uninstall.sh" --yes --keep-kit --port ${PORT} > "${T}/refuse-quit.log" 2>&1; rc=$?
check "uninstall stops when Cursor refuses to quit, and keeps the work folder" '[ ${rc} = 1 ] && [ -d "${W}" ] && [ -f "${W}/state/session" ] && listening && grep -q "作業フォルダーは削除しません" "${T}/refuse-quit.log"'
unset FAKE_OSA_REFUSE
"${DEV}/lab/stop.sh" --port ${PORT} > /dev/null 2>&1 || true
wait_gone || true
kill -TERM $(cursor_main) 2>/dev/null || true
wait_gone || true
FAKE_NO_PORT=1 PORT_WAIT=1 "${DEV}/lab/launch-lab.sh" --port ${PORT} > "${T}/noport.log" 2>&1; rc=$?
check "a port that never opens is exit 4, not an ownership failure" '[ ${rc} = 4 ] && grep -q "開きませんでした" "${T}/noport.log" && ! grep -q "接続しません" "${T}/noport.log"'
unset FAKE_NO_PORT
kill -TERM $(cursor_main) 2>/dev/null || true
wait_gone || true
printf 'normal\n' > "${W}/state/mode"
rm -f "${W}/state/debug-port-consent"
UI_TR_LANG=en "${DEV}/lab/launch-lab.sh" --port ${PORT} < /dev/null > "${T}/en-consent.log" 2>&1; rc=$?
check "English UI: consent is English only" \
  '[ ${rc} = 5 ] && grep -q "any other program on this device" "${T}/en-consent.log" && grep -q "Type yes to continue." "${T}/en-consent.log" && ! grep -q "この端末上のほかのプログラム" "${T}/en-consent.log"'
rm -rf "${T}"
echo "RESULT lab: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" = 0 ]
