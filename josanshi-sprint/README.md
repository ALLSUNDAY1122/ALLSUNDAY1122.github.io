# 助産師国家試験｜学びスプリント

開発連番 #14。SwiftUI native を前提とし、WKWebView を主UIとして使用しない。

## 現在のフェーズ

- Phase 0 市場・競合・権利・出題基準調査: PASS
- Phase 1 Native UI foundation: 着手
- Phase 2 問題設計・生成監査: OPEN
- Phase 3 StoreKit 2 / signed app: BLOCKED（本番識別子未確認）
- Phase 4 Internal TestFlight: BLOCKED（署名・実機ゲート）
- External TestFlight / App Store本審査: ユーザー承認まで実行禁止

## 正本

- Notion UI: Golden Master v2.1 を最上位として適用。旧v1.0指定は互換参照のみ。
- 共通実装: `native-ios/LearningSprintCore`
- 標準スプリント: 8問、選択可能目標 4 / 8 / 16問
- 本試験最新確認: 第109回、午前55問 + 午後55問 = 110問
- 試験科目: 基礎助産学 / 助産診断・技術学 / 地域母子保健 / 助産管理

## 権利方針

厚生労働省サイトは特記・個別権利表記がないコンテンツについて PDL1.0 を採用している。一方、PDL1.0 は第三者権利を利用者側で確認することを要求する。別冊画像・図表・写真等は第三者権利が混在し得るため、本アプリでは公式問題の直接転載を基本方針にしない。令和5年版出題基準・法令・ガイドライン等の一次資料を根拠に独自問題・独自解説を作成し、問題単位で根拠、確認日、法令基準日、権利根拠を保持する。

## 未確定・推測禁止

- Bundle ID: 要確認
- App Store Connect App ID: 要確認
- IAP Product ID: 要確認
- App Store価格: 要確認
- 本番署名設定: 要確認

詳細は `docs/RESEARCH_2026-08-12.md` と `docs/RELEASE_STATUS.md` を参照。
