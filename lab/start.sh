#!/usr/bin/env bash
# ワンステップ起動（将来のダブルクリック用アプリはこれを呼ぶだけにする）。
#   使い方: lab/start.sh [--lang ja] [--port 9333] [--show-original] [--quit-running] [--no-quit] [--with-langpack | --no-langpack]
#                        [--settings-only]   （設定画面だけを訳す。既定は設定画面 + エージェント画面のサイドバーなど）
#                        [--separate-profile | --copy] [--verbose]
# 1) 初回は準備（setup-lab.sh）。モードの既定は normal（普段の Cursor・標準プロファイル）
# 2) デバッグポート付きで Cursor を起動（起動中なら、確認してから普通に終了して開き直す。⌘Q、または Cursor メニューから終了）
# 3) 翻訳を当てて見張る。Cursor を終了すると、英語に戻して注入ツールも止まり、ポートも閉じる
#    Ctrl+C のときは英語に戻し、Cursor も普通に終了する（⌘Q、または Cursor メニューから終了。--no-quit なら Cursor は開いたまま）
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
source "${HERE}/_common.sh"
ui_prepare_args "$@"
LANG_CODE="ja"; PORT=""; QUIT=1; PASS=(); LAUNCH=(); SETUP=()
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) LANG_CODE="${2:?}"; shift 2 ;;
    --port) PORT="${2:?}"; shift 2 ;;
    --show-original) PASS+=(--show-original); shift ;;
    --settings-only) PASS+=(--scope settings); shift ;;
    --scope) case "${2:-}" in settings|all) PASS+=(--scope "${2}"); shift 2 ;; *) fail_k 2 FAIL_BAD_SCOPE ;; esac ;;
    --quit-running) LAUNCH+=(--quit-running); shift ;;
    --no-quit) QUIT=0; shift ;;
    --verbose|-v) PASS+=(--verbose); shift ;;
    --normal|--separate-profile|--copy|--with-langpack|--no-langpack) SETUP+=("$1"); shift ;;
    --help|-h)
      say_k plain HELP_START_1
      say_k plain HELP_START_2
      say_k plain HELP_START_VERBOSE
      say_k plain HELP_LANG_1
      say_k plain HELP_LANG_2
      exit 0 ;;
    *) fail_k 2 FAIL_BAD_OPT "$1" ;;
  esac
done
[ -n "${PORT}" ] || PORT="${DEFAULT_PORT}"; check_port "${PORT}"
[ -f "${KIT_DIR}/locales/${LANG_CODE}.json" ] || fail_k 3 FAIL_NO_LAYER "${LANG_CODE}" "$(available_langs)"
if [ ${#SETUP[@]} -gt 0 ] || [ ! -f "${STATE_DIR}/mode" ]; then
  "${HERE}/setup-lab.sh" --lang "${LANG_CODE}" ${SETUP[@]+"${SETUP[@]}"}
fi
set_mode "$(cat "${STATE_DIR}/mode" 2>/dev/null || echo normal)"
export UI_TR_MODE="${MODE}"
if [ "${MODE}" = copy ] && [ ! -x "${LAB_BIN}" ]; then "${HERE}/setup-lab.sh" --copy; fi
# ポートが開いていても launch-lab を省かない。同意と「記録した Cursor か」の確認はそちらで行う。
"${HERE}/launch-lab.sh" --port "${PORT}" --lang "${LANG_CODE}" ${LAUNCH[@]+"${LAUNCH[@]}"}

# 同じセッションの注入が生きていれば、もう一つは起動しない。死んだ PID や別プロセスは無視する。
injector_live_pid() {
  local pid cmd
  [ -f "${PID_FILE}" ] || return 1
  pid="$(tr -cd '0-9' < "${PID_FILE}")"
  case "${pid}" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "${pid}" 2>/dev/null || return 1
  cmd="$(ps -p "${pid}" -o command= 2>/dev/null || true)"
  case "${cmd}" in
    *inject.js*) printf '%s\n' "${pid}"; return 0 ;;
  esac
  return 1
}
if live="$(injector_live_pid)"; then
  say ""
  say_k plain START_ALREADY "${live}"
  say_k plain START_ALREADY_2
  exit 0
fi

INJ_PID=""
USER_STOP=0
cleanup() {
  trap - EXIT INT TERM
  if [ -n "${INJ_PID}" ] && kill -0 "${INJ_PID}" 2>/dev/null; then
    kill -TERM "${INJ_PID}" 2>/dev/null || true          # SIGTERM = 英語に戻してから終了
    for _ in $(seq 1 20); do kill -0 "${INJ_PID}" 2>/dev/null || break; sleep 0.5; done
  fi
  rm -f "${PID_FILE}"
  if [ "${QUIT}" = 1 ] && [ "${USER_STOP}" = 1 ] && port_listening "${PORT}"; then "${HERE}/stop.sh" --port "${PORT}" || true; fi
}
trap 'USER_STOP=1; exit 130' INT TERM
trap cleanup EXIT
manifest_add "${PID_FILE}" "注入ツールの PID"
CARGS=()
CPID="$(cat "${STATE_DIR}/cursor.pid" 2>/dev/null || true)"
case "${CPID}" in ''|*[!0-9]*) : ;; *) kill -0 "${CPID}" 2>/dev/null && CARGS=(--cursor-pid "${CPID}") ;; esac
ELECTRON_RUN_AS_NODE=1 "${LAB_BIN}" "${KIT_DIR}/tools/inject.js" apply --lang "${LANG_CODE}" --port "${PORT}" \
  ${CARGS[@]+"${CARGS[@]}"} ${PASS[@]+"${PASS[@]}"} &
INJ_PID=$!
echo "${INJ_PID}" > "${PID_FILE}"
ui_save
printf '%s\n' "${LANG_CODE}" > "${STATE_DIR}/layer-lang"
say ""
say "--- $(display_name "${KIT_DIR}/locales/${LANG_CODE}.json") ---"
say_k bold START_UNOFFICIAL
say ""
say_k plain START_TRANSLATING "${LANG_CODE}"
say_k plain START_OVERLAY
say_k plain START_LANGPACK
say ""
say_k plain START_STOP
say_k plain START_CTRLC
# Cursor が終了したら（ポートが閉じたら）終わる。注入ツールも自分で終わる（--cursor-pid / ポートの監視）
while kill -0 "${INJ_PID}" 2>/dev/null; do
  if ! port_listening "${PORT}"; then
    say ""
    say_k plain START_QUIT
    break
  fi
  sleep 2
done
