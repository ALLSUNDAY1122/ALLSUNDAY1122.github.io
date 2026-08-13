# Release Checklist｜保健師国家試験｜学びスプリント

更新: 2026-08-13

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

## Quality
- [x] Native product shell audit
- [x] Swift Package tests
- [x] LearningSprintCore tests
- [x] WebView禁止CI
- [x] 推測App Store identifier禁止CI
- [x] 辛口レビュー3周をリポジトリへ記録
- [ ] 30状態スクリーンショット比較（署名可能iOS target / TestFlight build後）
- [ ] Internal TestFlight実機確認（人間確認地点 #3）

## Privacy / Store
- [x] PrivacyInfo.xcprivacy原稿
- [x] UserDefaults required-reason `CA92.1` 記載
- [x] Privacy Policy原稿
- [x] Support原稿
- [x] App Store日本語メタデータ原稿
- [x] トラッキングなし / 第三者広告SDKなし / 第三者解析SDKなしの現在実装と原稿を一致
- [ ] Privacy / Support URLをmainへ公開（本体統合後）

## AppIcon
- [x] 正本ファイル特定: Google Drive `13_保健師国家試験.png`
- [ ] 署名対象App targetへ正本バイト配置
- [ ] 配置バイトSHA-256記録

## Apple / Signing
- [x] Apple Team ID正本: `MN3D2ZM44N`
- [x] Version正本: `1.0.0`
- [x] Distribution正本: App Store
- [x] TestFlight正本: Internal Testing only
- [ ] #13 Bundle ID（識別情報正本未登録・推測禁止）
- [ ] #13 App Store Connect App ID（識別情報正本未登録・推測禁止）
- [ ] #13 Codemagic profile（識別情報正本未登録・推測禁止）
- [ ] IAP Product ID（課金採用時のみ。現時点で正本未登録）
- [ ] Signed IPA
- [ ] Internal TestFlight upload

## Final submission
- [ ] Internal TestFlight実機確認でユーザー承認
- [ ] スクリーンショット / App Privacy / age rating / export compliance最終確認
- [ ] App Store本審査提出のユーザー明示承認

App Store本審査は自動提出しない。
