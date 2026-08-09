# 危険物乙4 リリース基盤｜2026-08-09

Notion正本「AIアプリ開発 標準手順 v2.2」「申請手順」に従い、製品本体PRより先に申請・検証基盤をmainへ固定する。

## このPRに含めるもの
- Otsu4 Content Audit workflow
- Otsu4 Native Typecheck workflow
- Otsu4 Xcode Release Simulator Build workflow
- 公開Supportページ
- 公開Privacy Policy
- 制度改定監視への乙4一次資料追加
- Codemagic内部TestFlight専用workflow

## Codemagic方針
- App Store distribution signing
- `testFlightInternalTestingOnly: true`
- `submit_to_testflight: false`（Beta App Reviewへ自動提出しない）
- `submit_to_app_store: false`（本審査へ自動提出しない）
- App Store Connect integration・署名情報・秘密情報はGitHubへ保存しない

## 非対象
- 360問本体
- SwiftUI本体
- StoreKit本体
- App Store Connectアプリ作成
- IAP商品登録
- 本審査提出

製品本体は既存PR #4069で管理する。
