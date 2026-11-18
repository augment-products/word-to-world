# Security Policy

## セキュリティ上の問題の報告 / Reporting Security Issues

**公開の GitHub Issue では報告しないでください。**  
**Please do not report security vulnerabilities through public GitHub issues.**

脆弱性は、非公開で報告してください。まず GitHub の非公開レポートを使い、それが使えないときだけメールを使ってください。  
Report it privately. Prefer a private GitHub report. Use email only when that is not available.

### 報告のしかた / How to Report

1. **GitHub の非公開レポート（こちらを優先） / Private GitHub report (preferred).** このリポジトリの **Security** タブを開き、**Report a vulnerability** を選んでください。  
   Open the **Security** tab of this repository and choose **Report a vulnerability**.
2. **メール（代わりの手段） / Email (alternative).** [contact@augp.jp](mailto:contact@augp.jp)

報告には、次を含めてください。  
Please include:

- 脆弱性の説明 / Description of the vulnerability
- 再現手順 / Steps to reproduce
- 影響の範囲 / Potential impact
- 分かる範囲での修正案 / Suggested fix, if you have one

## Supported Versions

We currently support the latest release version. Security updates will be applied to the main branch and released as patch versions.

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Security Considerations

### This Tool's Security Model

Word to World works by:
1. Asking once, before the first launch with your default profile, and continuing only if you type `yes` (pressing Enter is not consent)
2. Relaunching Cursor with a debug port (127.0.0.1:9333, local-only)
3. Injecting display-time translation through that port
4. Never modifying Cursor.app or your profile files, except the optional Microsoft language pack (installed under `~/.cursor/extensions`) and its `argv.json` locale change, described below

### What Users Should Know

- **Debug port**: While running, programs on this device can reach the Cursor session through 127.0.0.1:9333 (or the port you chose). That includes commands run by Cursor's AI agent or scripts started by npm install. The port is bound to 127.0.0.1, so other devices cannot reach it.
- **Debug port consent**: The first launch with your default profile explains that limit and continues only if you type `yes`. Pressing Enter is not consent. The default mode keeps using your default profile.
- **Profile access**: The default mode uses your default Cursor profile (including chats and account)
- **Network isolation**: The port is bound to 127.0.0.1 only (not exposed to the network)
- **Safe shutdown**: Quitting Cursor (⌘Q or Cursor menu > Quit) closes the port and stops all translation

### Recommendations

- Only run Word to World on trusted systems
- Use `--separate-profile` mode if you're concerned about profile access
- Quit Cursor when not in use (⌘Q or Cursor menu > Quit)
- Don't run untrusted programs while Word to World is active

### What This Tool Does NOT Do

- Does NOT modify `/Applications/Cursor.app`
- Does NOT modify your default profile files, except when you opt into the VS Code Japanese language pack by Microsoft: the pack is installed under `~/.cursor/extensions`, and the `argv.json` locale setting is changed
- Does NOT send data over the network
- Does NOT persist translations to disk

## Updates and Patches

Security fixes will be released as soon as possible after verification. Users will be notified through:
- GitHub Security Advisories
- Release notes
- README updates

## Disclaimer

This is an unofficial community project. Use at your own risk. See [LICENSE](LICENSE) for full disclaimer and warranty information.
