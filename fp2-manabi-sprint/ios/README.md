# FP2級｜学びスプリント iOS native wrapper

- XcodeGen: `fp2-manabi-sprint/ios/project.yml`; SwiftUI + WKWebView + StoreKit 2: `App.swift`
- Bundle ID: `com.allsunday1122.fp2manabisprint`; Version 1.0.0 / Build 9
- 買い切り `com.allsunday1122.fp2manabisprint.premium.lifetime`（ローカルStoreKit設定 ¥800）
- 自動更新月額 `com.allsunday1122.fp2manabisprint.premium.monthly`（ローカルStoreKit設定 ¥200 / P1M）
- 価格表示は Apple `Product.displayPrice` に限る。StoreKit設定の価格はローカルテスト用であり、App Store Connect実価格・商品登録の証拠ではない。
- WebView→StoreKit 2ブリッジ: `purchase(productID)`, `restore`, `refresh`。権利は検証済み `Transaction.currentEntitlements` / `Transaction.updates` だけを採用し、期限切れ・取消・返金・未検証・pendingでは解除しない。復元は `AppStore.sync()`。
- iOSネイティブ無料範囲: 2026年5月の公式60問から4/8/16問スプリントと同回の模擬試験。2024・2025年度、全分野演習、苦手復習はPremium。全298問の同梱を維持するため、**クライアントUIのゲートであり問題データの暗号化・秘匿ではない**。WebプレビューはFP3同様に課金橋渡しなし。
- `python3 fp2-manabi-sprint/ios/prepare-ios.py` が正規310問から選抜298問だけを生成・埋め込み、予備12問を除外。バンク・解答・解説には変更なし。CIはバンドルSHA、重複ID、選抜全298件、Product ID、StoreKit設定、Simulator、Chromium E2Eを検証。
- AppIconはユーザー承認済み2026-11-24正規シリーズアイコン。`APPICON_MANIFEST.json` に実PNG SHA-256、Git Blob SHA、1024×1024 RGB・アルファなしを記録し、ネイティブCIで実バイト照合する。App Store Connect側のアイコン一致は引き続き未確認。原典データは変更しない。Q0/Q5がBLOCKEDで公開は不承認のまま。TestFlightアップロード・署名・App Store審査提出は実施しない。
- ASC作業は `IAP_ASC_CHECKLIST.md` を参照。2商品とサブスクリプショングループの登録・価格設定・税務/契約/審査メタデータ確認を別途実施する必要がある。
