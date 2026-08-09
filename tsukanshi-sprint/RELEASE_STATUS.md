# 通関士｜学びスプリント RELEASE STATUS

更新日: 2026-08-09

## 現在地
**Apple署名前プリフライト完了｜App Store Connect入力待ち**

教材・UI・権利・申請資産・iOS Release buildに加え、App Store Connect入力値、IAP固定値、StoreKit取引更新、Codemagic安全設定を横断するApple署名前プリフライトまで完了した。公開Web試用版は2026-08-09にユーザー実機で問題なく動作することを確認済み。

## 固定値
- App: 通関士｜学びスプリント
- Bundle ID: `jp.allsunday1122.tsukanshi`
- Version: `1.0.0`
- SKU: `tsukanshi-sprint-ios`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- IAP Type: Non-Consumable
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
- [x] 公開Web試用版のユーザー動作確認
- [x] Bundle ID / Version / SKU / IAP Product ID固定
- [x] Privacy Manifest（UserDefaults / CA92.1）
- [x] 公開Support / Privacyページ
- [x] App Store Metadata / App Review Notes
- [x] App Store Connect入力票 `APPLE_CONNECT_PACKET.md`
- [x] StoreKit 2購入・復元テスト計画
- [x] `Transaction.currentEntitlements` / `Transaction.updates` / `AppStore.sync()` 実装
- [x] StoreKit状態変化をWKWebViewへ即時反映
- [x] 現行監査済みWeb資産のiOS bundle化
- [x] AppIcon 1024px生成工程
- [x] Privacy Manifest parse
- [x] XcodeGen生成
- [x] iPhone Simulator Release build
- [x] 実`.app`内Web教材 / 全監査パッチ / Privacy Manifest / AppIcon確認
- [x] 教材CI 480＋12維持
- [x] Apple署名前プリフライトCI成功
- [x] Codemagic安全ゲート成功
- [x] 本審査自動提出OFF

## 次のApple側工程
1. App Store Connectで新規Appレコードを作成
2. Bundle ID `jp.allsunday1122.tsukanshi` とSKU `tsukanshi-sprint-ios` を入力
3. IAP `jp.allsunday1122.tsukanshi.premium` をNon-Consumableで作成
4. IAP正式価格を決定・設定
5. Paid Apps Agreement / 税務・銀行情報を確認
6. Codemagic App Store Connect API integration / 署名を確認
7. signed IPAを生成しApp Store Connectへアップロード
8. TestFlight内部Buildとして処理・配布
9. iPhone実機で主要導線、機内モード、StoreKit表示価格を確認
10. Sandbox購入・再起動後権利維持・購入復元を確認
11. スクリーンショット / App Privacy / 年齢 / Content Rights / Review情報を最終入力
12. ユーザー最終確認後のみ `Add for Review` / `Submit for Review`

## 人の操作が必要な停止点
- Apple Developer / App Store Connectログイン・2FA
- 新規Appレコード作成
- IAP正式価格決定
- Paid Apps Agreement等の契約・税務・銀行状態
- CodemagicへのApp Store Connect APIキー登録
- App Review連絡先
- TestFlight実機Sandbox購入・復元
- 本審査提出ボタンの最終承認

## リリースゲート
**Apple署名前のコード・申請値・CIゲートは合格。**
**TestFlight-ready判定は、App Store Connect登録とCodemagic署名付きIPA生成・アップロードが完了した時点。**
**App Store-ready判定は、Sandbox購入・復元を含むiPhone実機確認完了後。**
