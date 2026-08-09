# RELEASE STATUS｜薬剤師国家試験｜学びスプリント

- 状態：製品化・TestFlight準備
- Version：1.0.0
- Build：1
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- GitHub正本：main / `pharmacist-manabi-sprint/`
- Web価値検証：v0.6.1 iPhone Safari ユーザー確認PASS（2026-08-09）
- iOS方式：SwiftUI + WKWebView（監査済みWeb教材ローカル同梱）
- ビルド方式：Codemagic + XcodeGen
- 課金：StoreKit 2／月額＋買い切り
- 月額：`jp.allsunday1122.yakuzaishi.monthly`
- 買い切り：`jp.allsunday1122.yakuzaishi.lifetime`
- 無料：第111回必須90問
- プレミアム：採点対象1,031問
- 問題監査：1,035/1,035、blocked 0、解説1,035/1,035、未解決高類似0、水増し0
- 公開Support/Privacy/Terms：作成済み
- データ収集：なし
- ログイン：なし
- 広告：なし
- 解析：なし
- 独自クラウド同期：なし
- AppIcon正本：Google Drive `05_薬剤師国家試験.png` / file ID `1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu`
- AppIcon SHA-256：`dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec`

## 次のゲート
1. iOSリリース静的監査・Simulator Build PASS
2. Apple Developer Explicit App ID / App Store Connect App / IAP商品を作成または確認
3. Codemagic signing / App Store Connect integrationを確認
4. Internal TestFlight Buildを送信
5. iPhone実機で購入・復元を含むTestFlight確認

本審査への自動提出は禁止。`submit_to_app_store: false`を維持する。
