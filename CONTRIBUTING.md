# CONTRIBUTING.md — 協力のしかた / How to contribute

> 日本語 ｜ [English](#english)

## 訳の修正を提案する
1. GitHub の Issue で **「訳の修正 / Translation fix」** を選ぶ。
2. 言語コード・画面と場所・英語の原文・今の訳・提案する訳・理由・Cursor の版を書く。
3. スクリーンショットには、チャットの内容・メールアドレス・アカウント名・リポジトリ名などが写らないようにする。

## 自分で直して Pull Request を送る
1. `locales/<言語コード>.json` だけを直す（訳はプログラムに書かない。`tools/`・`lab/` は訳のために触らない）。
2. 用語は `glossary/<言語コード>.md` に合わせる。新しい用語を決めたら、先に用語集へ書く。ブランド名などは `glossary/do-not-translate.txt` に従い訳さない。
3. `node tools/pack.js validate` がエラー 0、`tests/run-all.sh` が成功することを確認する。
4. Pull Request のチェック項目を埋める。

## 守ること
- **Cursor のコードを貼らない。Cursor のアプリのファイルや、生の文字列の一覧をリポジトリに入れない。**
- 辞書は、Cursor の UI の英語と、その日本語訳です。見出しは英語の UI の文です（`tools/inject.js --capture` / `watch` で集められます）。識別子・内部のメッセージ・VS Code 本体の文字は入れない。短すぎる語（1 語）は、メニューなど決まった場所のグループだけに入れる。
- 訳すのは表示される文字だけ。ユーザーのデータ（チャット・入力した文字・名前・ブランチ名・モデル名など）は訳さない。
- 画面を自動で見て回る `tools/tour.js` は**使い捨てのプロファイルの Cursor 専用**（注意は `tools/tour.js` の先頭。回し方は [CONTRIBUTING-AI.md](CONTRIBUTING-AI.md) の 9 章）。`docs/tour.md` はこのリポジトリに含まれていません。標準プロファイルでは動かさない。
- 詳しい手順（AI に作業させる場合も）は [CONTRIBUTING-AI.md](CONTRIBUTING-AI.md)。

## 言語を足す
`locales/` は出荷する言語だけです。未完成のファイルは置きません。英語の見出しの正本は `templates/locale-template.json` です。Cursor の版は `meta.cursorVersion` に書いてあります。各言語レイヤーの `meta.cursorVersion` は、その正本の版と揃えます。

言語 ID（vscode-loc と同じ小文字。文書のどこでもこの一覧）:

`ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl`

1. リポジトリを fork する。
2. `node tools/new-locale.js <id>` を実行する。大文字でも受け付け、上の小文字の ID に揃えます。一覧に無い繁体字の古い表記は `zh-tw` になります。既存のファイルは上書きしません。
3. できた下書きの空欄を訳す。英語のキーは変えない。空の訳が残っているファイルは完成するまで出荷されません。
4. `node tools/pack.js validate drafts/<id>.json` を実行する。空の訳、プレースホルダー（`{0}` など）の不一致、前後の空白はエラーです。
5. `node tools/sync-locale.js <id> --check` を実行する。正本にあって言語レイヤーに無いキー、言語レイヤーに残っている古いキー、プレースホルダーのずれを表示します。
6. `tests/run-all.sh` を実行する。
7. Pull Request を送る。出荷するときは `locales/<id>.json` に移し、`lab/messages/ui.<id>.sh` と `lab/messages/uninstall.<id>.sh` を添えます。
   英語の台帳をコピーして値だけ訳します（キーと `%s` の数は変えない）。`tools/script-messages.js` にもその言語を足します。表示は 1 言語です。
   表示名は `Word to World for Cursor | ` に、そのファイルの `meta.name` と ` Language Layer` を足した物です。

英語の UI が変わったとき（AUGMENT PRODUCTS）:

1. `templates/locale-template.json` だけを直し、`meta.cursorVersion` をその Cursor の版にする。
2. `node tools/sync-locale.js --check` で差を見る。
3. `node tools/sync-locale.js <id> --apply` で、足りないキーを空欄として足し、正本から消えた訳は `drafts/stale/<id>.json` に移す。訳は黙って消しません。
4. 空欄を訳し、その言語の `meta.cursorVersion` を正本と同じにする。

`meta.cursorVersion` を更新するのは AUGMENT PRODUCTS です。英語の UI が変わったときに、正本の `meta.cursorVersion` をその Cursor の版にします。翻訳する人は、訳が正本と揃ったあとで、その言語レイヤーの `meta.cursorVersion` を正本と同じにします。

出荷しているのは日本語 `ja`（`locales/ja.json`）だけです。

---
<a id="english"></a>
## English

**Suggest a fix:** open an issue with the "訳の修正 / Translation fix" form (language code, location, English original, current/proposed translation, reason, Cursor version). Keep chats, e-mail addresses, account and repository names out of screenshots.

**Send a pull request:** edit only `locales/<lang>.json` (translations never go into `tools/` or `lab/`), follow `glossary/<lang>.md` and `glossary/do-not-translate.txt`, run `node tools/pack.js validate` and `tests/run-all.sh`, and fill in the PR checklist.

**Rules:** never paste Cursor code or commit Cursor's app files or a raw list of strings. The dictionary is the English text of Cursor's UI and its Japanese translations. Keys are that English text (`tools/inject.js --capture` / `watch`). Leave out identifiers, internal messages, and VS Code core strings. Single words belong only in a tightly scoped group. Translate display text only,
  never user data. `tools/tour.js` (automatic UI tour) is for a **separate test profile only**. The rules are in the header of `tools/tour.js`; how to run it is [CONTRIBUTING-AI.md](CONTRIBUTING-AI.md) section 9. `docs/tour.md` is not included in this repository.

**Add a language.** `locales/` is only for a language that ships. `templates/locale-template.json` is the English source. `meta.cursorVersion` on that file is the Cursor version the keys were taken from, and each language layer records the same version when it matches.

The locale list is `ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl`.

1. Fork the repository.
2. Run `node tools/new-locale.js <id>`. Upper case is accepted and stored as the lowercase id from the list above. An older Traditional Chinese spelling that is not on the list is stored as `zh-tw`. An existing file is not overwritten.
3. Translate the empty values. Do not change the English keys. A file with empty values is not shipped until it is complete.
4. Run `node tools/pack.js validate drafts/<id>.json`. Empty values, placeholder mismatches (`{0}` and the rest), and surrounding whitespace are errors.
5. Run `node tools/sync-locale.js <id> --check`. It reports keys to translate, stale keys, and placeholder mismatches.
6. Run `tests/run-all.sh`.
7. Open a pull request. A shipped language layer moves to `locales/<id>.json` and comes with `lab/messages/ui.<id>.sh` and `lab/messages/uninstall.<id>.sh`.
   Copy the English catalogs and translate the values. Keep the keys and the `%s` counts. Add that language to `tools/script-messages.js`.
   Script output is one language. The display name is `Word to World for Cursor | ` plus that file's `meta.name` plus ` Language Layer`.

When the English UI changes, AUGMENT PRODUCTS updates `templates/locale-template.json` and sets `meta.cursorVersion` to that Cursor version. Contributors do not change `meta.cursorVersion`. After the template changes, AUGMENT PRODUCTS runs `node tools/sync-locale.js --check`, then `node tools/sync-locale.js <id> --apply`. Apply adds missing keys as empty values and moves stale
translations to `drafts/stale/<id>.json`. It does not delete a translation silently. The translator fills the new keys and sets that language layer's `meta.cursorVersion` to the template's once the layer matches.

Only `ja` ships (`locales/ja.json`).
