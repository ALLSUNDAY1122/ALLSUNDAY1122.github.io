# 通関士｜学びスプリント RELEASE CHECKLIST

更新日: 2026-08-09

## A. 完成版受け入れ
- [x] `CODEX_HANDOFF.md` 作成
- [x] 起動用Web資産の現行版を特定
- [x] 通常学習480問＋申告書12セット固定
- [x] 問題データCI
- [x] UI bootstrap CI
- [x] 過去問権利監査
- [x] 公式過去問本文をバンドルしない
- [x] 公開Web試用URLで問題なく動作（2026-08-09 ユーザー確認）
- [ ] TestFlight版をiPhone実機で起動
- [ ] TestFlight版で全主要ボタン
- [ ] TestFlight版でオフライン起動
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
- [x] StoreKit `Transaction.updates` 監視
- [x] StoreKit状態変化をWKWebViewへ即時反映
- [x] In-App Purchase Capabilityを生成Xcode projectへ正規化
- [x] XcodeGen 2.46.0のTargetAttributes文字列化を検出・補正
- [x] Apple署名前プリフライトCI成功
- [x] ASC/TestFlight前コードゲート成功
- [ ] Codemagic signed IPA成功

## C. 公開ページ
- [x] Supportページ作成
- [x] Privacy Policy作成
- [x] 公開Web試用URL表示・操作確認
- [x] Web試用版で未確定の固定課金価格を表示しない
- [ ] Support / Privacyのmain反映後 HTTP 200確認
- [ ] iPhone SafariでSupport / Privacy表示確認
- [ ] 未ログインでSupport / Privacy表示確認
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
- [x] 保留・別経路取引の自動更新監視
- [x] StoreKit 2テスト計画作成
- [x] ネイティブ版はStoreKit正式`displayPrice`取得後のみ購入操作を有効化
- [ ] App Store Connect商品作成
- [ ] 正式価格設定
- [ ] IAP審査用スクリーンショット
- [ ] Sandbox購入成功
- [ ] Sandbox復元成功
- [ ] 再起動後も権利維持

## F. Apple Developer / App Store Connect
- [x] App Store Connect入力票作成
- [x] SKU固定: `tsukanshi-sprint-ios`
- [ ] Apple Developer Explicit App ID `jp.allsunday1122.tsukanshi` 登録
- [ ] App Store ConnectのBundle ID選択肢に表示されることを確認
- [ ] 新規Appレコード作成
- [ ] App Store Connect App ID記録
- [ ] Version 1.0.0作成
- [ ] App Store Metadata登録
- [ ] Support URL登録
- [ ] Privacy URL登録
- [ ] カテゴリ登録
- [ ] 著作権登録
- [ ] App Review連絡先
- [ ] App Review Notes
- [ ] iPhoneスクリーンショット

## G. Codemagic / TestFlight
- [x] workflow `tsukanshi-ios` 作成
- [x] `distribution_type: app_store`
- [x] `testFlightInternalTestingOnly` 設定
- [x] 本審査自動提出OFF
- [x] Apple署名前Codemagic安全ゲート成功
- [x] Codemagic生成projectにもIAP Capability正規化工程を固定
- [ ] App Store Connect integration確認
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
