# 開発連番#11｜司法試験予備試験・短答式｜Native iOS進捗

更新日: 2026-08-14

## 正本

- Notion台帳: https://app.notion.com/p/3b609c10697d81ea8021da198988f436
- 開発正本: https://app.notion.com/p/3ba09c10697d81888b47e05a81d863c1
- Golden Master v2.1: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 標準手順 v2.3: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- 問題生成・監査ループ: https://app.notion.com/p/3b609c10697d8148a0c2db3a8c8d5e63
- GitHub branch: `feature/yobi-tantou-native-swiftui`
- Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4136

## 標準手順v2.3適用

`NO_PROGRESS｜処理停滞・自己復旧ループ`を適用する。同じCI状態の短周期ポーリング等で実質進展が3回ない場合は、その副ループだけを停止し、GitHub/Notion正本を再取得して完了済み／未完了を再分類し、未完了へ別手段で進む。完了済み工程を繰り返さない。

今回、旧Swift CI待機をNO_PROGRESSとして再判定した結果、Swift Validation #28が既に全PASSであることを確定し、CI待機ループを終了した。

## Native実装

- 純SwiftUI。WebKit/WKWebViewなし。
- ホーム／模試／記録／設定4タブ。
- 8問標準スプリント、4/8/16目標。
- 分野別演習、苦手復習、わからない記録。
- 苦手は3連続正解で解除。
- 中断再開、学習履歴、分野別正答率、5週間ヒートマップ。
- JSON書出し・読込。5MiB上限と整合性検証。
- 無料スプリント消費状態の復活防止。
- Premium再開時の資格再確認。
- StoreKit 2: verified transaction / current entitlements / revocation / Transaction.updates。Product ID未設定時fail-closed。
- Privacy Manifest。
- preview 8問は全問 `releaseEligible=false`。
- R6・R7公式採点canonicalをBundleからfail-closed読込。
- 公式問題本文未監査の年度模試は開始不可。

## 正式独自練習問題

42問を正式Release済み。

- foundation: 14
- standard: 14
- applied: 14
- 各層: 法律7科目×2問
- 基準日: 2026-01-01
- e-Gov exact-date source audit: PASS
- answer audit: PASS
- editorial quality: PASS
- near duplicate: 0
- `contentUse=practice`
- `examYear=null`

## Swift Validation確定結果

`Yobi Tantou Swift Validation` #28を現在の受入基準とする。

- Native 42-question source contract: PASS
- XCTest: PASS
- XCUITest: PASS
- Unsigned Release build: PASS
- Release app bundle 42問検査: PASS

この完了済みCIを短周期ポーリングしない。

## 公式構成・採点正本

R6・R7・R8の法務省公式資料から構成を確定。

- 法律基本科目95問: 憲法12／行政法12／民法15／商法15／民事訴訟法15／刑法13／刑事訴訟法13
- 法律基本科目: 210点
- 一般教養: R6=42題、R7/R8=44題。20題選択、60点
- 総計: 270点
- R6公式合格点: 165
- R7公式合格点: 159
- R6/R7: 正答・解答欄・配点・順不同・部分点を `official-scoring-canonical.v1.json` に固定
- R8: 構成・法令基準日は確定、公式正答・配点・合格点は未確認のため推測しない

## 公式本文の権利ゲート

- 法務省PDL1.0と第三者権利を分離。
- CBT体験版固有の画面・画像・問題・マニュアル素材を再利用しない。
- 一般教養R6-R8計130題は全件 `manual_review_required` / `reuseEligible=false`。
- 公式年度問題本文は設問単位権利クリアランス完了までReleaseしない。

## 独自模試3回分｜新しい完成ゲート

標準手順の「3回分の規定数一致」を満たすため、公式問題本文の再録とは分離して独自模試を3回作成する。

現行R8構成を構造正本として各回:

- 憲法12
- 行政法12
- 民法15
- 商法15
- 民事訴訟法15
- 刑法13
- 刑事訴訟法13
- 法律計95
- 一般教養44題提示、20題選択
- 1回139題提示

3回合計:

- 法律285問
- 一般教養132題
- 提示問題417題

既存42問をseedにし、不足375枠を独立論点で作成する。`practice-mock-config.v1.json` と `audit_practice_mock_readiness.py` が完成判定の正本。

Production Release preflightは3回分完成監査を必須化済み。本番IDが揃っても417題完成前はPASSしない。

## Mock Bank拡張ループ

大量作問で全体CIを反復しないよう、`Yobi Mock Bank Pipeline` を分離した。

各batchのゲート:

1. candidate schema / within-batch similarity
2. 2026-01-01 e-Gov exact-date marker
3. answer/explanation audit
4. distractor rationale
5. non-release staging
6. 既存正式バンクとのID・近似重複監査
7. editorial quality
8. `release_passed` promotion

### practice-mock-1 legal batch-01

14問追加。

- 憲法: 41条、59条
- 行政法: 行政手続法5条、6条
- 民法: 90条、99条
- 商法: 会社法295条、296条
- 民事訴訟法: 134条、159条
- 刑法: 36条、37条
- 刑事訴訟法: 199条、201条

候補preflight: PASS。
2026-01-01 e-Gov exact-date audit: 14/14 PASS。
answer audit: 14/14 PASS。
正式昇格用にdistractor rationalesと既存42問との横断重複監査を追加済み。専用CIで最終quality/promotionを判定する。

## AppIcon

- Drive正本: `11_司法試験予備試験_短答式.png`
- 1024×1024 PNG
- SHA-256: `c56c3f0acf7e05ec6096fdee881081b7b7e8e863ae2933b496550e902b840bf9`
- `app-icon-lock.json` で固定。再生成しない。

## App Store準備

作成済み:

- privacy/support page
- APP_STORE_METADATA_JA.md
- APP_REVIEW_NOTES_JA.md
- STOREKIT_TEST_PLAN.md
- RELEASE_CHECKLIST.md
- APPLE_CONNECT_PACKET.md
- validate-app-store-draft.py
- release-preflight.py

本番識別子は推測しない。

## 現在の受入条件

- [x] Golden Master v2.1主要UI
- [x] WebKit/WKWebView 0
- [x] 正式独自練習42問Release監査PASS
- [x] foundation/standard/applied各14問
- [x] 42問Native契約
- [x] XCTest
- [x] XCUITest
- [x] Unsigned Release build / bundle検査
- [x] R6-R8公式年度×科目構成
- [x] R6/R7公式採点canonical
- [x] 一般教養130題fail-closed権利トリアージ
- [x] 独自模試3回分の構成・417題完成ゲート
- [x] Production Release preflightへ3回分完成条件を接続
- [ ] 独自模試3回分417題の全作問・全監査
- [ ] 公式本文を利用する場合の設問単位権利クリアランス
- [ ] R8公式正答・配点・合格点の公開後監査
- [ ] 本番Bundle ID / App Store Connect App ID / IAP Product ID
- [ ] StoreKit Sandbox実機確認
- [ ] Internal TestFlight実機確認
- [ ] External Beta Review / App Store本審査はユーザー明示承認後のみ

## 次の作業

1. practice-mock-1 legal batch-01を全品質ゲートPASS後、mock-bank正式正本へ固定。
2. 模試1の残り法律枠を科目別batchで追加し、各batchを同じ専用CIへ通す。
3. 独自一般教養44題を第三者著作物に依存しない一次資料／自作素材ベースで作成する。
4. 模試2・3へ同方式を展開し、3回417題・高類似0・誤答0・根拠不明0まで反復する。
5. 417題完成後にNative模試データモデルへ正式統合し、Swift/XCTest/XCUITest/Release buildを再発火する。
6. 本番識別子確定 → StoreKit Sandbox / 実機 → Internal TestFlight。
7. External Beta Review / App Store本審査は明示承認まで実行しない。
