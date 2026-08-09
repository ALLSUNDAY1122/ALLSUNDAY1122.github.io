# 通関士｜学びスプリント RELEASE CHECKLIST

更新日: 2026-08-09

## A. 完成版受け入れ
- [x] 起動用Web資産の現行版を特定
- [x] 通常学習480問＋申告書12セット固定
- [x] 問題データCI
- [x] UI bootstrap CI
- [x] 過去問権利監査
- [x] 公式過去問本文をバンドルしない
- [ ] iPhone実機で起動
- [ ] iPhone実機で全主要ボタン
- [ ] iPhone実機でオフライン起動
- [ ] JSON書き出し／読み込み

## B. iOS / Build
- [x] Bundle ID: `jp.allsunday1122.tsukanshi`
- [x] Version: `1.0.0`
- [x] SwiftUI + WKWebView + StoreKit 2
- [x] XcodeGen設定
- [x] 現行Web bundle生成スクリプト
- [x] 1024px AppIcon生成工程
- [x] Privacy Manifest
- [x] XcodeGen CI成功
- [x] Simulator Release build成功
- [x] `.app`内Web教材・Privacy Manifest・AppIcon確認
- [ ] Codemagic signed IPA成功

## C. 公開ページ
- [x] Supportページ作成
- [x] Privacy Policy作成
- [ ] main反映後 HTTP 200確認
- [ ] iPhone Safari表示確認
- [ ] 未ログインで表示確認
- [ ] アプリ設定画面から外部表示確認

## D. Privacy / Compliance
- [x] 広告なし
- [x] 第三者解析SDKなし
- [x] アカウントなし
- [x] 開発者サーバーへの学習データ自動送信なし
- [x] StoreKit利用をPrivacy Policyへ記載
- [x] UserDefaults Required Reason `CA92.1`
- [x] `ITSAppUsesNonExemptEncryption: false`
- [ ] App Store Connect App Privacy最終入力
- [ ] 年齢制限アンケート最終入力
- [ ] Content Rights最終入力

## E. In-App Purchase
- [x] Product ID: `jp.allsunday1122.tsukanshi.premium`
- [x] Non-Consumable設計
- [x] 購入処理実装
- [x] 復元処理実装
- [ ] App Store Connect商品作成
- [ ] 正式価格設定
- [ ] IAP審査用スクリーンショット
- [ ] Sandbox購入成功
- [ ] Sandbox復元成功
- [ ] 再起動後も権利維持

## F. App Store Connect
- [ ] 新規Appレコード作成
- [ ] App Store Connect App ID記録
- [ ] SKU確定
- [ ] Version 1.0.0作成
- [ ] App Store Metadata登録
- [ ] Support URL登録
- [ ] Privacy URL登録
- [ ] カテゴリ登録
- [ ] 著作権登録
- [ ] App Review連絡先
- [ ] App Review Notes
- [ ] iPhoneスクリーンショット

## G. TestFlight
- [ ] Build番号を上げてsigned IPA生成
- [ ] App Store Connectへアップロード
- [ ] Apple側Build処理成功
- [ ] 内部テストグループへ追加
- [ ] iPhone実機で起動
- [ ] 学習／模試／記録／設定
- [ ] 途中復帰
- [ ] 機内モード
- [ ] 公式税関リンク
- [ ] 購入／復元
- [ ] クラッシュなし
- [ ] 表示崩れなし

## H. 本審査
- [ ] 最終差分監査
- [ ] Privacy / Metadata / Review Notesと実装一致
- [ ] ユーザー最終確認
- [ ] `Add for Review`
- [ ] `Submit for Review`
