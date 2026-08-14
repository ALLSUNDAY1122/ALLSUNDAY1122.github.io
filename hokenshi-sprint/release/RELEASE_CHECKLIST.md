# Release Checklist｜保健師国家試験｜学びスプリント

更新: 2026-08-14

## Product / Content
- [x] Golden Master v2.1を最上位UI正本として適用
- [x] SwiftUI Native / WebView不使用
- [x] 330問をrelease-ready resourceへ固定
- [x] 3回×110問
- [x] 各回 一般75 + 状況設定35
- [x] 10分野×11問/回（周回学習用独自均等配分と明示）
- [x] scenario本文をNative画面へ表示
- [x] 一次根拠URLと確認基準日を解説から確認可能
- [x] 2026-05-15現行保健師活動通知へ再照合
- [x] ID重複 / 高類似 / scenario連結 / answer schema監査

## Learning UX
- [x] 4 / 8 / 16問
- [x] 「わからない」
- [x] 誤答・unknown→苦手
- [x] 苦手3連続正解で解除
- [x] 確定済み回答の次から途中再開
- [x] 午前55 / 午後55 / 通し110
- [x] 4タブ：ホーム / 模試 / 記録 / 設定
- [x] 82pt進捗リング
- [x] 5週間ヒートマップ
- [x] 目標試験日 / 必要ペース
- [x] 3段階文字サイズ
- [x] JSONバックアップ / 読込
- [x] 選択状態VoiceOver表現
- [x] 科目別学習で同一問題をtarget数まで反復補充しない
- [x] 無料科目別3問は3 ID一意 / Premium科目別8問は8 ID一意を10科目で自動テスト

## Monetization
- [x] 非消耗型・買い切りPremiumを採用
- [x] 無料30問（第1回の10分野から各3問）
- [x] Premium残り300問＋模試
- [x] 無料範囲の10分野均等性をCIで固定
- [x] StoreKit 2実装
- [x] verified transactionのみ解放
- [x] revocation確認
- [x] transaction updates監視
- [x] 購入復元常設
- [x] `Product.displayPrice`だけを価格表示へ使用
- [x] 製品情報取得失敗時の再読み込み導線
- [ ] App Store Connect上で非消耗型IAPを作成
- [ ] Sandbox / TestFlightで購入・復元実機確認

## Quality
- [x] Native product shell audit
- [x] Swift Package tests
- [x] LearningSprintCore tests
- [x] WebView禁止CI
- [x] 正本識別情報一致CIへ更新
- [x] 辛口レビュー3周をリポジトリへ記録
- [x] 課金導入後の辛口レビュー3周を再実施
- [x] 最新機能変更後CI PASS（run #249 / `31772797429`）
- [x] iOS Simulator Release build PASS
- [ ] 30状態スクリーンショット比較（TestFlight build後）
- [ ] Internal TestFlight実機確認（人間確認地点 #3）

## Privacy / Store
- [x] PrivacyInfo.xcprivacy
- [x] UserDefaults required-reason `CA92.1` 記載
- [x] Privacy Policyを現行Premium実装へ同期
- [x] Supportに購入復元FAQ / 問い合わせ導線を追加
- [x] App Store日本語メタデータ原稿
- [x] 「過去問」誤認キーワードを削除し、独自問題であることを明示
- [x] App Store Connect入力回答正本を作成
- [x] トラッキングなし / 第三者広告SDKなし / 第三者解析SDKなしの現在実装と原稿を一致
- [x] Privacy URLをGitHub Pages mainへ公開
- [x] Support URLをGitHub Pages mainへ公開
- [x] `ITSAppUsesNonExemptEncryption=false`
- [x] Age Rating回答方針: Medical or Treatment Information = Infrequent

## AppIcon
- [x] 正本ファイル特定: Google Drive `13_保健師国家試験.png`
- [x] 1024×1024 / RGB / 609,807 bytesを確認
- [x] 正本SHA-256記録: `34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64`
- [x] 2026-08-14にDriveから再取得しローカルSHA完全一致
- [x] Asset Catalogに正本ファイル名 `AppIcon-1024.png` を登録
- [x] Driveはowner-onlyを維持し、代替画像生成・公開権限変更をしない
- [ ] 署名ビルド前に正本PNGバイトをAsset Catalogへ配置
- [ ] 配置後SHA-256再照合

## Apple / Signing
- [x] Apple Team ID: `MN3D2ZM44N`
- [x] Version: `1.0.0`
- [x] Distribution: App Store
- [x] TestFlight: Internal Testing only
- [x] Bundle ID: `jp.allsunday1122.hokenshi`
- [x] Codemagic profile/workflow: `hokenshi_appstore`
- [x] IAP Product ID: `jp.allsunday1122.hokenshi.premium`
- [x] SKU: `hokenshi-sprint-13-ios`
- [x] iPhone向けXcodeGen App target
- [x] IAP capability生成スクリプト
- [x] iOS Simulator Release build PASS
- [ ] Apple DeveloperでExplicit App IDを登録（未登録時）
- [ ] App Store Connect新規Appレコード作成
- [ ] App Store Connect App ID（Apple実発行値）
- [ ] Signed IPA
- [ ] Internal TestFlight upload

## Final submission
- [ ] Internal TestFlight実機確認でユーザー承認
- [ ] スクリーンショット / App Privacy / age rating / export compliance最終確認
- [ ] App Store本審査提出のユーザー明示承認

App Store本審査は自動提出しない。
