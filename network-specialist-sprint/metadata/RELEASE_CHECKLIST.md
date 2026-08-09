# RELEASE CHECKLIST

## 開発ループ完了
- [x] UI Golden Master v2.1適用
- [x] 3年度×25出題枠の問題監査
- [x] 重複を除いた通常学習用ユニーク問題バンク（68問）
- [x] 歴史的再出題・実質同一7出題をcanonical化し水増し防止
- [x] 問題・解説・出典・改変フラグ監査
- [x] 実装検証ループPASS
- [x] 30状態UI監査PASS
- [x] 辛口レビュー3周
- [x] 1024×1024 RGB正本AppIcon取得（Google Drive file ID `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`）
- [x] Support / Privacy静的ページ作成
- [x] Privacy Manifest作成
- [x] SwiftUI + WKWebViewローカル同梱ラッパー作成
- [x] portrait固定
- [x] 非免除暗号化を使用しない設定
- [x] Codemagic + XcodeGen設定作成
- [x] App Store日本語メタデータ下書き
- [x] GitHubクリーンPR #4092 をmainへ統合
- [x] 専用GitHub Actions検証ワークフローを追加
- [x] GitHub / Notionの状態を「開発ループ完了・公開準備」に更新

## TestFlight実行ゲート
- [ ] Google Drive正本PNGを `AppIcon-1024.png` としてiOS AppIcon資産へ配置
- [ ] Explicit App ID登録・確認：`jp.allsunday1122.networkspecialist`
- [ ] App Store Connectアプリレコード作成
- [ ] Codemagic App Store Connect integration設定
- [ ] Signing certificate / provisioning profile取得
- [ ] Archive / Validate / TestFlight upload PASS
- [ ] TestFlight実機：起動、8問完走、25問模試、中断復帰、JSON、機内モード
- [ ] Support / Privacy公開URLのHTTP 200確認
- [ ] App Privacyを実装と照合して入力
- [ ] スクリーンショット登録
- [ ] Add for Review直前の最終確認

開発ループ自体は完了。以降はApple/Codemagicの本人認証を伴う申請実行ループ。
