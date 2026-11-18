# drafts/ — Machine-Translated Drafts (Not for Release)

**これらの機械翻訳ファイルは、リリースには含まれていません。**  
**These machine-translated files are NOT included in the release.**

## Status

Language IDs (same list everywhere, lowercase vscode-loc ids):

`ja zh-cn zh-tw ko fr de es it ru pt-br cs tr pl`

Only `ja` ships, in `locales/ja.json`. The other IDs are planned. A new language starts here with `node tools/new-locale.js <id>`, copied from `templates/locale-template.json`. A file in this folder is not shipped. `locales/` stays for a language that is complete.

A machine-translated starting point may contain:
- Incorrect translations
- Inappropriate terminology
- Context-mismatched phrases
- Untranslated strings (shown in English)

Nothing here is ready to ship until a native speaker has reviewed it.

## Contributing

**ネイティブスピーカーによる確認と修正を歓迎します！**  
**Native speaker review and corrections are very welcome!**

If you would like to help bring one of these languages to release quality:

1. Open an issue using the "[Translation fix](../../issues/new?template=translation-fix.yml)" form
2. Indicate which language you'd like to help with
3. We can discuss the review process

## Roadmap

Planned language support order is documented in [docs/ROADMAP.md](../docs/ROADMAP.md). This is a guideline, not a commitment.

## Why Not Include Them?

Machine translations often produce awkward or incorrect results, especially for UI text where context matters greatly. We prefer to:
- Wait for native speaker review before shipping
- Avoid confusing users with poor-quality translations
- Maintain the quality standard set by the Japanese pack

English remains usable for all Cursor features, so there's no urgency to ship unverified translations.
