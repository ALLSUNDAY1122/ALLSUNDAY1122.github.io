# CODEX HANDOFF

目的: 第一種衛生管理者｜学びスプリントをTestFlight内部テストへ送る。

正本:
- Resources/index.html
- Resources/questions.json
- audit/LEGAL_AUDIT.md
- RELEASE_CHECKLIST.md
- IAP_SETUP.md
- APP_STORE_METADATA_JA.md

固定値:
- Bundle ID: jp.allsunday1122.healthmanager1
- Version/Build: 1.0.0 / 1
- IAP Monthly: jp.allsunday1122.healthmanager1.monthly
- IAP Lifetime: jp.allsunday1122.healthmanager1.lifetime
- Route: SwiftUI + WKWebView + StoreKit 2 + Codemagic

禁止:
- 問題を公式公表問題の全文転載へ戻さない
- IAP価格をHTMLへ固定値で埋め込まない（StoreKit displayPrice）
- 復元ボタンを削除しない
- submit_to_app_store をtrueにしない
- FP2級基準UIを独自再設計しない

次作業:
ユーザーのApple/Codemagicログイン後、Bundle ID/App/IAPを登録し、Codemagic build 1→TestFlight内部テスト。

## 課金変更
買い切り単独仕様は廃止。月額200円相当（初回対象者7日無料）と買い切り980円相当を併売する。
StoreKitから取得した価格・Intro Offer資格をUI正本とし、固定価格だけで課金画面を出さない。
