# App Store Connect 入力用｜第一種衛生管理者｜学びスプリント

更新: 2026-08-09

## App
- App名: 第一種衛生管理者｜学びスプリント
- Bundle ID: jp.allsunday1122.healthmanager1
- Version: 1.0.0
- Build: 1
- Category: 教育
- サインイン: 不要

## 課金プランA｜月額
- 種別: Auto-Renewable Subscription
- Subscription Group: 第一種衛生管理者 プレミアム
- Product ID: jp.allsunday1122.healthmanager1.monthly
- Reference Name: 第一種衛生管理者 月額プレミアム
- 期間: 1 Month
- 日本価格方針: 200円相当
- Introductory Offer: Free Trial / 1 Week
- 表示名候補: 月額プレミアム
- 説明候補: 全132問・苦手復習・模試を利用
- 自動更新: あり

## 課金プランB｜買い切り
- 種別: Non-Consumable
- Product ID: jp.allsunday1122.healthmanager1.lifetime
- Reference Name: 第一種衛生管理者 買い切りプレミアム
- 日本価格方針: 980円相当
- 表示名候補: 買い切りプレミアム
- 説明候補: 全132問・苦手復習・模試を期限なく利用
- 自動更新: なし
- 利用期限: なし

## 共通
- 月額または買い切りのどちらかが有効ならプレミアム解放
- 購入復元: 設定 → 購入を復元
- 月額管理: 設定 → サブスクリプションを管理
- 外部決済: なし
- 広告SDK: なし
- 解析SDK: なし
- アカウント登録: なし
- 学習履歴: 端末内保存
- StoreKit 2で正式価格・購入資格・Introductory Offer資格を取得

## 公開URL
- Support: https://allsunday1122.github.io/health-manager-1/support.html
- Privacy: https://allsunday1122.github.io/health-manager-1/privacy.html
- Terms: https://allsunday1122.github.io/health-manager-1/terms.html

## App Reviewメモ
本アプリはサインイン不要です。
無料状態では2026年4月公表回対応の独自演習を利用できます。
プレミアム画面には、月額自動更新サブスクリプションと非消耗型買い切りを並べて表示します。
月額の初回7日無料表示はStoreKitがIntroductory Offer利用資格ありと返したユーザーにのみ表示します。
購入後は全132問・苦手復習・模試などを解放します。
購入復元は設定画面から実行できます。
月額利用者は設定画面からAppleのサブスクリプション管理画面を開けます。
外部決済導線はありません。

## TestFlight実機確認
- [ ] 月額の正式価格を取得
- [ ] 買い切りの正式価格を取得
- [ ] 対象者だけ7日無料を表示
- [ ] 月額購入成功
- [ ] 月額キャンセル
- [ ] pending
- [ ] 月額期限切れ
- [ ] 買い切り購入
- [ ] 購入復元
- [ ] 再起動後の権利確認
- [ ] revocation / 返金時の権利反映
