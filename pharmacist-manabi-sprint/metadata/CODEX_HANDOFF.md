# CODEX HANDOFF｜薬剤師国家試験｜学びスプリント

> **SUPERSEDED / 使用禁止**
>
> この文書は2026-08-09時点の旧`SwiftUI + WKWebView`構成とCodex移管を記録した履歴ファイルである。2026-08-10のユーザー指示によりCodex移管は解除され、現在の担当はChatGPT。学習UIはSwiftUIネイティブへ置換するため、旧引継ぎ指示を作業開始点として使用してはいけない。

## 現行正本
- Notion：`薬剤師国家試験｜学びスプリント`
- GitHub作業PR：`#4128`
- Branch：`chatgpt/pharmacist-native-swiftui`
- 現行Release状態：`metadata/RELEASE_STATUS.md`
- 現行TestFlight確認：`metadata/RELEASE_CHECKLIST.md`

## 固定値
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- App Store Connect App ID：`6799753724`
- Codemagic profile正本名：`yakuzaishi_appstore`
- Version：`1.0.0`
- Monthly：`jp.allsunday1122.yakuzaishi.monthly`
- Lifetime：`jp.allsunday1122.yakuzaishi.lifetime`
- 問題バンク：1,035問（採点対象1,031／解なし4／multiple accepted 3）
- 無料範囲：第111回必須90問
- TestFlight：Internal testing only
- App Store本審査自動送信：禁止

## 旧情報からの重要変更
旧文書にあった以下は現在無効。
- `ChatGPT → Codex`への担当移管
- `SwiftUI + WKWebView`を完成形とする判断
- Web教材をiOS実行UIとしてそのまま採用する判断
- 旧WebView Simulator Preflightをネイティブ版の最終PASSとみなす判断

現行実装はSwiftUIネイティブで、`WKWebView`／`import WebKit`をリリース監査で禁止している。

## 現在の停止条件
ChatGPTは正本確認→実装→XCTest→専門監査→FAIL修正→再監査→Release buildまで担当する。署名付きInternal TestFlight生成時は、Apple Developer / App Store Connect / Codemagicのアカウント側設定が必要になる。

以下はユーザー本人確認を飛び越えない。
- Apple IDログイン、2FA、本人確認
- 契約／税務／銀行情報の確定
- 有料商品の最終価格決定
- TestFlight実機合否
- App Store本審査送信

本審査への`Add for Review` / `Submit for Review`は、このチャットの対象外。
