# 通関士｜学びスプリント Native Release Status

更新日時: 2026-08-10 18:44 JST

## 対象アプリ
- 資格名: `通関士｜学びスプリント`
- Bundle ID: `jp.allsunday1122.tsukanshi`
- App Store Connect App ID: `6799753744`
- Version: `1.0.0`
- Build番号: `1` は `tsukanshi-sprint/native-ios/project.yml` の現在設定値。Internal TestFlight配布Build番号はCodemagic実行時の `CM_BUILD_NUMBER` で確定するため未確定。
- Codemagic workflow: `tsukanshi-ios`
- Codemagic署名プロファイル: `tsukanshi_appstore`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- Team ID: `MN3D2ZM44N`
- GitHub Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4127
- 実装監査時コードHEAD: `e276cf7b64492dc30170d60671e9d3263730914f`
- 2026-08-10 18:44再確認時PR HEAD: `03470845c1a8dc3199542bf2d8395611b3e981b8`
- `e276cf7b...` → `03470845...` の差分は `CHATGPT_NATIVE_CANON.md` と本進捗ファイルのみ。ネイティブ実装コード変更なし。
- App Store本審査: 未提出。自動提出禁止。

## 正本再照合
2026-08-10 18:44 JSTに以下をNotionプラグインで再取得して照合した。
- 対象アプリ正本: https://app.notion.com/p/3b609c10697d817588d7ef5e8de23343
- 標準手順 v2.2: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- 申請手順: https://app.notion.com/p/3b009c10697d81eba325f86d8af55481
- UI正本 v2.1 Golden Master: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f

標準手順の再発火原則により、Release buildの証跡がない状態ではRelease工程をPASSにしない。申請手順に従い、本審査自動提出は無効のままとする。

## 実績ステータス

| 項目 | 判定 | 証跡 |
|---|---|---|
| Notion正本照合 | PASS | 上記Notion 4正本を2026-08-10 18:44 JSTに再取得。GitHub `tsukanshi-sprint/CHATGPT_NATIVE_CANON.md`、PR #4127、監査コードHEAD `e276cf7b...`。 |
| UI要件照合 | PASS | `tsukanshi-sprint/native-ios/TsukanshiRootShell.swift`、`TsukanshiHomeNativeView.swift`、`TsukanshiStudyViews.swift`、`TsukanshiRecordsNativeView.swift`、`TsukanshiSettingsNativeView.swift`。UI Master v2.1の4タブ、4/8/16問、即時採点、苦手3連続解除、中断復帰等を監査。PR #4127 / code HEAD `e276cf7b...`。 |
| ネイティブ実装 | PASS | `tsukanshi-sprint/native-ios/project.yml`、`TsukanshiNativeApp.swift` ほか純SwiftUIソース。`project.yml` は Bundle ID `jp.allsunday1122.tsukanshi` / Version `1.0.0` / Build設定値 `1`。PR #4127 / code HEAD `e276cf7b...`。 |
| データ監査 | PASS | `tsukanshi-sprint/native-ios/Tests/TsukanshiNativeTests.swift`、`TsukanshiContentStore.swift`。480学習問＋申告書12セット＝492件、法令基準日、ID重複、模試件数の監査コード。PR #4127 / code HEAD `e276cf7b...`。 |
| StoreKit 2 | PASS | `native-ios/LearningSprintCore/Sources/LearningSprintCore/PurchaseController.swift`。`Product.displayPrice`、verified transaction、`Transaction.currentEntitlements`、`Transaction.updates`、`AppStore.sync()`を実装。共通Core PR #4125 merge commit `f2c600682e88052c2fec70ddd3f023bcacf4a131`。Sandbox実購入はInternal TestFlight後の本人操作待ち。 |
| オフライン・途中再開・バックアップ | PASS | ローカル教材JSON、`LearningStateStore.swift` のApplication Support永続化＋JSON export/import、旧ISO-8601互換decoder、`TsukanshiNativeTests.swift` のresume snapshot回帰テスト。共通Core PR #4125 / PR #4127。 |
| 専門監査 | PASS | 3周監査でバックアップ日時精度、途中再開snapshot、複数選択必要数、AppIcon取得方式、無料模試件数のFAILを検出し修正。証跡: PR #4127、code HEAD `e276cf7b...`、本ファイル。 |
| 再監査 | PASS | 修正後にUI・教材・状態設計・Privacy Manifest・StoreKit 2・固定識別子を再照合。`e276cf7b...`以降のPR差分は進捗文書のみで実装コード変更なし。比較: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/compare/e276cf7b64492dc30170d60671e9d3263730914f...03470845c1a8dc3199542bf2d8395611b3e981b8 |
| Releaseビルド | FAIL | PR HEAD `03470845...` にGitHub combined statusなし。`release-evidence/tsukanshi-native-full-gate.md` は存在しない。正本AppIcon `tsukanshi-sprint/native-ios/CanonicalAssets/02_通関士.png` もGitHub上に存在しないため、`.github/workflows/tsukanshi-native.yml` のRelease simulator build / XCTest / small+large iPhone UI testを最新HEADで完走したPASS証跡なし。 |
| 署名IPA | 未実施 | root `codemagic.yaml` の `tsukanshi-ios` は現在も旧 `tsukanshi-sprint/ios/TsukanshiSprint.xcodeproj` / `TsukanshiSprint` を参照。`submit_to_testflight: false`。純SwiftUI候補は `tsukanshi-sprint/native-ios/codemagic-native-workflow.yaml` にあるがroot未反映、IPA artifact/logなし。 |
| App Store Connectアップロード | 未実施 | ASC App ID `6799753744` は確定済み。純SwiftUI signed IPAのアップロードBuild ID / processing log / upload証跡なし。 |
| Internal TestFlight | 未実施 | Internal TestFlight用Build番号、処理完了ログ、内部グループ配布証跡なし。 |

## 未完了項目

### 1. 正本AppIconをGitHubへstage
- 未完了内容: 正本 `02_通関士.png` を `tsukanshi-sprint/native-ios/CanonicalAssets/02_通関士.png` にバイト同一で配置する。
- FAIL理由: 2026-08-10 18:44再確認でGitHub上の対象パスは404。
- 正本検証値: 1024×1024 / 8-bit RGB / alphaなし / 556001 bytes / SHA-256 `ff9fd508930e8728ef54907ec64a7835dcffb69a1a773edc645b79715fbfccaa`。
- ChatGPTで実行可能: 配置後のSHA/IHDR検証、CI再発火、ログ解析、FAIL修正。
- 本人操作が必要な場合: GitHub UI等から正本PNGを指定パスへそのままupload/commitする。

### 2. macOS Full Gate
- 未完了内容: `.github/workflows/tsukanshi-native.yml` のRelease simulator build、native XCTest、小型/大型iPhone UI testを最新HEADでPASSさせる。
- FAIL理由: AppIcon未stageかつ最新HEADのPASSログなし。
- ChatGPTで実行可能: コード・テスト・workflow修正、ログ解析、再監査。
- 本人操作: 通常不要。GitHub/Codemagic側で認証・利用許可が要求された場合のみ対応。

### 3. Codemagic純SwiftUI切替
- 未完了内容: root `codemagic.yaml` の `tsukanshi-ios` を `tsukanshi-sprint/native-ios/TsukanshiNative.xcodeproj` / scheme `TsukanshiNative` へ切替し、Internal TestFlight専用exportを固定する。
- FAIL理由: 現行root workflowは旧WKWebView target参照、`submit_to_testflight: false`。
- ChatGPTで実行可能: Full Gate PASS後に `tsukanshi-sprint/native-ios/codemagic-native-workflow.yaml` をrootへ反映し静的監査。
- 本人操作: Codemagic integration、App Store Connect認証、`tsukanshi_appstore`相当の署名資材が要求された場合に対応。

### 4. 署名IPA / App Store Connect / Internal TestFlight
- 未完了内容: signed IPA生成 → ASC App ID `6799753744`へアップロード → Internal TestFlight処理・内部配布。
- FAIL理由: Release Gate未通過、root native workflow未切替。
- ChatGPTで実行可能: Codemagic設定、ログ監査、アップロード後の証跡記録、FAIL修正。
- 本人操作: Apple/Codemagicログイン、2FA、契約・権限確認が要求された場合。Internal TestFlight後のiPhone実機Sandbox購入・再起動後権利維持・購入復元確認。

## 次に実行すべき作業
1. 正本 `02_通関士.png` をGitHub指定パスへバイト同一でstage。
2. PR #4127最新HEADでmacOS Full Gateを実行し、Release build / XCTest / small+large iPhone UI testをPASS。
3. PASS後にroot `codemagic.yaml` を純SwiftUI workflowへ切替し、`submit_to_testflight: true` / `submit_to_app_store: false` を確認。
4. `tsukanshi_appstore`相当で署名IPA生成、ASC `6799753744`へアップロード。
5. Internal TestFlightへ配布し、Build番号・処理ログ・配布証跡をNotion/GitHubへ追記。
6. iPhone実機で主要導線・オフライン・Sandbox購入・再起動後権利維持・購入復元を確認。

## TestFlight判定
条件未達。ReleaseビルドPASS、Internal TestFlight配布Build番号確定、署名IPA/Codemagic実行証跡が不足しているため、Readyラベルは記録しない。

App Store本審査への提出は禁止。`submit_to_app_store: false` を維持する。
