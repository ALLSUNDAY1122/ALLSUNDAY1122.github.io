# 通関士｜学びスプリント ChatGPT Native Canon

更新日時: 2026-08-10 18:09 JST

このファイルは2026-08-10以降のiOSネイティブ実装における現在地の入口です。実績のPASS/FAILと証跡は `native-ios/NATIVE_RELEASE_STATUS.md` を正とします。

## 優先順位
1. ユーザー指定の対象アプリ固定識別情報・純SwiftUI方針
2. Notion「AIアプリ開発 標準手順 v2.2」
3. Notion「申請手順」
4. Notion「学びスプリント｜UI要件定義テンプレ v2.1 / Golden Master」
5. Notion「通関士｜学びスプリント」開発正本
6. `native-ios/NATIVE_RELEASE_STATUS.md`
7. `RELEASE_STATUS.md` / `RELEASE_CHECKLIST.md`

`CODEX_HANDOFF.md` は履歴資料です。現在はCodexへ引き継がず、ChatGPTで純SwiftUIネイティブ開発を継続します。

## 固定識別子
- Bundle ID: `jp.allsunday1122.tsukanshi`
- App Store Connect App ID: `6799753744`
- Version: `1.0.0`
- Build設定値: `1`（Internal TestFlight配布Buildは未確定。Codemagic実行時に `CM_BUILD_NUMBER` へ置換）
- Codemagic workflow: `tsukanshi-ios`
- Codemagic profile: `tsukanshi_appstore`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- Team ID: `MN3D2ZM44N`
- Distribution: App Store / Internal TestFlight only
- App Store本審査自動提出: 禁止

## GitHub正本
- Draft PR #4127: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4127
- 実装監査時コードHEAD: `e276cf7b64492dc30170d60671e9d3263730914f`
- 進捗証跡更新commit: `b1523a4ab0b2d0e2250ebd4087bb983e786d2093`
- 共通Native Core PR #4125 merge: `f2c600682e88052c2fec70ddd3f023bcacf4a131`
- 詳細進捗: `tsukanshi-sprint/native-ios/NATIVE_RELEASE_STATUS.md`

## 現在判定
- 正本・UI要件・純SwiftUI実装・教材データ・StoreKit 2・オフライン/途中再開/JSONバックアップ・専門監査・再監査: 証跡付きPASS。
- 最新HEAD Release build / XCTest / 小型・大型iPhone UI test: FAIL（正本AppIcon未stage、最新PASSログなし）。
- 署名IPA / App Store Connectアップロード / Internal TestFlight: 未実施。
- root `codemagic.yaml` は旧WKWebView workflowのため現行配布設定としてFAIL。純SwiftUI候補は `native-ios/codemagic-native-workflow.yaml`。

## 次のゲート
1. 正本 `02_通関士.png` を `native-ios/CanonicalAssets/02_通関士.png` にバイト同一でcommit。
2. macOS Full Gateを最新HEADでPASS。
3. root Codemagicを純SwiftUI workflowへ切替。
4. `tsukanshi_appstore` 署名 → ASC `6799753744` → Internal TestFlight。

TestFlight Ready条件は未達のため、Ready文字列は記録しない。
本審査への提出は禁止。
