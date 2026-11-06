# 開発連番#11｜司法試験予備試験・短答式｜Native iOS進捗

更新日: 2026-08-14
標準手順: v2.4

## 正本

- Notion台帳: https://app.notion.com/p/3b609c10697d81ea8021da198988f436
- 開発正本: https://app.notion.com/p/3ba09c10697d81888b47e05a81d863c1
- Golden Master v2.1: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 標準手順 v2.4: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- 問題生成・監査ループ: https://app.notion.com/p/3b609c10697d8148a0c2db3a8c8d5e63
- GitHub branch: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/tree/feature/yobi-tantou-native-swiftui/learning-sprint/yobi-tantou
- Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4136

## v2.4移行

- Bundle IDを `jp.allsunday1122.yobishikentantou` に確定。Bundle ID命名はユーザー確認ゲートにしない。
- 課金方式は法改正・問題追加・年度更新を継続価値と判断し、月額200円のAuto-Renewable Subscriptionを採用。
- planned Product IDは `jp.allsunday1122.yobishikentantou.monthly`。
- App Store Connect実登録一致確認まではruntime Product IDを空値にしてfail-closed。
- StoreKitは `.autoRenewable` だけを受理し、旧Non-Consumable商品を拒否する。
- アプリ内価格は `Product.displayPrice` のみを使用し、200円をSwiftコードへ固定しない。
- App Store Connect Apple IDは実発行の数値だけを正本化し、推測しない。
- 純SwiftUIネイティブでブラウザ実行可能な初期試作を持たないため、GitHub PagesのSupport/Privacyをアプリ試用URLとは扱わない。実機試用はInternal TestFlightで行う。

## Native実装

- 純SwiftUI。WebKit/WKWebViewなし。
- ホーム／模試／記録／設定4タブ。
- 8問標準スプリント、分野別、苦手、わからない、途中再開。
- 苦手は3連続正解で解除。
- 学習履歴、分野別正答率、5週間ヒートマップ。
- JSON書出し・読込。5MiB上限と整合性検証。
- 無料スプリント消費状態はバックアップ／リセットで復活不可。
- Premium専用セッションは再開時に契約資格を再確認。
- StoreKit 2 verified transaction / currentEntitlements / revocation / Transaction.updates。
- Privacy Manifest。
- R6・R7公式採点canonicalをBundleからfail-closed読込。
- 模試タブに確認済み公式構造・満点・合格点を表示。公式本文は権利・教材監査PASSまで開始不可。

## 正式独自問題の現在地

完成ゲートは現行R8構成を使う独自模試3回分。

1回あたり:
- 憲法12
- 行政法12
- 民法15
- 商法15
- 民事訴訟法15
- 刑法13
- 刑事訴訟法13
- 法律計95
- 一般教養44題提示・20題選択
- 合計139題

3回合計417題。

### Native seed

42問を正式Release済み。
- foundation 14 → practice-mock-1 seed
- standard 14 → practice-mock-2 seed
- applied 14 → practice-mock-3 seed
- 各層7法律科目×2問

### practice-mock-1

**139/139 完成。**

法律95問:
- Native foundation seed 14
- legal batch-01〜05: 14問×5=70
- legal batch-06: 11
- 合計95

一般教養44題:
- quantitative_logic 11
- natural_science_reasoning 11
- social_data_reasoning 11
- language_reading 11

一般教養は公式本文を再利用せず、全て `self_authored_original`。外部文章・実在統計・第三者図表を使用しない。設問内fixtureから正答を再計算・再構成する専用監査を通す。

### practice-mock-2 / 3

- practice-mock-2: 14/139（seedのみ）
- practice-mock-3: 14/139（seedのみ）

### 総数

- 正式監査済み・模試割当済み: **167/417**
- 残り: **250**
- 模試1: complete
- 模試2: 125題不足
- 模試3: 125題不足

## 品質ループ

法律mock-bank:
`candidate → optional editorial override → candidate preflight → 2026-01-01 e-Gov exact-date marker → answer/explanation → distractor rationales → global uniqueness → editorial quality → release_passed`

一般教養general-bank:
`self-authored candidate → schema/rights validator → deterministic answer recomputation → global uniqueness → editorial quality → release_passed`

共通原則:
- 重複閾値を下げない。
- FAIL時は該当設問を修正して上流監査から再実行。
- 言い換え水増しをしない。
- 公式問題本文と独自問題を混同しない。

## 公式資料・採点正本

- R6/R7/R8 法律基本科目95問。
- 憲法12、行政法12、民法15、商法15、民事訴訟法15、刑法13、刑事訴訟法13。
- 法律基本科目210点。
- 一般教養: R6=42題、R7/R8=44題、20題選択、60点。
- 総計270点。
- R6合格点165、R7合格点159。
- R6/R7は正答・配点・順不同・部分点を `official-scoring-canonical.v1.json` に固定。
- R7一般教養41・42の `were`→`wire` 訂正と特段の採点措置なしを反映。
- R8正答・配点・合格点は未確認のため推測しない。

## 権利ゲート

- 法務省PDL1.0と第三者権利を分離。
- CBT体験版固有の画面・画像・問題・マニュアル素材は再利用しない。
- 公式一般教養R6-R8計130題は全件 `manual_review_required` / `reuseEligible=false`。
- 公式問題本文を製品収録する場合は設問単位権利クリアランス必須。
- 独自模試は公式問題本文を流用しない。

## AppIcon

- Drive正本: `11_司法試験予備試験_短答式.png`
- file ID: `1EyeJxBN2WPEjEw9TUszhmyhuk3_3Lu6K`
- 1024×1024 PNG
- SHA-256: `c56c3f0acf7e05ec6096fdee881081b7b7e8e863ae2933b496550e902b840bf9`
- `app-icon-lock.json` で固定。

## v2.4受入CI

### Yobi Tantou Source Contract #361

全ステップPASS:
- Native source contract
- foundation / standard / applied candidate audits
- practice staging / promotion / quality self-tests
- Three-mock readiness audit
- R6-R8 official PDF structure audit
- R6/R7 scoring layout / question shape audit
- Production release preflight self-test
- App Store draft consistency
- script syntax

### Yobi Tantou Swift Validation #32

全PASS:
- Native 42-question source contract
- Release pipeline self-tests
- XCTest
- XCUITest
- unsigned Release build
- 42-question Native bundle inspection

## 現在のReleaseブロッカー

1. practice-mock-2の残り125題。
2. practice-mock-3の残り125題。
3. 417題完成後のmock-bank/general-bank→Native正式バンク統合。
4. R8公式正答・配点・短答合格点の公開後監査。
5. App Store Connect Apple IDの実発行値。
6. planned IAP Product IDをApp Store ConnectへAuto-Renewable Subscriptionとして実登録し、月額200円を設定。
7. StoreKit Sandbox実機確認。
8. canonical AppIcon付きsigned build。
9. Internal TestFlight実機確認。
10. External Beta Review / App Store本審査はユーザーの明示承認後のみ。

## 次工程

practice-mock-2を、法律の新規論点バッチと一般教養の自作決定論バッチに分け、模試1と同じ品質ループで125題を埋める。完了後にpractice-mock-3へ進む。人間判断が必要になるまでは自動継続する。
