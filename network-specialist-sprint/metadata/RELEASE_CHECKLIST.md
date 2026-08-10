# RELEASE CHECKLIST｜純SwiftUIネイティブ化

## 正本・問題監査
- [x] UI Golden Master v2.1要件確認
- [x] 2025/2024/2023 各25出題枠＝75問
- [x] 通常学習68ユニーク / 歴史的再出題・実質同一7出題をcanonical化
- [x] 問題・正答・解説・出典・改変フラグ監査
- [x] contentVersion / lawBaselineDate / sourceCheckedAtスキーマ保持
- [x] 正本に値がない lawBaselineDate / sourceCheckedAt を推測で埋めない

## ネイティブ実装
- [x] WKWebView/WebKitを削除し純SwiftUI化
- [x] ホーム / 模試 / 記録 / 設定の4タブ
- [x] 標準8問、設定4/8/16問
- [x] 通常問題の即時採点
- [x] 「わからない」を正式回答化
- [x] 誤答/わからない→苦手登録
- [x] 3連続正解で苦手解除
- [x] 年度別25問模試、解答中は正誤非表示
- [x] 中断・再開
- [x] 学習履歴 / 分野別 / 5週間ヒートマップ
- [x] JSONバックアップ / 復元
- [x] オフライン問題データ
- [x] JSON resource差異に備え、同一監査payload由来のSwift埋め込みfallbackを自動生成
- [x] VoiceOver向けラベル・accessibilityIdentifier
- [x] 生成り紙＋藍＋朱＋緑＋金 / 28pxグリッド / 82pxリング / 明朝＋ゴシック
- [x] portrait / 横スクロールなし

## StoreKit 2 / 課金監査
- [x] StoreKit 2 非消耗型購入エンジン
- [x] `Product.products` で商品取得
- [x] `Product.displayPrice` のみ価格表示
- [x] verified active transactionのみ解放
- [x] unverified / pending / cancelled / revocationでは解放しない
- [x] `Transaction.currentEntitlements` で権利再判定
- [x] `Transaction.updates` 起動中監視
- [x] ユーザー操作の復元時のみ `AppStore.sync()`
- [x] Product ID未設定時は購入UI非表示
- [x] Product ID未設定の署名ReleaseをCIでブロック
- [x] 課金アクセス方針Unit test
- [x] Privacy / Support / App Store metadataをStoreKit 2構成へ更新
- [ ] #7 Product IDを正本で確定
- [ ] 無料体験範囲 / 買い切り解放範囲を正本で確定
- [ ] `PremiumProductID`を正本値で設定
- [ ] App Store Connectに非消耗型商品を作成
- [ ] Sandbox/TestFlight購入・取消・保留・復元・失効確認

## 自動監査
- [x] native JSON + Swift埋め込みpayload生成
- [x] native release static validator
- [x] Unit tests
- [x] UI tests
- [x] 大/小2つのiPhone Simulator検証
- [x] Ubuntu static gate PASS
- [x] macOS XcodeGen / Swift compile PASS
- [x] Unit tests 5/5 PASS
- [x] UI tests 3/3 PASS
- [x] iPhone 17 Pro Max PASS
- [x] iPhone SE (3rd generation) PASS
- [x] GitHub Actions run #36 `31360542268` PASS
- [x] ネイティブUI辛口レビュー3周
- [x] PR #4126 mainへ統合
- [x] main統合コミット `2387b5136e3114d8af694647b2afa44eb3404024`

## FAIL→修正
- [x] WKWebView依存 → 純SwiftUIへ置換
- [x] 初回 `questions.native.json missingResource` → explicit resource化
- [x] 再度resource layout差異 → `GeneratedQuestionPayload.swift` fallback化 → PASS
- [x] 未確認60%良否色分け → 中立化
- [x] LearningStore初期化順 → 安全化
- [x] sourceCheckedAt誤代入 → 撤去

## Apple / TestFlight実行ゲート
- [ ] 正本AppIcon PNGを `AppIcon-1024.png` としてGitHub checkoutへ同一SHAで配置
- [ ] #7 App Store Connect App IDを正本で確定
- [ ] #7 IAP Product IDと解放範囲を正本で確定
- [ ] Support / Privacy公開URL HTTP 200
- [ ] Codemagic `networkspecialist_appstore` integration認証
- [ ] Signing certificate / provisioning profile取得
- [ ] Signed IPA作成
- [ ] App Store Connectへバイナリアップロード
- [ ] TestFlight Internal Testingのみで配布
- [ ] 実機：起動、8問、25問模試、中断復帰、JSON、機内モード、VoiceOver、購入/復元
- [ ] App Privacy / Content Rights / Age Rating / Export Compliance最終照合
- [ ] 実アプリ画面のApp Storeスクリーンショット

## STOP
- App Store本審査への自動提出は禁止
- 外部TestFlight beta reviewへ自動提出しない
- `Add for Review` / `Submit for Review` はユーザー最終確認前に実行しない
- #7 App Store Connect App ID / IAP Product ID / 解放範囲を推測しない
