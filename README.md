# Word to World for Cursor | Japanese Language Layer

> **⚠️ UNOFFICIAL COMMUNITY PROJECT**
>
> **This is an unofficial community project. It is not affiliated with, made, endorsed, or supported by Anysphere, Inc. or Cursor.**
>
> これは**非公式のコミュニティプロジェクト**です。Anysphere, Inc. および Cursor が作ったものではなく、関係・承認・後援・サポートもありません。

---

> **日本語** ｜ [English](#english)

画面に出ている文字を置き換えるツールです。VS Code の拡張機能でも、Microsoft の言語パックでもありません。

Cursor IDE の**設定画面**と、エージェント画面・エディター画面の**決まった操作部分**（サイドバー・メニュー・ボタンなど）の表示を日本語にする、**非公式**の補助ツールです。

**A Babel fish for Cursor** — インストール済みの Cursor のファイルは一切書き換えず、画面に表示されている英語の文字だけを、表示中にその場で日本語に置き換えます。

## ⚠️ 必ずお読みください（免責・商標・利用規約）

- これは**非公式**のツールです。Cursor の開発元である Anysphere, Inc. とは**関係がなく、承認・後援も受けていません**。
- 「Cursor」は、その権利者（Anysphere, Inc.）の商標です。このツールでは「Cursor 向けのツールである」ことを説明するためだけに名前を使っています。Cursor の名前やロゴを、このツールの製品名・ロゴとして使うことはありません。
- このリポジトリには **Cursor のプログラム（コード）は一切含まれていません**。含まれるのは、Cursor の UI の英語と、その日本語訳と、このツール自身のスクリプトだけです。
- Cursor のスタッフが、非公式のプロジェクトとして公開することについてフォーラムで見解を述べています。これは公式の承認ではありません。[投稿](https://forum.cursor.com/t/unofficial-ui-localization-overlay-asking-permission-before-release/178487/9)
- **利用規約について**: 表示を書き換えて使うことが、Cursor の利用規約に反する可能性があります。ご自身で Cursor の利用規約を確認し、**自己責任**でお使いください。
- **無保証**: このツールは「現状のまま」提供され、いかなる保証もありません。利用によって生じた損害について、作者・提供者は責任を負いません（詳しくは [LICENSE](LICENSE)）。
- **Cursor の更新**で、訳が出なくなったり、動かなくなったりすることがあります。
- Anysphere, Inc. などの権利者から求められた場合は、**速やかに公開を停止・削除**します。

## 何をするツールか

- インストール済みの Cursor（`/Applications/Cursor.app`）を、**標準プロファイルのまま**（チャット履歴・設定・拡張機能はそのまま）起動し直します。**アプリはコピーも改変もしません。**
- そのとき「デバッグ用のポート」（この端末内だけからつながる **127.0.0.1** のポート。既定は **9333**）を付けて起動し、そこから翻訳の仕組みを画面に入れます。翻訳は**表示だけ**で、ファイルには何も書きません。
- 標準プロファイルで**最初に開く前に一度だけ**、このポートの説明を出して `yes` の入力を求めます。説明では、ポートが 127.0.0.1（既定は 9333）に限られ、他のデバイスからは届かないことと、この端末上のほかのプログラム（Cursor の AI エージェントが実行するコマンドや、npm install などで動くスクリプトも含みます）からは届くことを伝えます。Enter だけでは進みません。別プロファイル（`--separate-profile`）ではこの確認はありません。
- 翻訳されるのは、**設定画面**と、次の決まった場所の**固定の表示**だけです:
  - エージェント画面の左のサイドバー（New Chat・Automations・Customize、Projects・Repositories の見出し、No Repo など）と絞り込みメニュー
  - サイドバーのボタンの読み上げ名・ツールチップ（Hide Sidebar・Go Back・Pin・Archive など）と、チャットの行の右端の経過時間（3h → 3時間。チャットの名前はそのまま）
  - 入力欄まわり: プロジェクト／実行環境の選択（No Repo・Cloud）、Plan New Idea、ツールバーのボタン、Claude Code の会話インポートの案内
  - 入力欄の案内文（Plan, Build, / for skills, @ for context など）: **CSS だけで**表示を差し替えます。入力欄の中身・属性には一切手を入れません
  - エディター画面: 最初の画面、「Cursor Settings」タブ、「Agents Window」ボタン、タイトルバーのボタンの読み上げ名、ステータスバーの Cursor 自身の項目、「…」メニューの Cursor 自身の項目
  - 開いたときだけ出る物: メニュー・ツールチップ・確認の画面（ダイアログ）・通知（トースト）・「まだ何もありません」などの表示。英語と**完全に同じ**ときだけ置き換えます（1 語だけの短い語は、メニューなどの中だけ）
- **触らない物**: チャットの本文、あなたが入力した文字、入力欄・テキスト欄の中身、エディター、ターミナル、チャット・リポジトリ・プロジェクトの名前、モデル名、ブランチ名、アカウント名・メールアドレス、拡張機能の項目（Claude Code など）。
- Cursor を終了すると、翻訳の仕組みも止まり、ポートも閉じます。オーバーレイだけなら、次に普通に Cursor を開けば英語です。VS Code の日本語言語パック（Microsoft 公式、MS-CEINTL.vscode-language-pack-ja）を入れた場合は、メニューなどの表示言語はアンインストールするまで残ります。

## ⚠️ 日本語表示中の注意（必ずお読みください）

- 標準プロファイルで最初に開くとき、ツールは一度だけ次の説明を出し、`yes` と入力しないと進みません。Enter だけでは同意になりません。
- 日本語表示で開いている間は、**この端末上で動いている他のプログラム（Cursor の AI エージェントが実行するコマンドや、npm install などで動くスクリプトも含みます）が、127.0.0.1 のポート（既定は 9333。変えた場合はそのポート）を通じて Cursor の画面（あなたの標準プロファイルのデータを含む）にアクセスできる状態**になります。既定の起動方法は「標準プロファイル」なので、チャット・ログイン中のアカウントなども対象です。
- この制限は、ポートを 127.0.0.1 だけに結んでいることです。他のデバイスやインターネットからはつながりません。
- ポートは **Cursor を終了すると閉じます**。使い終わったら Cursor を終了してください。信頼できないプログラムを動かしている間は使わないでください。
- 心配な場合は、標準プロファイルとは別のプロファイルで起動する方法もあります（下の「起動モード」の `--separate-profile`）。
- このツールは、標準プロファイル（`~/Library/Application Support/Cursor`、`~/.cursor`）や Cursor.app に**何も書き込みません**。**例外:** 任意の VS Code 日本語言語パック（Microsoft 公式、下記）を使う場合、そのパックは `~/.cursor/extensions` に入り、`~/.cursor/argv.json` の `"locale"` だけを書き換えます（アンインストール時にパックを外し、locale を元に戻します）。

## 必要な物

- macOS と、インストール済みの Cursor（`/Applications/Cursor.app`）
- 確認済みの版: Cursor 3.28.7 および 3.30.14（ほかの版では、訳されない部分が増えることがあります）
- 追加のインストールは不要です（翻訳エンジンは Cursor に内蔵の Node で動きます）

## インストール

```bash
# GitHub から取得
git clone https://github.com/augment-products/word-to-world.git
cd word-to-world
```

## 使い方（今はターミナルで操作します）

```bash
# 1) 準備（初回だけ。何度実行しても安全）
lab/setup-lab.sh

# 2) 日本語表示で起動（Cursor が開いていれば、確認のあと普通に終了してから開き直します。⌘Q、または Cursor メニューから終了）
lab/start.sh --lang ja
#    設定画面だけを訳す:        lab/start.sh --lang ja --settings-only
#    英語の原文も見たいとき:    lab/start.sh --lang ja --show-original

# 3) 終わるときは Cursor を普通に終了するだけ（⌘Q、または Cursor メニューから終了。オーバーレイは英語に戻り、すべて止まります）
#    別のターミナルから止める場合:  lab/stop.sh
```

- Cursor がすでに開いているときは「いったん終了します」と表示して確認します（Enter で続行）。保存していないファイルなどがあれば、Cursor がいつもどおり確認を出します。**強制終了はしません**。60 秒たっても終了しない場合は止まります（終了コード 7）。
- 確認なしで進めたいとき: `lab/start.sh --lang ja --quit-running`
- 標準プロファイルでの最初の起動は、`--quit-running` を付けても `yes` の入力が必要です。端末がないときは終了コード 5 で止まります。
- 細かく操作したい場合: `lab/launch-lab.sh`（起動だけ）→ `lab/apply.sh --lang ja`（翻訳、Ctrl+C で英語に戻る）→ `lab/revert.sh`（英語に戻す）。使える言語は `lab/apply.sh --list`。
- スクリプトの文は 1 言語です。`--lang ja` なら日本語だけ。省略したときは、保存した言語、システムの言語（AppleLanguages、次に LC_ALL、次に LANG）、英語の順です。`UI_TR_LANG` は表示の言語だけを上書きします。画面の置き換えに使う言語レイヤーは `--lang` で、既定は ja です。

## メニューバー（ファイル・編集・表示…）も日本語にしたいとき（Microsoft の言語パック・任意）

メニューバーやコマンドパレットは、VS Code の日本語言語パック（Microsoft 公式） **MS-CEINTL.vscode-language-pack-ja**（[Open VSX](https://open-vsx.org/extension/MS-CEINTL/vscode-language-pack-ja)）で日本語になります。これは任意です。`lab/setup-lab.sh` が**一度だけ**聞きます（**Enter は入れない** / y で入れる。答えは覚えていて、2 回目からは聞きません）。入れると `~/.cursor/argv.json` の `"locale"` を書き換え、その変更はアンインストールするまで残ります。

```bash
lab/setup-lab.sh --with-langpack   # 聞かずに入れる
lab/setup-lab.sh --no-langpack     # 聞かずに入れない
```

- 言語パックは**このツールの一部ではありません**。Microsoft が作った物で、**Microsoft のライセンス**で提供されています（入れる前にご確認ください）。Cursor 付属の `cursor --install-extension` で入れます。
- 入れたあと、`~/.cursor/argv.json` の `"locale"` だけを `"ja"` にします（中のコメント・ほかの設定は変えません。元のファイルは作業フォルダーに保存し、元の値も記録します）。**Cursor を一度再起動すると**メニューが日本語になります。
- このツールを使う前にご自身で入れた言語パックは、入れ直しません。所有の記録には残さず、アンインストールでも外しません。このツールが入れた言語パックは所有の記録に残り、アンインストールで外します。
- ターミナル以外から実行したとき（聞けないとき）は、入れません。
- 別プロファイル / コピーのモードでは、VS Code の日本語言語パック（Microsoft 公式）は別プロファイル側に入り、`argv.json` は変えません（起動時に `--locale` で指定します）。

## 知っておいてほしいこと（リスク）

- **Cursor の更新**: 画面の英語が変わると、その部分は英語のまま表示されます。仕組みが変わると、翻訳が働かなくなることもあります。
- **設定の検索**: 検索は英語のまま使えます（日本語の語では検索できません）。
- **訳の正確さ**: 分かりやすさを優先していますが、誤訳があり得ます。大事な設定は `--show-original` で英語の原文も確認してください。

## 起動モード（通常は変更不要）

| モード | 指定方法 | 内容 |
|---|---|---|
| normal（既定） | `lab/setup-lab.sh --normal` | 普段の Cursor・標準プロファイル。標準プロファイルには書き込みません。モードの指定を省略すると、前回のモードをそのまま使います（記録が無ければ normal） |
| 別プロファイル | `lab/setup-lab.sh --separate-profile` | 普段の Cursor.app を、別プロファイル（`~/Library/Application Support/word-to-world/lab-profile`）で起動します。普段の Cursor と同時に使えます。チャット履歴・ログイン・拡張機能は別です |
| コピー（開発者向け） | `lab/setup-lab.sh --copy` | Cursor のコピー（`Cursor-Lab.app`）を別プロファイルで起動します。数 GB 使います |

## アンインストール（作ったものを削除します）

```bash
lab/uninstall.sh --dry-run   # 何を削除するか確認するだけです
lab/uninstall.sh             # 一覧を見て yes と入力すると削除します（確認なし: --yes）
```

- 注入ツールを止め、このツールが起動した Cursor を**普通に終了**させ（⌘Q、または Cursor メニューから終了。強制終了はしません）、ポートが閉じたことを確かめてから、**このツールが作った物をすべて**消し、最後に「何も残っていません」と確認結果を表示します（作業フォルダー `~/Library/Application Support/word-to-world`、別プロファイル、ログ、状態ファイル、一時ファイル）。
- setup でこのツールが入れた言語パックだけを外します（所有の記録に残っているもの。このツールを使う前にご自身で入れたパックは外しません）。`~/.cursor/argv.json` の `"locale"` を元の値に戻します。Cursor の CLI が無いときは、Cursor.app の有無にかかわらず確認できないので止まり、状態とバックアップを残します。ただし、別プロファイルの中だけにある言語パックは、作業フォルダーと一緒に削除します。拡張はアプリの外（`~/.cursor/extensions`）に残ることがあります。`--skip-langpack` で確認と削除を省けます（既定は省きません）。省いたときは「何も残っていません」とは言わず、残っている場合があると表示します。
- **消さない物**: `/Applications/Cursor.app`、標準プロファイル（`~/Library/Application Support/Cursor`。`~/.cursor` は、locale を元に戻すことと、任意の言語パックを `~/.cursor/extensions` から外すこと以外は触りません）、このツールを使う前にご自身で入れた VS Code の日本語言語パック（Microsoft 公式）。

## 訳の修正・新しい言語への協力

- **訳の修正の提案**: GitHub の Issue で「訳の修正 / Translation fix」を選んで、場所・英語の原文・今の訳・提案する訳を書いてください（スクリーンショットがあると助かります。チャットの内容やメールアドレスなどが写らないように注意してください）。
- **自分で直す**: `locales/ja.json` を直して、`node tools/pack.js validate` と `tests/run-all.sh` を通してから Pull Request を送ってください。用語は `glossary/ja.md` に合わせます。詳しくは [CONTRIBUTING.md](CONTRIBUTING.md)。
- **新しい言語**: `node tools/new-locale.js <id>` で下書きを作ります。手順は [CONTRIBUTING.md](CONTRIBUTING.md)。AI に作業させる場合は [CONTRIBUTING-AI.md](CONTRIBUTING-AI.md) を渡してください。
- 訳（`locales/`）とプログラム（`tools/`・`lab/`）は分かれています。訳を直すだけならプログラムに触る必要はありません。
- **対応予定の言語と順番**: [docs/ROADMAP.md](docs/ROADMAP.md)（目安です）。

## 対応言語

現在、翻訳が用意されているのは**日本語のみ**です。

辞書は、このツール独自のオーバーレイ用の形式です。VS Code の言語パックではありません。言語 ID は [VS Code / vscode-loc](https://github.com/microsoft/vscode-loc) の ID を使います。対応予定は次のとおりです:
`ja` `zh-cn` `zh-tw` `ko` `fr` `de` `es` `it` `ru` `pt-br` `cs` `tr` `pl`

## テスト

`tests/run-all.sh` — すべての自動テスト（言語レイヤーの検査、翻訳エンジン、作業リスト、シェルスクリプトの検査、起動・停止・アンインストール、Microsoft の言語パックと argv.json（偽の cursor コマンドで確認）、リポジトリの衛生チェック）。Node 16 以上、Python 3、Chrome/Chromium が必要。実物の Cursor は使いません。

## フォルダー構成

| 場所 | 中身 |
|---|---|
| `locales/ja.json` | 日本語のオーバーレイ辞書（Cursor の UI の英語と、その日本語訳。プログラムは入れない） |
| `templates/locale-template.json` | 英語の見出しの正本（訳ではない。出荷しない） |
| `glossary/` | 用語集・訳さない語の一覧 |
| `schema/` | オーバーレイ辞書の形式 |
| `tools/` | 翻訳エンジン（`inject.js`）、オーバーレイ辞書の検査（`pack.js`）、作業リスト（`update_worklists.py`）、argv.json の locale だけを書き換える `argv-locale.js` |
| `lab/` | 起動・翻訳・停止・アンインストールのスクリプトと、そのメッセージ（`lab/messages/`） |
| `tests/` | 自動テスト（`tests/fixtures/` は手で書いた模型の画面で、Cursor のコードではありません） |
| `docs/` | 対応言語のロードマップ（`ROADMAP.md`）、画面を見て回るときのチェックリスト（`capture-checklist-ja.md`） |

## 終了コード（将来のダブルクリック用アプリ向け）

0 成功 / 1 失敗（言語パックを確認できず中止したときを含む） / 2 使い方の誤り / 3 言語レイヤーが無い・壊れている / 4 Cursor につながらない / 5 取り消し / 6 安全のため中止 / 7 Cursor が終了しなかった

## 変更履歴

詳しくは [CHANGELOG.md](CHANGELOG.md) をご覧ください。

## ライセンス

[MIT License](LICENSE) © 2026 AUGMENT PRODUCTS Co., Ltd.（オーグメントプロダクツ株式会社）。Cursor 本体のライセンス・利用規約は、このライセンスとは別に適用されます。

---

<a id="english"></a>

# Word to World for Cursor | Japanese Language Layer

> **⚠️ UNOFFICIAL COMMUNITY PROJECT**
>
> **This is an unofficial community project. It is not affiliated with, made, endorsed, or supported by Anysphere, Inc. or Cursor.**

This tool swaps the text on screen. It is not a VS Code extension and it is not a Microsoft language pack.

An **unofficial** helper that shows Cursor IDE's **Settings** and fixed parts of the Agents and editor windows (sidebar, menus, buttons) in Japanese at display time. **A Babel fish for Cursor** — It never modifies Cursor's files; it only replaces the English text that is currently displayed, at runtime.

## ⚠️ Disclaimer, trademarks and terms

- This is an **unofficial** project. It is **not affiliated with, endorsed by, or sponsored by Anysphere, Inc.** (the maker of Cursor).
- "Cursor" is a trademark of its owner (Anysphere, Inc.) and is used here only descriptively, to say what this tool works with. Cursor's name and logo are not used as this project's product name or logo.
- This repository **contains no Cursor code**: only the English text of Cursor's UI and its Japanese translations, and this tool's own scripts.
- Cursor staff gave their view on publishing it as an unofficial project. That is not an official endorsement. [Forum post](https://forum.cursor.com/t/unofficial-ui-localization-overlay-asking-permission-before-release/178487/9)
- **Terms of service:** changing how Cursor's UI is displayed may conflict with Cursor's terms. Check them yourself; **use at your own risk**.
- **No warranty:** provided "as is", without warranty of any kind; the authors are not liable for any damage (see [LICENSE](LICENSE)).
- **Cursor updates may break translations** or the tool itself.
- We will **take the project down promptly** if asked by Anysphere or another rights holder.

## How it works

- Relaunches the installed `/Applications/Cursor.app` **unmodified, with your default profile** (chats, settings and extensions stay as they are), adding only `--remote-debugging-port=9333`, bound to **127.0.0.1**.
- Before the first launch with your default profile, the tool explains once that the port is limited to this device (127.0.0.1, default 9333), that other devices cannot reach it, and that other programs on this device, including commands run by Cursor's AI agent or scripts started by `npm install`, can. It continues only if you type `yes`. Pressing Enter is not consent. `--separate-profile` does not ask.
- Through that local debug port it injects a small translator that changes **display text only**: Settings, plus defined areas of the Agents window (sidebar entries, headers and icon-button labels, relative times on chat rows, filter menu, composer pickers/toolbar/chips, the Claude Code import banner) and of the editor window (welcome screen, "Cursor Settings" tab, "Agents Window" button, title-bar button labels, Cursor's own status-bar items and "…" menu items). Nothing is written to disk.
- The composer placeholder is translated with **one CSS rule only**; the editable input's DOM and attributes are never changed.
- Never touched: chat messages, anything you typed, input values, editors, terminals, chat/repository/project names, model names, branch names, account name/e-mail, extension items.
- Quitting Cursor stops the translator and closes the port. Overlay only: the next normal launch is English again. If you installed the VS Code Japanese language pack (by Microsoft, MS-CEINTL.vscode-language-pack-ja), the menu language stays until you uninstall.

## ⚠️ While Japanese mode is open

- The first launch with your default profile asks once and continues only if you type `yes`. Pressing Enter is not consent.
- **While the port is open, other programs on this device, including commands run by Cursor's AI agent or scripts started by `npm install`, can reach the Cursor session through 127.0.0.1:9333 (or the port you chose), including your default profile's data.** The default mode uses your default profile, so this includes your chats and signed-in account.
- That limit is the bind to 127.0.0.1: other devices and the internet cannot connect. The port **closes when you quit Cursor**. Quit Cursor when you are done, and don't use Japanese mode while running untrusted programs. If you prefer, use `--separate-profile` (see Modes).
- The tool never writes to your default profile (`~/Library/Application Support/Cursor`, `~/.cursor`) or to Cursor.app. **Exception:** When you opt into the VS Code Japanese language pack by Microsoft (see below), that pack is installed under `~/.cursor/extensions`, and it sets `"locale"` in `~/.cursor/argv.json` (uninstall removes the pack and restores the locale).

## Requirements

- macOS and an installed Cursor (`/Applications/Cursor.app`)
- Tested with: Cursor 3.28.7 and 3.30.14
- Nothing else to install (the engine runs on Cursor's bundled Node)

## Install

```bash
# from GitHub
git clone https://github.com/augment-products/word-to-world.git
cd word-to-world
```

## Start / stop

```bash
lab/setup-lab.sh            # once (safe to repeat)
lab/start.sh --lang ja      # if Cursor is open, it asks, quits it normally (⌘Q or Cursor menu > Quit; never force-quits) and reopens it in Japanese mode
                            # --settings-only: Settings only; --show-original: show the English as a tooltip
# stop: just quit Cursor (⌘Q or Cursor menu > Quit; the overlay reverts and everything stops), or run lab/stop.sh
#       The VS Code Japanese language pack (by Microsoft), if you installed it, keeps the menu language until uninstall
```

Non-interactive: `lab/start.sh --lang ja --quit-running`. If Cursor does not quit within 60 s (e.g. a save dialog), the script stops with exit code 7. The first launch with the default profile still requires typing `yes`, even with `--quit-running`. Without a terminal it stops with exit code 5.

Script messages are one language. `--lang ja` prints Japanese only. If `--lang` is omitted: the saved language, then the system language (AppleLanguages, then LC_ALL, then LANG), then English. `UI_TR_LANG` overrides the message language only. The overlay language stays `--lang`, and the default is ja.

## Menu bar in Japanese (Microsoft language pack, optional)

The menu bar and command palette are translated by the VS Code Japanese language pack (by Microsoft) **MS-CEINTL.vscode-language-pack-ja** ([Open VSX](https://open-vsx.org/extension/MS-CEINTL/vscode-language-pack-ja)). This is opt-in. `lab/setup-lab.sh` asks **once** (**Enter = do not install** / y = install; the answer is remembered). Before you agree, it tells you that installing it changes `"locale"` in `~/.cursor/argv.json` and that the change stays until you uninstall. `--with-langpack` / `--no-langpack` skip the question; without a terminal the default is not to install.

- The pack is **not part of this tool**: it is made by Microsoft and provided under **Microsoft's own license**. It is installed with Cursor's own `cursor --install-extension`.
- Then only the `"locale"` key in `~/.cursor/argv.json` is set to `"ja"` (comments and other settings are kept; the original file is backed up in the work folder and the previous value recorded). **Restart Cursor once** for the menus to change.
- A pack you installed yourself before using this tool is not reinstalled, is not added to the ownership record, and is not removed on uninstall. A pack this tool installed stays in the ownership record and is removed on uninstall.

## Modes

`lab/setup-lab.sh --normal` (your default profile; nothing is written there). Omitting the mode flag reuses the previous mode, or normal when none is recorded. `--separate-profile` (installed Cursor.app with a separate profile at `~/Library/Application Support/word-to-world/lab-profile`, can run next to your usual Cursor) / `--copy` (developer lab copy).

## Uninstall (removes everything)

```bash
lab/uninstall.sh --dry-run   # show exactly what would be removed
lab/uninstall.sh             # type "yes" to confirm   (or --yes for non-interactive use)
```

Stops the injector, quits the Cursor started by this tool normally (⌘Q or Cursor menu > Quit; never force-quits), verifies the port is closed, removes everything this tool created (work folder `~/Library/Application Support/word-to-world`, separate profile, logs, state and temp files; recorded in `install-manifest.txt` plus known defaults), then verifies nothing remains. Language pack: only a pack that this tool installed (it stays in the ownership record) is uninstalled — never a pack you installed yourself before using this tool — and `"locale"` in `~/.cursor/argv.json` is restored to its previous value (or removed if it was not there). Apart from that it never touches `/Applications/Cursor.app` or `~/Library/Application Support/Cursor`. Under `~/.cursor` it only restores locale and, when it installed the optional pack, removes that pack from `~/.cursor/extensions`. If Cursor's CLI is missing, uninstall stops whether or not Cursor.app is still there, and it keeps the state and the backup, except a pack that is only inside the separate profile: that pack is removed together with the work folder. Extensions can remain outside the app, in `~/.cursor/extensions`. `--skip-langpack` skips the check and the removal, and the final line then says the pack may still be there. The default does not skip.

## Contributing translations

- **Report a wrong or missing translation:** open an issue with the "訳の修正 / Translation fix" form (location, English original, current and proposed translation; screenshots help, but make sure no chats or e-mail addresses are visible).
- **Fix it yourself:** edit `locales/ja.json`, run `node tools/pack.js validate` and `tests/run-all.sh`, then open a pull request. Follow `glossary/ja.md`. See [CONTRIBUTING.md](CONTRIBUTING.md); for AI-assisted work, [CONTRIBUTING-AI.md](CONTRIBUTING-AI.md).
- **New language:** `node tools/new-locale.js <id>` writes a draft. See [CONTRIBUTING.md](CONTRIBUTING.md).
- Translations (`locales/`) are kept separate from code (`tools/`, `lab/`); fixing a translation never requires touching code.
- **Planned languages and order:** [docs/ROADMAP.md](docs/ROADMAP.md) (a guide, not a promise).

## Supported Languages

Currently, **Japanese is the only language with translations**.

The dictionary is this tool's own overlay dictionary format. It is not a VS Code language pack. It uses [VS Code / vscode-loc](https://github.com/microsoft/vscode-loc) language IDs. Planned languages:
`ja` `zh-cn` `zh-tw` `ko` `fr` `de` `es` `it` `ru` `pt-br` `cs` `tr` `pl`

## Tests

`tests/run-all.sh` (Node 16+, Python 3, Chrome/Chromium; does not use a real Cursor).

## Structure

| Location | Contents |
|---|---|
| `locales/ja.json` | Japanese overlay dictionary (the English text of Cursor's UI and its Japanese translations; no code) |
| `templates/locale-template.json` | English keys, the source for every locale (not a translation, not shipped) |
| `glossary/` | Terminology and do-not-translate lists |
| `schema/` | Overlay dictionary schema |
| `tools/` | Translation engine (`inject.js`), language-layer checker (`pack.js`), worklist updater (`update_worklists.py`), locale-only argv.json writer (`argv-locale.js`) |
| `lab/` | Start/stop/uninstall scripts and messages (`lab/messages/`) |
| `tests/` | Automated tests (`tests/fixtures/` are hand-written mock pages, not Cursor code) |
| `docs/` | Language roadmap (`ROADMAP.md`), screen capture checklist (`capture-checklist-ja.md`) |

## Exit Codes

0 success / 1 failure (including a stop because a language pack could not be checked) / 2 usage error / 3 language layer missing or broken / 4 cannot connect to Cursor / 5 cancelled / 6 safety abort / 7 Cursor did not quit

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for details.

## License

[MIT License](LICENSE) © 2026 AUGMENT PRODUCTS Co., Ltd. Covers this repository only; no rights to Cursor are granted. Cursor itself is governed by its own license and terms, separately from this license.
