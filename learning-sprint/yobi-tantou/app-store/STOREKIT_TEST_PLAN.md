# StoreKit 2 実機テスト計画｜司法試験予備試験・短答式

更新: 2026-08-13
対象: Internal TestFlight / Sandbox
IAP方式: Non-Consumable買い切り予定
Product ID: `要確認`（未確定値を推測しない）

## 自動テスト済み／CI対象

- Product IDが空、`UNSET`、ビルド変数のままならStoreKit操作をfail-closed。
- Product ID未設定時に購入処理を開始しない。
- Product ID未設定時に `AppStore.sync()` を開始しない。
- プレミアム専用の苦手・分野別・模試セッションは権利失効後に途中再開できない。
- 無料の今日のスプリントは1回消費後、バックアップ読込・学習データリセットで無料権を復活できない。
- 購入資格はJSONバックアップへ含めない。
- StoreKit transactionはverification成功時のみ採用し、revocation済みtransactionをPremium扱いしない。

## Internal TestFlight実機で確認する項目

1. 初回未購入状態でアプリ起動。
2. 「今日のスプリント」が最大8問だけ無料で開始できる。
3. 無料スプリント完了後、再度Premiumなしで今日のスプリントを開始できない。
4. 分野別演習・模試・苦手復習がPremiumなしで解放されない。
5. StoreKitから本番商品名・ローカライズ価格を取得できる。
6. コード内固定価格ではなくStoreKitの `displayPrice` が表示される。
7. Sandbox購入成功後、Premiumが即時反映される。
8. アプリ再起動後も `Transaction.currentEntitlements` によりPremiumが復元される。
9. 購入後に分野別演習・模試・苦手復習を開始できる。
10. Premium専用セッションを途中保存し、購入資格がない状態では再開できない。
11. 「購入を復元」で同一Apple AccountのNon-Consumable購入資格が復元される。
12. 別Apple Account／未購入Accountでは復元されない。
13. 購入キャンセル時にPremiumへ変化しない。
14. 購入承認待ち（pending）の場合、Premiumへ早期解放しない。
15. revocation/refundをSandboxで再現できる場合、revoked transactionをPremium扱いしない。
16. JSONバックアップを書き出し、学習データをリセット／再読込しても購入資格はStoreKit側だけから判定される。
17. オフライン起動時、既に確認済みの教材は利用でき、課金状態に関する誤表示をしない。
18. App Store ConnectのIAP商品種別がNon-Consumableであることを確認する。

## PASS条件

- 上記の実行可能項目が全PASS。
- 購入・復元・キャンセル・pending・権利失効でPremiumゲートの誤解放0。
- App Store Connectの商品IDとアプリ設定が完全一致。
- 固定価格表記0。

## ユーザー確認ポイント

Internal TestFlightをiPhoneへインストールできる状態になった時点で、ユーザーには実機結果の確認だけを依頼する。External Beta App Review／App Store本審査の提出は別途明示承認まで行わない。
