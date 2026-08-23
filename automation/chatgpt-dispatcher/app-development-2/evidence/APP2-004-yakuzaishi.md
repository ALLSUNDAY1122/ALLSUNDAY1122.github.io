# APP2-004 薬剤師国家試験｜課金ロック修正後の再Build

完了時刻: 2026-08-19 15:41 JST
Worker: YAKUZAISHI

## 正本再取得

- Notion: `薬剤師国家試験対策アプリ`（page id `3b609c10-697d-81c6-b58d-d0935d581b7d`）を再取得。
- GitHub: `ALLSUNDAY1122/ALLSUNDAY1122.github.io` の現行 `main` を再取得。
- PR #4218 は merge 済み。旧 Build 1 のPASSは失効扱いとした。
- App Store Connect / Codemagic は会話履歴ではなくAPI/gatewayの現行実状態を再取得した。

## 現行製品識別子

- App Store Connect App ID: `6799753724`
- Bundle ID: `jp.allsunday1122.yakuzaishi`
- Monthly Product ID: `jp.allsunday1122.yakuzaishi.monthly`
- Lifetime Product ID: `jp.allsunday1122.yakuzaishi.lifetime`

## StoreKit / ロック導線監査

現行 `main` の `pharmacist-manabi-sprint/ios/StoreKitManager.swift` と `RootAndHomeViews.swift` を監査。

- 無料状態: 分野別カードは `storeKit.isPremium == false` のときロック表示し、タップでPaywallを表示。
- 購入後: `Transaction.currentEntitlements` / `Transaction.updates` を検証し、月額または買い切りentitlementがあれば `isPremium = true`。
- 購入: StoreKit 2 `Product.purchase()` を使用。
- 復元: `AppStore.sync()` → entitlement再取得。
- 学習導線: Daily / Weak / Field / Mock / Resume の現行routeを保持し、premium状態を学習開始時へ渡す。

## IAP / Subscription 実設定

APP2-004専用bootstrapをApp Store Connect実APIへ適用し、現行APIのversioned metadata / starting-price / UPFRONT plan semanticsへ追従した。

read-back: `automation/app2-004-yakuzaishi-iap-result.json`

- 買い切り:
  - ASC IAP ID `6802918851`
  - `jp.allsunday1122.yakuzaishi.lifetime`
  - Non-Consumable
  - 日本価格 `¥980`
- 月額:
  - ASC Subscription ID `6802958538`
  - `jp.allsunday1122.yakuzaishi.monthly`
  - `ONE_MONTH`
  - 日本価格 `¥200`
- Subscription Group: `22318957` (`薬剤師国試プレミアム`)
- Introductory Offer:
  - Territory `JPN`
  - `FREE_TRIAL`
  - `ONE_WEEK`
  - 1 period
  - target plan `UPFRONT`

ASCの商品stateは現時点で `MISSING_METADATA`。これは審査提出用のスクリーンショット等が未完了である状態。今回のTaskは本審査提出ではなくInternal TestFlight/Sandbox実機確認までであり、AppleのSandbox準備条件（product reference name / Product ID / localized name / price）は満たしている。TestFlightアプリはSandboxでIAPを実行する。

## Build 2 / Codemagic

証拠: `automation/codemagic-results/app2-004-yakuzaishi-build2-main-20260819-1253.json`

- Workflow: `pharmacist-ios`
- Codemagic Build ID: `6a85289fc5a316035645648d`
- Build number: `2`
- Version: `1.0.0`
- Branch: `main`
- Signed IPA: `PharmacistSprint.ipa`
- IPA size: `18,547,560` bytes
- Release audit: SUCCESS
- Signing setup: SUCCESS
- `testFlightInternalTestingOnly: true`: SUCCESS
- Signed IPA build: SUCCESS
- Publishing: SUCCESS

## App Store Connect 最終read-back

証拠: `automation/app2-004-yakuzaishi-asc-final.json`

Build 2:

- ASC Build ID: `c7a954bc-3677-418e-88b6-1e65d2ba086e`
- version/build: `2`
- processingState: `VALID`
- expired: `false`
- minOsVersion: `16.0`
- buildAudienceType: `INTERNAL_ONLY`
- usesNonExemptEncryption: `false`
- internalBuildState: `IN_BETA_TESTING`
- externalBuildState: `NOT_APPLICABLE`

Internal TestFlight group:

- Group: `sun`
- Group ID: `56dfa9cf-bceb-477d-94bd-b65d9ebf26ff`
- `isInternalGroup: true`
- `hasAccessToAllBuilds: true`
- Build 2 membership read-back済み。

## 判定

APP2-004の要求範囲は完了。

- 旧 Build 1 PASSは不使用。
- 現行mainから署名Build 2を生成済み。
- ASC upload済み。
- Build 2は `VALID` / `INTERNAL_ONLY` / `IN_BETA_TESTING`。
- 内部テスターgroupへの紐付け済み。
- 月額¥200・1週間無料、買い切り¥980の商品実体をASCへ設定済み。
- 現行コードは無料時ロック、購入後全解放、購入、復元、学習導線を実機TestFlight/Sandboxで確認できる状態。

注: このWorkerが物理端末を直接操作して購入ボタンを押したわけではないため、「実機テスト実施済み」ではなく「実機確認可能状態」と判定する。本審査提出は行っていない。

---

# 2026-08-23 追補｜公式紙面ズーム＋分野別約20問セット

ユーザー提供のiPhone画面録画 `RPReplay_Final1787489128.mp4` を確認し、公式紙面画像がiPhone幅へ縮小された際に本文・図表が小さく読みにくいケースを確認した。OCR文字起こしへの置換は誤変換・図表欠落による問題改変リスクがあるため、公式画像を保持したまま拡大閲覧可能にする方針を採用した。

## 実装

PR: `#4545 薬剤師国試：図版ズームと分野別20問セット`
main merge SHA: `a4ffbed0c4d67b37f702a93d261ecde538840162`

- 公式紙面画像:
  - 画像タップで全画面表示。
  - ピンチズーム最大6倍。
  - 拡大後ドラッグ移動。
  - ダブルタップで2.5倍／リセット。
  - 問題内容・正答・公式画像自体は変更しない。
- 分野別学習:
  - 分野カード押下後に約20問ずつのセット選択画面を表示。
  - 問題数を均等分割し、極端に小さい最終セットを作らない。
  - `今日のスプリント` の4／8／16問設定から分野別を独立。
  - 選択した分野セットはセット内全問を解く。
- 回帰テスト:
  - 分野セットが全問題を重複・欠落なく含むことを確認。
  - 分野セットの問題数がDaily goal 8へ切られないことを確認。

## CI

PR #4545 head `47d590f0a4de097b67832350d3af0092fa6e2349` で以下を全てPASS。

- `Pharmacist Native Static Gate` run 29: SUCCESS
- `Pharmacist Native Compile Xcode16` run 27: SUCCESS
  - XCTest SUCCESS
  - Release build SUCCESS
- `Pharmacist Native iOS Preflight` run 222: SUCCESS

## Build 4 / Codemagic

証拠: `automation/codemagic-results/app2-004-yakuzaishi-zoom-field-batches-build4-20260823-2207.json`

- Workflow: `pharmacist-ios`
- Codemagic Build ID: `6a8af0160ca566da0c025ba5`
- Version: `1.0.0`
- Build number: `4`
- Signed IPA: `PharmacistSprint.ipa`
- IPA size: `18,637,895` bytes
- Release audit: SUCCESS
- Signing setup: SUCCESS
- Signed IPA build: SUCCESS
- Publishing: SUCCESS

Build 3以前は今回のUI／分野別仕様を含まないため、実機受入対象としては失効扱いとする。

## App Store Connect Build 4 read-back

証拠: `automation/app2-004-yakuzaishi-build4-asc.json`

- ASC Build ID: `08361432-b815-4194-ab9d-b3860d71cbe2`
- build: `4`
- processingState: `VALID`
- expired: `false`
- minOsVersion: `16.0`
- buildAudienceType: `INTERNAL_ONLY`
- usesNonExemptEncryption: `false`
- internalBuildState: `IN_BETA_TESTING`
- externalBuildState: `NOT_APPLICABLE`
- Internal group: `sun`
- Group ID: `56dfa9cf-bceb-477d-94bd-b65d9ebf26ff`
- `isInternalGroup: true`
- `hasAccessToAllBuilds: true`

## 2026-08-23 判定

今回の変更はmain、CI、署名Build、App Store Connect、Internal TestFlightまで反映完了。

残る受入はiPhone実機操作のみ:

1. 公式紙面画像をタップし、全画面表示・ピンチ拡大・ドラッグ・ダブルタップが読みやすく機能する。
2. `分野から解く` → 分野 → 約20問セットを選択できる。
3. 分野別セットがDaily goal 8問で終了せず、選択セットの全問を解ける。
4. 無料状態では分野カードがロックされる。
5. 購入／復元後は分野セットを含むプレミアム範囲が解放される。

本審査送信は行っていない。
