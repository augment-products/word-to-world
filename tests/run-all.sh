#!/usr/bin/env bash
# すべての自動テストを 1 回で実行する / Run every automated test with one command:
#   tests/run-all.sh
# 必要な物: Node 16+、Python 3、（ブラウザーテスト用）Chrome または Chromium（CHROME=パス で指定可）
# bash 3.2（macOS 標準）があれば lab スクリプトをそれでも実行する: BASH32=/path/to/bash-3.2（/opt/bash32/bin/bash は自動検出）
# 実物の Cursor は使わない（偽の Cursor.app と手書きの画面で確かめる）。
set -uo pipefail
cd "$(dirname "$0")/.."
FAILED=()
run() { local name="$1"; shift; echo; echo "===== ${name}"; if "$@"; then :; else FAILED+=("${name}"); fi; }
[ -z "${BASH32:-}" ] && [ -x /opt/bash32/bin/bash ] && export BASH32=/opt/bash32/bin/bash
run "pack validation"   node tools/pack.js validate
if [ -d drafts ] && compgen -G "drafts/*.json" > /dev/null; then run "draft packs (drafts/*.json, not shipped)" node tools/pack.js validate drafts/*.json; fi
run "pack validator"    node tests/test-pack.js
run "english template"  node tests/test-locale-source.js
run "engine (browser)"  node tests/test-engine.js
run "script messages"   node tests/test-script-messages.js
run "update worklists"  python3 tests/test_update_worklists.py
run "shell lint"        bash tests/test-shell-lint.sh
run "lab + uninstall (system bash)" env -u BASH32 bash tests/test-lab-scripts.sh
if [ -n "${BASH32:-}" ]; then run "lab + uninstall (bash 3.2)" bash tests/test-lab-scripts.sh; fi
run "language pack + argv.json (system bash)" env -u BASH32 bash tests/test-langpack.sh
if [ -n "${BASH32:-}" ]; then run "language pack + argv.json (bash 3.2)" bash tests/test-langpack.sh; fi
run "repo hygiene"      bash tests/test-hygiene.sh
echo
if [ ${#FAILED[@]} -eq 0 ]; then echo "ALL TESTS PASSED"; exit 0; fi
echo "FAILED: ${FAILED[*]}"; exit 1
