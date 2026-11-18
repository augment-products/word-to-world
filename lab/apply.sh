#!/usr/bin/env bash
# 起動中の（デバッグポート付きの）Cursor の画面に翻訳を当てる。表示中の文字だけを置き換え、ファイルは書き換えない。
#   使い方: lab/apply.sh [--lang ja] [--port 9333] [--scope all|settings] [--once]  （all = 設定画面 + エージェント画面のサイドバー等。settings = 設定画面だけ）
#                        [--show-original] [--extra 追加辞書.json] [--list] [--verbose]
#   --once            今開いている画面に 1 回だけ当てて終了（再読み込みすると英語に戻る）
#   --show-original   訳した文字にマウスを乗せると英語の原文が出る
# 既定では動かしたままにし、新しいウィンドウや再読み込みにも当て直す。Ctrl+C で英語に戻して終了。
# Cursor が終了すると、注入ツールも自動で終わる。
set -euo pipefail
source "$(dirname "$0")/_common.sh"
ui_prepare_args "$@"

LANG_CODE="ja"; PORT=""; SCOPE="all"; ONCE=0
EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) LANG_CODE="${2:?}"; shift 2 ;;
    --port) PORT="${2:?}"; shift 2 ;;
    --scope) SCOPE="${2:?}"; shift 2 ;;
    --once) ONCE=1; shift ;;
    --show-original) EXTRA+=(--show-original); shift ;;
    --extra) EXTRA+=(--extra "${2:?}"); shift 2 ;;
    --list) say_k plain APPLY_LIST "$(available_langs)"; exit 0 ;;
    --verbose|-v) EXTRA+=(--verbose); shift ;;
    *) fail_k 2 FAIL_BAD_OPT "$1" ;;
  esac
done
case "${LANG_CODE}" in *[!A-Za-z0-9-]*|"") fail_k 2 FAIL_BAD_LANG "${LANG_CODE}" ;; esac
[ -f "${KIT_DIR}/locales/${LANG_CODE}.json" ] || fail_k 3 FAIL_NO_LAYER "locales/${LANG_CODE}.json" "$(available_langs)"
case "${SCOPE}" in settings|all) : ;; *) fail_k 2 FAIL_BAD_SCOPE ;; esac
[ -n "${PORT}" ] || PORT="$(cat "${STATE_DIR}/port" 2>/dev/null || echo "${DEFAULT_PORT}")"
check_port "${PORT}"
require_lab_app
port_listening "${PORT}" || fail_k 4 APPLY_PORT_CLOSED "${PORT}"
listener_owned_by_us "${PORT}" || fail_k 6 LAUNCH_NOT_OURS "${PORT}"

INJECT="${KIT_DIR}/tools/inject.js"
[ -f "${INJECT}" ] || fail_k 1 APPLY_NO_INJECT "${INJECT}"
ARGS=(apply --lang "${LANG_CODE}" --port "${PORT}" --scope "${SCOPE}")
[ "${ONCE}" = 1 ] && ARGS+=(--once)
CPID="$(cat "${STATE_DIR}/cursor.pid" 2>/dev/null || true)"
case "${CPID}" in ''|*[!0-9]*) : ;; *) kill -0 "${CPID}" 2>/dev/null && ARGS+=(--cursor-pid "${CPID}") ;; esac

if [ "${ONCE}" = 1 ]; then
  exec env ELECTRON_RUN_AS_NODE=1 "${LAB_BIN}" "${INJECT}" "${ARGS[@]}" ${EXTRA[@]+"${EXTRA[@]}"}
fi
if [ -f "${PID_FILE}" ] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
  fail_k 1 APPLY_INJECT_RUNNING "$(cat "${PID_FILE}")"
fi
manifest_add "${PID_FILE}" "注入ツールの PID"
echo $$ > "${PID_FILE}"   # exec で PID は引き継がれる
say ""
say_k plain APPLY_DOING "${LANG_CODE}"
say_k plain APPLY_SCOPE "${SCOPE}" "${PORT}"
say_k plain APPLY_CTRLC
exec env ELECTRON_RUN_AS_NODE=1 "${LAB_BIN}" "${INJECT}" "${ARGS[@]}" ${EXTRA[@]+"${EXTRA[@]}"}
