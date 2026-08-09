# 通関士｜学びスプリント RELEASE STATUS

更新日: 2026-08-09

## 現在地
**申請前リリース基盤整備中**

教材・UI・権利監査は完了。App Store申請手順に従い、iOS ReleaseビルドとTestFlightへ進むための申請資産・CIを整備する。

## 固定値
- App: 通関士｜学びスプリント
- Bundle ID: `jp.allsunday1122.tsukanshi`
- Version: `1.0.0`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- iOS方式: SwiftUI + WKWebView + StoreKit 2
- iOS最低バージョン: iOS 16.0
- Build方式: XcodeGen → Codemagic優先
- 公開Web: `https://allsunday1122.github.io/tsukanshi-sprint/`
- Support: `https://allsunday1122.github.io/tsukanshi-sprint/support.html`
- Privacy: `https://allsunday1122.github.io/tsukanshi-sprint/privacy.html`

## 完了
- [x] UI Master v2.1 Golden Master準拠
- [x] 全ボタン無反応修正・UI bootstrap監査
- [x] 通常学習480/480問 二次編集監査
- [x] 申告書12/12セット 二次編集監査
- [x] 第59〜57回過去問権利監査
- [x] 公式PDF本文を同梱しない権利安全設計
- [x] 税関公式問題への外部導線
- [x] Bundle ID確定 `jp.allsunday1122.tsukanshi`
- [x] Version 1.0.0へ申請用設定整理
- [x] Privacy Manifest作成（UserDefaults / CA92.1）
- [x] 公開Support / Privacyページ作成
- [x] App Store Metadata初稿
- [x] iOS Web資産を現行監査済みセットへ切替
- [x] AppIcon 1024px生成工程を準備

## このPRでCI確認する項目
- [ ] Release foundation lint
- [ ] Privacy Manifest parse
- [ ] XcodeGen生成
- [ ] iPhone Simulator Release build
- [ ] アプリbundle内 `Web/index.html` / 全監査パッチ / Privacy Manifest / AppIcon確認
- [ ] 既存教材CI 480＋12を維持

## CI成功後に残るApple側工程
1. App Store Connectで新規Appレコード作成
2. Explicit App ID / Bundle ID一致確認
3. IAP `jp.allsunday1122.tsukanshi.premium` をNon-Consumableで作成
4. IAP価格・審査画像を設定
5. Paid Apps Agreement / 税務・銀行情報を確認
6. Codemagic App Store Connect integration / 署名を確認
7. signed IPA作成
8. TestFlight内部Buildへアップロード
9. iPhone実機で主要導線、オフライン、購入、復元を確認
10. スクリーンショット作成・App Store Connectへ登録
11. App Privacy / 年齢 / Content Rights / 輸出回答を最終入力
12. ユーザー最終確認後のみ `Add for Review` / `Submit for Review`

## 未確定（人の操作が必要）
- App Store Connect App ID
- Apple Developer / App Store Connectログイン・2FA
- IAP正式価格
- App Review連絡先
- Paid Apps Agreement等の契約状態
- TestFlight実機結果
- 本審査提出ボタンの最終承認

## リリースゲート
**TestFlight-ready判定は、macOS CIのRelease build成功とCodemagic署名設定確認後。**
**App Store-ready判定は、Sandbox購入・復元を含むiPhone実機確認完了後。**
