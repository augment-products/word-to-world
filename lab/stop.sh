#!/usr/bin/env bash
# 翻訳を止めて英語に戻し、このツールが起動した Cursor を「普通に」終了して、デバッグポートが閉じたことを確認する。
#   使い方: lab/stop.sh [--port 9333]
# normal モードでは、普段の Cursor を普通に終了する（⌘Q、または Cursor メニューから終了。保存の確認などは Cursor が出す。強制終了はしない）。
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
source "${HERE}/_common.sh"
ui_prepare_args "$@"
PORT=""
while [ $# -gt 0 ]; do case "$1" in --port) PORT="${2:?}"; shift 2 ;; --lang) shift 2 ;; *) fail_k 2 FAIL_BAD_OPT "$1" ;; esac; done
[ -n "${PORT}" ] || PORT="$(cat "${STATE_DIR}/port" 2>/dev/null || echo "${DEFAULT_PORT}")"
check_port "${PORT}"
"${HERE}/revert.sh" --port "${PORT}" || true
if [ -n "$(lab_pids)" ]; then
  say_k plain STOP_QUIT "$(lab_pids | tr '\n' ' ')"
  if [ "${MODE}" = normal ]; then
    quit_cursor_gracefully lab_pids || { say_k plain STOP_FAIL; exit 7; }
  else
    kill -TERM $(lab_pids) 2>/dev/null || true
    for _ in $(seq 1 20); do [ -z "$(lab_pids)" ] && break; sleep 0.5; done
    [ -z "$(lab_pids)" ] || { say_k plain STOP_FAIL; exit 7; }
  fi
fi
for _ in $(seq 1 10); do port_listening "${PORT}" || break; sleep 0.5; done
if port_listening "${PORT}"; then fail_k 1 STOP_PORT "${PORT}"; fi
rm -f "${STATE_DIR}/cursor.pid" "${STATE_DIR}/session"
say_k plain STOP_OK "${PORT}"
