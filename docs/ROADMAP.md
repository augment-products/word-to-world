# ロードマップ — 対応言語 / Roadmap — languages

> **これは目安で、約束ではありません。** 順番の最終判断は AUGMENT PRODUCTS がします。数字は「需要の手がかり」として使っているだけです。
> **This is a guide, not a promise.** The final order is decided by AUGMENT PRODUCTS. The numbers are only a demand proxy.

[日本語](#日本語) · [English](#english)

---

## 日本語

### 方針
- 言語の範囲は **VS Code 公式の表示言語（Microsoft の言語パックがある言語）** に合わせます。メニューバーなど VS Code 由来の部分は Microsoft の言語パック、Cursor 独自の画面はこのツールの言語レイヤー、と役割を分けられるからです（README「メニューバー…」の節）。
- 日本語以外の言語レイヤーは**まだこのリポジトリにありません**。ネイティブの確認（issue の「訳の修正」フォーム）が集まってから `locales/<lang>.json` を足します。
- 訳の出発点は機械翻訳 + AI 補助です。「だいたい合っている」状態から、ネットの仲間に直してもらう前提です。

### 段階
言語 ID（vscode-loc と同じ小文字。文書のどこでもこの一覧）:

`ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl`

| 段階 | 言語 | Microsoft 言語パック ID | 状態 |
|---|---|---|---|
| 公開 | 日本語 `ja` | `MS-CEINTL.vscode-language-pack-ja` | `locales/ja.json`（この公開版に含まれます） |
| 次 | 簡体字中国語 `zh-cn`、繁体字中国語 `zh-tw` | `…-zh-hans` / `…-zh-hant` | 言語レイヤーのファイルはまだこのリポジトリにありません |
| その後 | `ko` `fr` `de` `es` `it` `ru` `pt-br` `cs` `tr` `pl` | 同じ ID の Microsoft パック（`pt-br` の拡張機能 ID は `pt-BR`） | 言語レイヤーのファイルはまだこのリポジトリにありません |
| 別トラック | アラビア語 `ar` | （VS Code 公式パックなし） | 右から左（RTL）のレイアウトが別に必要です。上の一覧には入れません |

繁体字は `zh-tw` 一つです。メニューバーなどは Microsoft の繁体字パック（zh-hant）を使います。

### 需要の手がかり
VS Code の言語パックのダウンロード数（Visual Studio Marketplace の表示、2026-11-04 時点）:

| 言語 | ダウンロード数 |
|---|---|
| 簡体字中国語（zh-hans） | 約 5,690 万 |
| 日本語 | 約 1,580 万 |
| スペイン語 | 約 1,230 万 |
| ポルトガル語（ブラジル） | 約 980 万 |
| ロシア語 | 約 930 万 |
| 韓国語 | 約 720 万 |
| フランス語 | 約 670 万 |
| ドイツ語 | 約 580 万 |

Cursor フォーラムでの要望（2026-11 時点で目についたもの）:
- 中国語（簡体字）: 「Add support for Chinese」（2025-05 から続く長いスレッド）、「Native Simplified Chinese UI Localization」
- 中国語（繁体字・台湾/香港）: 「Marketing shows Chinese UI, but paid product has no usable Traditional Chinese interface」
- 日本語: 「Feature Request: Native Japanese UI Localization」（機械翻訳でもよいので、という声）
- ロシア語: 「I can't change the interface language」（ロシア語化に協力したいという申し出）

韓国語の数字は 720 万でスペイン語などより少なめですが、日本語・中国語と同じ東アジアの言語で、用語表の作り方が近いため第 2 波に入れています。

### 次に動くこと
1. 言語ごとに、ネイティブの方からの「訳の修正」issue を受け付けます。
2. 画面での確認（`docs/capture-checklist-ja.md` と同じ手順）を通った言語から `locales/<lang>.json` を足し、`lab/start.sh --lang` で選べるようにします。

### 将来の表示（このリリースでは行いません）
今の版は、設定のラベルと入力欄の案内文を CSS で描き、その DOM には英語を残します。それ以外の一部の表示は、文字ノードと `aria-label`・`placeholder`・`title` を書き換えます。将来の版で、表示中の訳をすべて CSS で描き、DOM と読み上げには英語が残るようにすることを検討します。
このリリースの範囲ではありません。

---

## English

### Policy
- The language set follows **VS Code's official display languages (those with a Microsoft language pack)**. That way the VS Code side (menu bar etc.) comes from Microsoft's pack and Cursor's own screens come from this tool's language layer (see the README section on the menu bar).
- Language layers other than Japanese are **not in this repository yet**. A language is added as `locales/<lang>.json` once native speakers have reviewed it (via the "translation fix" issue form). The display name is `Word to World for Cursor | ` plus `meta.name` plus ` Language Layer`.
- The starting point is machine translation plus AI help — "roughly right" first, then fixed by the community.

### Stages
Language IDs (lowercase vscode-loc ids; the same list everywhere):

`ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl`

| Stage | Languages | Microsoft language pack ID | Status |
|---|---|---|---|
| Public release | Japanese `ja` | `MS-CEINTL.vscode-language-pack-ja` | `locales/ja.json` (included in this public release) |
| Next | Simplified Chinese `zh-cn`, Traditional Chinese `zh-tw` | `…-zh-hans` / `…-zh-hant` | no language layer file in this repository yet |
| Later | `ko` `fr` `de` `es` `it` `ru` `pt-br` `cs` `tr` `pl` | the Microsoft pack with the same id (`pt-br` uses extension id `pt-BR`) | no language layer file in this repository yet |
| Separate track | Arabic `ar` | (no official VS Code pack) | right-to-left layout needs its own design. Not part of the list above |

Traditional Chinese is the single id `zh-tw`. The menu bar uses Microsoft's Traditional Chinese pack (zh-hant).

### Demand proxy
VS Code language pack downloads as displayed on the Visual Studio Marketplace on 2026-11-04:

| Language | Downloads |
|---|---|
| Simplified Chinese (zh-hans) | 56.9M |
| Japanese | 15.8M |
| Spanish | 12.3M |
| Portuguese (Brazil) | 9.8M |
| Russian | 9.3M |
| Korean | 7.2M |
| French | 6.7M |
| German | ~5.8M |

Requests on the Cursor forum (noticed as of 2026-11):
- Simplified Chinese: "Add support for Chinese" (long thread since 2025-05), "Native Simplified Chinese UI Localization"
- Traditional Chinese: "Marketing shows Chinese UI, but paid product has no usable Traditional Chinese interface"
- Japanese: "Feature Request: Native Japanese UI Localization" ("even machine translation would help")
- Russian: "I can't change the interface language" (an offer to help translate)

Korean (7.2M) is below Spanish and others but sits in wave 2 because, like ja/zh, it is an East Asian language whose glossary work is similar.

### Next
1. Collect "translation fix" issues from native speakers for each language.
2. Languages that pass an on-screen check (same steps as `docs/capture-checklist-ja.md`) are added as `locales/<lang>.json` and become selectable with `lab/start.sh --lang`.

### Future display (not in this release)
This version draws settings labels and the composer placeholder with CSS and leaves the English in that DOM. Some other visible text is applied by replacing text nodes and the `aria-label`, `placeholder`, and `title` attributes. A later version may draw every visible translation with CSS, so the DOM and assistive technologies keep the original English. That work is deferred and is not
part of this release.
