# 通関士｜学びスプリント ChatGPT Native Canon

更新日: 2026-08-10

このファイルは2026-08-10以降のiOSネイティブ実装における現在地の入口です。

## 優先順位
1. ユーザーが2026-08-10に指定した対象アプリ固定識別情報・実装方針
2. Notion「AIアプリ開発 標準手順 v2.2」
3. Notion「申請手順」
4. Notion「学びスプリント｜UI要件定義テンプレ v2.1」
5. Notion「通関士｜学びスプリント」開発正本
6. `native-ios/NATIVE_RELEASE_STATUS.md`
7. `RELEASE_STATUS.md` / `RELEASE_CHECKLIST.md`
8. 監査記録・申請資料

`CODEX_HANDOFF.md` は2026-08-09時点の履歴資料です。現在はCodexへ引き継がず、現在地・再開手順・Release Gateの判定には使用しません。

## 固定識別子
- Bundle ID: `jp.allsunday1122.tsukanshi`
- App Store Connect App ID: `6799753744`
- Codemagic profile: `tsukanshi_appstore`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- Distribution: App Store
- TestFlight: Internal Testing only
- App Store本審査自動提出: 禁止

## 現在地
純SwiftUIネイティブ化を実装済み。WKWebViewを主UIに使わない。

- Draft PR #4127
- Fast Preflight PASS
- macOS Full Gate（Release build / XCTest / small+large iPhone UI test）はGitHub macOS runner待ち
- 正本AppIconはGoogle Drive `02_通関士.png`（file id `1fVipxbpieTaTW81ZlXYklWXqsViDcVw3`）をビルド時にSHA-256固定で取得し、不一致ならFAIL
- `codemagic.yaml` は旧WKWebView targetのままなのでsigned IPAをまだ作らない

次の合格条件は `native-ios/NATIVE_RELEASE_STATUS.md` を参照する。
