#!/usr/bin/env bash
# Microsoft の公式 VS Code 言語パック（任意）を入れる・戻すための共通部分。_common.sh の後に source する。単体では実行しない。
# Optional: Microsoft's official VS Code language pack (menu bar, VS Code menus, editor parts in the chosen language).
#   - 入れるのはユーザーが選んだときだけ（setup-lab.sh が 1 回だけ聞く / --with-langpack / --no-langpack）
#   - Cursor 自身のコマンド（cursor --install-extension）で、Cursor がいつも使うマーケットプレイスから入れる
#   - 表示言語は ~/.cursor/argv.json の "locale" だけを変える（コメントや他の設定はそのまま。元の値を記録）
#   - アンインストールは「このツールが入れた」と記録がある物だけ外し、locale を元の値（無かったなら無し）に戻す
# bash 3.2 で動く書き方。文字列の中の変数は ${VAR}。
CURSOR_CLI="${CURSOR_CLI:-${SRC_APP}/Contents/Resources/app/bin/cursor}"   # Cursor の公式 CLI（アプリの中。書き換えない）
ARGV_JSON="${CURSOR_ARGV_JSON:-${HOME}/.cursor/argv.json}"                 # Cursor の起動設定（JSONC）
LP_CHOICE="${STATE_DIR}/langpack-choice"          # yes / no（1 回だけ聞くため）
LP_OURS="${STATE_DIR}/langpack-installed"         # 入れた場所ごとに1行: <id><TAB><拡張フォルダー>。空のフォルダーは標準プロファイル。タブの無い古い1行も読む。
LP_ARGV="${LP_ARGV_FILE:-${STATE_DIR}/argv-locale.state}"     # argv.json を変えた記録（key=value の行）
LP_ARGV_ORIG="${LP_ARGV_BACKUP:-${STATE_DIR}/argv.json.orig}" # 変える前の argv.json（そのままのバイト列）

lp_pack_name() { # $1 = 拡張機能 ID。表示中の 1 言語だけ。
  case "$1" in
    *language-pack-ja) text_k LP_PACK_JA "$1" ;;
    *) text_k LP_PACK_OTHER "$1" ;;
  esac
}
lp_fail() { say_k plain "$@"; return 1; }

# 言語コード -> 言語パックの ID / argv.json の locale（VS Code の表記）
# 言語 ID は vscode-loc と同じ小文字: ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl
# 以前の表記（zh-CN, zh-TW, pt-BR）と、一覧には無い zh-hk は繁体字 zh-tw に寄せて受け付ける
langpack_id() {
  case "$1" in
    ja) echo MS-CEINTL.vscode-language-pack-ja ;;
    zh-cn|zh-CN) echo MS-CEINTL.vscode-language-pack-zh-hans ;;
    zh-tw|zh-TW|zh-hk|zh-HK) echo MS-CEINTL.vscode-language-pack-zh-hant ;;
    ko) echo MS-CEINTL.vscode-language-pack-ko ;;
    fr) echo MS-CEINTL.vscode-language-pack-fr ;;
    de) echo MS-CEINTL.vscode-language-pack-de ;;
    es) echo MS-CEINTL.vscode-language-pack-es ;;
    it) echo MS-CEINTL.vscode-language-pack-it ;;
    ru) echo MS-CEINTL.vscode-language-pack-ru ;;
    pt-br|pt-BR) echo MS-CEINTL.vscode-language-pack-pt-BR ;;
    cs) echo MS-CEINTL.vscode-language-pack-cs ;;
    tr) echo MS-CEINTL.vscode-language-pack-tr ;;
    pl) echo MS-CEINTL.vscode-language-pack-pl ;;
    *) echo "" ;;
  esac
}
langpack_locale() { ui_locale "$1"; }   # argv.json の "locale" の値（_common.sh）
# Cursor.app を消したあとでも locale の読み書きだけはできる（argv-locale.js は素の Node）。
lp_node() {
  if [ -x "${SRC_BIN}" ]; then ELECTRON_RUN_AS_NODE=1 "${SRC_BIN}" "$@"
  elif command -v node >/dev/null 2>&1; then command node "$@"
  else return 127
  fi
}
lp_argv() { lp_node "${KIT_DIR}/tools/argv-locale.js" "$@"; }   # get|set|remove <file> [locale]
lp_sum() { if [ -f "$1" ]; then cksum < "$1" | tr -s ' ' | tr ' ' '-'; else echo absent; fi; }
lp_cli_ok() { [ -x "${CURSOR_CLI}" ]; }
# Cursor の実行ファイルも、システムの node も無い（argv.json をここから戻せない）。
lp_no_runtime() { [ ! -x "${SRC_BIN}" ] && ! command -v node >/dev/null 2>&1; }
lp_cli() { # 別プロファイルのときは、その拡張機能フォルダーに入れる
  if [ -n "${LP_EXTDIR:-}" ]; then "${CURSOR_CLI}" --user-data-dir "${LAB_PROFILE}" --extensions-dir "${LP_EXTDIR}" "$@"
  else "${CURSOR_CLI}" "$@"; fi
}
# 0 = 入っている / 1 = 入っていない（一覧は取れた） / 2 = 一覧を取れなかった。
# CLI が無いことはここでは見ない。呼び出し側が lp_cli_ok と分ける。
# id の大文字小文字は無視する。id@version も入っているとみなす。grep -q は使わない。
lp_id_low() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }
lp_pack_state() {
  local id="$1" list rc=0 id_low one
  list="$(lp_cli --list-extensions 2>/dev/null)" || rc=$?
  [ "${rc}" -eq 0 ] || return 2
  id_low="$(lp_id_low "${id}")"
  while IFS= read -r one || [ -n "${one}" ]; do
    one="$(lp_id_low "${one}")"
    case "${one}" in
      "${id_low}"|"${id_low}@"*) return 0 ;;
    esac
  done <<EOF
${list}
EOF
  return 1
}
# 拡張フォルダーに id / id-version / id@version のディレクトリがある（大文字小文字は無視）。
lp_pack_on_disk() {
  local id="$1" dir="$2" low name base
  [ -d "${dir}" ] || return 1
  low="$(lp_id_low "${id}")"
  for base in "${dir}"/* "${dir}"/.[!.]* "${dir}"/..?*; do
    [ -d "${base}" ] || continue
    name="$(lp_id_low "$(basename -- "${base}")")"
    case "${name}" in
      "${low}"|"${low}-"*|"${low}@"*) return 0 ;;
    esac
  done
  return 1
}
lp_state_get() { [ -f "${LP_ARGV}" ] && sed -n "s/^$1=//p" "${LP_ARGV}" | head -1; return 0; }

# setup: $1 = lang, $2 = yes|no|ask（--with-langpack / --no-langpack / 指定なし）。
# 入れられなかった（ネットワークなど）ときは 0。翻訳自体は使える。
# 一覧が取れないとき、およびバックアップ・所有記録・復元記録を書けないときは 1。
# lp_pack_state の 2 はここで 1 にする。setup-lab.sh は直接呼ぶ（`||` の中では bash が set -e を切る）。
# lp_fail は上で定義。メッセージは 1 言語（say_k）。
lp_ours_line() { printf '%s\t%s' "$1" "$2"; }
lp_ours_fields() { # 呼び出し側の id と ext に入れる。タブが無い行は、標準プロファイルの古い記録。
  local line="$1"
  case "${line}" in
    *$'\t'*) id="${line%%$'\t'*}"; ext="${line#*$'\t'}" ;;
    *) id="${line}"; ext="" ;;
  esac
}
lp_ours_has() {
  local id="$1" ext="$2" line
  [ -f "${LP_OURS}" ] || return 1
  line="$(lp_ours_line "${id}" "${ext}")"
  if grep -Fxq -- "${line}" "${LP_OURS}"; then return 0; fi
  if [ -z "${ext}" ] && grep -Fxq -- "${id}" "${LP_OURS}"; then return 0; fi
  return 1
}
lp_ours_add() { # 同じ場所の行は足さない。書けなければ 1（set -e が切れていても）。
  local id="$1" ext="$2" line
  lp_ours_has "${id}" "${ext}" && return 0
  mkdir -p "$(dirname "${LP_OURS}")" || lp_fail LP_OWN_WRITE || return 1
  line="$(lp_ours_line "${id}" "${ext}")"
  printf '%s\n' "${line}" >> "${LP_OURS}" || lp_fail LP_OWN_WRITE || return 1
  return 0
}
langpack_setup() {
  local lang="$1" want="$2" id loc ans cur st=0 already=0 disk
  id="$(langpack_id "${lang}")"; loc="$(langpack_locale "${lang}")"
  [ -n "${id}" ] || return 0
  if [ "${want}" = ask ] && [ -f "${LP_CHOICE}" ]; then want="$(cat "${LP_CHOICE}")"; fi   # 1 回だけ聞く
  LP_EXTDIR=""; [ "${MODE}" != normal ] && LP_EXTDIR="${LAB_EXT}"
  # 既に入っている（このツールの記録が無い）なら聞かない。所有記録も locale も書かない。
  if [ "${want}" = ask ] && ! lp_ours_has "${id}" "${LP_EXTDIR}"; then
    already=0
    if lp_cli_ok; then
      lp_pack_state "${id}" && st=0 || st=$?
      if [ "${st}" = 0 ]; then already=1; fi
    fi
    if [ "${already}" = 0 ]; then
      disk="${HOME}/.cursor/extensions"; [ -n "${LP_EXTDIR}" ] && disk="${LP_EXTDIR}"
      if lp_pack_on_disk "${id}" "${disk}"; then already=1; fi
    fi
    if [ "${already}" = 1 ]; then
      printf '\n'
      say_k plain LP_ALREADY "$(lp_pack_name "${id}")"
      say_k plain LP_NOT_OURS_NOTE
      return 0
    fi
  fi
  if [ "${want}" = ask ]; then
    if [ -t 0 ] || [ -n "${UI_TR_ASSUME_TTY:-}" ]; then
      printf '\n'
      say_k plain LP_ASK_MENU
      say_k plain LP_ASK_DEFAULT "$(lp_pack_name "${id}")"
      say_k plain LP_ASK_LICENSE
      say_k plain LP_ASK_RESTART
      if [ "${MODE}" = normal ]; then
        say_k plain LP_ASK_ARGV
        say_k plain LP_ASK_PERSIST
      fi
      say_k plain LP_YN
      say_k prompt LP_YN_PROMPT
      read -r ans || ans=""
      case "${ans}" in y|Y|yes|YES|はい) want=yes ;; *) want=no ;; esac
    else
      want=no
      printf '\n'
      say_k plain LP_NO_TTY "$(lp_pack_name "${id}")"
      say_k plain LP_NO_TTY_HOW
    fi
  fi
  printf '%s\n' "${want}" > "${LP_CHOICE}" || lp_fail LP_CHOICE_WRITE || return 1
  [ "${want}" = yes ] || return 0

  if ! lp_cli_ok; then
    say_k plain LP_NO_CLI "${CURSOR_CLI}"
    return 0
  fi
  lp_pack_state "${id}" && st=0 || st=$?
  if [ "${st}" = 2 ]; then
    say_k plain LP_LIST_FAIL
    return 1
  fi
  if [ "${st}" = 0 ]; then
    if lp_ours_has "${id}" "${LP_EXTDIR}"; then
      say_k plain LP_OURS_ALREADY "$(lp_pack_name "${id}")"
      say_k plain LP_OURS_REMOVE
    else
      say_k plain LP_ALREADY "$(lp_pack_name "${id}")"
      say_k plain LP_NOT_OURS_SKIP
    fi
  else
    say_k plain LP_INSTALLING "$(lp_pack_name "${id}")" "${id}"
    if ! lp_cli --install-extension "${id}" >> "${LOG_DIR}/langpack.log" 2>&1; then
      say_k plain LP_INSTALL_FAIL "${LOG_DIR}/langpack.log"
      return 0
    fi
    lp_pack_state "${id}" && st=0 || st=$?
    if [ "${st}" = 0 ]; then
      lp_ours_add "${id}" "${LP_EXTDIR}" || return 1
      say_k plain LP_INSTALLED "$(lp_pack_name "${id}")"
    elif [ "${st}" = 2 ]; then
      say_k plain LP_LIST_AFTER
      return 1
    else
      say_k plain LP_INSTALL_FAIL "${LOG_DIR}/langpack.log"
      return 0
    fi
  fi
  # 別プロファイル・コピーのモードは、起動時に --locale を付けるので argv.json は変えない
  [ "${MODE}" = normal ] || return 0
  # `|| return` の中では set -e が切れる。バックアップと復元記録は langpack_set_locale が自分で見る。
  langpack_set_locale "${loc}" || return 1
  return 0
}

langpack_set_locale() {
  local loc="$1" info has prev existed
  if ! info="$(lp_argv get "${ARGV_JSON}" 2>&1)"; then
    say_k plain LP_ARGV_UNSAFE "${ARGV_JSON}" "${info}"
    return 0
  fi
  case "${info}" in *'"exists":true'*) existed=1 ;; *) existed=0 ;; esac
  case "${info}" in *'"has":true'*) has=1 ;; *) has=0 ;; esac
  prev="$(printf '%s' "${info}" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')"
  if [ "${has}" = 1 ] && [ "${prev}" = "${loc}" ]; then
    say_k plain LP_ALREADY_LOCALE "${loc}" "${ARGV_JSON}"
    return 0
  fi
  if [ ! -f "${LP_ARGV}" ]; then   # 初回だけ元の状態を記録（2 回目以降の setup で上書きしない）
    mkdir -p "$(dirname "${LP_ARGV}")" || lp_fail LP_RESTORE_DIR || return 1
    if [ "${existed}" = 1 ]; then
      cp -p "${ARGV_JSON}" "${LP_ARGV_ORIG}" || lp_fail LP_BACKUP_WRITE || return 1
    fi
    printf 'file=%s\nexisted=%s\nhad=%s\nprev=%s\n' "${ARGV_JSON}" "${existed}" "${has}" "${prev}" > "${LP_ARGV}" || lp_fail LP_RESTORE_WRITE || return 1
  fi
  mkdir -p "$(dirname "${ARGV_JSON}")" || lp_fail LP_ARGV_DIR "${ARGV_JSON}" || return 1
  if lp_argv set "${ARGV_JSON}" "${loc}"; then
    sed -i.bak '/^written=/d' "${LP_ARGV}" && rm -f "${LP_ARGV}.bak" || lp_fail LP_RESTORE_UPDATE || return 1
    printf 'written=%s\n' "$(lp_sum "${ARGV_JSON}")" >> "${LP_ARGV}" || lp_fail LP_RESTORE_UPDATE || return 1
    if [ "${has}" = 1 ]; then
      say_k plain LP_CHANGED "${prev}" "${loc}" "${ARGV_JSON}"
      say_k plain LP_CHANGED_NOTE
    else
      say_k plain LP_SET "${loc}" "${ARGV_JSON}"
      say_k plain LP_SET_NOTE
    fi
  else
    say_k plain LP_ARGV_FAIL "${ARGV_JSON}"
  fi
  return 0
}

# ---- アンインストール用
# Cursor.app を消しても拡張は ~/.cursor/extensions に残る。CLI が無いときは、アプリの有無にかかわらず確認できない。
lp_say_skip() {
  printf '\n'
  say_k plain LP_SKIP "$1"
  say_k plain LP_SKIP_MAYBE
}
lp_say_unchecked() {
  printf '\n'
  say_k plain LP_NO_CLI_CHECK
  say_k plain LP_NO_CLI_HOW
  say_k plain LP_NO_CLI_MAYBE "$1"
}
lp_line_seen() { # $1 既出の行（改行区切り） $2 この行。0 = 既出。
  local blob="$1" line="$2" one
  [ -n "${blob}" ] || return 1
  while IFS= read -r one || [ -n "${one}" ]; do
    [ "${one}" = "${line}" ] && return 0
  done <<EOF
${blob}
EOF
  return 1
}
lp_ext_kept() { # 別プロファイルの拡張フォルダーを --keep で残すとき 0。
  local ext="$1" c
  type is_kept >/dev/null 2>&1 || return 1
  [ -n "${ext}" ] || return 1
  if is_kept "${ext}"; then return 0; fi
  if type canon >/dev/null 2>&1; then c="$(canon "${ext}")"; is_kept "${c}" && return 0; fi
  return 1
}
# 何をするかを表示する（確認の一覧・--dry-run 用）。m は uninstall.sh の m 関数。記録は場所ごとに1行。
langpack_plan() {
  local id="" ext="" line saw=0 seen="" f had prev layer=""
  if [ -f "${LP_OURS}" ]; then
    while IFS= read -r line || [ -n "${line}" ]; do
      [ -n "${line}" ] || continue
      lp_line_seen "${seen}" "${line}" && continue
      seen="${seen}
${line}"
      saw=1
      lp_ours_fields "${line}"
      if [ "${SKIP_LANGPACK:-0}" = 1 ]; then
        lp_say_skip "${id}"
      elif lp_ext_kept "${ext}"; then
        m LP_REMOVE_LAB_KEPT "${id}"
      elif [ -z "${ext}" ] && ! lp_cli_ok; then
        lp_say_unchecked "${id}"
      elif [ -n "${ext}" ]; then
        # CLI が無くても、別プロファイルの行は作業フォルダーごと消える（実削除と同じ。~/.cursor/extensions とは言わない）。
        m LP_REMOVE_LAB "${id}"
      else
        m LP_REMOVE "${id}"
      fi
    done < "${LP_OURS}"
  fi
  if [ "${saw}" = 0 ]; then
    # 言語レイヤー（オーバーレイ）の ID。表示言語 UI_TR_LANG とは別。未記録なら ja。
    layer=""
    if [ -f "${STATE_DIR}/layer-lang" ]; then
      layer="$(tr -d '[:space:]' < "${STATE_DIR}/layer-lang" 2>/dev/null || true)"
    fi
    id="$(langpack_id "${layer:-ja}")"
    [ -n "${id}" ] && m LP_NOT_OURS "${id}"
  fi
  if [ -f "${LP_ARGV}" ]; then
    f="$(lp_state_get file)"; had="$(lp_state_get had)"; prev="$(lp_state_get prev)"
    if [ "${had}" = 1 ]; then m LP_LOCALE_RESTORE "${f}" "${prev}"; else m LP_LOCALE_REMOVE "${f}"; fi
  fi
  return 0
}
# 実行。結果は LP_LEFT（0 = 問題なし / 1 = 残った）。中止の要約は argv.json の復元のあとで出す。
# 0 = 外れた、または元から無かった / 1 = まだ残っている / 2 = 確認できない
lp_remove_ours() {
  local id="$1" st=0
  if ! lp_cli_ok; then lp_say_unchecked "${id}"; return 2; fi
  lp_pack_state "${id}" && st=0 || st=$?
  if [ "${st}" = 2 ]; then
    say_k plain LP_LIST_REMOVE
    return 2
  fi
  [ "${st}" = 1 ] && return 0
  if ! lp_cli --uninstall-extension "${id}" >/dev/null 2>&1; then m LP_LEFT_PACK "${id}"; return 1; fi
  lp_pack_state "${id}" && st=0 || st=$?
  if [ "${st}" = 1 ]; then m LP_REMOVED "${id}"; return 0; fi
  if [ "${st}" = 2 ]; then
    say_k plain LP_LIST_AFTER_REMOVE
    return 2
  fi
  m LP_LEFT_PACK "${id}"
  return 1
}
lp_hand_locale() {
  local had prev
  had="$(lp_state_get had)"; prev="$(lp_state_get prev)"
  say_k plain LP_NO_NODE "${ARGV_JSON}"
  if [ "${had}" = 1 ]; then
    say_k plain LP_HAND_SET "${prev}"
  else
    say_k plain LP_HAND_DEL
  fi
  say_k plain LP_HAND_BAK "${LP_ARGV_ORIG}"
}
lp_abort_restore() {
  say_k plain LP_ABORT
  if lp_no_runtime; then lp_hand_locale; fi
  LP_LEFT=1
  return 1
}
# uninstall.sh は `if ! langpack_undo` から呼ぶ。その間は関数の中で set -e が切れるので、書き込みは || で見る。
# 点検: 同じ形で呼ばれ、利用者のファイルを書く関数はこれと langpack_set_locale / lp_ours_add だけ。
# quit_cursor_gracefully、load_msgs、listener_owned_by_us、is_allowed はファイルを書かない。
# write_session と manifest_add と同意の記録は直接呼ばれるので set -e が有効。
langpack_undo() {
  local id="" ext="" line seen="" kept="" with_folder="" rc_one=0 pack_rc=0 rewrite_rc=0 f had prev existed written now
  LP_LEFT=0
  LP_SKIPPED=0
  if [ -f "${LP_OURS}" ]; then
    while IFS= read -r line || [ -n "${line}" ]; do
      [ -n "${line}" ] || continue
      lp_line_seen "${seen}" "${line}" && continue
      seen="${seen}
${line}"
      lp_ours_fields "${line}"
      LP_EXTDIR="${ext}"
      if [ "${SKIP_LANGPACK:-0}" = 1 ]; then
        LP_SKIPPED=1
        lp_say_skip "${id}"
        kept="${kept}${line}
"
      elif lp_ext_kept "${ext}"; then
        kept="${kept}${line}
"
      elif [ -n "${ext}" ] && ! lp_cli_ok; then
        # 例外: 別プロファイルの中だけにある言語パックは、CLI が無くても作業フォルダーと一緒に削除する（成功）。
        # --keep でそのフォルダーを残すときは、上の lp_ext_kept で残す。
        # 標準プロファイル（ext が空）はここを通らず、CLI が無いと止まる。
        # ほかの行が失敗してフォルダーを消さないときは、あとでこの行も残す。
        with_folder="${with_folder}${line}
"
      else
        lp_remove_ours "${id}" && rc_one=0 || rc_one=$?
        if [ "${rc_one}" != 0 ]; then
          pack_rc="${rc_one}"
          kept="${kept}${line}
"
        fi
      fi
    done < "${LP_OURS}"
    # --skip-langpack のときは記録を書き換えない（作業フォルダーを消すときに一緒に消える）。
    # 別プロファイルの行は、フォルダーを消せるときだけ記録から外す。消せないときは残す。
    if [ "${SKIP_LANGPACK:-0}" != 1 ]; then
      if [ "${pack_rc}" != 0 ]; then kept="${kept}${with_folder}"; fi
      if [ -n "${kept}" ]; then
        printf '%s' "${kept}" > "${LP_OURS}" || lp_fail LP_OWN_UPDATE || rewrite_rc=1
      else
        : > "${LP_OURS}" || lp_fail LP_OWN_UPDATE || rewrite_rc=1
      fi
    fi
  fi
  if [ -f "${LP_ARGV}" ]; then
    f="$(lp_state_get file)"; had="$(lp_state_get had)"; prev="$(lp_state_get prev)"; existed="$(lp_state_get existed)"; written="$(lp_state_get written)"
    now="$(lp_sum "${f}")"
    if [ -n "${written}" ] && [ "${now}" = "${written}" ]; then
      # 変えた後に誰も触っていない: 元のファイルをそのまま戻す（バイト単位で同じ）
      if [ "${existed}" = 1 ]; then
        # バックアップが無い・空・シンボリックリンクのときは、ユーザーの argv.json を消さない
        if [ -f "${LP_ARGV_ORIG}" ] && [ ! -L "${LP_ARGV_ORIG}" ] && [ -s "${LP_ARGV_ORIG}" ]; then
          cp -p "${LP_ARGV_ORIG}" "${f}" || lp_abort_restore || return 1
        else
          say_k plain LP_BACKUP_BAD "${f}"
          if [ -f "${f}" ] && { if [ "${had}" = 1 ]; then lp_argv set "${f}" "${prev}"; else lp_argv remove "${f}"; fi; }; then
            say_k plain LP_LOCALE_ONLY
          else
            lp_abort_restore || return 1
          fi
        fi
      else
        rm -f -- "${f}" || lp_abort_restore || return 1
      fi
    elif [ -f "${f}" ]; then
      # その後に Cursor やユーザーが書き換えた: locale だけを元に戻す（他は触らない）。失敗したらファイルは触らず中止。
      if [ "${had}" = 1 ]; then
        lp_argv set "${f}" "${prev}" || lp_abort_restore || return 1
      else
        lp_argv remove "${f}" || lp_abort_restore || return 1
      fi
    fi
    if langpack_locale_ok; then m LP_LOCALE_DONE "${f}"; else m LP_LEFT_LOCALE "${f}"; LP_LEFT=1; fi
  fi
  if [ "${pack_rc}" != 0 ] || [ "${rewrite_rc}" != 0 ]; then
    say_k plain LP_STOP
    LP_LEFT=1
  fi
  if [ "${LP_LEFT}" = 1 ]; then return 1; fi
  return 0
}
langpack_locale_ok() {   # argv.json の locale が記録した元の状態か
  local f had prev info
  f="$(lp_state_get file)"; had="$(lp_state_get had)"; prev="$(lp_state_get prev)"
  if [ ! -f "${f}" ]; then [ "${had}" != 1 ]; return; fi
  info="$(lp_argv get "${f}" 2>/dev/null)" || return 1
  if [ "${had}" = 1 ]; then case "${info}" in *"\"value\":\"${prev}\""*) return 0 ;; esac; return 1; fi
  case "${info}" in *'"has":true'*) return 1 ;; esac
  return 0
}
