# RELEASE STATUS

更新: 2026-08-10 15:18 JST

- 状態：純SwiftUIネイティブ実装・自動監査PASS / Release外部ゲート待ち
- Version：1.0.0
- Build：1
- Bundle ID：`jp.allsunday1122.networkspecialist`（正本固定）
- Apple Team ID：`MN3D2ZM44N`（正本固定）
- Codemagic profile：`networkspecialist_appstore`（正本固定）
- App Store Connect App ID：#7正本に未記載。推測禁止。
- GitHub正本：`main / network-specialist-sprint/`
- ネイティブ化PR：#4126 merged
- main統合コミット：`2387b5136e3114d8af694647b2afa44eb3404024`
- iOS方式：**純SwiftUIネイティブ**。WKWebView/WebKitはアプリターゲットから削除
- データ：既監査75出題枠 / 68ユニーク。JSONと同一監査payload由来のSwift埋め込みフォールバックをビルド時生成
- contentVersion：`nw-a2-2026-08-v1`
- lawBaselineDate：正本に値がないため `null`。推測しない
- sourceCheckedAt：正本に明示値がないため空値。設定画面では「未取得」
- IAP方式：StoreKit 2 / 非消耗型買い切り機構を実装済み
- IAP Product ID：#7正本に未記載。推測禁止。未設定時は購入UIを表示せず、署名Release GateをFAILさせる
- 無料/プレミアム解放範囲：正本では「一部無料＋買い切り全解放」が候補。未確定のため機能ロックへ接続しない
- IAP権利判定：verified active transactionのみ解放。unverified / pending / cancelled / revocationでは解放しない
- 購入復元：ユーザー操作時のみ `AppStore.sync()`
- 価格表示：`Product.displayPrice` のみ。固定価格を記載しない
- データ収集：学習データの開発者サーバー送信なし
- ログイン：なし
- 広告：なし
- 解析：なし
- Distribution：App Store
- TestFlight：Internal Testing only
- App Store本審査自動提出：禁止

## 自動監査 PASS
GitHub Actions run #36 (`31360542268`)：
- Ubuntu static gate：PASS
- XcodeGen / Swift compile：PASS
- Unit tests：5/5 PASS
- UI tests：3/3 PASS
- iPhone 17 Pro Max：PASS
- iPhone SE (3rd generation)：PASS
- 標準8問 / 4・8・16設定 / 4タブ / 即時採点 / わからない / 苦手3連続解除 / 中断復帰 / 25問模試 / 模試中の即時正誤非表示 / JSON / 特大文字横はみ出し / StoreKit権利方針を検証

## FAIL→修正記録
1. 旧WKWebView依存 → 純SwiftUIへ置換、WebKit削除 → PASS
2. `questions.native.json` がUnit/UI実行時Bundleで見つからず `missingResource` → JSON明示resource化 → 再FAIL
3. resource layout差異が残存 → 同一監査payloadから `GeneratedQuestionPayload.swift` をビルド時生成しオフラインfallback化 → run #36 PASS
4. 未確認の60%良否色分け → 中立表示へ修正 → PASS
5. LearningStore初期化順の潜在不整合 → 安全化 → PASS
6. `sourceCheckedAt`への監査生成日時誤代入 → 撤去 → PASS
7. StoreKit 2追加 → Privacy / Support / App Store metadata / 課金監査を再発火・更新 → 機構PASS、Product IDは外部正本ブロッカー

## Release blocker
1. #7 IAP Product IDを正本で確定
2. 無料体験範囲 / 買い切り後の解放範囲を正本で確定
3. 正本AppIcon `07_ネットワークスペシャリスト試験.png` をGitHub checkoutへ同一SHAで配置（再生成禁止）
4. #7 App Store Connect App IDを正本で確定
5. Support / Privacy公開URLの未ログインHTTP 200確認
6. Codemagic App Store Connect integration / signingの認証
7. Signed IPA生成・App Store Connect upload
8. TestFlight Internal Testing実機確認（起動、8問、25問模試、中断復帰、JSON、機内モード、VoiceOver、購入/復元）

本審査へは進めない。
