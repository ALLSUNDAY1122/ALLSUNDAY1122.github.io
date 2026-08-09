# RELEASE STATUS｜薬剤師国家試験｜学びスプリント

- 状態：製品化完了／Appleアカウント設定待ち
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
- AppIcon iOS asset materialize：PASS
- iOS Release Preflight：PASS
- GitHub Actions run：`31304173464` / run #15
- Static audit：PASS
- XcodeGen：PASS
- In-App Purchase capability：PASS
- iOS Simulator compile：PASS（exit 0）
- App Store本審査自動送信：OFF

## 現在のゲート
コード・問題・Privacy・StoreKit・AppIcon・Simulator Buildに未解決FAILなし。

次は本人アカウント操作：
1. Apple Developer Explicit App ID `jp.allsunday1122.yakuzaishi` を登録/確認
2. App Store Connect Appレコードを作成/確認
3. 月額・買い切りIAPと月額7日Free Trialを設定
4. Paid Apps Agreement／税務／銀行情報を必要に応じて有効化
5. Codemagic App Store Connect integration/signingを確認
6. `pharmacist-ios` workflowを実行しInternal TestFlightへ送信
7. iPhone実機で購入・復元・権利維持・全問題解放を確認

本審査への自動提出は禁止。`submit_to_app_store: false`を維持する。
