# 通関士｜学びスプリント Native Release Status

更新日時: 2026-08-10 18:09 JST

## 対象アプリ
- 資格名: `通関士｜学びスプリント`
- Bundle ID: `jp.allsunday1122.tsukanshi`
- App Store Connect App ID: `6799753744`
- Version: `1.0.0`
- Build番号: `1`（`native-ios/project.yml` の現在値。Internal TestFlight配布BuildはCodemagic実行時に `CM_BUILD_NUMBER` へ置換するため未確定）
- Codemagic workflow: `tsukanshi-ios`。root `codemagic.yaml` は旧WKWebView版のため現行配布設定としてFAIL。純SwiftUI候補は `tsukanshi-sprint/native-ios/codemagic-native-workflow.yaml`
- Codemagic署名プロファイル: `tsukanshi_appstore`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- GitHub Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4127
- 実装監査時コードHEAD: `e276cf7b64492dc30170d60671e9d3263730914f`
- 共通Native Core: PR #4125 / merge commit `f2c600682e88052c2fec70ddd3f023bcacf4a131`
- App Store本審査: 未提出。自動提出禁止。

## 実績ステータス

| 項目 | 判定 | 証跡 |
|---|---|---|
| Notion正本照合 | PASS | Notion `通関士｜学びスプリント` 正本 https://app.notion.com/p/3b609c10697d817588d7ef5e8de23343 / GitHub `tsukanshi-sprint/CHATGPT_NATIVE_CANON.md` / PR #4127 / code HEAD `e276cf7b...` |
| UI要件照合 | PASS | Notion UI Master v2.1 / `tsukanshi-sprint/native-ios/TsukanshiRootShell.swift`, `TsukanshiHomeNativeView.swift`, `TsukanshiStudyViews.swift`, `TsukanshiRecordsNativeView.swift`, `TsukanshiSettingsNativeView.swift` / PR #4127 / HEAD `e276cf7b...` |
| ネイティブ実装 | PASS | `tsukanshi-sprint/native-ios/project.yml`, `TsukanshiNativeApp.swift` ほか純SwiftUIソース。`project.yml`: Bundle ID `jp.allsunday1122.tsukanshi`, Version `1.0.0`, Build `1`。PR #4127 / HEAD `e276cf7b...` |
| データ監査 | PASS | `tsukanshi-sprint/native-ios/Tests/TsukanshiNativeTests.swift` に480学習問＋申告書12セット＝492件、法令基準日、ID重複、模試件数監査。`tsukanshi-sprint/native-ios/TsukanshiContentStore.swift`。PR #4127 / HEAD `e276cf7b...` |
| StoreKit 2 | PASS | `native-ios/LearningSprintCore/Sources/LearningSprintCore/PurchaseController.swift`。`Product.displayPrice`, `Transaction.currentEntitlements`, `Transaction.updates`, `AppStore.sync()`, verified entitlementのみ解放。Native Core PR #4125 merge `f2c60068...`。Sandbox実購入は別途未実施。 |
| オフライン・途中再開・バックアップ | PASS | 教材はローカルJSON。`LearningStateStore.swift` にApplication Support永続化＋JSON export/import、旧ISO-8601互換decoder。`TsukanshiNativeTests.swift` にresume snapshot回帰テスト。Native Core PR #4125 merge `f2c60068...`、PR #4127。 |
| 専門監査 | PASS | 2026-08-10に3周実施。日時精度、途中再開、複数選択、AppIcon取得方式、無料模試件数をFAILとして検出・修正。証跡: 本ファイル、Notion正本更新、PR #4127 / HEAD `e276cf7b...`。 |
| 再監査 | PASS | 修正後にUI・教材・状態設計・Privacy Manifest・StoreKit 2・固定識別子を再照合。証跡: `NATIVE_RELEASE_STATUS.md`, `CHATGPT_NATIVE_CANON.md`, PR #4127 / HEAD `e276cf7b...`。 |
| Releaseビルド | FAIL | 最新HEADでRelease build＋XCTest＋小型/大型iPhone UI testのPASSログなし。正本AppIcon `02_通関士.png` がGitHub `CanonicalAssets/` 未stageでFull Gateを完走できていない。Build番号1は設定値のみでRelease build証跡ではない。 |
| 署名IPA | 未実施 | root `codemagic.yaml` が旧WKWebView workflowのまま。純SwiftUI候補 `native-ios/codemagic-native-workflow.yaml` は作成済みだが、Codemagic実行ログ／IPA artifactなし。 |
| App Store Connectアップロード | 未実施 | App Store Connect App ID `6799753744` は固定済みだが、純SwiftUI signed IPAのアップロードBuild／ログなし。 |
| Internal TestFlight | 未実施 | TestFlight Build番号、処理完了ログ、内部配布Build URL/スクリーンショットなし。 |

## 未完了項目

### 1. 正本AppIconのGitHub stage
- 未完了内容: Notion/Google Drive正本 `02_通関士.png` を `tsukanshi-sprint/native-ios/CanonicalAssets/02_通関士.png` にバイト同一で配置する。
- FAIL理由: 現在のGitHubコネクタはテキスト更新は可能だが、このチャットからPNGバイナリをcontents APIへ直接commitできない。
- 検証済み正本: 1024×1024 / 8-bit RGB / alphaなし / 556001 bytes / SHA-256 `ff9fd508930e8728ef54907ec64a7835dcffb69a1a773edc645b79715fbfccaa`。
- ChatGPTで実行可能: stage後のSHA/IHDR検証、Full Gate解析、FAIL修正。
- 本人操作: 正本PNGを指定GitHubパスへそのままcommitする操作が必要。

### 2. macOS Full Gate
- 未完了内容: Release build / XCTest / 小型iPhone UI test / 大型iPhone UI test。
- FAIL理由: 正本AppIcon未stageのため最新HEADで完走したPASS証跡なし。
- ChatGPTで実行可能: GitHub Actions/Codemagicログ解析、コード修正、テスト追加、再監査。
- 本人操作: 原則なし。ただしmacOS runner/Codemagic側の認証・利用許可が要求された場合のみ対応。

### 3. Codemagic純SwiftUI配布設定
- 未完了内容: root `codemagic.yaml` の `tsukanshi-ios` を純SwiftUI `TsukanshiNative.xcodeproj` / `TsukanshiNative` へ切替。
- FAIL理由: root workflowは旧 `tsukanshi-sprint/ios` WKWebView targetを参照中。
- ChatGPTで実行可能: Full Gate PASS後、候補 `tsukanshi-sprint/native-ios/codemagic-native-workflow.yaml` をrootへ反映し静的監査。
- 本人操作: Codemagic側で `tsukanshi_appstore` プロファイルとApp Store Connect integrationが実在・利用可能か確認。認証が要求された場合に対応。

### 4. 署名IPA / App Store Connect / Internal TestFlight
- 未完了内容: signed IPA生成 → ASC App ID `6799753744` へアップロード → Internal TestFlight処理・内部配布。
- FAIL理由: Release Gate未通過、native root workflow未切替。
- ChatGPTで実行可能: Codemagic設定、ログ監査、アップロード結果の追跡、FAIL修正。
- 本人操作: Apple/Codemagicの認証、契約・権限確認が要求された場合に実施。Internal TestFlight後のiPhone実機Sandbox購入・復元確認も本人操作。

## 次に実行すべき作業
1. 正本 `02_通関士.png` を `tsukanshi-sprint/native-ios/CanonicalAssets/02_通関士.png` へcommit。
2. 最新PR #4127 HEADでmacOS Full Gateを実行し、Release build / XCTest / small+large iPhone UI testをPASSさせる。
3. PASS後にroot `codemagic.yaml` を純SwiftUI workflowへ切替。
4. `tsukanshi_appstore` で署名IPAを生成し、ASC `6799753744` へ送信。
5. Internal TestFlightへ配布し、Build番号と配布証跡を記録。
6. iPhone実機で主要導線・オフライン・Sandbox購入・再起動後権利維持・購入復元を確認。

## TestFlight判定
条件未達。ReleaseビルドPASS、Internal TestFlight用Build番号確定、署名IPA/Codemagic実行証跡が不足しているため、TestFlight Ready文字列は記録しない。

App Store本審査への提出は禁止。`submit_to_app_store: false` を維持する。
