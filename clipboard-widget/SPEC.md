# クリップボードWidget｜Phase 0 PoC仕様

## 技術ゲート
実機iPhoneのLarge Widgetから、アプリ画面を開かず `UIPasteboard.general` に文字列を書き込めるかを検証する。Simulatorの結果だけではPASSにしない。

## A｜現行安定版
- Button: `TESTをコピー`
- Intent: 通常の `AppIntent`
- supported mode: `.background`
- expected paste: `Widget Copy Test`
- Apple公式のWidgetKit仕様では、通常の `AppIntent` は既定でWidget Extensionと同じプロセスで実行される。
- Xcode 26.6 / iOS 26.5 SDKでcompileできることを機械ゲートとする。

## B｜main app process
Aが実機で失敗した場合のみ検討する。
- Appleの現行Webドキュメントには `allowedExecutionTargets` / `.main` が掲載されている。
- ただし2026-08-26時点で同APIはBeta表記で、実CIのXcode 26.6 / iOS 26.5 SDKには `IntentExecutionTargets` 型が存在しなかった。
- よって現行安定版向け製品のBとしては未採用。新しい最終版SDKへ収録された時点で再評価する。
- Beta OS / Beta Xcodeを前提にMVPを出荷しない。

## C｜明示的フォールバック
Aが実機で失敗し、安定版APIでB相当が成立しない場合のみ、Widget → app起動 → 即コピーを検証する。明確な画面遷移が中心体験を損なう場合は技術的に動いてもFAILとする。

## 判定
- PASS-A: Aだけで正しいPaste、アプリ画面遷移なし。
- PASS-B: 安定版でB相当が成立し、正しいPaste、明確なアプリ画面遷移なし。
- FAIL: A/Bとも成立しない、不安定、またはコピーに毎回明確なアプリ画面遷移が必要。

## 証拠
Widget内の「Intent実行」表示は実行経路の証拠であり、Pasteboard書込成功の証拠ではない。最終証拠は実機でメモ等にPasteした結果とする。
