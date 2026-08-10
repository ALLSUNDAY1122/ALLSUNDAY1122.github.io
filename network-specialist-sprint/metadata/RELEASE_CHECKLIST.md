# RELEASE CHECKLIST｜純SwiftUIネイティブ化

## 維持する既存PASS
- [x] UI Golden Master v2.1要件確認
- [x] 2025/2024/2023 各25出題枠＝75問
- [x] 通常学習68ユニーク / 歴史的再出題・実質同一7出題をcanonical化
- [x] 問題・正答・解説・出典・改変フラグ監査
- [x] Support / Privacy静的ページ
- [x] PrivacyInfo.xcprivacy
- [x] portrait / 非免除暗号化なし
- [x] 正本AppIconのDrive file ID・SHA固定（再生成禁止）

## ネイティブ実装
- [x] WKWebView/WebKitアプリターゲットを削除
- [x] ホーム / 模試 / 記録 / 設定の純SwiftUI 4タブ
- [x] 標準8問、設定4/8/16問
- [x] 通常問題の即時採点
- [x] 「わからない」を正式回答化
- [x] 誤答/わからない→苦手登録
- [x] 3連続正解で苦手解除
- [x] 模試は年度別25問、解答中は正誤非表示
- [x] 中断・再開
- [x] 学習履歴 / 分野別 / 5週間ヒートマップ
- [x] JSONバックアップ / 復元
- [x] オフライン問題データをアプリbundleへ生成
- [x] VoiceOver向けラベル・accessibilityIdentifier
- [x] 生成り紙＋藍＋朱＋緑＋金 / 28pxグリッド / 82pxリング / 明朝＋ゴシック
- [x] contentVersion / lawBaselineDate / sourceCheckedAtのスキーマをネイティブpayloadへ保持
- [x] 正本に値がない lawBaselineDate / sourceCheckedAt を推測で埋めない

## StoreKit 2 / 課金監査
- [x] StoreKit 2 非消耗型購入エンジンを実装
- [x] 商品情報は `Product.products` から取得
- [x] 価格は `Product.displayPrice` のみ表示し固定価格を記載しない
- [x] verified active transactionのみ解放
- [x] unverified / pending / cancelled / revocationでは解放しない
- [x] `Transaction.currentEntitlements` で起動時・復元後の権利を再判定
- [x] `Transaction.updates` を起動中監視
- [x] ユーザー操作の「購入を復元」からのみ `AppStore.sync()`
- [x] Product ID未設定時は購入UIを表示しない
- [x] 課金アクセス方針Unit test追加
- [x] Privacy / Support / App Store metadataをStoreKit 2構成へ更新
- [ ] #7 Product IDを正本で確定
- [ ] `Info.plist` の `PremiumProductID` を正本値で設定
- [ ] App Store Connectに非消耗型IAP商品を作成し商品情報取得PASS
- [ ] Sandbox/TestFlightで購入・cancel・pending相当・復元・revocation挙動を確認

## 自動監査
- [x] `build_native_questions.py` で既存監査データ→native JSON変換
- [x] `validate_native_release.py` 追加
- [x] Unit test追加
- [x] UI test追加
- [x] 大/小2つのiPhone Simulatorを選ぶテストrunner追加
- [x] GitHub ActionsへUbuntu静的監査＋macOS Simulator監査を追加
- [x] Ubuntu静的ゲート PASS（問題/権利/native/JS/75-68/source policy）
- [x] 前回Simulator FAIL原因特定：生成済み `questions.native.json` がBundleルートから取得できなかった
- [x] FAIL修正：XcodeGenでJSONを明示Copy Bundle Resources化＋RepositoryにResources subdirectory fallback追加
- [x] ネイティブUIの辛口レビュー3周完了
- [x] 辛口1：未確認の「60%」良否色分けを削除
- [x] 辛口2：LearningStore初期化順の潜在不整合を修正
- [x] 辛口3：sourceCheckedAtへの監査生成日時の誤代入を撤去
- [x] Simulator専用テストでは正本AppIconを仮生成せず、AppIcon指定だけ無効化
- [x] Simulatorテストへ実行時間上限を設定
- [ ] PR #4126 最新macOS Unit/UI test最終PASS
- [ ] 変更後の実装/UI/Release Gateを最終PASSへ更新

## Apple / TestFlight実行ゲート
- [ ] 正本AppIcon PNGを `AppIcon-1024.png` としてGitHub checkoutへ同一SHAで配置
- [ ] #7 App Store Connect App IDを正本で確定（未記載のため推測禁止）
- [ ] #7 IAP Product IDを正本で確定（未記載のため推測禁止）
- [ ] Support / Privacy公開URL HTTP 200
- [ ] Codemagic `networkspecialist_appstore` integration認証
- [ ] Signing certificate / provisioning profile取得
- [ ] Signed IPA作成
- [ ] App Store Connectへバイナリアップロード
- [ ] TestFlight Internal Testingのみで配布
- [ ] 実機：起動、8問、25問模試、中断復帰、JSON、機内モード、VoiceOver、購入/復元
- [ ] App Privacy / Content Rights / Age Rating / Export Compliance照合
- [ ] 実アプリ画面のApp Storeスクリーンショット

## STOP
- App Store本審査への自動提出は禁止
- 外部TestFlight beta reviewへ自動提出しない
- `Add for Review` / `Submit for Review` はユーザー最終確認前に実行しない
- #7のApp Store Connect App ID / IAP Product IDを推測・生成しない
