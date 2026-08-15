# 看護師国家試験｜学びスプリント Release Checklist

更新: 2026-08-15

## A. コンテンツ・製品
- [x] canonical 720問
- [x] 第115・114・113回 各240問
- [x] 必修150 / 一般390 / 状況設定180
- [x] 解説720/720
- [x] 動的根拠85/85
- [x] 図版38/38
- [x] 特殊採点8件runtime監査
- [x] release quarantine 0
- [x] Web runtime監査

## B. Native iOS
- [x] SwiftUI native
- [x] WebView非依存
- [x] canonical 720問をnative payload化
- [x] media 38件をbundle化
- [x] StoreKit 2
- [x] `Product.displayPrice`
- [x] 購入復元導線: Paywall / 設定
- [x] Privacy Manifest
- [x] Debug Simulator build
- [x] Release Simulator build
- [ ] 2サイズUI automation PASS（最終run進行中）
- [ ] Google Drive正本 `03_看護師国家試験.png` の完全一致AppIconをXcode assetへ格納

## C. App Store提出物
- [x] App Store日本語メタデータ
- [x] App Review notes
- [x] Support page source
- [x] Privacy policy source
- [x] Codemagic `kangoshi-ios` Internal TestFlight workflow
- [ ] App Store用スクリーンショット最終生成・確認

## D. Apple側実値・契約 — 人間/Apple gate
- [ ] App Store Connect Appレコード作成
- [ ] 数値App Store Connect Apple ID取得 → 正本へ記録
- [ ] Explicit Bundle ID `jp.allsunday1122.kangoshi` 実登録確認
- [ ] IAP `jp.allsunday1122.kangoshi.monthly` 実登録
- [ ] Paid Apps Agreement / 税務 / 銀行情報が有効
- [ ] Appleログイン / 2FAが必要な場合の本人操作

## E. Internal TestFlight
- [ ] signed IPA build
- [ ] Internal TestFlight upload
- [ ] Apple processing完了
- [ ] 実機インストール
- [ ] ユーザーによるTestFlight実機確認

## F. 本審査
- [ ] 実機確認後の修正完了
- [ ] App Privacy / 年齢 / 輸出回答を最終照合
- [ ] スクリーンショット・IAP審査情報を登録
- [ ] ユーザーが `Add for Review` / `Submit for Review` を承認

**禁止:** ユーザー承認なしのApp Store本審査自動提出。
