# RELEASE CHECKLIST｜薬剤師国家試験｜学びスプリント

## 自動完了対象
- [x] Safari価値検証 v0.6.1 ユーザーPASS
- [x] 1,035問問題監査／採点対象1,031／blocked 0
- [x] SwiftUI + WKWebViewローカル教材方式
- [x] StoreKit 2 月額＋買い切り実装
- [x] currentEntitlements／pending／cancel／revocation／restore／manage subscriptions設計
- [x] 無料90問／プレミアム1,031問ゲート
- [x] Privacy Manifest（tracking false / collected data []）
- [x] Support／Privacy／Terms公開ファイル
- [x] Codemagic `pharmacist-ios` workflow
- [x] App Store本審査自動提出OFF
- [x] AppIcon正本のDrive ID・寸法・RGB・SHA-256固定
- [x] GitHub Actions iOS preflight / Simulator compile PASS（run `31304173464`）
- [x] 正本AppIcon PNGをiOS assetへmaterialize・SHA一致

## Apple / Codemagic本人認証が必要
- [ ] Explicit App ID `jp.allsunday1122.yakuzaishi` を登録/確認
- [ ] App Store Connectに新規Appを作成（SKU `yakuzaishi-sprint-ios`）
- [ ] Paid Apps Agreement、税務、銀行情報の有効状態を確認
- [ ] Subscription Group「薬剤師国家試験 プレミアム」を作成
- [ ] `jp.allsunday1122.yakuzaishi.monthly` / 1 month / 日本200円相当
- [ ] 月額へFree Trial 1 Weekを設定
- [ ] `jp.allsunday1122.yakuzaishi.lifetime` / Non-Consumable / 日本980円相当
- [ ] 両商品のローカライズ・審査用スクリーンショットを設定
- [ ] Codemagic App Store Connect integration `codemagic` とApp Store signingを確認
- [ ] `pharmacist-ios` workflowを実行しInternal TestFlightへ送信

## TestFlight人間確認
- [ ] 起動／クラッシュなし
- [ ] 無料状態：第111回必須90問のみ
- [ ] 4／8／16問スプリント
- [ ] 中断→続きから
- [ ] 苦手3連続卒業
- [ ] 達成度／35マスヒートマップ
- [ ] 月額商品価格がApp Store価格で表示
- [ ] 7日無料はeligible時だけ表示
- [ ] 月額購入／cancel／pending
- [ ] 買い切り購入
- [ ] 購入復元
- [ ] 再起動後の権利維持
- [ ] プレミアムで全1,031問・9区分解放
- [ ] サブスクリプション管理導線
- [ ] 機内モードで教材・記録が利用可能
- [ ] レイアウト崩れ・横はみ出しなし

## App Store提出前の最後の人間確認
価格・説明・スクリーンショット・Content Rights・App Privacy・年齢制限・公開内容を確認後にのみ`Add for Review` / `Submit for Review`を実行する。
