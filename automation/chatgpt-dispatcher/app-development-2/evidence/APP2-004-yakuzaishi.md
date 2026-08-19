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
