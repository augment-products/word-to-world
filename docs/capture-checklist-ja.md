# 画面を見て回るチェックリスト（日本語パックの取りこぼし探し）

Cursor の画面には、**開いたときだけ出る文字**（メニュー・ツールチップ・確認の画面・通知など）がたくさんあります。
このリストの順に画面を開いていくと、訳されていない英語を集められます。対象は Cursor の UI の英語です（版が変わると場所や名前が変わります）。

## 準備（記録だけ。画面は何も変わりません）
1. いつもどおり日本語表示を止めた状態か、日本語表示中のどちらでもかまいません。
2. ターミナルで、記録を始めます（**読み取り専用**: 画面の文字は書き換えません。入力欄の中身・エディター・ターミナル・チャットの本文・チャットやプロジェクトの名前は記録しません）。
   ```bash
   cd word-to-world
   ELECTRON_RUN_AS_NODE=1 /Applications/Cursor.app/Contents/MacOS/Cursor tools/inject.js watch --lang ja --out work/watch.json
   ```
3. 下のリストの場所を、順にクリックして開きます。**ゆっくりで大丈夫**です（出てきた文字は自動で記録されます。5 秒ごとに保存）。
4. 終わったら、ターミナルで **Ctrl+C**。まとめを作ります:
   ```bash
   ELECTRON_RUN_AS_NODE=1 /Applications/Cursor.app/Contents/MacOS/Cursor tools/inject.js coverage --in work/watch.json --lang ja --out work/coverage.md
   ```
   - `work/coverage.md` … 英語のまま残っていた文字の一覧（場所ごと。どの部品の中か＝DOM の道筋つき）
   - 「in pack? yes」の行 … 辞書にはあるのに、その場所では訳されていない（場所の指定が足りない）
5. **共有する前に** `work/watch.json` と `work/coverage.md` を見て、名前やメールアドレスなどが入っていないか確認してください。

ヒント: ツールチップは、ボタンの上にマウスを **1 秒ほど止める**と出ます。メニューは開いたら、**中の「›」（サブメニュー）にもマウスを乗せて**ください。

---

## A. エージェント画面（Agents Window）

### A-1. 左のサイドバー
- [ ] 上のアイコン（サイドバーを隠す・戻る・進む・検索）に順にマウスを止める（ツールチップ）
- [ ] 「New Chat」「Automations」「Customize」それぞれにマウスを止める・クリックする
- [ ] 見出し「Projects」「Repositories」と、その右の「＋」「…」
- [ ] 絞り込みボタン（Customize Sidebar）→ Grouping / Ordering / Show / Filters の各サブメニュー（Status・PR・Environment・Source・Archived）
- [ ] 「Mark All as Read」
- [ ] チャットの行の上で右クリック（または「…」）→ メニューを**全部**（Pin・Rename・Fork・Export・Move to ›・Mark as Read/Unread・Copy Link ›・Open in New Window・Archive・Archive All Below など）。**チャットの名前そのものは記録されません**
- [ ] プロジェクトの行の「…」→ Rename・Edit Icon・Invite・New Section・Move to ›・アイコン選び（Icons / Grid）
- [ ] リポジトリの行の「…」、「No Repo」の行
- [ ] 行の右端の状態アイコン（完了・実行中・待ち・エラー）と、経過時間（3h など）にマウスを止める
- [ ] 一番下のアカウントの所（名前は記録されません）→ 出てくるメニュー
- [ ] サイドバーが空のとき（新しいプロフィール、または全部アーカイブした状態）の案内文

### A-2. チャットの画面（本文以外）
- [ ] 上のバー: タイトル右の「…」（Chat actions）→ 全項目、Copy ›（Copy Transcript・Copy Request ID・Copy Deep Link など）
- [ ] 上のバーの各アイコン（分割・ブラウザー・ターミナル・変更・閉じる）にマウスを止める
- [ ] 右側のパネル: Changes・Terminal・Browser・Canvas などのタブと、空のときの表示
- [ ] 変更（diff）の画面の上のボタン: Keep / Undo / Review / Commit / Create PR / Checkout ›、その確認の画面
- [ ] PR の表示（PR の題名は記録されません）: 状態のバッジ、Checks、Merge のメニュー
- [ ] エラーのとき: 「Something went wrong」「Retry」、ネットワーク切断時の表示（Wi-Fi を一時的に切ると出ることがある）
- [ ] 実行中: Stop・Queue（順番待ち）・Steer（軌道修正）・Interrupt のボタンとツールチップ
- [ ] ツールの承認: Allow / Deny / Always allow / Run / Skip のボタン、Auto-review の表示
- [ ] 質問への回答（Ask Question）・Plan の確認（Build / Approve）の画面
- [ ] To-dos の一覧と、その「…」

### A-3. 入力欄のまわり（入力した文字は記録されません）
- [ ] 案内文（Plan, Build, / for skills…）: 新しいチャット・続きの入力・クラウド・プランのモードを切り替えて、それぞれの案内文を表示する
- [ ] モード切り替え（Agent / Plan / Ask / Debug / Multitask）のメニューと説明文
- [ ] モデルの選び方（Auto など）のメニュー: Add or search model、Max Mode、モデルの説明のツールチップ（**モデル名は訳しません**）
- [ ] プロジェクト／リポジトリの選び方、ブランチの選び方（Search branches…）、実行環境（Local / Cloud / Worktree / SSH）のメニュー
- [ ] 「＋」（エージェント・コンテキスト・ツールを追加）→ 全項目とサブメニュー（Files・Folders・Docs・Web・Git・Terminals・Rules・Skills…）
- [ ] 「/」を入力して出るコマンドの一覧（Cursor 自身の項目だけが対象）、「@」で出る一覧
- [ ] マイク（音声入力）・音声チャットのボタン → 許可の確認、声の選び方（Choose a voice）
- [ ] 画像を貼る・ファイルを落とす（ドラッグ）ときの表示
- [ ] Claude Code の会話インポートの案内 → Import の画面（What to import… など）

### A-4. 自動化（Automations）・カスタマイズ（Customize）
- [ ] Automations の一覧・空のとき・New Automation の画面（Trigger・Schedule・Daily/Weekly・Weekdays・Time zone の選び方 Search time zones…）
- [ ] 実行の履歴（Runs）・Search runs…・状態の絞り込み
- [ ] Customize: Rules・Skills・Subagents・Commands・Hooks・Plugins・MCP の各タブ、New … のボタン、空のときの表示
- [ ] Plugins / Marketplace: 検索、Install / Uninstall、Add Marketplace の画面（Marketplace repository URL…）
- [ ] MCP: サーバーを追加・OAuth（Client ID / Client Secret）・接続エラーの表示

### A-5. プロジェクト
- [ ] New Project の画面（Workspace name・Repository URL・Clone…）
- [ ] プロジェクトの設定・メンバーの招待（Add emails, separated by commas）・共有
- [ ] Kanban（Board）表示・List 表示の切り替え、列の見出し（Todo・In Progress・For Review・Done・Canceled）

### A-6. 通知・確認の画面（出たときに記録されます）
- [ ] コピーしたときの「Copied…」の通知、エラーの通知、Undo つきの通知
- [ ] 削除・アーカイブ・変更の破棄（Discard changes）などの確認の画面
- [ ] アップデートの通知（Restart to Update など）、ログインが切れたときの表示
- [ ] 新機能の紹介・オンボーディング・おすすめ（Tips）の表示（出ていれば）

## B. 設定（Cursor Settings）
エージェント画面の設定（歯車）と、エディター画面の「Cursor Settings」タブの**両方**で見てください。
- [ ] 左の一覧の**すべてのタブ**を順に開く: General / Agents / Tab / Models / Cloud Agents / Tools & MCP / Rules, Skills, Subagents / Indexing & Docs / Network / Hooks / Plugins / Beta / Plan & Usage / Appearance / Keyboard Shortcuts / Notifications / Privacy / Voice / Worktrees / Integrations など（版によって名前・数が違います）
- [ ] 各タブで**下までスクロール**し、すべての「›」（詳細）、「Edit」「Manage」「Configure」を開く
- [ ] 各項目の「?」・説明の小さなアイコンにマウスを止める（ツールチップ）
- [ ] プルダウン（選択肢の一覧）を**全部**開く（例: 既定のモード、表示密度、テーマ、言語、ショートカットの方式）
- [ ] 切り替えスイッチを ON にすると出てくる追加の項目（終わったら元に戻す）
- [ ] Models: Add or search model、API キーの入力欄（Enter API key・AWS Access Key ID など。**入力しない**）、Verify のエラー表示
- [ ] Cloud Agents: 実行環境（Environments）の作成画面（Add custom setup steps…）、Secrets、GitHub の連携の案内
- [ ] Indexing & Docs: インデックスの状態、Add Doc の画面
- [ ] Network: 診断（Run Diagnostics）の結果の表示
- [ ] Plan & Usage: 使用量のグラフ・表、期間の切り替え、Upgrade・Manage のボタン、上限の設定（Spending / Amount）
- [ ] アカウント: ログアウトの確認、チーム（Team）・招待の表示
- [ ] 設定の検索欄に英語の語を入れて、検索結果の表示（「No results」など）

## C. エディター画面（Cursor 自身の部分だけ）
- [ ] 最初の画面（Open project・Clone repo・Connect via SSH・Recent projects）
- [ ] タイトルバーのボタン（Agents Window・サイドバーの切り替え・設定）にマウスを止める
- [ ] 下のステータスバーの Cursor 自身の項目（Cursor Tab・Tab Stats・No commit scored など）にマウスを止める・クリックする
- [ ] ステータスバーの「…」メニュー（Configure Icon Visibility・Open Browser など）
- [ ] コマンドパレット（⌘⇧P）で「Cursor」と入力し、Cursor 自身のコマンドの一覧を上から下までスクロール（※ VS Code 本体のコマンドは対象外）
- [ ] エディターの中の Cursor の表示: ⌘K（インラインの編集）の入力欄のまわり・ボタン、変更の受け入れ（Accept / Reject）のボタン、Tab 補完の案内
- [ ] 右クリックメニューの Cursor 自身の項目（Add to Chat など）
- [ ] 右側のチャット（エディター画面のエージェント）: A-2・A-3 と同じ所
- [ ] 通知（右下）: Cursor 自身の通知（ログイン・アップデート・インデックス・Tab）

## D. その他
- [ ] ログイン・ログアウトの画面、プランの案内（Upgrade to Pro など）
- [ ] オフラインのとき（Wi-Fi を切る）の表示 → 終わったら戻す
- [ ] Cursor の再起動後の「What's New」（出れば）

---
## 終わったら
- `work/coverage.md` の英語の一覧を、訳の担当（AI でも可）に渡します。手順は [CONTRIBUTING-AI.md](../CONTRIBUTING-AI.md)。
- `python3 tools/update_worklists.py work/watch.json --out work/worklists` で作業リストも作れます。
