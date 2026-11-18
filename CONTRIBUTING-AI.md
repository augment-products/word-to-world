# CONTRIBUTING-AI.md — AI が言語レイヤーを作る・更新するときの手順書

この文書は、AI（または人）が `locales/<lang>.json` を**作成・更新**するときに必ず従う手順です。
最後に必ず検査コマンドを実行し、エラー 0 を確認してから提出してください。

## 0. 守ること（最重要）
1. **Cursor のコードを貼らない。Cursor のアプリのファイルや、生の文字列の一覧をリポジトリに入れない。** 主な入力は、
   画面から記録したキャプチャ（`--capture` / `watch`）・作業リスト（`work/worklists/<lang>.worklist.json`）・既存の言語レイヤー・用語集。
   辞書は、Cursor の UI の英語と、その日本語訳です。識別子・ログ・VS Code 本体の文字は入れない。
2. 翻訳するのは**表示される文字だけ**。設定のキー名・コマンド ID・エラーの内部コード・ファイル名・URL は訳さない。
3. **分かりやすさ優先**: その言語の、英語が分からない人が読んで分かる言葉にする。日本で（その国で）広く通じていない英単語は、カタカナ等で残さず訳す。
4. ブランド名・製品名・規格名は訳さない → `glossary/do-not-translate.txt`（Cursor, GitHub, MCP, VS Code など）。
5. 用語は `glossary/<lang>.md` に従う。新しい用語を決めたら、その表に追記してから言語レイヤーに反映する（表記ゆれを作らない）。

## 1. ファイル形式（schemaVersion 1）
```json
{
  "$schema": "../schema/locale-pack.schema.json",
  "schemaVersion": 1,
  "meta": { "lang": "ja", "name": "Japanese", "nativeName": "日本語", "packVersion": "0.3.9",
            "cursorVersion": "3.27.22", "updated": "2026-11-02", "scope": "all",
            "maintainers": [], "glossary": "glossary/ja.md" },
  "exact":    { "Window Restoration": "ウィンドウの復元" },
  "patterns": { "Open {0}": "{0} を開く" },
  "scoped":   []
}
```
- ファイル名は `meta.lang` と同じ（`ja` → `ja.json`）。英語は基準なので言語レイヤーを作らない。表示名は `Word to World for Cursor | ` に `meta.name` と ` Language Layer` を足した物（日本語なら `Word to World for Cursor | Japanese Language Layer`）。
- **キー = 画面に出る英語そのもの**（前後の空白は除く。大文字・小文字・記号も完全一致）。
- `exact` は完全一致で置き換える。`patterns` は `{0}` `{1}` を含む文（例: `"Remove {0}"`）。
- `scoped` は「特定の場所でだけ訳す」ための物（CSS セレクター + exact）。通常は使わない。
- 訳を空にしない。訳さない場合はキーごと書かない。英語と同じ訳は書かない（不要）。
- HTML タグ・制御文字を入れない。同じキーを 2 回書かない。

## 2. {0} の扱い
- 英語にある `{0}` `{1}` を**同じ番号・同じ数**だけ訳に入れる。位置は自然な語順に動かしてよい。
  - `"Delete \"{0}\"?"` → `"「{0}」を削除しますか？"`
- `{0}` の中身（ファイル名・数・キー名など）は実行時に入るので、訳の中で推測して書き足さない。
- `{0}` の直後の単位や助詞はその言語の規則で（日本語: 英数字との間に半角スペース）。

## 3. 作業の流れ
### 新しい言語を作る
1. `node tools/new-locale.js <id>` を実行する。正本は `templates/locale-template.json`。キーは変えない。`locales/ja.json` はコピーしない。
2. 空欄を訳す。`meta.lang` はファイル名と揃っている。`meta.cursorVersion` は正本と同じにする。
3. `glossary/<lang>.md` を作る（表記ルール + 用語の決定 + 自信が低い訳）。
4. スクリプトの表示は 1 言語。`lab/messages/ui.en.sh` と `lab/messages/uninstall.en.sh` を `ui.<lang>.sh` / `uninstall.<lang>.sh` にコピーし、値だけ訳す（キー名・`%s` の数は変えない）。`tools/script-messages.js` の `MESSAGES` にも同じ言語を足す。無いファイルやキーは英語に戻る。
5. `node tools/pack.js validate` と `node tools/sync-locale.js <id> --check` を通す。空の訳が残るファイルは `locales/` に置かない。`verification/` はこのリポジトリに含まれていません。

### Cursor の新しい版に合わせて更新する
1. 作業リストを読む: `work/worklists/<lang>.worklist.json`（`tools/update_worklists.py` が全言語分を作る）。
2. 状態ごとの対応:
   - `new` → `section`（exact / patterns）に訳を追加
   - `changed` → `previous_english` のキーを消し、`english` をキーにして追加。`previous_translation` を元に、変わった部分だけ直す
   - `removed` → そのキーを消す
   - `unverified` → 変更しない（人が実画面で確認する）
   - `backlog` → 任意
3. `meta.packVersion` を上げ（訳の追加 = 2 桁目、修正のみ = 3 桁目）、`meta.cursorVersion` と `meta.updated` を更新する。

## 4. 検査（必ず実行）
```bash
node tools/pack.js validate                 # 全言語レイヤー。エラー 0 が条件（警告は内容を確認）
node tools/pack.js validate locales/ko.json # 1 つだけ
tests/run-all.sh                            # 全テスト
```
終了コード: 0 = OK / 1 = エラーあり / 2 = 使い方の誤り。

## 5. 提出物
- 変更した言語レイヤー（出荷するものは `locales/<lang>.json`。未完成の下書きは出荷しない）
- 更新した `glossary/<lang>.md`
- 「自信が低い訳」の一覧（英語 / 訳 / 理由）
- 検査結果（`node tools/pack.js validate` の出力）

## 6. アンインストールについて
ツールが作る物はすべて `~/Library/Application Support/word-to-world/install-manifest.txt` に記録され、`lab/uninstall.sh` が記録と既定の場所から全部消します。
新しいスクリプトでファイルやフォルダーを作る場合は、必ず `manifest_add <パス> <説明>`（`lab/_common.sh`）で記録し、`tests/test-lab-scripts.sh` に「アンインストール後に残っていない」確認を追加してください。
`/Applications/Cursor.app`、`~/Library/Application Support/Cursor`、`~/.cursor` には決して書き込まない・消さないこと（既定の normal モードは標準プロファイルで動くので、特に注意）。
唯一の例外（0.3.6〜、利用者が選んだときだけ）: `lab/_langpack.sh` が Microsoft 公式の言語パックを `cursor --install-extension` で入れる（標準プロファイルでは `~/.cursor/extensions`）。
あわせて `~/.cursor/argv.json` の `"locale"` キー 1 つだけを `tools/argv-locale.js` で書き換える（コメント・ほかのキーは 1 バイトも変えない。書く前に元ファイルを `state/argv.json.orig`
に保存し、元の値または「無かった」ことを `state/argv-locale.state` に記録）。`lab/uninstall.sh` は所有の記録があるパックだけを外し（このツールを使う前にご自身で入れたパックは外さない）、locale を元の値に戻す（無かったなら消す）。この範囲を広げないこと。テストは
`tests/test-langpack.sh`（偽の cursor CLI）。
Cursor を止めるときは「普通に終了」（⌘Q、または Cursor メニューから終了。`quit_cursor_gracefully`）だけを使い、強制終了（kill -9）はしない。

## 7. シェルスクリプトの書き方（macOS の bash 3.2）
- 文字列の中の変数は必ず `${VAR}` と書く。`$VAR` の直後に日本語などが続くと、bash 3.2 は変数名の一部と誤解して `unbound variable` で止まる（0.3.0 の不具合）。`tests/test-shell-lint.sh` が検査する。
- 連想配列・`mapfile`・`${var,,}` など bash 4 以降の書き方は使わない。空の配列は `${A[@]+"${A[@]}"}` で展開する。
- スクリプトの表示は 1 言語。台帳は `lab/messages/ui.<lang>.sh` と `lab/messages/uninstall.<lang>.sh`。`--lang`、保存した `state/ui-lang`、システムの言語、英語の順。`UI_TR_LANG` は表示だけを上書きする。注入ツールの人向けの 1 行は `tools/script-messages.js`。

## 8. 設定画面の外を訳すとき（scoped グループ）
- 設定画面の外では、辞書全体（exact / patterns）は使われない。訳すには `scoped` に**グループ**を足す:
  `{"id": "...", "area": "agents|editor|settings", "note": "...", "selector": "<CSS>", "deny": "<CSS>", "attrs": [], "exact": {...}}`
- `selector` は**固定の表示だけ**を指す狭いものにする（例: `[data-component="workspace-sidebar"] [data-sidebar-primary-action]`）。
  チャット行・プロジェクト行・タイトル・メニューの検索欄などユーザーのデータが入る場所は `deny`、または `tools/inject.js` の共通の DENY に入れる。
- `attrs` を書かないと、設定画面の外では属性（aria-label など）を訳さない。aria-label は Cursor 自身が要素を探すのに使うことがあるので、必要なときだけ。
- `--scope settings`（`lab/start.sh --settings-only`）のときは area が settings のグループだけが使われる。
- 新しいグループには、**ユーザーのデータが変わらないこと**を確かめるテスト（`tests/fixtures/workbench-agents.html` と `tests/test-engine.js`）を必ず足す。
- 0.3.3 から使える項目（`node tools/pack.js validate` が検査する）:
  - `patterns`: グループの中だけで使う `{0}` 付きの訳（例: `"Branch {0}, open branch menu"`）。`{0}` に入るブランチ名・リポジトリ名などはそのまま残る。
  - `bypassDeny: true`: 共通の DENY（チャット行など）の**中にある**固定の表示を訳す。`selector` が指す要素の中だけで働くので、selector は「経過時間」「アイコンボタン」のように**タイトルを含まない**最小の要素にする。settings のグループでは使えない。
  - `via: "css-placeholder"`: 入力欄の案内文（`data-placeholder`）を CSS の `::before` だけで差し替える。入力欄の DOM・属性・文字は一切変えない。`exact` だけ使える（attrs / patterns / bypassDeny は不可）。
- Cursor 自身が `aria-label` で要素を探している物（例: `button[aria-label^="Remove"]`、`[aria-label="Use Existing"]`）は**訳さない**。訳す前に `aria-label` を条件にした検索がないか確かめる。
- 自分で aria-label を訳すグループと、aria-label で要素を選ぶグループを同時に使うときは、セレクターに**英語と訳の両方**を書く（例: `button[aria-label$=", select project"]` と `button[aria-label$="、プロジェクトを選択"]`）。
- 設定画面の外の文字を集めるには `inject.js apply --once --capture <file> --capture-scope all`。各文字に `path`（祖先 6 段までの要素）が付くので、それを手がかりに selector を決める。入力欄・エディター・ターミナル・チャット・アカウント表示は記録されない。
- 編集画面の「…」メニューなど、開いた shadow root の中もエンジンが見て訳す（`.monaco-menu .action-label` のように shadow root の中で完結する selector を書く）。拡張機能の項目は訳さない。
- 新しいグループのテストは `tests/fixtures/workbench-real.html`（実機で記録した DOM の形に合わせた模型）と `tests/test-engine.js` の `real()` に足す。

## 9. 画面めぐり（`tools/tour.js`）で集める・確かめる（0.3.5 から）
> ⚠️ **使い捨てのプロファイル専用。** 標準プロファイル（ふだんの Cursor）では絶対に動かさない。注意は `tools/tour.js` の先頭にあります。`docs/tour.md` はこのリポジトリに含まれていません。

- `tools/tour.js` はデバッグポート（127.0.0.1）越しにクリック・ホバー・キー操作をして、メニュー・ツールチップ・設定の各タブ・ドロップダウン・Customize ページなど「操作しないと出てこない表示」を順に開く。`--throwaway-profile` を付けないと動かず、ポート 9333（ふだんの起動用）は拒否する。
- 削除・リセット・サインアウト・インストール・インポートなどの言葉（英語・日本語・中国語）を含む項目は押さない。エディターやチャットには入力しない。それでも UI の自動操作なので、必ず**新しい空の** `--user-data-dir` と `--extensions-dir`、サインインしない Cursor、偽の
  `xdg-open`/`BROWSER` で動かす。終わったら使い捨ての Cursor を止め、そのフォルダーを消す。
- 回し方は 2 回に分ける（1 つのウィンドウで動かせる翻訳スクリプトは 1 つ）:
  1. **カバレッジ**: `inject.js watch --lang <lang> --out work/tour-watch.json`（画面は変えない）+ `tour.js --hide-onboarding` → `inject.js coverage --in work/tour-watch.json --lang <lang> --out work/tour-coverage.md`。「seen and still English」が残りの作業です。
  2. **訳の見た目**: `inject.js apply --lang <lang> --capture work/tour-capture.json --capture-scope all` + `tour.js --shots <dir>`。スクリーンショットで、訳の長さ・文脈の合わない訳（1 語の訳など）・残った英語を目で確かめる。翻訳後のラベル（日本語・中国語）でも Customize
  のタブ・サイドバーの項目を開けるように、tour.js は既知の訳でも探す。
- サインインが必要な画面（Agents ウィンドウ本体、Automations の中身、チャットの実行中の表示、Plan & Usage など）は開けない。レポート（`--report`）の `blocked` を見て、実機（サインイン済み）での確認に回す。
- 画面めぐりで集めた文字にも、ユーザー名・ブランチ名・フォルダー名・モデル名・拡張機能名が混ざる。これらは訳さない（キーにしない）。aria-label は、Cursor が探すのに使うおそれがあるので訳さない。
- スクリーンショット・watch/capture ファイルは `work/`（公開物に入らない）に置き、共有する前に中身を確かめる。
