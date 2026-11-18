#!/usr/bin/env bash
set -euo pipefail
# このツールが作った物を「細かい物まで」すべて消す。 / Removes everything this tool created.
#   使い方 / usage: lab/uninstall.sh [--dry-run] [--yes] [--keep-kit] [--keep PATH]... [--include-legacy-lab] [--include-backups] [--skip-langpack] [--port 9333]
#   メッセージは 1 言語。--lang、保存した state/ui-lang、システムの言語、英語の順。UI_TR_LANG があればそれを優先。
#   --dry-run   何を消すか表示するだけ（何も止めない・消さない）
#   --yes       確認なしで実行（将来のダブルクリック用アプリ向け。アプリ側で確認ダイアログを出す）
#   --keep-kit  展開したキット（このスクリプトがあるフォルダー）は残す
#   --keep PATH 指定した場所（とその中身）は消さない。何度でも指定できる（例: --keep "~/Library/Application Support/word-to-world/logs"）
#   --include-legacy-lab  試作版の作業フォルダー ~/cursor-i18n-work も消す（既定では消さない。
#               Cursor のコピーやバックアップなど、ご自身の物が入っていることがあるため。中身を確認してから）
#   --skip-langpack  言語パックの確認と削除を省略する（既定は省略しない）。CLI が無いときはアプリの有無にかかわらず止まる。
#               省略したときは ~/.cursor/extensions に残っている場合がある、と表示する（「もう無い」とは言わない）。
#   --include-backups  アップグレード時に作った古いキットの退避フォルダー ~/ui-translator-kit*.bak も消す
#               （既定では一覧に「消さない」と表示するだけ。キットの印 .cursor-i18n-kit がある物だけが対象）
# 手順: 1) 消す物の一覧を表示 → 2) 「yes」と入力して確認 → 3) 注入ツールと翻訳用の Cursor を止め、
#       デバッグポートが閉じたことを確認 → 4) 削除 → 5) 何も残っていないことを確認して表示
# 絶対に消さない物: /Applications/Cursor.app、普段の Cursor のデータ
#   （~/Library/Application Support/Cursor、~/.cursor）、その他このツールが作っていない物。
# 終了コード: 0 完了 / 1 残った物がある、または言語パックを確認できず中止 / 2 使い方の誤り / 5 取り消し / 6 安全のため中止
#   --skip-langpack の 0 は作業フォルダーを消したという意味で、言語パックは ~/.cursor/extensions に残っている場合がある。
# Cursor は「普通に終了」させるだけ（⌘Q、または Cursor メニューから終了。強制終了はしない）。終了しない、または元に戻せないときは、削除せずに止まる。
# 例外（元に戻すだけ）: setup で選んだときに入れた Microsoft の言語パック（記録があるときだけ外す。ご自身で入れた物は外さない）と、
#   ~/.cursor/argv.json の "locale"（記録した元の値に戻す。元が無ければ消す。ほかの設定・コメントは触らない）。
HERE="$(cd "$(dirname "$0")" && pwd -P)"
source "$HERE/_common.sh"
source "$HERE/_langpack.sh"
ui_prepare_args "$@"

# ---- メッセージは 1 言語。英語を読んでから、その言語のファイルで上書きする。
load_um() { # $1=lang
  local f="$HERE/messages/uninstall.$1.sh" line k v
  [ -f "$f" ] || return 1
  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      ''|\#*) continue ;;
      UM_*=*) k="${line%%=*}"; v="${line#*=}"; v="${v#\'}"; v="${v%\'}"; eval "${k}=\$v" ;;
    esac
  done < "${f}"
}
load_um en || true
[ "${UI_LANG}" = en ] || load_um "${UI_LANG}" || true
LAYER_LANG=""
if [ -f "${STATE_DIR}/layer-lang" ]; then
  LAYER_LANG="$(tr -d '[:space:]' < "${STATE_DIR}/layer-lang" 2>/dev/null || true)"
fi
[ -n "${LAYER_LANG}" ] || LAYER_LANG=ja
layer_file="${KIT_DIR}/locales/${LAYER_LANG}.json"
[ -f "${layer_file}" ] || layer_file="${KIT_DIR}/locales/ja.json"
DISP=""
if disp="$(display_name "${layer_file}")"; then DISP="${disp}"; fi
m() { # m KEY [args...]  選択した 1 言語だけ
  local k="$1"; shift
  local var="UM_${k}" fmt text
  fmt="${!var-}"
  [ -n "${fmt}" ] || fmt="${k}"
  text="$(printf -- "${fmt}" "$@")"
  if [ "${M_GAP:-0}" = 1 ]; then printf '\n'; fi
  M_GAP=1
  case "${text}" in
    OK:*) say "${text}"; return 0 ;;
  esac
  case "${k}" in
    LIST|ASK) say_hot "${text}" ;;
    DONE|DONE_KEEP|DONE_SKIP_LP|DONE_SKIP_LP_KEEP) say_bold "${text}" ;;
    *) say "${text}" ;;
  esac
  return 0
}

DRY=0; YES=0; KEEP_KIT=0; PORT=""; INC_LEGACY=0; INC_BAK=0; SKIP_LANGPACK=0; KEEPS=()
# 実際の場所に直す（/tmp と /private/tmp、シンボリックリンクなどの重複をなくす）。macOS 標準の bash 3.2 でも動く書き方
canon() {
  local p="$1" d b
  p="${p%/}"; [ -n "${p}" ] || { printf '/\n'; return 0; }
  if [ -d "${p}" ] && [ ! -L "${p}" ]; then (cd -P -- "${p}" 2>/dev/null && pwd -P) || printf '%s\n' "${p}"; return 0; fi
  d="$(dirname -- "${p}")"; b="$(basename -- "${p}")"
  if [ -d "${d}" ]; then d="$(cd -P -- "${d}" 2>/dev/null && pwd -P)" || d="$(dirname -- "${p}")"; fi
  [ "${d}" = / ] && d=""
  printf '%s/%s\n' "${d}" "${b}"
}
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --yes|-y) YES=1; shift ;;
    --keep-kit) KEEP_KIT=1; shift ;;
    --keep) [ -n "${2:-}" ] || { m BADOPT "$1" >&2; exit 2; }; KEEPS+=("$(canon "${2}")"); shift 2 ;;
    --include-legacy-lab) INC_LEGACY=1; shift ;;
    --include-backups) INC_BAK=1; shift ;;
    --skip-langpack) SKIP_LANGPACK=1; shift ;;
    --port) PORT="${2:?}"; shift 2 ;;
    --lang) [ -n "${2:-}" ] || { m BADOPT "$1" >&2; exit 2; }; shift 2 ;;
    --help|-h)
      say_k plain HELP_UNINSTALL
      say_k plain HELP_LANG_1
      say_k plain HELP_LANG_2
      exit 0 ;;
    *) m BADOPT "$1" >&2; exit 2 ;;
  esac
done
guard_lab_dir
PORTS="$DEFAULT_PORT"
[ -n "$PORT" ] && { check_port "$PORT"; PORTS="$PORTS $PORT"; }
[ -f "$STATE_DIR/port" ] && PORTS="$PORTS $(cat "$STATE_DIR/port" 2>/dev/null | tr -cd '0-9')"

# ---- 絶対に消してはいけない場所
REAL_PROFILE="$HOME/Library/Application Support/Cursor"
is_forbidden() {
  case "$1" in
    ""|/|/Applications|/Applications/*|/System|/System/*|/Library|/Library/*|/usr|/usr/*|/bin/*|/sbin/*|/private|/private/var|/tmp|/private/tmp) return 0 ;;
    "$HOME"|"$HOME/"|"$HOME/Applications"*|"$HOME/.cursor"|"$HOME/.cursor/"*|"$REAL_PROFILE"|"$REAL_PROFILE/"*|"$HOME/Library"|"$HOME/Desktop"|"$HOME/Documents"|"$HOME/Downloads") return 0 ;;
  esac
  return 1
}
# ---- 消してよい場所か（実験用フォルダーの中 / 印のあるキット / 既知の一時ファイル）
TMPD="${TMPDIR:-/tmp}"; TMPD="${TMPD%/}"; TMPD="$(canon "${TMPD}")"
C_HOME="$(canon "${HOME}")"; C_LAB_DIR="$(canon "${LAB_DIR}")"; C_LEGACY="$(canon "${LEGACY_LAB_DIR}")"; C_KIT="$(canon "${KIT_DIR}")"
is_kept() {   # その場所自体、または中に --keep の場所を含む
  local p="$1" k
  for k in ${KEEPS[@]+"${KEEPS[@]}"}; do
    case "${p}" in "${k}"|"${k}"/*) return 0 ;; esac
    case "${k}" in "${p}"/*) return 0 ;; esac
  done
  return 1
}
legacy_is_ours() {
  [ -d "$LEGACY_LAB_DIR" ] && [ "$LEGACY_LAB_DIR" != "$LAB_DIR" ] || return 1
  [ -e "$LEGACY_LAB_DIR/Cursor-Lab.app" ] || [ -d "$LEGACY_LAB_DIR/lab-profile" ] || [ -f "$LEGACY_LAB_DIR/.cursor-i18n-lab" ]
}
# 古いキットの退避フォルダー（例 ~/ui-translator-kit-0.3.1.bak）。名前だけでなく中身（キットの印・git でない）でも確かめる
list_backups() {
  local g
  for g in "${HOME}"/ui-translator-kit*.bak; do
    [ -d "${g}" ] && [ ! -L "${g}" ] || continue
    canon "${g}"
  done
  return 0
}
is_backup_path() { [ "$1" = "${C_KIT}" ] && return 1; case "$1" in "${HOME}"/ui-translator-kit*.bak|"${C_HOME}"/ui-translator-kit*.bak) return 0 ;; esac; return 1; }
# git の作業ツリー（自身か親に .git）は消さない
path_in_git() { in_git_work_tree "$1"; }
# キットの親フォルダーは消さない（親を消すとキットも消える）。
# キット本体は、.git が無い配布物のときだけ後段で消す。git の作業ツリーは path_in_git が先に拒否する。
path_is_kit_ancestor() {
  case "${C_KIT}" in "$1"/*) return 0 ;; esac
  return 1
}
path_is_legacy_lab() {
  case "$1" in "$LEGACY_LAB_DIR"|"$LEGACY_LAB_DIR"/*|"${C_LEGACY}"|"${C_LEGACY}"/*) return 0 ;; esac
  return 1
}
# 空のまま引き継いだ作業フォルダーか。印の行か、state の記録のどちらか。
runtime_was_adopted_empty() {
  if [ -f "${STATE_DIR}/adopted-empty-dir" ]; then return 0; fi
  if [ -f "${LAB_MARKER}" ] && grep -qx 'adopted-empty=1' "${LAB_MARKER}"; then return 0; fi
  return 1
}
# 作業フォルダーの所有印（setup が書く）。この印があるディレクトリだけを消してよい。
path_has_ownership_marker() {
  [ -d "$1" ] || return 1
  [ -f "$1/.word-to-world-lab" ] || [ -f "$1/.cursor-i18n-lab" ]
}
# 印のあるディレクトリ自身、またはその中。名前が作業フォルダーでも、印が無ければ消さない。
# 削除の途中で印ファイル自体を消しても、計画時に OWNED へ写したパスは消してよい。
path_is_owned_runtime() {
  local d="$1"
  if [ -f "${OWNED:-}" ] && grep -Fxq -- "$1" "$OWNED"; then return 0; fi
  if [ ! -d "$d" ]; then d="$(dirname -- "$d")"; fi
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    path_has_ownership_marker "$d" && return 0
    d="$(dirname -- "$d")"
  done
  return 1
}
path_is_marked_kit() {
  [ -d "$1" ] || return 1
  [ -e "$1/.git" ] && return 1
  [ -f "$1/.word-to-world-kit" ] || [ -f "$1/.cursor-i18n-kit" ]
}
# 一時ファイルは、マニフェストに記録されたパスだけ。名前のパターン（i18n-probe*）では消さない。
# 記録は RECORDED に写してから消す。作業フォルダーを先に消すとマニフェストも消え、再確認で一時ファイルを取りこぼす。
path_is_recorded_temp() {
  local dir
  dir="$(dirname -- "$1")"
  case "$dir" in /tmp|/private/tmp|"$TMPD") ;; *) return 1 ;; esac
  [ -f "${RECORDED:-}" ] || return 1
  grep -Fxq -- "$1" "$RECORDED"
}
# 消してよいか。危険な場所の拒否を、作業フォルダーを許可する判断より先に行う。
is_allowed() {
  local p="$1"
  if is_forbidden "$p"; then return 1; fi
  if path_in_git "$p"; then return 1; fi
  if [ -d "$p" ] && dir_contains_nested_git "$p"; then return 1; fi
  if path_is_kit_ancestor "$p"; then return 1; fi
  if path_is_legacy_lab "$p"; then
    [ "${INC_LEGACY}" = 1 ] && legacy_is_ours && return 0
    return 1
  fi
  if is_backup_path "$p" && [ "${INC_BAK}" != 1 ]; then return 1; fi
  if path_is_owned_runtime "$p"; then return 0; fi
  if path_is_marked_kit "$p"; then return 0; fi
  if path_is_recorded_temp "$p"; then return 0; fi
  return 1
}

# ---- 候補を集める: manifest + 既定の場所 + 一時ファイル
CAND="$(mktemp "${TMPD}/uitr-uninstall.XXXXXX")"
RECORDED="$(mktemp "${TMPD}/uitr-recorded.XXXXXX")"
OWNED="$(mktemp "${TMPD}/uitr-owned.XXXXXX")"
trap 'rm -f "$CAND" "$RECORDED" "$OWNED"' EXIT
if [ -f "$MANIFEST" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    path="${line%%$'\t'*}"
    [ -n "$path" ] || continue
    c="$(canon "$path")"
    d="$(dirname -- "$c")"
    case "$d" in /tmp|/private/tmp|"$TMPD") printf '%s\n' "$c" ;; esac
  done < "$MANIFEST" > "$RECORDED"
fi
{
  [ -f "$MANIFEST" ] && grep -v '^#' "$MANIFEST" | cut -f1
  [ "${INC_LEGACY}" = 1 ] && legacy_is_ours && printf '%s\n' "$LEGACY_LAB_DIR"
  [ "${INC_BAK}" = 1 ] && list_backups
  printf '%s\n' "$LAB_DIR" "$LAB_APP" "$LAB_PROFILE" "$LAB_EXT" "$LOG_DIR" "$STATE_DIR" "$PID_FILE" "$MANIFEST" "$LAB_MARKER"
  [ "$KEEP_KIT" = 0 ] && printf '%s\n' "$KIT_DIR"
  true
} 2>/dev/null | while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ "$p" = "$CAND" ] && continue
  p="$(canon "${p}")"
  [ "$KEEP_KIT" = 1 ] && [ "$p" = "${C_KIT}" ] && continue
  printf '%s\n' "$p"
done | awk '!seen[$0]++' > "$CAND.all"
trap 'rm -f "$CAND" "$CAND.all" "$CAND.left" "$RECORDED" "$OWNED"' EXIT

DEL=(); REFUSED=(); KEPT=(); LEGACY_SKIP=""; BAK_SKIP=()
while IFS= read -r p; do
  if [ ! -e "${p}" ] && [ ! -L "${p}" ]; then continue; fi
  if is_backup_path "${p}" && [ "${INC_BAK}" != 1 ]; then continue; fi
  case "${p}" in "${C_LEGACY}"|"${C_LEGACY}"/*) if [ "${INC_LEGACY}" != 1 ]; then LEGACY_SKIP=1; continue; fi ;; esac
  if is_kept "${p}"; then { [ -e "${p}" ] || [ -L "${p}" ]; } && KEPT+=("${p}"); continue; fi
  # 空のまま引き継いだフォルダー自体は残す。中の、このツールが作った物だけ消す。
  if [ "${p}" = "${C_LAB_DIR}" ] && runtime_was_adopted_empty; then KEPT+=("${p}"); continue; fi
  if is_allowed "$p"; then
    [ -e "$p" ] || [ -L "$p" ] && DEL+=("$p")
    path_is_owned_runtime "$p" && printf '%s\n' "$p" >> "$OWNED"
  else REFUSED+=("$p"); fi
done < "$CAND.all"
# 親フォルダーが一覧にあるなら子は省略して表示（消す範囲は同じ）
SHOW=()
for p in ${DEL[@]+"${DEL[@]}"}; do
  covered=0
  for q in ${DEL[@]+"${DEL[@]}"}; do [ "$p" != "$q" ] && case "$p" in "$q"/*) covered=1 ;; esac; done
  [ "$covered" = 0 ] && SHOW+=("$p")
done

m TITLE "${DISP}"
LPIDS="$(lab_pids | tr '\n' ' ')"; IPIDS="$(inject_pids | tr '\n' ' ')"
m PROCS "${IPIDS:--}" "${LPIDS:--}"
m PORTS "$(printf '%s\n' $PORTS | sort -u | tr '\n' ' ')"
if [ ${#SHOW[@]} -eq 0 ]; then m NOTHING
else
  m LIST "${#SHOW[@]}"
  for p in "${SHOW[@]}"; do
    if [ -d "$p" ]; then sz="$(du -sh "$p" 2>/dev/null | cut -f1)"; else sz="$(du -sh "$p" 2>/dev/null | cut -f1)"; fi
    say "  - $p  (${sz:-?})"
  done
fi
if [ ${#KEPT[@]} -gt 0 ]; then
  m KEPT_HDR; for p in "${KEPT[@]}"; do say "  = ${p}"; done
fi
if [ "${INC_LEGACY}" != 1 ] && [ -d "${LEGACY_LAB_DIR}" ] && [ "${C_LEGACY}" != "${C_LAB_DIR}" ]; then LEGACY_SKIP=1; fi
if [ -n "${LEGACY_SKIP}" ]; then m LEGACY_SKIPPED "${LEGACY_LAB_DIR}"; fi
if [ "${INC_BAK}" != 1 ]; then
  while IFS= read -r p; do [ -n "${p}" ] && BAK_SKIP+=("${p}"); done < <(list_backups)
  if [ ${#BAK_SKIP[@]} -gt 0 ]; then
    m BACKUPS_SKIPPED; for p in "${BAK_SKIP[@]}"; do say "  · ${p}  ($(du -sh "${p}" 2>/dev/null | cut -f1))"; done
  fi
fi
if [ "${INC_LEGACY}" = 1 ]; then
  if legacy_is_ours; then m LEGACY_WARN "${LEGACY_LAB_DIR}" "$(du -sh "${LEGACY_LAB_DIR}" 2>/dev/null | cut -f1)"
  elif [ -d "${LEGACY_LAB_DIR}" ]; then m LEGACY_NOT_OURS "${LEGACY_LAB_DIR}"; fi
fi
if [ ${#REFUSED[@]} -gt 0 ]; then
  m REFUSED; for p in "${REFUSED[@]}"; do say "  × $p"; done
fi
langpack_plan
m KEEP "$SRC_APP" "$REAL_PROFILE" "$HOME/.cursor"
m SHARED

if [ "$DRY" = 1 ]; then m DRYRUN; exit 0; fi

if [ "$YES" != 1 ]; then
  if [ ! -t 0 ] && [ -z "${UNINSTALL_ASSUME_TTY:-}" ]; then m NOTTY >&2; exit 5; fi
  m ASK
  read -r ans || ans=""
  [ "$ans" = "yes" ] || { m CANCEL; exit 5; }
fi

# ---- 1) 注入ツールを止める（英語に戻してから終わる）
for pid in $IPIDS $( [ -f "$PID_FILE" ] && cat "$PID_FILE" 2>/dev/null ); do
  if kill -0 "$pid" 2>/dev/null && ps -p "$pid" -o command= 2>/dev/null | grep -q inject.js; then
    m STOP_INJ "$pid"; kill -INT "$pid" 2>/dev/null || true
    for _ in $(seq 1 10); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
  fi
done
# ---- 2) 翻訳用の Cursor を終了（実行ファイルが実験用コピーの中にあるプロセスだけ）
# 終了を確認できるまで、復元も削除もしない（別プロファイルのフォルダーを起動中に消さない）
if [ -n "$(lab_pids)" ]; then
  m STOP_CURSOR
  if ! quit_cursor_gracefully lab_pids || [ -n "$(lab_pids)" ]; then
    m QUIT_FAILED "${QUIT_TIMEOUT}"
    say_k plain UN_STILL
    exit 1
  fi
fi
# ---- 2b) 言語パック（このツールが入れた物だけ）と argv.json の locale を元に戻す（作業フォルダーの記録を消す前に）
LP_LEFT=0
if ! langpack_undo || [ "${LP_LEFT}" = 1 ]; then
  say_k plain UN_RESTORE
  exit 1
fi
# ---- 3) Launch Services の登録を外す（macOS のみ・あれば）
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREG" ] && [ -d "$LAB_APP" ]; then "$LSREG" -u "$LAB_APP" >/dev/null 2>&1 || true; fi
# ---- 4) 削除
for p in ${SHOW[@]+"${SHOW[@]}"}; do
  is_allowed "$p" || continue          # 念のため直前にもう一度確認
  rm -rf -- "$p" && m DELETED "$p"
done

# ---- 5) 確認
LEFT=0
m VERIFY
[ "${LP_LEFT}" = 1 ] && LEFT=1
for p in ${DEL[@]+"${DEL[@]}"}; do if [ -e "$p" ] || [ -L "$p" ]; then m LEFT "$p"; LEFT=1; fi; done
[ -n "$(lab_pids)" ] && { m LEFT_PROC "$(lab_pids | tr '\n' ' ')"; LEFT=1; }
[ -n "$(inject_pids)" ] && { m LEFT_INJ; LEFT=1; }
for pt in $(printf '%s\n' $PORTS | sort -u); do
  if port_listening "$pt"; then m LEFT_PORT "$pt"; LEFT=1; fi
done
[ -e "$SRC_APP" ] && m REAL_OK "$SRC_APP"
kept_requested=0
if [ ${#KEEPS[@]} -gt 0 ] && [ ${#KEPT[@]} -gt 0 ]; then
  for p in ${KEPT[@]+"${KEPT[@]}"}; do
    if is_kept "${p}"; then kept_requested=1; break; fi
  done
fi
if [ "$LEFT" = 0 ]; then
  if [ "${LP_SKIPPED:-0}" = 1 ]; then
    if [ "${kept_requested}" = 1 ]; then m DONE_SKIP_LP_KEEP; else m DONE_SKIP_LP; fi
    exit 0
  fi
  if [ "${kept_requested}" = 1 ]; then m DONE_KEEP; else m DONE; fi
  exit 0
fi
m PARTIAL; exit 1
