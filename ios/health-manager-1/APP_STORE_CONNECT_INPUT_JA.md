# App Store Connect 入力用｜第一種衛生管理者｜学びスプリント

更新: 2026-09-13

## App
- App名: 第一種衛生管理者｜学びスプリント
- App Store Connect App ID: `6799581662`
- Bundle ID: `jp.allsunday1122.healthmanager1`
- Version: 1.0.0
- Category: 教育
- サインイン: 不要
- Release Build番号は固定値を正本にせず、fresh ASC read-backで確定する

## 課金プランA｜月額
- 種別: Auto-Renewable Subscription
- Subscription Group: 第一種衛生管理者 プレミアム
- Product ID: `jp.allsunday1122.healthmanager1.monthly`
- Reference Name: 第一種衛生管理者 月額プレミアム
- 期間: 1 Month
- 日本価格: 200円
- Introductory Offer: Free Trial / 1 Week（対象者のみ）
- 表示名: 月額プレミアム
- 説明: 全264問・追加演習・苦手復習を利用
- 自動更新: あり

## 課金プランB｜買い切り
- 種別: Non-Consumable
- Product ID: `jp.allsunday1122.healthmanager1.lifetime`
- Reference Name: 第一種衛生管理者 買い切りプレミアム
- 日本価格: 800円
- 表示名: 買い切りプレミアム
- 説明: 全264問・追加演習・苦手復習を期限なく利用
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
公表問題の論点と現行法令を確認して独自作成した264問を収録し、公表回対応3セット＋追加演習3セット、44問通し、4/8/16問スプリント、苦手復習を提供します。
プレミアム画面には月額200円と買い切り800円を並べ、実取引価格はStoreKit取得値を正本として表示します。
月額の7日無料表示はStoreKitがIntroductory Offer利用資格ありと返したユーザーにのみ表示します。
購入復元は設定画面から実行できます。外部決済導線はありません。

## Human Test
TestFlightはAI Preflight / Visual Gate / Release Gate通過後にのみ使用する。
- [ ] 月額の正式価格を取得
- [ ] 買い切りの正式価格を取得
- [ ] 対象者だけ7日無料を表示
- [ ] 月額購入成功 / キャンセル / pending / 期限切れ
- [ ] 買い切り購入
- [ ] 購入復元
- [ ] 再起動後の権利確認
- [ ] revocation / 返金時の権利反映
