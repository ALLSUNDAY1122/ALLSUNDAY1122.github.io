# CODEX HANDOFF｜薬剤師国家試験｜学びスプリント

更新：2026-08-09

## 現在地
ChatGPT側でWeb価値検証、本番問題バンク、iOS製品化、StoreKit 2、申請原稿、Privacy、Codemagic、リリース監査を整備中。ユーザーはGitHub Pages v0.6.1をiPhone Safariで確認し「問題なし」と承認済み。

## 固定値
- Repo：`ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Path：`pharmacist-manabi-sprint/`
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- Version / Build：`1.0.0 / 1`
- iOS：SwiftUI + WKWebView / local bundled assets
- Build：Codemagic workflow `pharmacist-ios`
- Monthly：`jp.allsunday1122.yakuzaishi.monthly`
- Lifetime：`jp.allsunday1122.yakuzaishi.lifetime`
- TestFlight：internal testing only
- App Store本審査自動送信：禁止

## 変更禁止の正本
- UI：Notion 学びスプリント UI Master v2.1 Golden Master
- 問題：`content/product/questions.json` + `final-audit-v2.json`
- AppIcon：Drive `05_薬剤師国家試験.png` / ID `1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu` / SHA-256 `dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec`

## TestFlight前に実行
1. `python3 pharmacist-manabi-sprint/scripts/validate_release.py`
2. 正本AppIconを`ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`へmaterializeしSHA一致確認
3. Apple DeveloperでExplicit App IDを登録/確認
4. App Store Connect Appを作成/確認
5. Subscription Group、月額1か月＋1週間Free Trial、Non-Consumable買い切りを設定
6. Codemagic integration/signingを確認
7. `pharmacist-ios` workflowを実行
8. TestFlightへ到着後、`RELEASE_CHECKLIST.md`の実機項目をユーザーが確認

## STOP
Apple ID・2FA・本人確認・契約/税務/銀行、TestFlight実機確認、App Store提出最終承認はユーザー本人へ返す。本審査へ自動提出しない。
