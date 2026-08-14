# StoreKit 2 実機テスト計画｜司法試験予備試験・短答式

更新: 2026-08-14
対象: Internal TestFlight / Sandbox
課金方式: 自動更新サブスクリプション（月額）
日本向け基準価格: 200円/月
Bundle ID: `jp.allsunday1122.yobishikentantou`
planned Product ID: `jp.allsunday1122.yobishikentantou.monthly`
runtime Product ID: App Store Connect実登録一致確認まで未設定

## 自動テスト済み／CI対象

- Product IDが空、`UNSET`、ビルド変数のままならStoreKit操作をfail-closed。
- Product ID未設定時に購入処理を開始しない。
- Product ID未設定時に `AppStore.sync()` を開始しない。
- StoreKitから取得した商品種別が `.autoRenewable` 以外なら商品を採用しない。
- プレミアム専用の苦手・分野別・模試セッションは権利失効後に途中再開できない。
- 無料の今日のスプリントは1回消費後、バックアップ読込・学習データリセットで無料権を復活できない。
- 購入資格はJSONバックアップへ含めない。
- StoreKit transactionはverification成功時かつProduct ID一致・未取消の権利だけを採用する。
- 価格表示は `Product.displayPrice` を使い、アプリコードへ `200円` を固定しない。

## Internal TestFlight実機で確認する項目

1. 初回未契約状態でアプリ起動。
2. 「今日のスプリント」が最大8問だけ無料で開始できる。
3. 無料スプリント完了後、再度Premiumなしで今日のスプリントを開始できない。
4. 分野別演習・模試・苦手復習がPremiumなしで解放されない。
5. StoreKitから本番商品名・ローカライズ価格を取得できる。
6. コード内固定価格ではなくStoreKitの `displayPrice` が表示される。
7. App Store Connectの商品種別がAuto-Renewable Subscriptionであることを確認する。
8. Sandbox契約成功後、Premiumが即時反映される。
9. アプリ再起動後も `Transaction.currentEntitlements` により有効契約が復元される。
10. 契約後に分野別演習・模試・苦手復習を開始できる。
11. Premium専用セッションを途中保存し、契約資格がない状態では再開できない。
12. 「購入を復元」実行後、同一Apple Accountの有効契約資格が復元される。
13. 別Apple Account／未契約Accountでは復元されない。
14. 購入キャンセル時にPremiumへ変化しない。
15. 購入承認待ち（pending）の場合、Premiumへ早期解放しない。
16. Sandboxの更新で契約が継続している間はPremiumを維持する。
17. Sandboxで契約期限切れを再現した場合、期限切れ後はPremiumを維持しない。
18. revocation/refundを再現できる場合、revoked transactionをPremium扱いしない。
19. JSONバックアップを書き出し、学習データをリセット／再読込しても購入資格はStoreKit側だけから判定される。
20. オフライン起動時、既に確認済みの教材は利用でき、課金状態に関する誤表示をしない。
21. App Store Connect Product IDとplanned ID `jp.allsunday1122.yobishikentantou.monthly` が完全一致する。
22. 日本ストア設定の基準価格が標準手順v2.4の200円/月であることをApp Store Connect側で確認する。

## PASS条件

- 上記の実行可能項目が全PASS。
- 購入・復元・キャンセル・pending・更新・期限切れ・権利失効でPremiumゲートの誤解放0。
- App Store Connectの商品ID・商品種別・アプリ設定が完全一致。
- 固定価格表記0。

## 人間確認ポイント

Bundle IDの命名は標準手順v2.4によりChatGPTへ委任済みで、確認ゲートにしない。App Store Connect Apple IDは実発行値のみを記録し推測しない。Internal TestFlightをiPhoneへインストールできる状態になった時点で、ユーザーには実機結果の確認を依頼する。External Beta App Review／App Store本審査の提出は別途明示承認まで行わない。
