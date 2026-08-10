# RELEASE STATUS

更新: 2026-08-10 JST

- 状態：純SwiftUIネイティブ化・実装/UI/課金/Release Gate再監査中
- Version：1.0.0
- Build：1
- Bundle ID：`jp.allsunday1122.networkspecialist`（正本固定）
- Apple Team ID：`MN3D2ZM44N`（正本固定）
- Codemagic profile：`networkspecialist_appstore`（正本固定）
- App Store Connect App ID：#7正本に未記載。推測禁止。
- GitHub正本候補：`agent/network-specialist-native-swiftui` / PR #4126
- Web公開版：既存の価値検証・問題確認用として維持
- iOS方式：**純SwiftUIネイティブ**。WKWebView/WebKitはアプリターゲットから削除
- データ：既監査75出題枠 / 68ユニークを内容変更せずネイティブJSONへ変換
- contentVersion：`nw-a2-2026-08-v1`
- lawBaselineDate：資格正本に値がないため `null` を保持し推測しない
- sourceCheckedAt：資格正本に明示値がないため空値を保持し、設定画面では「未取得」と表示
- IAP方式：StoreKit 2 / 非消耗型買い切り機構を実装済み
- IAP Product ID：#7正本に未記載。推測禁止。未設定時は購入UIを表示せず、Codemagic Release GateをFAILさせる
- IAP権利判定：検証済み `Transaction.currentEntitlements` を正本とし、unverified / pending / cancelled / revocationでは解放しない
- 購入復元：ユーザー操作時のみ `AppStore.sync()`
- 価格表示：`Product.displayPrice` のみ。固定価格はコード・申請原稿へ書かない
- データ収集：学習データの開発者サーバー送信なし
- ログイン：なし
- 広告：なし
- 解析：なし
- Distribution：App Store
- TestFlight：Internal Testing only
- App Store本審査自動提出：禁止

## 監査状態
- 問題・正答・解説・出典・権利監査：既存PASSを維持（問題内容を変更していないため）
- 実装監査：PR #4126で再監査中。前回FAIL原因 `questions.native.json missingResource` に対し、XcodeGenの明示resource登録＋Bundle subdirectory fallbackを適用
- UI監査：ネイティブ化により旧30状態PASS失効 → 最新Simulator/UI test後に再判定
- 課金監査：StoreKit 2実装・静的監査を追加。Product ID未設定のためRelease課金GateはBLOCKED
- Privacy監査：StoreKit 2追加に合わせPrivacy/Supportページを2026-08-10更新
- Release Gate：AppIcon / IAP Product ID / ASC App ID / 署名認証が未完了

## Release blocker
1. #7 IAP Product IDが正本に未記載。`PremiumProductID`を設定できない
2. 正本AppIcon `07_ネットワークスペシャリスト試験.png` をGitHub checkoutへ同一SHAで配置する必要がある（再生成禁止）
3. #7 App Store Connect App IDが正本に未記載
4. 最新macOS Unit/UI test・2サイズ検証の最終PASS待ち
5. Support / Privacy公開URLの未ログインHTTP 200をこの実行環境から独立確認できていない
6. Codemagic App Store Connect integration / signingの認証
7. Signed IPA生成・App Store Connect upload
8. TestFlight内部実機確認

本審査へは進めない。
