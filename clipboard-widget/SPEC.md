# クリップボードWidget｜Phase 0 PoC仕様

## 技術ゲート
実機iPhoneのLarge Widgetから、アプリ画面を開かず `UIPasteboard.general` に文字列を書き込めるかを検証する。Simulatorの結果だけではPASSにしない。

## A
- Button: `TESTをコピー`
- Intent execution target: `.widgetKitExtension`
- supported mode: `.background`
- expected paste: `Widget Copy Test`

## B
Aが実機で失敗した場合のみ試す。
- Intent execution target: `.main`
- supported mode: `.background`
- expected paste: `Widget Copy Test - Main Background`
- アプリUIが前面に出ないことを確認する。

## 判定
- PASS-A: Aだけで正しいPaste、アプリ画面遷移なし。
- PASS-B: Aは失敗、Bで正しいPaste。明確なアプリ画面遷移なし。
- FAIL: A/Bとも失敗、不安定、またはコピーに毎回明確なアプリ画面遷移が必要。

## 証拠
Widget内の「Intent実行」表示は実行経路の証拠であり、Pasteboard書込成功の証拠ではない。最終証拠は実機でメモ等にPasteした結果とする。
