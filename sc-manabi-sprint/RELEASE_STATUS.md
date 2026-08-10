# 情報処理安全確保支援士試験｜学びスプリント RELEASE STATUS

更新基準日: 2026-08-10 18:43 JST

## 対象アプリ

- 資格名: 情報処理安全確保支援士試験
- 開発連番: #8
- Bundle ID: `jp.allsunday1122.scmanabisprint` **（暫定。App Store Connect作成前のため最終確定扱いにしない）**
- App Store Connect App ID: **未発行 / 未確認**
- Version: `1.0.0`
- Build番号: `1`（GitHub preflight）。Codemagic signed buildは `CM_BUILD_NUMBER` を使用するため配布Buildは未確定
- iOS方式: Capacitor `8.4.2` / app内Web資産同梱 / iPhone-only
- Codemagic workflow候補: `sc-manabi-sprint-ios`
- workflow定義: `sc-manabi-sprint/app-store/codemagic-sc-workflow.yaml`
- Codemagic App Store Connect integration候補: `codemagic`
- 署名方式候補: Codemagic automatic App Store signing (`distribution_type: app_store`)
- 署名プロファイル: **未確認 / 未実行**
- root `codemagic.yaml`へのSC workflow統合: **未実施**
- App Store本審査提出: **禁止 / 未実施**

## 実績ステータス

| 項目 | 判定 | 証跡 |
|---|---|---|
| Notion正本照合 | **PASS** | 対象正本 `https://app.notion.com/p/3b609c10697d8191b58fdcffd8ec7f44`。標準手順 v2.2 / UI Golden Master v2.1 / 問題監査ループ / 申請手順を正本ページで参照固定。 |
| UI要件照合 | **PASS** | `sc-manabi-sprint/app-store/release-preflight.md`、GitHub Pages `https://allsunday1122.github.io/sc-manabi-sprint/full/`。iPhone Safari HUMAN PASSを正本・進捗へ記録済み。Golden Master v2.1の8問、4タブ、4/8/16、途中再開等を反映。 |
| ネイティブ実装 | **PASS** | Capacitor iOS target: `sc-manabi-sprint/native/`。`native/package.json` / `native/capacitor.config.json` / `native/configure-ios.sh`。GitHub Actions run `31375145017` job `ios-preflight` steps 8-14 success。source commit `9b1bf60f2ad19ef9603f8d86753fc36dc64eebc0`。純SwiftUIではなくCapacitorネイティブパッケージ。 |
| データ監査 | **PASS** | `sc-manabi-sprint/app-store/release-preflight.md` に公開過去問75問＋独自250問＝325問、IPA公式解答75/75、重複・高類似・水増し監査PASSを記録。Notion対象正本にも問題生成・監査ループのFAIL→修正→PASS履歴を保存。 |
| StoreKit 2 | **本人操作待ち** | コード側IAP実装・ビルド検証はPASS: `sc-manabi-sprint/full/iap-v1.js`, `sc-manabi-sprint/app-store/iap-premium.md`, commit `b749f7ff283b756e2c898395bafb6199acfa109b`, run `31375145017` step 6 success。ただしApp Store ConnectでIAP商品未作成のため、Sandboxの購入/キャンセル/復元/購入済みオフライン再起動は未検証。完全PASSにしない。 |
| オフライン・途中再開・バックアップ | **PASS** | `sc-manabi-sprint/app-store/release-preflight.md` に中断復帰・JSON書出/読込・オフライン同梱を監査記録。run `31375145017` step 5 `Prepare bundled offline web assets` success、steps 12/14で生成.appへの問題データ・patch・IAP資産同梱確認。 |
| 専門監査 | **PASS** | `sc-manabi-sprint/app-store/release-preflight.md`。IPA利用条件・著作権・2026年度非公開問題不使用・制度監査・Privacy Manifest・輸出コンプライアンスを記録。Notion正本 `https://app.notion.com/p/3b609c10697d8191b58fdcffd8ec7f44` に一次根拠と運用ルールを保持。 |
| 再監査 | **PASS** | build-number対応変更後に実装検証を再発火。最新 run `31375145017` conclusion `success`。`sc-manabi-sprint/build-results/ios-preflight.txt`: source `9b1bf60f2ad19ef9603f8d86753fc36dc64eebc0`, result記録 commit `c24d78f1f569f2aa4352da072bfc38b3adaf3ede`。 |
| Releaseビルド | **PASS** | **署名なし** physical-device Release build。workflow `.github/workflows/sc-manabi-ios-preflight.yml` は `xcodebuild -configuration Release -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO`。run `31375145017` step 13 `Unsigned physical-device build` success、step 14 bundle inspection success。 |
| 署名IPA | **本人操作待ち** | signed IPA artifactなし。候補workflow `sc-manabi-sprint/app-store/codemagic-sc-workflow.yaml` は commit `0ddb87c4953f950c6837d911378a99d32e8ed9b6` で準備済みだがroot `codemagic.yaml`未統合、正本AppIcon未配置、Apple署名プロファイル未確認。 |
| App Store Connectアップロード | **本人操作待ち** | App Store Connect App ID未発行/未確認。signed IPA未生成のため未アップロード。 |
| Internal TestFlight | **本人操作待ち** | App Store Connectアップロード未実施。Internal TestFlight buildなし、実機確認未実施。 |

## 主要証跡

- GitHub進捗正本: `sc-manabi-sprint/RELEASE_STATUS.md`
- GitHub URL: `https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/blob/main/sc-manabi-sprint/RELEASE_STATUS.md`
- 申請前監査: `sc-manabi-sprint/app-store/release-preflight.md`
- iOS preflight workflow: `.github/workflows/sc-manabi-ios-preflight.yml`
- 最新preflight result: `sc-manabi-sprint/build-results/ios-preflight.txt`
- 最新preflight run: `31375145017` / success
- 最新検証source: `9b1bf60f2ad19ef9603f8d86753fc36dc64eebc0`
- preflight result commit: `c24d78f1f569f2aa4352da072bfc38b3adaf3ede`
- release status整備 commit: `97e4569919c50786a9a8d1ebfce70fefa3cb9fd9`
- Codemagic候補workflow commit: `0ddb87c4953f950c6837d911378a99d32e8ed9b6`
- IAP code-side preflight PASS commit: `b749f7ff283b756e2c898395bafb6199acfa109b`
- IAP offline entitlement fix commit: `4de3a6f50a1692e1d826d555df36ca7d100340ee`
- IAP spec commit: `774113e6cb4176307caeac32f4970530b507b070`
- AppIcon正本: Google Drive `08_情報処理安全確保支援士試験.png`, file ID `1HuyIsiuQFmCbW266NbZIz5YM7tC08fON`, SHA-256 `6bf2945788da0be45b9e448ea79d5c40ac197e97d6bed387d4215c50d486bb3d`
- GitHub `sc-manabi-sprint/native/AppIcon-1024.png`: **未配置（2026-08-10 18:43確認時 404）**
- SC専用PR: なし。主要変更はmain直接コミットで記録。

## 未完了項目

### 1. AppIconのiOS資産配置
- 未完了内容: Google Drive正本 `08_情報処理安全確保支援士試験.png` を `sc-manabi-sprint/native/AppIcon-1024.png` へ同一バイトで配置し、SHA-256一致を確認する。
- FAIL理由: GitHub対象パスは404。署名Releaseのcanonical icon gateを満たさない。
- ChatGPTで実行可能: Drive正本を取得できる環境でバイト同一性を検証し、GitHubへ配置する。
- 本人操作が必要: 原則なし。ただしDrive→GitHubバイナリ転送経路が利用不可の場合は次担当AI/Codex環境で実施。
- 次: canonical icon配置→SHA検証。

### 2. Codemagic workflow統合
- 未完了内容: `sc-manabi-sprint/app-store/codemagic-sc-workflow.yaml` の `sc-manabi-sprint-ios` をroot `codemagic.yaml`へ統合。
- FAIL理由: 候補定義のみでCodemagic実行条件が本番設定へ反映されていない。
- ChatGPTで実行可能: root YAMLへの安全な統合、構文確認。
- 本人操作が必要: Codemagic App Store Connect integration/署名プロファイルの実アカウント確認。
- 次: AppIcon配置後にroot workflow統合。

### 3. Bundle ID / App Store Connect App ID
- 未完了内容: Bundle ID最終確定、App Store Connect Appレコード作成、App ID取得。
- FAIL理由: 現在のBundle IDは暫定。App Store Connect App IDは未発行/未確認。
- ChatGPTで実行可能: 入力値・SKU・メタデータの準備。
- 本人操作が必要: Appleログイン、2FA、Appレコード作成。
- 次: `jp.allsunday1122.scmanabisprint` を採用するか本人確定→Appレコード作成→App IDを正本へ記録。

### 4. Paid Apps Agreement / IAP商品
- 未完了内容: Paid Apps Agreement、税務・銀行状態確認、Non-Consumable `jp.allsunday1122.scmanabisprint.premium` 作成、価格確定。
- FAIL理由: App Store Connect商品が存在しないためSandbox E2Eを実行できない。
- ChatGPTで実行可能: 商品名・説明・Review Notes・価格案・Sandbox監査手順の準備。
- 本人操作が必要: 契約・税務・銀行・IAP作成・価格設定。
- 次: IAP作成後、Sandboxで未購入→購入→解放 / キャンセル / 復元 / 購入済みオフライン再起動を確認。

### 5. 署名・IPA・アップロード・Internal TestFlight
- 未完了内容: Apple署名、signed IPA生成、App Store Connect upload、Internal TestFlight配信。
- FAIL理由: AppIcon未配置、Codemagic本番workflow未統合、Apple signing未確認、App Store Connect App IDなし。
- ChatGPTで実行可能: workflow統合、release gate整備、ログ監査。
- 本人操作が必要: Apple Developer/Codemagic認証、証明書/provisioning、2FA、必要な契約確認、TestFlight実機確認。
- 次: 前項完了後にCodemagic signed build→App Store Connect upload→Internal TestFlight。

### 6. App Store提出前最終項目
- 未完了内容: TestFlight実画面スクリーンショット、Age Rating、Content Rights、App Privacy最終入力、App Store提出承認。
- FAIL理由: TestFlight未到達。
- ChatGPTで実行可能: 入力案・監査・スクリーンショット構成の準備。
- 本人操作が必要: TestFlight実機確認、App Store Connect最終回答、最終提出承認。
- 次: Internal TestFlight HUMAN PASS後に実施。

## TestFlight判定

**現在判定: NOT READY / 外部ゲート未完了**

`[CODEX TESTFLIGHT READY]` は記録しない。

未達条件:
- Bundle IDが最終確定扱いではない
- App Store Connect App ID未確定
- StoreKit 2のSandbox購入・キャンセル・復元・オフライン実機監査未完了
- canonical AppIconがiOS資産へ未配置
- Codemagic SC workflowがroot設定へ未統合
- 署名プロファイル未確認
- signed IPA未生成
- App Store Connect upload未実施
- Internal TestFlight未実施

本審査への提出は禁止。Internal TestFlight HUMAN PASSおよび最終提出承認まで `submit_to_app_store: false` を維持する。

## 再発火原則

コード、UI、問題、制度、著作権、課金、Privacy、外部通信、保存方式のいずれかを変更した場合、その変更に影響する既存PASSを失効させ、該当品質ループをPASSまで再実行する。
