# Release Checklist｜司法試験予備試験・短答式｜学びスプリント

更新: 2026-08-13
現在判定: `BLOCKED / DEVELOPMENT`

## A. 正本・教材

- [x] Notion開発正本を作成し台帳へ接続
- [x] Golden Master v2.1を適用
- [x] 純SwiftUI・WebView 0
- [x] 法務省利用条件・PDL1.0・第三者権利を分離
- [x] CBT体験版の二次利用禁止を明文化
- [x] R6-R8法令基準日を一次資料ルールから固定
- [x] R6・R7の問題ページ／正解及び配点ページの存在確認
- [x] R7誤記訂正資料をReleaseゲートへ追加
- [x] R8問題4冊の公開確認
- [ ] R6正式問題PDFをページ単位監査
- [ ] R6正解・配点PDFをページ単位監査
- [ ] R7正式問題PDFをページ単位監査
- [ ] R7正解・配点／誤記訂正PDFをページ単位監査
- [ ] R8正解・配点の一次資料を確定
- [ ] R8問題・正解資料をページ単位監査
- [ ] R6-R8年度×科目の正式問題数確定
- [ ] 正式3回分の正答・配点・特殊採点確定
- [ ] 一般教養の第三者権利監査
- [ ] canonical正式問題バンクを生成
- [ ] 共通validatorで件数・ID・重複・高類似FAIL 0
- [ ] 内容・法令・権利・正答監査FAIL 0

## B. 独自問題・品質基盤

- [x] 8科目論点マップv1
- [x] 法律7科目の一次法令ベース候補14問
- [x] Candidate preflight
- [x] Candidateの `release_eligible=true` 禁止
- [x] Release builderは `release_passed` のみ変換可能
- [x] Native `QuestionRepository` fail-closed
- [ ] 候補問題の2026-01-01時点e-Gov法令監査PASS
- [ ] 候補問題の正答・解説内容監査PASS
- [ ] 正式教材採用問題を `release_passed` に昇格

## C. Native iOS

- [x] ホーム／模試／記録／設定4タブ
- [x] 8問スプリント、4/8/16設定
- [x] 分野別、苦手、わからない、途中再開
- [x] 苦手3連続正解解除
- [x] 記録・5週間ヒートマップ
- [x] JSONバックアップ
- [x] バックアップ5MiB上限・整合性検証
- [x] 無料利用状態のバックアップ／リセット復活防止
- [x] Premium専用途中再開の権利再確認
- [x] StoreKit 2 fail-closed
- [x] StoreKit transaction updates監視
- [x] Privacy Manifest
- [x] iPhone縦向き固定
- [ ] 最新XCTest全PASS
- [ ] 最新XCUITest全PASS
- [ ] Release configurationのunsigned build PASS

## D. AppIcon

- [x] Drive正本 `11_司法試験予備試験_短答式.png` を特定
- [x] 1024×1024 PNG確認
- [x] SHA-256 `c56c3f0acf7e05ec6096fdee881081b7b7e8e863ae2933b496550e902b840bf9` 固定
- [x] Canonicalビルド時SHA検証スクリプト
- [x] Simulator専用placeholderを本番正本と分離
- [ ] Signed ReleaseビルドでCanonical AppIcon実バイト検証

## E. App Store資産

- [x] 公開Privacy Policy原稿
- [x] 公開Support原稿
- [x] App Store metadata原稿
- [x] Premium機能がアプリ内課金で解放されることをmetadataへ明記
- [x] App Review Notes原稿
- [x] StoreKit実機テスト計画
- [ ] 正式教材Release後にmetadata収録内容を再照合
- [ ] iPhoneスクリーンショット作成
- [ ] 公開Privacy URL HTTP 200確認
- [ ] 公開Support URL HTTP 200確認

## F. 本番識別子・署名

以下は推測禁止。正本へ明示値が登録されるまでBLOCKする。

- [ ] Bundle ID: `要確認`
- [ ] App Store Connect App ID: `要確認`
- [ ] SKU: `要確認`
- [ ] IAP Product ID: `要確認`
- [ ] IAP商品種別Non-ConsumableをApp Store Connectで確認
- [ ] IAP価格設定をApp Store Connectで確認
- [ ] 初回Non-Consumable IAPをアプリversion 1.0.0と同時に審査対象へ紐付ける
- [ ] Codemagic signing profile: `要確認`
- [ ] root Codemagic workflow統合
- [ ] Signed IPA生成
- [ ] App Store Connect upload

## G. Internal TestFlight

- [ ] Internal Testing only設定
- [ ] TestFlightへbuildを配置
- [ ] iPhone実機で起動・主要導線確認
- [ ] StoreKit Sandbox購入・復元・pending・cancel等を確認
- [ ] 正本AppIcon表示確認
- [ ] 正式教材件数・模試構成・特殊採点表示確認

## H. 外部審査

- [ ] ユーザーの明示承認
- [ ] External Beta App Review（必要な場合）
- [ ] Add for Review
- [ ] Submit for Review

**ユーザー承認前にHを実行しない。**
