#!/usr/bin/env bash
# Cursor をデバッグポート付きで起動する（ポートは 127.0.0.1 だけ。Cursor を終了すると閉じる）。
#   使い方: lab/launch-lab.sh [--port 9333] [--lang ja] [--quit-running]
#   --quit-running : normal モードで Cursor が既に起動しているとき、確認なしで「普通に終了」（⌘Q、または Cursor メニューから終了）させてから起動する
#                    （付けない場合は、端末なら Enter で確認、端末でなければ終了コード 5 で止まる）
# 起動中の Cursor は「普通に終了」させる（⌘Q、または Cursor メニューから終了。保存の確認などは Cursor が出す）。強制終了はしない。
set -euo pipefail
source "$(dirname "$0")/_common.sh"
ui_prepare_args "$@"

PORT="${DEFAULT_PORT}"; LANG_CODE="ja"; QUIT_RUNNING=0
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:?}"; shift 2 ;;
    --lang) LANG_CODE="${2:?}"; shift 2 ;;
    --quit-running) QUIT_RUNNING=1; shift ;;
    [0-9]*) PORT="$1"; shift ;;
    *) fail_k 2 FAIL_BAD_OPT "$1" ;;
  esac
done
check_port "${PORT}"
require_lab_app

# 標準プロファイルでデバッグポートを開く前に、一度だけ説明して yes をもらう。Enter だけでは進まない。
ensure_debug_consent() {
  [ "${MODE}" = normal ] || return 0
  local file="${STATE_DIR}/debug-port-consent" ans
  if [ -f "${file}" ] && [ "$(cat "${file}" 2>/dev/null)" = yes ]; then return 0; fi
  say ""
  say_k plain CONSENT_TITLE
  say ""
  say_k plain CONSENT_OPEN "${PORT}"
  say_k plain CONSENT_DEFAULT_PORT
  say_k hot CONSENT_REACH "${PORT}"
  say_k hot CONSENT_REACH_AGENT
  say_k hot CONSENT_REACH_ACCOUNT
  say_k bold CONSENT_LOCAL
  say_k plain CONSENT_CLOSE
  say ""
  say_k bold CONSENT_YES
  say_k plain CONSENT_ENTER
  say_k plain CONSENT_SEPARATE
  if [ ! -t 0 ] && [ -z "${UI_TR_ASSUME_TTY:-}" ]; then
    say_k plain CONSENT_NOTTY
    exit 5
  fi
  say_k prompt CONSENT_PROMPT
  read -r ans || ans=""
  if [ "${ans}" = yes ]; then
    guard_not_in_git
    mkdir -p "${STATE_DIR}"
    printf 'yes\n' > "${file}"
    return 0
  fi
  say_k plain CONSENT_NO
  exit 5
}
ensure_debug_consent

if port_listening "${PORT}"; then
  if listener_owned_by_us "${PORT}"; then
    say ""
    say_k plain LAUNCH_OURS
    say_k plain LAUNCH_OURS_PORT "${PORT}"
    exit 0
  fi
  "${LSOF}" -nP -iTCP:"${PORT}" -sTCP:LISTEN >&2 || true
  fail_k 6 LAUNCH_NOT_OURS "${PORT}"
fi

# normal モード: 普段の Cursor が起動中なら、いったん普通に終了してもらう（⌘Q、または Cursor メニューから終了。デバッグポートは起動時にしか付けられない）
if [ "${MODE}" = normal ] && [ -n "$(normal_cursor_pids)" ]; then
  say ""
  say_k plain LAUNCH_RUNNING
  say_k plain LAUNCH_REOPEN
  say_k plain LAUNCH_KEPT
  if [ "${QUIT_RUNNING}" != 1 ]; then
    if [ -t 0 ]; then
      say_k plain LAUNCH_ENTER
      read -r _ || fail_k 5 FAIL_CANCEL
    else
      say_k plain LAUNCH_NOTTY_QUIT
      exit 5
    fi
  fi
  if quit_cursor_gracefully normal_cursor_pids; then
    say ""
    say_k plain LAUNCH_QUIT
  else
    say_k plain LAUNCH_QUIT_FAIL "${QUIT_TIMEOUT}"
    exit 7
  fi
fi

ARGS=()
while IFS= read -r a; do ARGS+=("${a}"); done < <(launch_args "${PORT}" "${LANG_CODE}")
for a in "${ARGS[@]}"; do
  case "${a}" in *remote-debugging-address*|*0.0.0.0*) fail_k 6 FAIL_BAD_FLAG "${a}" ;; esac
done

guard_not_in_git
mkdir -p "${LOG_DIR}" "${STATE_DIR}"
manifest_add "${LOG_DIR}" "ログ"; manifest_add "${STATE_DIR}" "状態ファイル"
LOG="${LOG_DIR}/cursor-launch.log"
printf '%s\n' "${PORT}" > "${STATE_DIR}/port"
say ""
say_k plain LAUNCH_CMD "${MODE}" "${LAB_BIN} ${ARGS[*]}"
nohup "${LAB_BIN}" "${ARGS[@]}" >"${LOG}" 2>&1 &
printf '%s\n' "$!" > "${STATE_DIR}/cursor.pid"
write_session "${PORT}" "$!"

PORT_WAIT="${PORT_WAIT:-60}"
case "${PORT_WAIT}" in ''|*[!0-9]*) PORT_WAIT=60 ;; esac
for _ in $(seq 1 "${PORT_WAIT}"); do port_listening "${PORT}" && break; sleep 1; done
if ! port_listening "${PORT}"; then
  fail_k 4 LAUNCH_PORT_TIMEOUT "${PORT_WAIT}" "${PORT}" "${LOG}"
fi
if ! listener_owned_by_us "${PORT}"; then
  "${LSOF}" -nP -iTCP:"${PORT}" -sTCP:LISTEN >&2 || true
  fail_k 6 LAUNCH_NOT_LISTEN "${PORT}"
fi
say ""
say_k plain LAUNCH_OK "${PORT}"
