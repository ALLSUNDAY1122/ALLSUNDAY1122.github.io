# 司法書士｜学びスプリント Native iOS 進捗正本

更新日時: 2026-08-10 18:10 JST

## 対象アプリ

- 資格名: 司法書士試験・択一式｜学びスプリント
- Bundle ID: `jp.allsunday1122.shoshi`
- App Store Connect App ID: `6799755748`
- Version: `1.0.0`
- Build番号: `1`（`learning-sprint/shoshi/ios/project.yml` の既定値。Codemagic signed buildでは `CM_BUILD_NUMBER` に置換する設計。Codemagic未実行のため実配布Build番号は未確定）
- Codemagic workflow: `shoshi-ios`（定義: `learning-sprint/shoshi/ios/codemagic-shoshi.yml`）
- Codemagic署名プロファイル: `shoshi_appstore`
- IAP: `jp.allsunday1122.shoshi.premium`
- PR: #4129 `司法書士｜WKWebView廃止・純SwiftUIネイティブ化`
- 実装ブランチ: `feature/shoshi-native-swiftui`
- 記録時PR head: `a92ac10eb5f0bcddcec9a31af56ca475578e6bcf`

## 実績ステータス

| 項目 | 判定 | 証跡 |
|---|---|---|
| Notion正本照合 | PASS | Notion `標準手順 v2.2`、`申請手順`、Golden Master v2.1、司法書士開発正本を2026-08-10再取得・照合。開発正本: https://app.notion.com/p/3b709c10697d81059119e5b324dbfb0c |
| UI要件照合 | PASS | `learning-sprint/shoshi/ios/Views.swift`, `Theme.swift`, `AppModel.swift`; PR #4129; GitHub Actions Run #43 (`31363823126`) の `native-source-and-contract` PASS |
| ネイティブ実装 | PASS | WebKit/WKWebViewをアプリ実装から排除。`learning-sprint/shoshi/ios/*.swift`; PR #4129; Run #43 `native-source-and-contract` PASS |
| データ監査 | PASS | `learning-sprint/shoshi/content-loop/learning-sprint-audit.json`, `content-audit-report.json`, `learning-sprint/shoshi/ios/Resources/questions.generated.json`; Run #43 `Validate audited 210-question content` PASS。210問・ID一意・R7午後33 `all_correct` を再検証 |
| StoreKit 2 | PASS | `learning-sprint/shoshi/ios/StoreKitManager.swift`, `learning-sprint/shoshi/app-store/STOREKIT_TEST_PLAN.md`, `apply-xcode-capabilities.py`; Run #43 source contract PASS。Product ID `jp.allsunday1122.shoshi.premium` 固定 |
| オフライン・途中再開・バックアップ | PASS | 問題JSONをapp bundleへ同梱、`AppModel.swift`, `BackupDocument.swift`, `LearningLogic.swift`, `Tests/ShoshiSprintTests.swift`; Run #43 XCTest PASS / built `.app` resource inspection PASS |
| 専門監査 | PASS | PR #4129内で、無料1スプリント消費状態がJSON/学習リセットで復活する課金境界不備、JSON入力整合、旧Privacy WebView表記を検出し修正。関連コミット `cb7964c01a365fdacdb316f8b287998930fc586f`, `c90a37334163a6806dcba7d825fd8955139015d9`, `a92ac10eb5f0bcddcec9a31af56ca475578e6bcf` |
| 再監査 | PASS | GitHub Actions Run #43 (`31363823126`): `native-source-and-contract` PASS、XCTest PASS、Release Simulator build PASS、built `.app` inspection PASS。正本AppIcon専用ゲートは別途FAIL |
| Releaseビルド | PASS | Run #43 `native-tests-and-release-build`: unsigned iOS Simulator Release build PASS、`questions.generated.json` / `PrivacyInfo.xcprivacy` / `Assets.car`存在、`Web`ディレクトリ不在を検査 |
| 署名IPA | 未実施 | 正本AppIconがReleaseハードゲートFAIL、root Codemagic統合未完了のため signed IPA buildは未実施 |
| App Store Connectアップロード | 未実施 | signed IPA未生成。App Store Connect App IDは `6799755748` で固定済み |
| Internal TestFlight | 未実施 | ASC upload未実施。実機確認未実施 |

## FAIL / 未完了項目

1. **正本AppIcon Releaseゲート: FAIL**
   - 必須SHA-256: `c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506`
   - Run #43 `canonical-app-icon` job はFAIL。
   - 原因: 正本PNGの元バイトはGoogle Driveコネクタで取得確認済みだが、`Assets.xcassets/AppIcon.appiconset/AppIcon.png` に正本バイナリをまだ固定できていない。
   - 仮アイコンでRelease/TestFlightへ進むことは禁止。

2. **root Codemagic統合: 未実施**
   - `learning-sprint/shoshi/ios/codemagic-shoshi.yml` に `shoshi-ios` workflowは定義済み。
   - root `codemagic.yaml` への競合なし統合が未完了。
   - 設計は `submit_to_testflight: true` / `submit_to_app_store: false`。

3. **実配布Build番号: 未確定**
   - `project.yml` 既定は Build 1。
   - Codemagic signed buildでは `CM_BUILD_NUMBER` を採用するため、実行前はTestFlightへ上げるBuild番号が未確定。

4. **署名IPA / ASC upload / Internal TestFlight: 未実施**
   - signed IPAを生成していない。
   - App Store Connectへアップロードしていない。
   - Internal TestFlightへ配布していない。
   - 本審査には提出していない。

## ChatGPTで実行可能な作業

- 正本AppIconをGitHubへ破損なく配置しSHA-256一致を再検証する。
- AppIcon gateを含むRelease Gateを再実行する。
- PR #4129を最新mainへ同期し、競合を解消してmainへ統合する。
- root `codemagic.yaml` へ `shoshi-ios` workflowを安全に統合する。
- Codemagic実行条件、Bundle ID、ASC App ID、IAP、署名プロファイル、Internal TestFlight only設定を再監査する。
- Codemagic/Apple連携が接続済みで実行可能ならsigned IPA生成とInternal TestFlight uploadを実施する。
- 本審査提出は行わない。

## 本人操作が必要になり得る作業

- CodemagicのApple認証/証明書/Provisioning Profile連携が失効・未接続の場合の再認証。
- App Store Connect側でIAP `jp.allsunday1122.shoshi.premium` の販売設定・契約/税務/銀行情報など、API/コネクタから変更できない項目。
- Internal TestFlightに配布されたBuildをiPhoneへインストールして行う実機確認。
- StoreKit Sandbox購入、キャンセル、pending、復元、再インストール後の復元等の実機確認。

## 次に実行すべき作業

1. 正本AppIconを `learning-sprint/shoshi/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png` へ配置しSHA一致。
2. Release Gate再実行、AppIconを含め全job PASS確認。
3. PR #4129をmainへ統合。
4. root `codemagic.yaml`へ`shoshi-ios`統合。
5. Codemagic signed IPA build実行。実Build番号を確定。
6. App Store Connect App ID `6799755748` へInternal TestFlight upload。
7. iPhone実機で `STOREKIT_TEST_PLAN.md` の12項目を確認。

## TestFlight判定

**現在: FAIL / NOT READY**

未達条件: 正本AppIcon、root Codemagic統合、実配布Build番号、signed IPA、App Store Connect upload、Internal TestFlight。

本審査提出: **未実施・禁止を維持**。
