#!/usr/bin/env bash
# 準備。何度実行しても安全（既にある物は作り直さない）。
#   使い方: lab/setup-lab.sh [--normal | --separate-profile | --copy] [--lang ja] [--with-langpack | --no-langpack]
#   --normal             : 普段の Cursor・標準プロファイルを使う。作業フォルダーを作るだけで、
#                          Cursor.app にも標準プロファイル（~/Library/Application Support/Cursor、~/.cursor）にも書き込まない
#   モードの指定を省略したときは、state/mode に記録された前回のモードを使う（記録が無ければ normal）
#   --separate-profile   : 別プロファイル（~/Library/Application Support/word-to-world/lab-profile）を作る
#   --copy               : 実験用コピー Cursor-Lab.app を作る（開発者の実験用。数 GB 使う）
#   --with-langpack / --no-langpack : Microsoft 公式の VS Code 言語パック（任意）を入れる / 入れない。
#                          指定なしなら 1 回だけ聞く（端末がなければ入れない）。詳しくは lab/_langpack.sh
# 作った物はすべて install-manifest.txt に記録する（lab/uninstall.sh で全部消せる）。
# 言語パックと ~/.cursor/argv.json の locale は、変えたときだけ state/ に記録し、uninstall.sh が元に戻す。
set -euo pipefail
source "$(dirname "$0")/_common.sh"
source "$(dirname "$0")/_langpack.sh"
ui_prepare_args "$@"
guard_lab_dir
LANG_CODE=ja; WANT_LP=ask
while [ $# -gt 0 ]; do
  case "$1" in
    --normal) set_mode normal; shift ;; # 明示指定。省略時は state/mode の前回モード（無ければ normal）
    --separate-profile|--direct) set_mode separate; shift ;;
    --copy) set_mode copy; shift ;;
    --lang) LANG_CODE="${2:?}"; shift 2 ;;
    --with-langpack) WANT_LP=yes; shift ;;
    --no-langpack) WANT_LP=no; shift ;;
    --help|-h)
      say_k plain HELP_SETUP
      say_k plain HELP_LANG_1
      say_k plain HELP_LANG_2
      exit 0 ;;
    *) fail_k 2 FAIL_BAD_OPT "$1" ;;
  esac
done

# 空のディレクトリだけ、印と state の記録を書いて引き継ぐ。中身がある印のないディレクトリは拒否する。
dir_is_empty() {
  local f
  [ -d "$1" ] || return 1
  for f in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    # -e だけだと、切れたシンボリックリンクを「空」と数えてしまう
    if [ -e "${f}" ] || [ -L "${f}" ]; then return 1; fi
  done
  return 0
}
claim_runtime_dir() {
  local adopt=0
  guard_not_in_git
  if [ -d "${LAB_DIR}" ] && [ ! -f "${LAB_MARKER}" ]; then
    if ! dir_is_empty "${LAB_DIR}"; then
      fail_k 6 SETUP_ADOPT "${LAB_DIR}"
    fi
    adopt=1
  fi
  mkdir -p "${LAB_DIR}" "${STATE_DIR}" "${LOG_DIR}"
  if [ ! -f "${LAB_MARKER}" ]; then
    if [ "${adopt}" = 1 ]; then
      printf 'owner=word-to-world\ncreated-by=lab/setup-lab.sh\nadopted-empty=1\n' > "${LAB_MARKER}"
      printf 'path=%s\nadopted-by=lab/setup-lab.sh\nreason=pre-existing-empty\n' "${LAB_DIR}" > "${STATE_DIR}/adopted-empty-dir"
    else
      printf 'owner=word-to-world\ncreated-by=lab/setup-lab.sh\n' > "${LAB_MARKER}"
    fi
  fi
}
claim_runtime_dir
manifest_add "${LAB_DIR}" "作業フォルダー（中身ごと）"
manifest_add "${LAB_MARKER}" "フォルダーの印"
manifest_add "${MANIFEST}" "この一覧"
manifest_add "${STATE_DIR}" "状態ファイル"
manifest_add "${LOG_DIR}" "ログ"
manifest_add "${KIT_DIR}" "このキット（展開したフォルダー）"
[ -d "${SRC_APP}" ] || fail_k 1 SETUP_NO_CURSOR "${SRC_APP}"

case "${MODE}" in
  normal)
    say ""
    say_k bold SETUP_MODE_NORMAL
    say_k plain SETUP_NORMAL_BODY
    say_k plain SETUP_NORMAL_SAFE
    ;;
  separate|copy)
    if [ "${MODE}" = copy ]; then
      guard_not_real_app "${LAB_APP}"
      if [ -d "${LAB_APP}" ]; then
        say_k plain SETUP_COPY_EXISTS "${LAB_APP}"
      else
        say_k plain SETUP_COPYING "${SRC_APP}" "${LAB_APP}"
        manifest_add "${LAB_APP}" "実験用 Cursor（コピー）"
        ditto "${SRC_APP}" "${LAB_APP}"     # コード署名や属性を保ったままコピー（コピー元は変更しない）
        say_k plain SETUP_COPIED
      fi
      manifest_add "${LAB_APP}" "実験用 Cursor（コピー）"
    else
      say ""
      say_k bold SETUP_MODE_SEP
      say_k plain SETUP_SEP_BODY
    fi
    mkdir -p "${LAB_PROFILE}/User" "${LAB_EXT}"
    manifest_add "${LAB_PROFILE}" "別プロファイル"
    manifest_add "${LAB_EXT}" "別プロファイルの拡張機能フォルダー"
    SETTINGS="${LAB_PROFILE}/User/settings.json"
    if [ ! -f "${SETTINGS}" ]; then
      printf '{\n  "update.mode": "none"\n}\n' > "${SETTINGS}"
      say_k plain SETUP_SEP_SETTINGS "${SETTINGS}"
    fi
    ;;
esac
printf '%s\n' "${MODE}" > "${STATE_DIR}/mode"

VER="$(/usr/bin/defaults read "$(dirname "$(dirname "${LAB_BIN}")")/Info" CFBundleShortVersionString 2>/dev/null || echo '?')"
say ""
say_k plain SETUP_VERSION "${VER}"
printf '%s\n' "${VER}" > "${STATE_DIR}/cursor-version"

# Cursor を Node として使えるか確認（アプリは起動せず、Node として 1 行実行するだけ）
if NODE_VER="$(ELECTRON_RUN_AS_NODE=1 "${LAB_BIN}" -e 'process.stdout.write(process.versions.node)' 2>/dev/null)"; then
  say_k plain SETUP_NODE_OK "${NODE_VER}"
else
  fail_k 1 SETUP_NODE_FAIL
fi
case "${LANG_CODE}" in *[!A-Za-z-]*|"") fail_k 2 FAIL_BAD_LANG "${LANG_CODE}" ;; esac
# 直接呼ぶ。`||` や if の条件から呼ぶと、bash はその関数と、そこから呼ぶ関数の set -e を切る。
# 一覧の失敗は langpack_setup が 1 で返す（2 は使い方の誤り）。
langpack_setup "${LANG_CODE}" "${WANT_LP}"
ui_save
printf '%s\n' "${LANG_CODE}" > "${STATE_DIR}/layer-lang"
say ""
say_k bold SETUP_READY
say_k plain SETUP_NEXT
