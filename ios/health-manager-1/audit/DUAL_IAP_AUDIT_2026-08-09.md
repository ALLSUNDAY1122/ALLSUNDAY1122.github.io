# 月額＋買い切り 課金実装監査

日付: 2026-08-09

## Notion正本
「申請手順」第6節:
- 長期学習・法改正・問題追加の価値が高い資格
- 月額目安 200円
- 買い切り目安 980円
- 月額は初回7日無料
- サブスクと買い切りを比較表示
- StoreKit正式価格・期間を表示

第一種衛生管理者は法令問題を含み、法改正監視と新公表回への教材更新が必要なため、この区分を採用。

## 実装
- Monthly: `jp.allsunday1122.healthmanager1.monthly`
- Lifetime: `jp.allsunday1122.healthmanager1.lifetime`
- `Product.products(for:)`で2商品取得
- `Transaction.currentEntitlements`で双方の権利確認
- `subscription.isEligibleForIntroOffer`
- `subscription.introductoryOffer`
- freeTrialが1 week / 7 daysの場合だけ7日無料表示
- 月額・買い切りどちらでも`isPremium`
- `AppStore.sync()`で復元
- `Transaction.updates`を監視
- revocationを考慮
- 月額管理導線を設置

## Apple側に残る検査
App Store Connect商品作成後にStoreKit Sandbox実機監査を必須とする。
