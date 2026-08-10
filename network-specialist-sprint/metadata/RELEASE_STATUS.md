# RELEASE STATUS

更新: 2026-08-10 JST

- 状態：純SwiftUIネイティブ化・実装/UI/Release Gate再監査中
- Version：1.0.0
- Build：1
- Bundle ID：`jp.allsunday1122.networkspecialist`（ユーザー正本固定）
- Apple Team ID：`MN3D2ZM44N`（ユーザー正本固定）
- Codemagic profile：`networkspecialist_appstore`（ユーザー正本固定）
- App Store Connect App ID：今回の#7正本ブロックに未記載。推測禁止。
- GitHub正本候補：`agent/network-specialist-native-swiftui` / PR #4126
- Web公開版：既存の価値検証・問題確認用として維持
- iOS方式：**純SwiftUIネイティブ**。WKWebView/WebKitはアプリターゲットから削除
- データ：既監査75出題枠 / 68ユニークを内容変更せずネイティブJSONへ変換
- contentVersion：`nw-a2-2026-08-v1`
- lawBaselineDate：資格正本に値がないため `null` を保持し推測しない
- sourceCheckedAt：資格正本に明示値がないため空値を保持し、設定画面では「未取得」と表示
- IAP：#7の資格別Product IDが正本にないため初期版なし。Product IDを推測しない
- データ収集：なし
- ログイン：なし
- 広告：なし
- 解析：なし
- Distribution：App Store
- TestFlight：Internal Testing only
- App Store本審査自動提出：禁止

## 監査状態
- 問題・正答・解説・出典・権利監査：既存PASSを維持（問題内容を変更していないため）
- 実装監査：ネイティブ化により旧PASS失効 → PR #4126で再監査中
- UI監査：ネイティブ化により旧30状態PASS失効 → Simulator/UI test後に再判定
- Release Gate：ネイティブ化により再発火。署名前ゲート未完了

## Release blocker
1. 正本AppIcon `07_ネットワークスペシャリスト試験.png` をGitHub checkoutへ同一SHAで配置する必要がある（再生成禁止）
2. #7のApp Store Connect App IDが今回のユーザー正本に未記載
3. macOS Unit/UI test・サイズ別検証の最終PASS待ち
4. Codemagic App Store Connect integration / signingの認証
5. Signed IPA生成・App Store Connect upload
6. TestFlight内部実機確認

本審査へは進めない。
