# 旧Codex引継ぎメモ — 使用停止

更新: 2026-08-10 JST

このファイルは2026-08-09時点の旧 `SwiftUI + WKWebView` 実装をCodexへ引き継ぐ目的で作成されたが、現在は**失効**している。

2026-08-10、開発担当をChatGPTへ戻し、ユーザー指定によりWebView/WKWebView実装を禁止して**純SwiftUIネイティブ化**を開始した。

現行状態は次を参照すること。

- Notion: `司法書士試験・択一式｜学びスプリント 開発正本`
- GitHub: `learning-sprint/shoshi/ios/NATIVE_MIGRATION_STATUS.md`
- Native source: `learning-sprint/shoshi/ios/`
- Current PR: #4129 `司法書士｜WKWebView廃止・純SwiftUIネイティブ化`

## 保持するPASS
問題本文・正答・短解説・一次根拠は今回変更していないため、令和5〜7年度択一210問の問題内容監査PASSは保持する。R7午後33は`all_correct`のまま。

## 失効したPASS
旧WKWebViewを対象にしたiOS実装/UI/browser audit/Release buildのPASSは、純SwiftUI移行開始時点で失効した。現行Release Gateで再監査する。

## 固定Apple情報
- App: `司法書士 学びスプリント`
- Bundle ID: `jp.allsunday1122.shoshi`
- App Store Connect App ID: `6799755748`
- Codemagic signing profile canonical name: `shoshi_appstore`
- IAP: `jp.allsunday1122.shoshi.premium`

このファイルをCodex作業開始指示として使用しないこと。現在の担当はChatGPTであり、次の人間確認点はInternal TestFlightのiPhone実機確認。
