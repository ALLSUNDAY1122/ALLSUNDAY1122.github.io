# CODEX HANDOFF

このアプリはChatGPT側でWeb本体、問題監査、UI監査、iOSラッパー、申請下書きまで準備済み。

## 変更禁止の正本
- UI：学びスプリント Golden Master v2.1
- AppIcon：Google Drive正本 `07_ネットワークスペシャリスト試験.png`
- 通常問題：重複除外済みユニークバンク
- 模試：2025/2024/2023 各25出題枠

## 次に実行する場合
1. `python3 scripts/validate_release.py`
2. macOS/Codemagicで `cd ios && xcodegen generate`
3. Bundle ID / signingをApple Developerと一致確認
4. Archive → TestFlight
5. 実機確認でFAILなら該当ループへ戻す

問題データ、正解、解説、出典、試験構成を変更した場合は問題生成・監査ループのPASSを失効させること。
