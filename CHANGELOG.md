# 変更履歴 / Changelog

## 0.3.9 (2026-11-17)
- **日本語パック**: Cursor 3.30.14 で見落としていた表示を追加（課金・自動化など）。短い語や汎用的な 1〜2 語（View、Ask など）は、関係ない場所まで訳さないようトップレベルの exact には入れなかった。課金の `{amount}` / `{card}` のような名前付きプレースホルダーは、エンジンが `{0}` `{1}`
  しか展開できないため見送り。
- **Zoom**: 0.3.8 でトップレベルに入れていた「Zoom」を、外観の拡大率の行だけに効く scoped グループ `settings-appearance-zoom` に移した（3.30.14 のバンドルでセレクターを確認）。
- **Build an App**: セレクターを確認できず、タスク名にも使われうるので、いったんトップレベルから外した。
- **確認した版**: パックの `meta.verifiedCursorVersions` に 3.28.7 と 3.30.14 を記載。

## 0.3.8 (2026-11-16)
- **日本語パック（Cursor 3.30.14 対応）**: 3.28.7 からの差分で増えた・言い換わった表示を追加（43 件の exact とパターン 1 件）。Models の「Projects」見出しと取りまとめ役のエフォート、Voice の「Status Chimes」（大文字化。古い「Status chimes」も残す）、Origin、外観の拡大率、アプリ作成の案内、
  作業役のモデルなど。3.28.7 向けの古いキーはそのまま。
- **セレクター修正（3.28.x の指定は残す）**: `model-picker-options` の `ui-model-picker__menu` が 3.30.14 で消えたので、`[data-component="search-menu-popup"]` と `.ui-model-picker__item-content-name` を追加。`bundle-popups` の `ui-menu__empty` が消えたので、`[data-component="menu-empty"]` / `menu-filter-empty` / `search-menu-empty` を追加。
- **エクスプローラー**: Microsoft の日本語パックに無い「You have not yet opened a folder.」「OUTLINE」を追加。「Open Folder」は既にあった。

## 0.3.7 (2026-11-04)
- **watch の不具合を修正**: 翻訳中（`apply`）に `inject.js watch` を動かすと、翻訳が止まっていました。watch は別のページ変数（`window.__cursorI18nWatch`）で動くようになり、翻訳を止めずに横で記録します。翻訳済みの文字は英語のキーで「訳あり」として数えます。テスト追加（`tests/test-engine.js`）。
  **Fixed**: running `watch` while `apply` was active reverted and replaced the translator. The watcher now lives in its own global and records alongside the running translator.
- **日本語パック（Cursor 3.28.7 対応）**: 実機スクリーンショット 228 枚の確認結果を反映。エージェント設定（リモートコントロール・ペアリング済みのデバイス・コンピューター操作）、音声（状態の通知音）、プランと使用量、クラウドエージェント、
  エージェント画面のプロジェクト選択（`agents-project-picker`）、VS Code Settings エディター内の Cursor 自身の設定の説明（`editor-vscode-settings-cursor`）、「VS Code Settings」タブ、カスタマイズの「Installed」「Edit」、3.28.7 で増えた文字。半分英語だった「pull request links …
  を開く」、「ダッシュボードを統合」、ブラウザ→ブラウザー を修正。
  **ja pack** updated for Cursor 3.28.7 (see above). Other languages (drafts/) unchanged.

## 0.3.6
- 訳の変更はなし。任意で Microsoft の日本語言語パックを入れ、表示言語を設定できるようにした（`lab/setup-lab.sh --with-langpack`）。

## 0.3.5
- 画面で確認した表示を追加: 設定のサンドボックス・ネットワーク・API キー、エディターのカスタマイズページ、空のエディターの案内、サインインの案内、ステータスバーのホバー。
- エディター画面のエージェント欄、カスタマイズのタブと Browse ボタン、エージェント欄の「…」メニュー、モデル選択の項目を追加。
- 用語: Steer→軌道修正、Queue→順番待ち、Fork→分岐、Stale→古い状態、Push→プッシュ。

## 0.3.4
- 日本語パックに、まだ画面で確認していない UI の訳を足した（対象の Cursor は 3.27.22）。値は表示用の文字だけ。
