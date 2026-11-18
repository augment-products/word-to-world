# スクリプトの表示言語。_common.sh から source する。単体では実行しない。
# 優先順位:
#   1. UI_TR_LANG（メッセージだけを上書き。--lang より優先）
#   2. 親プロセスが既に決めた UI_LANG（UI_LANG_READY=1）
#   3. このコマンドの --lang
#   4. 保存した state/ui-lang
#   5. システムの言語: AppleLanguages、次に LC_ALL、次に LANG
#   6. 英語
# 台帳は lab/messages/ui.<lang>.sh と uninstall.<lang>.sh。
# 言語ファイルが無い、またはキーが無いときは英語。zh-cn / zh-tw / ko などはファイルを足す。
# bash 3.2。連想配列は使わない。

ui_norm_lang() {
  local raw="$1"
  raw="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
  raw="${raw%%.*}"
  case "${raw}" in
    ja|ja-*) printf 'ja\n' ;;
    zh-cn|zh-hans|zh-sg|zh) printf 'zh-cn\n' ;;
    zh-tw|zh-hk|zh-mo|zh-hant) printf 'zh-tw\n' ;;
    ko|ko-*) printf 'ko\n' ;;
    pt-br|pt|pt-*) printf 'pt-br\n' ;;
    fr|fr-*) printf 'fr\n' ;;
    de|de-*) printf 'de\n' ;;
    es|es-*) printf 'es\n' ;;
    it|it-*) printf 'it\n' ;;
    ru|ru-*) printf 'ru\n' ;;
    cs|cs-*) printf 'cs\n' ;;
    tr|tr-*) printf 'tr\n' ;;
    pl|pl-*) printf 'pl\n' ;;
    en|en-*|c|posix|"") printf 'en\n' ;;
    *) printf 'en\n' ;;
  esac
}

ui_apple_lang() {
  local raw line
  command -v defaults >/dev/null 2>&1 || return 1
  raw="$(defaults read -g AppleLanguages 2>/dev/null || true)"
  [ -n "${raw}" ] || return 1
  line="$(printf '%s\n' "${raw}" | sed -n 's/.*"\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "${line}" ] || return 1
  printf '%s\n' "${line}"
}

ui_system_raw() {
  local apple
  if apple="$(ui_apple_lang)"; then printf '%s\n' "${apple}"; return 0; fi
  if [ -n "${LC_ALL:-}" ]; then printf '%s\n' "${LC_ALL}"; return 0; fi
  if [ -n "${LANG:-}" ]; then printf '%s\n' "${LANG}"; return 0; fi
  printf 'en\n'
}

ui_load_file() { # $1=ファイル。UI_<KEY> を上書きする。
  local f="$1" line k v
  [ -f "${f}" ] || return 1
  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      ''|\#*) continue ;;
      [A-Z0-9_]*=*)
        k="${line%%=*}"
        v="${line#*=}"
        v="${v#\'}"; v="${v%\'}"
        eval "UI_${k}=\$v"
        ;;
    esac
  done < "${f}"
}

ui_load() {
  local dir="${KIT_DIR}/lab/messages"
  ui_load_file "${dir}/ui.en.sh" || true
  if [ "${UI_LANG}" != en ]; then
    ui_load_file "${dir}/ui.${UI_LANG}.sh" || true
  fi
}

ui_prepare() { # $1 = このコマンドの --lang。空なら使わない。
  local raw="" saved=""
  if [ -n "${UI_TR_LANG:-}" ]; then
    raw="${UI_TR_LANG}"
  elif [ "${UI_LANG_READY:-}" = 1 ] && [ -n "${UI_LANG:-}" ]; then
    raw="${UI_LANG}"
  elif [ -n "${1:-}" ]; then
    raw="$1"
  elif [ -f "${STATE_DIR}/ui-lang" ]; then
    saved="$(cat "${STATE_DIR}/ui-lang" 2>/dev/null || true)"
    raw="${saved}"
  else
    raw="$(ui_system_raw)"
  fi
  UI_LANG="$(ui_norm_lang "${raw}")"
  export UI_LANG UI_LANG_READY=1
  ui_load
}

ui_prepare_args() {
  local prev="" a explicit=""
  for a in "$@"; do
    if [ "${prev}" = "--lang" ]; then explicit="${a}"; break; fi
    prev="${a}"
  done
  ui_prepare "${explicit}"
}

ui_save() {
  mkdir -p "${STATE_DIR}" 2>/dev/null || return 0
  printf '%s\n' "${UI_LANG}" > "${STATE_DIR}/ui-lang" 2>/dev/null || true
  return 0
}

text_k() { # KEY [printf の引数...]
  local key="$1" var fmt
  shift
  var="UI_${key}"
  fmt="${!var-}"
  if [ -z "${fmt}" ]; then fmt="${key}"; fi
  printf -- "${fmt}" "$@"
}

say_k() { # plain|bold|hot|prompt KEY [引数...]
  local style="$1" key text
  shift
  key="$1"
  shift
  text="$(text_k "${key}" "$@")"
  case "${style}" in
    bold) say_bold "${text}" ;;
    hot) say_hot "${text}" ;;
    prompt) say_prompt "${text}" ;;
    *) say "${text}" ;;
  esac
}

fail_k() { # 終了コード KEY [引数...]
  local code="$1" key
  shift
  key="$1"
  shift
  fail "$(text_k "${key}" "$@")" "${code}"
}
