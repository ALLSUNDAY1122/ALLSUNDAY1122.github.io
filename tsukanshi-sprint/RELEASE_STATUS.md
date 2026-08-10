# 通関士｜学びスプリント RELEASE STATUS

更新日: 2026-08-10

## 現行正本
2026-08-10以降は純SwiftUIネイティブ版を現行リリース対象とする。旧 `SwiftUI + WKWebView` 版のRelease完了記録は履歴扱いであり、Internal TestFlight判定には使用しない。

最新の実装・監査・Release Gate状態は次を正本とする。

- `tsukanshi-sprint/native-ios/NATIVE_RELEASE_STATUS.md`
- Draft PR #4127 `通関士｜純SwiftUIネイティブ移行`
- 共通Core Draft PR #4125 `学びスプリント SwiftUI Native Core`

## 固定識別子
- App: `通関士｜学びスプリント`
- Bundle ID: `jp.allsunday1122.tsukanshi`
- App Store Connect App ID: `6799753744`
- Version: `1.0.0`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- Codemagic profile: `tsukanshi_appstore`
- Team ID: `MN3D2ZM44N`

## 現在地
純SwiftUI実装、480学習問＋申告書12セット、4タブ、4/8/16問、即時採点、苦手3連続正解解除、途中再開、オフライン教材、JSONバックアップ、StoreKit 2まで実装済み。

現時点ではInternal TestFlight-readyではない。阻害要因は以下。

1. Notion/Drive正本 `02_通関士.png` をnative branchへstageし、最新macOS Full Gateを完走する。
2. Release simulator build、XCTest、小型/大型iPhone UI testを最新HEADでPASSさせる。
3. root `codemagic.yaml` の旧WKWebView `tsukanshi-ios` workflowを純SwiftUI native workflowへ切り替える。
4. Codemagic署名付きIPAをApp Store Connect App ID `6799753744`へ送信し、Internal TestFlightへ配布する。
5. iPhone実機でSandbox購入・復元を確認する。

App Store本審査への自動提出は禁止。`submit_to_app_store` はfalseを維持する。
