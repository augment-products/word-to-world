# 日本語の用語集（ja）

方針: **英語が分からない人が読んで分かる日本語**にする。日本で広く通じていない英単語はカタカナでも残さず訳す。
ブランド名・製品名・ファイル名・キー名は訳さない（`glossary/do-not-translate.txt`）。
用語を変えるときは、この表を先に直してからパック全体を一括で置き換える（表記ゆれを作らない）。

## 表記ルール
- 説明文は「です・ます」。ラベル・ボタンは体言止めか「〜する」（例: 「透明度を下げる」）
- 英数字と日本語の間は半角スペース（例: 「VS Code の設定」「15 秒」）。日本語どうしの間には入れない
- 括弧は全角（）、省略記号は「…」、かぎ括弧「」でボタン名・モード名を示す
- 長音は付ける: ブラウザー / フォルダー / コンピューター / サーバー / ユーザー
- 「Default」は「デフォルト」に統一（「既定」は使わない）
- {0} などのプレースホルダーは英語と同じ数・番号で残す。語順は日本語として自然に並べ替えてよい

## 用語の決定
| English | 日本語 | 理由・メモ |
|---|---|---|
| Agent / Agents | エージェント | 「Agent」のままでは読めない人がいる。複数形も同じ |
| Cloud Agents / Cloud Agent | クラウドエージェント | 機能名だが訳す |
| Background Agent | バックグラウンドエージェント | |
| Subagent(s) | サブエージェント | |
| Agent Review | エージェントレビュー | |
| Auto | 自動 | モデル選択の「Auto」も設定画面では「自動」 |
| Tab（補完機能） | Tab 補完 | Tab キーの意味と区別するため「補完」を付ける |
| Cursor Tab | Cursor Tab 補完 | |
| LSP | 言語サーバー (LSP) | 略語だけでは分からないため |
| Rules / Skills / Hooks / Plugins | ルール / スキル / フック / プラグイン | |
| MCP | MCP | 固有の規格名。訳さない |
| Models | モデル | |
| Privacy Mode | プライバシーモード | |
| Plan & Usage | プランと使用量 | |
| Early Access | 先行アクセス | |
| Nightly | 毎日更新版（ナイトリー） | 「ナイトリー」だけでは通じない |
| Stable | 安定版 | |
| Beta | ベータ | 日本語として定着 |
| Default | デフォルト | |
| Steer（実行中のエージェントへ） | 軌道修正 | 止めずに指示を変えること（0.3.5 で「方向修正」から変更） |
| Queue (messages) | 順番待ちにする | 0.3.5 で「キューに入れる」から変更（分かりやすさ優先） |
| Worktree(s) | ワークツリー | Git の用語。ほかに訳がない |
| codebase | コードベース | URL 内の codebase は訳さない |
| Explore（サブエージェント名） | 探索 | |
| Quick Edit | クイック編集 | |
| Web | ウェブ | 「Web 検索」→「ウェブ検索」 |
| Fetch（Web Fetch Tool） | 取得 | 「ウェブ取得ツール」 |
| Desktop Bridge | デスクトップ連携 | |
| Private Inference | プライベート推論 | |
| On / Off | オン / オフ | |
| Never | しない | 選択肢として「〜しない」の意味 |
| OK | OK | 日本語として定着（パックには入れない） |
| Breadcrumb | パンくずリスト | |
| Island（表示スタイル） | アイランド | 見た目の名前。訳すと意味が通じにくい |
| Quick / Deep | クイック / 詳細 | |
| Docs | ドキュメント | |
| General / Appearance | 一般 / 外観 | |
| Source Control | ソース管理 | |
| Code Intelligence | コードインテリジェンス | |
| Browser & Network | ブラウザーとネットワーク | |
| Voice | 音声 | |
| Usage Summary | 使用量サマリー | |
| Dismiss | 閉じる | お知らせを消すボタン。「却下」は強すぎる |
| Import / Show / Hide | インポート / 表示 / 非表示 | |
| Title Bar / Status Bar | タイトルバー / ステータスバー | 定着したカタカナ |
| Layout（Agent / Editor） | エージェント用 / エディター用のレイアウト | |
| Automations | 自動化 | 機能名だが「オートメーション」より分かりやすい |
| New Chat / New Agent / New Project | 新しいチャット / 新しいエージェント / 新しいプロジェクト | ボタン・操作の名前だけ。同じ名前のチャットやプロジェクトの名前は訳さない |
| Projects / Repositories / Workspaces | プロジェクト / リポジトリ / ワークスペース | サイドバーの見出しだけ。フォルダー名・リポジトリ名は訳さない |
| No Repo | リポジトリなし | |
| Grouping / Ordering | グループ分け / 並び順 | 絞り込みメニュー |
| Filters | 絞り込み | 「フィルター」より分かりやすい |
| Status | 状態 | |
| PR | プルリクエスト | 「PR」だけでは分からない人がいる。PR Draft →「プルリクエスト（下書き）」など |
| Environment | 実行環境 | エージェントが動く場所（クラウド / ローカル / マシン） |
| Source（作成元のフィルター） | 作成元 | チャットをどこから始めたか（デスクトップ / Slack など） |
| Archived / Mark All as Read | アーカイブ済み / すべて既読にする | |
| Needs Attention / Working / Unread / Draft | 対応が必要 / 作業中 / 未読 / 下書き | |
| Open project / Clone repo / Connect via SSH / Recent projects | プロジェクトを開く / リポジトリをクローン / SSH で接続 / 最近のプロジェクト | エディター画面の最初の画面 |
| Create Repo | リポジトリを作成 | |
| Merge Method | マージの方法 | Git の用語「マージ」は残す |
| Secrets | シークレット（秘密の値） | カタカナだけでは分からないため補足 |
| Spend limit / Current cycle | 利用額の上限 / 今回の請求期間 | |
| Got it | わかりました | |
| Plan New Idea | 新しいアイデアを計画 | 入力欄の下のチップ（⇧Tab の表示はそのまま） |
| Cloud / Local（実行環境の選択） | クラウド / ローカル | マシン名は訳さない |
| 3h / 1mo など（経過時間） | 3時間 / 1か月（s 秒・m 分・h 時間・d 日・w 週間・mo か月・y 年、now → 今） | チャット行の右端だけ。名前は訳さない |
| Pin / Unpin / Archive / Unarchive | ピン留め / ピン留めを外す / アーカイブ / アーカイブから戻す | |
| Completed / Running | 完了 / 実行中 | チャット行の状態アイコンの読み上げ名 |
| Hide Sidebar / Go Back / Go Forward | サイドバーを隠す / 戻る / 進む | |
| Customize Sidebar / Open Workspace / Resize sidebar | サイドバーのカスタマイズ / ワークスペースを開く / サイドバーの幅を変更 | |
| Add agents, context, tools | エージェント・コンテキスト・ツールを追加 | |
| Start voice input / Start voice chat | 音声入力を開始 / 音声チャットを開始 | |
| Chat actions | チャットの操作 | |
| Plan, Build, / for skills, @ for context | 計画・作成（/ でスキル、@ でコンテキスト） | 入力欄の案内文。CSS だけで表示 |
| Send follow-up / Add a follow-up | 続けて指示を送る / 続けて指示を追加 | |
| Import your Claude Code conversations | Claude Code の会話をインポート | |
| Cursor Settings（タブ名） | Cursor の設定 | |
| Agents Window | エージェント画面 | エディター画面からエージェント画面を開くボタン |
| Cursor Tab | Cursor Tab 補完 | 機能名は残し、意味を補う |
| Tab Stats / Agent Stats | Tab 補完の統計 / エージェントの統計 | 数字（3/7 (42%)）はそのまま |
| No commit scored | 集計済みのコミットなし | AI が書いたコードの割合を集計する機能 |
| Open Browser / Configure Icon Visibility | ブラウザーを開く / アイコンの表示を設定 | 「…」メニュー |
| NEW（バッジ） | 新機能 | |
| Premium Plan（など） | Premium プラン | プラン名は英語のまま、「Plan」だけ訳す |

## 自信が低い訳（実画面で見て見直す候補）
- Steer → 軌道修正（0.3.5 で決定）
- Island → アイランド
- Nightly → 毎日更新版（ナイトリー）
- Tab → Tab 補完（画面によっては Tab キーの意味かもしれない）
- Queue Messages → メッセージを順番待ちにする（0.3.5 で変更）
- Code Intelligence → コードインテリジェンス（「コード解析」も候補）
- Automations → 自動化（「オートメーション」も候補。Cursor の機能名として覚えている人には別物に見えるかもしれない）
- Source（絞り込み）→ 作成元（「発生元」「起点」も候補）
- Environment → 実行環境（「環境」だけでもよいかもしれない）
- Steer from iOS → iOS から操作（Steer の訳と揃えるなら「iOS から軌道修正」）
- Wait indefinitely… When off, skip authentication prompts after 30 seconds → 「30 秒たつと認証の確認を飛ばします」（skip の意味を実画面で確認したい）
- No commit scored → 集計済みのコミットなし（「採点」「スコア」も候補。機能の中身を実画面で確認したい）
- Plan, Build, / for skills, @ for context → 計画・作成（/ でスキル、@ でコンテキスト）（長さを実画面で確認したい）
- Agents Window → エージェント画面（「エージェントのウィンドウ」も候補）
- NEW → 新機能（「新着」も候補）
- Send follow-up → 続けて指示を送る

## 0.3.4 で追加した語（画面での確認待ち）
決めた用語のうち、迷った物:
- Fork → 分岐（0.3.5 で「フォーク」から変更。チャットを途中から枝分かれさせる操作で、Git を知らない人にも伝わる言葉にした）
- Steer → 軌道修正（0.3.5 で「方向修正」から変更。動いているエージェントを止めずに、追加の指示で向きを変える操作。日本語の慣用句の方が通じる）
- Queue / Queued → 順番待ち（0.3.5 で「キュー」をやめて統一。ボタンの Queue は「順番待ちに追加」、Queue Messages は「メッセージを順番待ちにする」）
- Push → プッシュ（0.3.5 で英語のままから変更。VS Code の日本語表示（日本語の言語パック）の「プッシュ」「コミット」と揃える）
- Checkout Branch → ブランチをチェックアウト
- Squash / Rebase → スカッシュ / リベース
- Board（Kanban）→ ボード
- Multitask → マルチタスク
- Trigger(s) → トリガー（自動化の起動条件。0.3.5 で「きっかけ」から変更：Automations の画面ではほかの語と並ぶ機能名なので、カタカナの方が分かりやすい）
- Secrets → シークレット（秘密の値）
- Stale → 古い状態（0.3.5 で「古い情報」から変更。状態を示す短い札として使われるため）
- Canvas → キャンバス
- Auto-review → 自動レビュー
- Deep Link → ディープリンク
- 1 語だけの語（Add・Open・Delete など）は、メニュー・ツールチップ・確認の画面・通知・空の表示の中だけで訳す（`bundle-popups` グループ）。Auto・Composer・Thinking・Tab など、モデル名やキー名と紛らわしい語は訳さない。
- aria-label（読み上げ名）は、この追加分では訳さない（Cursor が英語の読み上げ名で部品を探すことがあるため）。

## 0.3.5 で追加・変更した語（画面を見て確認）
- Allowlist → 許可リスト／Sandbox → サンドボックス
- Customize ページのタブ：Plugins・MCPs・Skills・Subagents・Rules・Commands・Hooks → プラグイン・MCP・スキル・サブエージェント・ルール・コマンド・フック
- 「You can put in ／ your Anthropic key ／ to use Claude at cost…」のように 1 つの文が部品に分かれている所は、部品ごとに訳して日本語の語順で読めるようにした（ここに入力した ／ Anthropic のキー ／ を使うと…）
- at cost → 原価で
- 決めた語（0.3.5）：Steer → 軌道修正、Queue → 順番待ち（「キュー」はやめた）、Fork → 分岐、Stale → 古い状態、Push → プッシュ。どれもサインインしないと実際の流れ（実行中のエージェントに送るときの選択肢など）は見られないので、実機で見て不自然なら直す。
- 編集画面（IDE）の右側のエージェント欄：既定の題名「New Agent」→ 新しいエージェント、入力欄の案内文、「Log in」→ ログイン、タイトルバーの「Upgrade」→ アップグレード（題名が付いたチャットの名前は訳さない）
- Customize ページ：編集画面のタブ名 Customize → カスタマイズ、「Browse Marketplace」ボタン → 探す（マーケットプレイス）（英語では「Browse」と「Marketplace」が別の部品で、幅が狭いと後ろが隠れるため、語順を入れ替えられない）
- 編集画面のエージェント欄の「…」メニュー：Maximize Chat → チャットを最大化、Close All Tabs → すべてのタブを閉じる、Close Other Tabs → ほかのタブを閉じる、Open Tab as Editor → タブをエディターで開く
- モデルの選択メニューの決まった選択肢：Default → デフォルト、Disable → 無効にする、Inherit from parent → 親から引き継ぐ（モデル名は訳さない）
- 設定の入力例：e.g. us-east-1 → 例: us-east-1（例の値そのものは訳さない）
