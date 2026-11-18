#!/usr/bin/env bash
# 共通設定（各スクリプトから source される）。単体では実行しない。
# macOS 標準の bash 3.2 で動くように書いている。
#   注意: bash 3.2 では「$変数」の直後に日本語などの文字が続くと変数名の一部と誤解される。
#         文字列の中の変数は必ず ${変数} と波かっこで書く（tests/test-shell-lint.sh が検査する）。
#
# 終了コード（全スクリプト共通。将来のダブルクリック用アプリはこれで結果を判断する）
#   0 成功 / 1 失敗（理由は日本語で表示） / 2 使い方の誤り / 3 言語レイヤーが無い・壊れている
#   4 Cursor のデバッグポートにつながらない / 5 ユーザーが取り消した / 6 安全のため中止
#   7 起動中の Cursor が終了しなかった（強制終了はしない）
set -euo pipefail

# 作業フォルダー（ツールが作る物はすべてここ。例外は uninstall.sh が把握する一時ファイルだけ）
# macOS のアプリ用データ置き場。~/word-to-world は README どおりのクローン先と重なるので使わない。
LAB_DIR="${LAB_DIR:-${HOME}/Library/Application Support/word-to-world}"
# 対応する言語 ID（vscode-loc と同じ小文字）。今ある言語レイヤーは ja だけ。
# ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl
LEGACY_LAB_DIR="${HOME}/cursor-i18n-work"         # 試作版が使っていた場所（uninstall.sh が片付ける）
LAB_APP="${LAB_APP:-${LAB_DIR}/Cursor-Lab.app}"   # コピーモードでだけ使う実験用コピー
LAB_PROFILE="${LAB_DIR}/lab-profile"              # 別プロファイルモードのユーザーデータ
LAB_EXT="${LAB_DIR}/lab-extensions"               # 別プロファイルモードの拡張機能フォルダー
PID_FILE="${LAB_DIR}/inject.pid"
STATE_DIR="${LAB_DIR}/state"                      # 使用中のポート番号・起動モードなど
LOG_DIR="${LAB_DIR}/logs"
MANIFEST="${LAB_DIR}/install-manifest.txt"        # このツールが作った物の一覧（uninstall.sh が使う）
LAB_MARKER="${LAB_DIR}/.word-to-world-lab"         # 「このフォルダーはツールが作った」印
DEFAULT_PORT=9333
SRC_APP="${SRC_APP:-/Applications/Cursor.app}"    # インストール済みの Cursor（読むだけ・書き換えない）
SRC_BIN="${SRC_APP}/Contents/MacOS/Cursor"
OSASCRIPT="${OSASCRIPT:-/usr/bin/osascript}"
QUIT_TIMEOUT="${QUIT_TIMEOUT:-60}"                 # Cursor の終了を待つ秒数（保存確認などに答える時間）

# 起動モード（state/mode に記録。環境変数 UI_TR_MODE でも指定可）
#   setup でモードのフラグを省略すると、ここに記録された前回のモードを使う。記録が無ければ normal。
#   --normal は標準プロファイルを明示する。
#   normal（既定）: 普段の Cursor を、標準プロファイル（チャット履歴・設定・拡張機能）のまま起動し、
#                   デバッグポートだけ付ける。標準プロファイルには何も書き込まない
#   separate      : 普段の Cursor.app を、別プロファイル（${LAB_PROFILE}）で起動する
#   copy          : 実験用コピー（Cursor-Lab.app）を別プロファイルで起動する（開発者の実験用）
MODE="${UI_TR_MODE:-$(cat "${STATE_DIR}/mode" 2>/dev/null || echo normal)}"
case "${MODE}" in direct) MODE=separate ;; normal|separate|copy) : ;; *) MODE=normal ;; esac
set_mode() {
  MODE="$1"
  if [ "${MODE}" = copy ]; then LAB_BIN="${LAB_APP}/Contents/MacOS/Cursor"; else LAB_BIN="${SRC_BIN}"; fi
}
set_mode "${MODE}"

# このキット（lab/ の親フォルダー）。tools/ と locales/ がここにある
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
LSOF="${LSOF:-$(command -v lsof 2>/dev/null || echo /usr/sbin/lsof)}"

# 色は標準出力が端末のときだけ。NO_COLOR がセットされていれば（空でも）付けない。TERM=dumb も付けない。
# https://no-color.org  ログ・パイプ・テストは無色のまま。
use_color() {
  [ -t 1 ] || return 1
  [ -z "${NO_COLOR+x}" ] || return 1
  [ "${TERM:-}" != "dumb" ] || return 1
  return 0
}
paint() { # $1=SGR $2=text。無色のときは文字だけ。
  if use_color; then printf '\033[%sm%s\033[0m\n' "$1" "$2"; else printf '%s\n' "$2"; fi
}
say() {
  case "$*" in
    OK:*) paint '1;32' "$*" ;;
    *) printf '%s\n' "$*" ;;
  esac
}
say_bold() { paint '1' "$*"; }
say_hot()  { paint '1;31' "$*"; }
say_prompt() { # 太字・改行なし（yes の入力待ち）
  if use_color; then printf '\033[1m%s\033[0m' "$*"; else printf '%s' "$*"; fi
}
fail() { # 接頭辞は表示言語。台帳を読む前は Error。
  local code="${2:-1}" prefix
  prefix="$(text_k FAIL_PREFIX 2>/dev/null || true)"
  case "${prefix}" in ""|FAIL_PREFIX) prefix="Error" ;; esac
  printf '%s\n' "${prefix}: ${1}" >&2
  exit "${code}"
}

# 表示名。言語の部分は locales/<id>.json の meta.name（英語の言語名）。
# Word to World for Cursor | <meta.name> Language Layer
display_name() {
  local file="$1" name
  [ -f "${file}" ] || return 1
  name="$(awk -F'"' '/^[[:space:]]*"name": / { print $4; exit }' "${file}")"
  [ -n "${name}" ] || return 1
  printf 'Word to World for Cursor | %s Language Layer\n' "${name}"
}

# 本物の Cursor・標準プロファイルには書き込まないためのガード（コピーモードのコピー先の確認）
guard_not_real_app() {
  local target="$1" resolved
  if [ -e "${target}" ]; then resolved="$(cd "${target}" && pwd -P)"; else resolved="${target}"; fi
  case "${resolved}" in
    /Applications/*|/System/*|"${HOME}/Applications/"*)
      fail_k 6 FAIL_APP_PATH "${resolved}" "${LAB_DIR}" ;;
  esac
  case "${resolved}" in
    "${LAB_DIR}"/*) : ;;
    *) fail_k 6 FAIL_OUTSIDE "${resolved}" "${LAB_DIR}" ;;
  esac
}

# パス自身か、その親に .git があるか。親は $HOME の手前で止める。
# ~/.git（ドットファイル用）だけでは作業フォルダーを止めない。
# パス自身の .git、キット自身の .git、フォルダーの中の .git は、こことは別に拒否する。
# 見つかった .git のパスを表示する。無ければ何も出さず 1。
git_work_tree_hit() {
  local d="${1%/}" home next
  home="${HOME%/}"
  [ -n "${d}" ] || return 1
  while [ -n "${d}" ] && [ "${d}" != "/" ]; do
    [ "${d}" = "${home}" ] && return 1
    if [ -e "${d}/.git" ]; then printf '%s\n' "${d}/.git"; return 0; fi
    next="$(dirname -- "${d}")"
    [ "${next}" = "${d}" ] && return 1
    d="${next}"
  done
  return 1
}
in_git_work_tree() { git_work_tree_hit "$1" >/dev/null; }

# $1 の中（直下の .git は除く）に .git というファイルかディレクトリがある
dir_contains_nested_git() {
  local p="$1" hit
  [ -d "${p}" ] || return 1
  hit="$(find "${p}" -mindepth 2 -name .git -print 2>/dev/null | head -n 1 || true)"
  [ -n "${hit}" ]
}

guard_lab_dir() {
  local support="${HOME}/Library/Application Support/word-to-world"
  case "${LAB_DIR}" in
    ""|/|"${HOME}"|"${HOME}/"|/Applications*|/System*|/Library*|/usr*|"${HOME}/.cursor"*)
      fail_k 6 FAIL_LAB_DANGEROUS "${LAB_DIR}" ;;
  esac
  # ~/Library は普段の Cursor のデータがあるので、このツールの作業フォルダー以外は拒否する
  case "${LAB_DIR}" in
    "${HOME}/Library"|"${HOME}/Library/"|"${HOME}/Library/Application Support"|"${HOME}/Library/Application Support/"|"${HOME}/Library/Application Support/Cursor"|"${HOME}/Library/Application Support/Cursor"/*)
      fail_k 6 FAIL_LAB_DANGEROUS "${LAB_DIR}" ;;
    "${HOME}/Library"/*)
      case "${LAB_DIR}" in
        "${support}"|"${support}"/*) : ;;
        *) fail_k 6 FAIL_LAB_DANGEROUS "${LAB_DIR}" ;;
      esac
      ;;
  esac
}

# lab-profile / logs / state / Cursor-Lab.app は git の作業ツリーの中に作らない
guard_not_in_git() {
  local hit
  hit="$(git_work_tree_hit "${LAB_DIR}" || true)"
  if [ -n "${hit}" ]; then
    fail_k 6 FAIL_GIT_TREE "${LAB_DIR}" "${hit}"
  fi
}

# 起動したときの記録（頼まれたモード state/mode とは別）。再利用はこれと一致するときだけ。
SESSION_FILE="${STATE_DIR}/session"
requested_profile() {
  if [ "${MODE}" = normal ]; then printf '%s\n' normal; else printf '%s\n' "${LAB_PROFILE}"; fi
}
session_field() {
  [ -f "${SESSION_FILE}" ] || return 1
  sed -n "s/^${1}=//p" "${SESSION_FILE}" | head -n 1
}
write_session() { # $1=port $2=pid
  mkdir -p "${STATE_DIR}"
  printf 'mode=%s\nport=%s\npid=%s\nbinary=%s\nprofile=%s\n' \
    "${MODE}" "$1" "$2" "${LAB_BIN}" "$(requested_profile)" > "${SESSION_FILE}"
}
# 記録したセッションの Cursor が、このポートを 127.0.0.1 だけで待っているか。
# 待ち受けの行はすべて、127.0.0.1 で、記録した PID かその子孫であること。1 つでも違う行があれば拒否する。
# モード・プロファイル・実行ファイル・ポートが、今頼まれているものと全部一致するときだけ再利用する。
listener_owned_by_us() {
  local port="$1" pid rec cmd listen line lpid saw=0 smode sbin sprof
  [ -f "${SESSION_FILE}" ] || return 1
  smode="$(session_field mode || true)"
  sbin="$(session_field binary || true)"
  sprof="$(session_field profile || true)"
  rec="$(session_field port || true)"
  pid="$(session_field pid || true)"
  [ "${smode}" = "${MODE}" ] || return 1
  [ "${rec}" = "${port}" ] || return 1
  [ -n "${sbin}" ] && [ "${sbin}" = "${LAB_BIN}" ] || return 1
  [ "${sprof}" = "$(requested_profile)" ] || return 1
  case "${pid}" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "${pid}" 2>/dev/null || return 1
  cmd="$(ps -p "${pid}" -o command= 2>/dev/null || true)"
  case "${cmd}" in *inject.js*) return 1 ;; esac
  case "${cmd}" in *"${sbin}"*) ;; *) return 1 ;; esac
  listen="$("${LSOF}" -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"
  [ -n "${listen}" ] || return 1
  while IFS= read -r line; do
    [ -n "${line}" ] || continue
    case "${line}" in COMMAND*) continue ;; esac
    case "${line}" in *127.0.0.1:"${port}"*) ;; *) return 1 ;; esac
    lpid="$(printf '%s\n' "${line}" | awk '{print $2}')"
    case "${lpid}" in ''|*[!0-9]*) return 1 ;; esac
    pid_is_under "${lpid}" "${pid}" || return 1
    saw=1
  done <<EOF
${listen}
EOF
  [ "${saw}" = 1 ]
}
pid_is_under() { # $1 pid, $2 ancestor (same pid counts)
  local p="$1" a="$2" i=0 pp
  [ -n "${p}" ] && [ -n "${a}" ] || return 1
  while [ "${i}" -lt 30 ]; do
    [ "${p}" = "${a}" ] && return 0
    [ "${p}" = 0 ] || [ "${p}" = 1 ] && return 1
    pp="$(ps -p "${p}" -o ppid= 2>/dev/null | tr -cd '0-9')"
    [ -n "${pp}" ] && [ "${pp}" != "${p}" ] || return 1
    p="${pp}"
    i=$((i + 1))
  done
  return 1
}

# 起動する Cursor の確認
require_lab_app() {
  if [ "${MODE}" = copy ]; then
    guard_not_real_app "${LAB_APP}"
    [ -x "${LAB_BIN}" ] || fail_k 1 FAIL_NO_COPY "${LAB_BIN}"
  else
    [ -x "${LAB_BIN}" ] || fail_k 1 FAIL_NO_CURSOR "${LAB_BIN}"
  fi
  if [ "${MODE}" != normal ] && [ ! -d "${LAB_PROFILE}" ]; then
    fail_k 1 FAIL_NO_SEPARATE
  fi
}

# Cursor の起動オプション（--remote-debugging-address は絶対に付けない = 127.0.0.1 だけで待ち受け）
# パックの言語コード → VS Code / Cursor の表示言語 ID（--locale・argv.json）。対応外は空
ui_locale() {
  case "$1" in
    ja) echo ja ;;
    zh-cn|zh-CN) echo zh-cn ;;
    zh-tw|zh-TW|zh-hk|zh-HK) echo zh-tw ;;
    ko) echo ko ;; fr) echo fr ;; de) echo de ;; es) echo es ;; it) echo it ;; ru) echo ru ;;
    pt-br|pt-BR) echo pt-br ;;
    cs) echo cs ;; tr) echo tr ;; pl) echo pl ;;
    *) echo "" ;;
  esac
}
launch_args() { # $1=port $2=lang
  if [ "${MODE}" = normal ]; then
    printf '%s\n' "--remote-debugging-port=${1}"
  else
    printf '%s\n' "--user-data-dir=${LAB_PROFILE}" "--extensions-dir=${LAB_EXT}" "--remote-debugging-port=${1}" "--locale=$(ui_locale "${2:-ja}" | sed 's/^$/en/')"
  fi
}

# ポート番号の検査（数字のみ・1024〜65535）
check_port() {
  case "$1" in ''|*[!0-9]*) fail_k 2 FAIL_BAD_PORT "$1" ;; esac
  if [ "$1" -lt 1024 ] || [ "$1" -gt 65535 ]; then fail_k 2 FAIL_PORT_RANGE "$1"; fi
}
port_listening() { "${LSOF}" -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

# 作った物を記録する（同じ行は 1 回だけ）。形式: パス<TAB>説明
manifest_add() {
  local p="$1" what="${2:-}"
  guard_not_in_git
  mkdir -p "${LAB_DIR}"
  [ -f "${MANIFEST}" ] || printf '# word-to-world install manifest（uninstall.sh が読む。手で編集しない）\n' > "${MANIFEST}"
  if ! cut -f1 "${MANIFEST}" | grep -Fxq -- "${p}"; then printf '%s\t%s\n' "${p}" "${what}" >> "${MANIFEST}"; fi
}

# ---- プロセスの見分け方（パスは環境変数で awk に渡す。引数で渡すと awk 自身がヒットするため）
# Cursor 本体（メインプロセス）: コマンドに「…/Contents/MacOS/Cursor」がある物。注入ツール（inject.js）は除く。
cursor_main_pids() {
  ps -axo pid=,command= 2>/dev/null | B="${SRC_BIN}" C="${LAB_APP}/Contents/MacOS/Cursor" awk '
    /inject\.js/ || /awk/ { next }
    { line = $0 " " }
    index(line, ENVIRON["B"] " ") || index(line, ENVIRON["C"] " ") { print $1 }'
}
# このツールが起動した Cursor: デバッグポート付き / 別プロファイル / 実験用コピー / 試作版の物
lab_pids() {
  ps -axo pid=,command= 2>/dev/null | P="--user-data-dir=${LAB_PROFILE}" Q="${LAB_APP}/" \
    R="${LEGACY_LAB_DIR}/Cursor-Lab.app/" S="--user-data-dir=${LEGACY_LAB_DIR}/lab-profile" B="${SRC_BIN}" awk '
    /inject\.js/ || /awk/ { next }
    index($0, ENVIRON["P"]) || index($0, ENVIRON["Q"]) || index($0, ENVIRON["R"]) || index($0, ENVIRON["S"]) { print $1; next }
    index($0, ENVIRON["B"] " ") && /--remote-debugging-port=/ { print $1 }'
}
# 標準プロファイルで動いている Cursor（このツールの別プロファイル・コピーの物は除く）
normal_cursor_pids() {
  ps -axo pid=,command= 2>/dev/null | B="${SRC_BIN}" P="--user-data-dir=${LAB_PROFILE}" awk '
    /inject\.js/ || /awk/ { next }
    { line = $0 " " }
    index(line, ENVIRON["B"] " ") && !index($0, ENVIRON["P"]) && !/--user-data-dir=/ { print $1 }'
}
inject_pids() { ps -axo pid=,command= 2>/dev/null | P="${KIT_DIR}/tools/inject.js" awk 'index($0, ENVIRON["P"]) && / apply/ && !/awk/ { print $1 }'; }

# Cursor を「普通に」終了させる（保存の確認などは Cursor が出す）。強制終了（kill -9）はしない。
# $1 = 対象 PID の一覧を返す関数名。戻り値 0 = 終了した / 7 = 終了しなかった
quit_cursor_gracefully() {
  local pids_fn="$1" waited=0
  [ -n "$(${pids_fn})" ] || return 0
  if [ -x "${OSASCRIPT}" ]; then
    "${OSASCRIPT}" -e 'tell application "Cursor" to quit' >/dev/null 2>&1 || true
  else
    kill -TERM $(${pids_fn}) 2>/dev/null || true
  fi
  while [ -n "$(${pids_fn})" ] && [ "${waited}" -lt "${QUIT_TIMEOUT}" ]; do sleep 1; waited=$((waited + 1)); done
  [ -z "$(${pids_fn})" ] && return 0
  return 7
}

available_langs() { local f; for f in "${KIT_DIR}"/locales/*.json; do [ -f "${f}" ] && basename "${f}" .json; done | tr '\n' ' '; }

# 表示言語と台帳。各スクリプトは引数を読む前に ui_prepare_args を呼ぶ。
source "$(dirname "${BASH_SOURCE[0]}")/_i18n.sh"
