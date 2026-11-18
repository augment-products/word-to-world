#!/usr/bin/env bash
# 翻訳を外して英語に戻し、注入ツールを止める。何度実行しても安全。Cursor は終了させない。
#   使い方: lab/revert.sh [--port 9333]
set -euo pipefail
source "$(dirname "$0")/_common.sh"
ui_prepare_args "$@"

PORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="${2:?}"; shift 2 ;;
    --lang) shift 2 ;;
    *) fail_k 2 FAIL_BAD_OPT "$1" ;;
  esac
done
[ -n "${PORT}" ] || PORT="$(cat "${STATE_DIR}/port" 2>/dev/null || echo "${DEFAULT_PORT}")"
check_port "${PORT}"

for PID in $( { [ -f "${PID_FILE}" ] && cat "${PID_FILE}"; inject_pids; } 2>/dev/null | sort -u ); do
  # その PID が本当に注入ツールか確認してから合図を送る（SIGTERM = 英語に戻してから終了）
  if kill -0 "${PID}" 2>/dev/null && ps -p "${PID}" -o command= | grep -q "inject.js"; then
    say_k plain REVERT_STOP "${PID}"
    kill -TERM "${PID}" 2>/dev/null || true
    for _ in $(seq 1 10); do kill -0 "${PID}" 2>/dev/null || break; sleep 0.5; done
  fi
done
rm -f "${PID_FILE}"

if port_listening "${PORT}" && [ -x "${LAB_BIN}" ]; then
  ELECTRON_RUN_AS_NODE=1 "${LAB_BIN}" "${KIT_DIR}/tools/inject.js" revert --port "${PORT}" || true
else
  say_k plain REVERT_CLOSED "${PORT}"
fi
