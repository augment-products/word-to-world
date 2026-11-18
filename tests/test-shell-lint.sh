#!/usr/bin/env bash
# シェルスクリプトの静的検査 / static checks for every shell script (macOS bash 3.2 compatibility)
#  1) ドル記号つき変数の直後に ASCII 以外の文字（日本語など）が続く書き方を禁止する。bash 3.2 は「ドル記号 VAR（」を
#     1 つの変数名と誤解し、set -u で "unbound variable" になる（0.3.0 の start.sh の不具合）。必ず ${VAR} と書く。
#  2) bash -n（構文）と bash --posix -n
#  3) bash 4 以降にしか無い書き方（連想配列・mapfile・${var,,}・&>> など）を禁止
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"; cd "${ROOT}"
PASS=0; FAIL=0
check() { if [ "$2" = 0 ]; then PASS=$((PASS+1)); echo "PASS  $1"; else FAIL=$((FAIL+1)); echo "FAIL  $1"; fi; }
FILES="$(find lab tests -type f \( -name '*.sh' -o -path 'tests/bin/*' \) | sort)"
BAD="$(LC_ALL=C grep -nE '\$([A-Za-z_][A-Za-z0-9_]*|[0-9#?@*$!-])[^ -~[:space:]]' ${FILES} || true)"
[ -n "${BAD}" ] && printf '%s\n' "${BAD}"
check "no \$VAR directly followed by a non-ASCII character (use \${VAR})" "$([ -z "${BAD}" ] && echo 0 || echo 1)"
r=0; for f in ${FILES}; do bash -n "${f}" || { echo "  syntax: ${f}"; r=1; }; done
check "bash -n (syntax) for all scripts" "${r}"
r=0; for f in ${FILES}; do bash --posix -n "${f}" 2>/dev/null || { echo "  posix-mode syntax: ${f}"; r=1; }; done
check "bash --posix -n for all scripts" "${r}"
B4="$(grep -nE 'declare -A|local -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|&>>|\bcoproc\b|\$\{[A-Za-z_]+@[QEPAa]\}' ${FILES} | grep -v 'test-shell-lint.sh' || true)"
[ -n "${B4}" ] && printf '%s\n' "${B4}"
check "no bash-4-only syntax" "$([ -z "${B4}" ] && echo 0 || echo 1)"
# _*.sh は source される共通部分なので set -euo pipefail は不要
SU=0; for f in lab/*.sh; do case "${f}" in */_*.sh) continue ;; esac; head -20 "${f}" | grep -q 'set -euo pipefail' || { echo "  missing set -euo pipefail: ${f}"; SU=1; }; done
check "every lab script uses set -euo pipefail" "${SU}"
if [ -x /opt/bash32/bin/bash ] || [ -n "${BASH32:-}" ]; then
  B32="${BASH32:-/opt/bash32/bin/bash}"; r=0
  for f in ${FILES}; do "${B32}" -n "${f}" || { echo "  bash 3.2 syntax: ${f}"; r=1; }; done
  check "bash 3.2 (${B32}) -n for all scripts" "${r}"
fi
echo "RESULT shell-lint: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" = 0 ]
