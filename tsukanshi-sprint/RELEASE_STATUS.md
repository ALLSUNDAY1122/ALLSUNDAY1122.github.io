# 通関士｜学びスプリント RELEASE STATUS

更新日: 2026-08-09

## 現在地
**Codex引継ぎ正本作成済み｜Apple Developer Explicit App ID登録待ち**

教材・UI・権利・申請資産・iOS Release build・StoreKit 2・ASC/TestFlightコードゲートまで完了。Notion「申請手順」で最初に確認する正本 `CODEX_HANDOFF.md` を作成した。2026-08-09にユーザーがApp Store Connectの新規アプリ画面を確認したところBundle ID選択肢が空だったため、現在の最初の外部停止点はApp Store Connect Appレコード作成ではなく、Apple DeveloperでExplicit App ID `jp.allsunday1122.tsukanshi` を登録すること。

## 固定値
- App: 通関士｜学びスプリント
- Bundle ID: `jp.allsunday1122.tsukanshi`
- Version: `1.0.0`
- SKU: `tsukanshi-sprint-ios`
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- IAP Type: Non-Consumable
- iOS方式: SwiftUI + WKWebView + StoreKit 2
- iOS最低バージョン: iOS 16.0
- Build方式: XcodeGen → Capability正規化 → Codemagic
- 公開Web: `https://allsunday1122.github.io/tsukanshi-sprint/`
- Support: `https://allsunday1122.github.io/tsukanshi-sprint/support.html`
- Privacy: `https://allsunday1122.github.io/tsukanshi-sprint/privacy.html`

## 完了
- [x] `CODEX_HANDOFF.md` 作成
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
- [x] Web試用版で未確定の固定価格を表示しない
- [x] ネイティブ版はStoreKit `displayPrice`取得後のみ購入操作を有効化
- [x] Xcode生成projectへIn-App Purchase Capabilityを正規化
- [x] XcodeGen 2.46.0のTargetAttributes誤シリアライズを自動検出・修正
- [x] Codemagic署名ビルドにも同じCapability正規化工程を固定
- [x] 現行監査済みWeb資産のiOS bundle化
- [x] AppIcon 1024px生成工程
- [x] Privacy Manifest parse
- [x] XcodeGen生成
- [x] iPhone Simulator Release build
- [x] 実`.app`内Web教材 / 全監査パッチ / StoreKit価格ガード / Privacy Manifest / AppIcon確認
- [x] 教材CI 480＋12維持
- [x] Apple署名前プリフライトCI成功
- [x] ASC/TestFlight前コードゲート成功
- [x] Codemagic安全ゲート成功
- [x] 本審査自動提出OFF

## 次のApple側工程
1. Apple DeveloperでExplicit App ID `jp.allsunday1122.tsukanshi` を登録
2. App Store Connectの新規アプリ画面を開き直し、Bundle ID選択肢に表示されることを確認
3. App Store Connectで新規Appレコードを作成
   - Platform: iOS
   - Name: `通関士｜学びスプリント`
   - Primary Language: Japanese
   - Bundle ID: `jp.allsunday1122.tsukanshi`
   - SKU: `tsukanshi-sprint-ios`
   - User Access: アクセス制限なし / Full Access
4. App Store Connect App IDを正本へ記録
5. IAP `jp.allsunday1122.tsukanshi.premium` をNon-Consumableで作成
6. IAP正式価格を決定・設定
7. Paid Apps Agreement / 税務・銀行情報を確認
8. Codemagic App Store Connect integration / 署名を確認
9. signed IPAを生成しApp Store Connectへアップロード
10. TestFlight内部Buildとして処理・配布
11. iPhone実機で主要導線、機内モード、StoreKit表示価格を確認
12. Sandbox購入・再起動後権利維持・購入復元を確認
13. スクリーンショット / App Privacy / 年齢 / Content Rights / Review情報を最終入力
14. ユーザー最終確認後のみ `Add for Review` / `Submit for Review`

## 人の操作が必要な停止点
- Apple Developer / App Store Connectログイン・2FA
- Explicit App IDのRegister
- 新規Appレコード作成
- IAP正式価格決定
- Paid Apps Agreement等の契約・税務・銀行状態
- CodemagicへのApp Store Connect連携設定
- App Review連絡先
- TestFlight実機Sandbox購入・復元
- 本審査提出ボタンの最終承認

## リリースゲート
**Apple Developer / App Store Connectへ入る前に実行可能なコード・申請値・CIゲートは合格。**
**現在の最初の外部停止点は、Apple DeveloperでExplicit App ID `jp.allsunday1122.tsukanshi` を登録すること。**
**TestFlight-ready判定は、App Store Connect登録とCodemagic署名付きIPA生成・アップロードが完了した時点。**
**App Store-ready判定は、Sandbox購入・復元を含むiPhone実機確認完了後。**
