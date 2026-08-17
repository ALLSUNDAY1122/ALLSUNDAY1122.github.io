# App Store Connect IAP設定｜月額＋買い切り

更新: 2026-08-09

Notion「申請手順」第6節B/Cに従い、第一種衛生管理者は法改正・新公表回への継続対応価値がある資格として、
**月額200円 + 買い切り980円** の2プランを採用する。

## 1. 月額プラン
- 種別: Auto-Renewable Subscription
- Subscription Group: `第一種衛生管理者 プレミアム`
- Product ID: `jp.allsunday1122.healthmanager1.monthly`
- Reference Name: `第一種衛生管理者 月額プレミアム`
- 期間: 1 Month
- 日本価格方針: 月額200円相当
- Introductory Offer: Free Trial / 1 Week
- UI表示: StoreKitの正式な`displayPrice`を使用
- 無料トライアル表示: StoreKitが「introductoryOfferあり」かつ「利用資格あり」と返した場合のみ表示
- 自動更新: ユーザーが解約するまで毎月
- 解約後: 有効期間終了まではプレミアム利用可。期限切れ後に無料範囲へ戻る

### 必須表示
`初回7日間無料。その後は月額200円で自動更新。無料期間中に解約した場合、料金は発生しない。`
ただし実アプリではStoreKitの正式価格を差し込み、対象外ユーザーには無料トライアルを表示しない。

## 2. 買い切りプラン
- 種別: Non-Consumable
- Product ID: `jp.allsunday1122.healthmanager1.lifetime`
- Reference Name: `第一種衛生管理者 買い切りプレミアム`
- 日本価格方針: 980円相当
- 自動更新: なし
- 利用期限: なし
- UI表示: StoreKitの正式な`displayPrice`を使用

## 3. 両プラン共通の解放範囲
- 全132問
- 3公表回対応
- 苦手復習
- 模擬試験
- 詳細な学習記録
- 法改正・教材更新後のアプリ内プレミアム範囲

無料版は無料対象範囲のみ利用できる。広告は現バージョンでは搭載しない。

## 4. entitlement
次のどちらかが有効なら`isPremium = true`。
- 月額サブスクリプションが`Transaction.currentEntitlements`に存在する
- 買い切りNon-Consumableが`Transaction.currentEntitlements`に存在する

買い切りを購入済みの場合は買い切りを優先表示する。

## 5. App Store Connect
1. Paid Apps Agreement / 税務 / 銀行情報を有効化
2. Subscriptions > Subscription Groupを作成
3. `jp.allsunday1122.healthmanager1.monthly` を1か月のAuto-Renewable Subscriptionとして作成
4. Introductory Offer = Free / 1 Weekを設定
5. In-App Purchases > `jp.allsunday1122.healthmanager1.lifetime` をNon-Consumableとして作成
6. 各商品に日本語表示名・説明・価格・Review Screenshotを登録
7. 初回サブスクリプションと初回Non-ConsumableはVersion 1.0と同じ提出物へAdd for Review
8. Sandboxで購入・復元・キャンセル・pending・期限切れ・返金/失効を確認

## 6. Sandbox合格条件
- 月額の正式価格取得
- 買い切りの正式価格取得
- 対象者だけ7日無料を表示
- 月額購入成功で即時解放
- 買い切り購入成功で即時解放
- 月額キャンセル時に即時ロックしない（期間終了まで有効）
- 月額期限切れで無料へ戻る
- billing grace periodで有効な場合は解放継続
- 買い切りは再起動後も解放
- 復元で双方のentitlementを再確認
- revocation/返金を反映
