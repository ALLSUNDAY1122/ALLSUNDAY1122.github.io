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
- [x] contentVersion / lawBaselineDate / sourceCheckedAtをネイティブpayloadへ保持

## 自動監査
- [x] `build_native_questions.py` で既存監査データ→native JSON変換
- [x] `validate_native_release.py` 追加
- [x] Unit test追加
- [x] UI test追加
- [x] 大/小2つのiPhone Simulatorを選ぶテストrunner追加
- [x] GitHub ActionsへUbuntu静的監査＋macOS Simulator監査を追加
- [ ] PR #4126 macOS Unit/UI test最終PASS
- [ ] ネイティブUIの辛口レビュー3周完了
- [ ] 変更後の実装/UI/Release Gateを最終PASSへ更新

## Apple / TestFlight実行ゲート
- [ ] 正本AppIcon PNGを `AppIcon-1024.png` としてGitHub checkoutへ同一SHAで配置
- [ ] #7 App Store Connect App IDをユーザー正本で確定（未記載のため推測禁止）
- [ ] Codemagic `networkspecialist_appstore` integration認証
- [ ] Signing certificate / provisioning profile取得
- [ ] Signed IPA作成
- [ ] App Store Connect upload
- [ ] TestFlight Internal Testingのみで配布
- [ ] 実機：起動、8問、25問模試、中断復帰、JSON、機内モード、VoiceOver
- [ ] Support / Privacy公開URL HTTP 200
- [ ] App Privacy / Content Rights / Age Rating / Export Compliance照合
- [ ] 実アプリ画面のApp Storeスクリーンショット

## STOP
- App Store本審査への自動提出は禁止
- `Add for Review` / `Submit for Review` はユーザー最終確認前に実行しない
- #7のIAP Product IDが正本にないため、StoreKit商品を推測・追加しない
