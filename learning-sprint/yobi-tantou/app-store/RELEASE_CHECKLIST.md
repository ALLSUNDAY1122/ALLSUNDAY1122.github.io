# Release Checklist｜司法試験予備試験・短答式｜学びスプリント

更新: 2026-08-14
現在判定: `BLOCKED / DEVELOPMENT`
標準手順: v2.4

## A. 正本・教材

- [x] Notion開発正本を作成し台帳へ接続
- [x] Golden Master v2.1を適用
- [x] 純SwiftUI・WebView 0
- [x] 法務省利用条件・PDL1.0・第三者権利を分離
- [x] CBT体験版の二次利用禁止を明文化
- [x] R6-R8法令基準日を一次資料ルールから固定
- [x] R6-R8法律基本科目95問の科目別内訳を公式PDFで確定
- [x] 一般教養R6=42、R7/R8=44、20題選択を公式資料で確定
- [x] R6・R7の正答・配点・順不同・部分点を問題単位canonical化
- [x] R7誤記訂正資料の対象と採点影響を反映
- [ ] R8正答・配点・短答合格点の一次資料公開／確認
- [x] 公式一般教養R6-R8計130題をfail-closed権利トリアージ
- [ ] 公式問題本文を再録する場合の設問単位権利クリアランス
- [ ] 独自模試3回分417題の完成（現在84/417）
- [ ] 3回分の規定数一致
- [ ] 全417題で誤答・重複・高類似・根拠不明・水増し0
- [ ] mock-bankからNative正式バンクへの専用統合監査PASS

## B. 独自問題・品質基盤

- [x] 8科目論点マップv1
- [x] Native正式練習問題42問をrelease_passedへ昇格
- [x] 独自模試1の追加42問（legal batch-01／02／03）をrelease_passedへ昇格
- [x] 候補preflight
- [x] 2026-01-01 e-Gov exact-date source audit
- [x] 正答・解説監査
- [x] 誤答理由監査
- [x] 既存問題との横断近似重複監査
- [x] 品質HOLD時に閾値を下げず設問修正→上流監査から再実行
- [x] 候補の `release_eligible=true` 禁止
- [x] Release builderは `release_passed` のみ変換可能
- [x] Native `QuestionRepository` fail-closed
- [ ] 残り333題を同一品質ゲートで作成・監査

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
- [x] StoreKit 2 verified transaction / currentEntitlements / Transaction.updates
- [x] v2.4によりAuto-Renewable Subscriptionのみ受理
- [x] Product ID未登録時fail-closed
- [x] Privacy Manifest
- [x] iPhone縦向き固定
- [ ] v2.4変更後の最新XCTest全PASS
- [ ] v2.4変更後の最新XCUITest全PASS
- [ ] v2.4変更後のRelease configuration unsigned build PASS

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
- [x] App Review Notes原稿
- [x] StoreKit実機テスト計画
- [x] v2.4月額サブスクリプションへ原稿同期
- [x] アプリ内価格はStoreKit `displayPrice` のみを使用する契約
- [ ] 正式417題完成後にmetadata収録内容を再照合
- [ ] iPhoneスクリーンショット作成
- [ ] 公開Privacy URL HTTP 200確認
- [ ] 公開Support URL HTTP 200確認

## F. 本番識別子・課金・署名

- [x] Bundle ID: `jp.allsunday1122.yobishikentantou`
- [x] 課金モデル: Auto-Renewable Subscription（月額）
- [x] 日本向け基準価格: 200円/月
- [x] planned IAP Product ID: `jp.allsunday1122.yobishikentantou.monthly`
- [ ] App Store Connect Apple ID: 実発行値
- [ ] SKU: App Store Connect作成時の実値
- [ ] planned Product IDをApp Store ConnectへAuto-Renewable Subscriptionとして実登録
- [ ] App Store Connectで日本向け価格200円/月を設定
- [ ] runtime Product IDを実登録値へ設定
- [ ] サブスクリプショングループ実値を正本へ記録
- [ ] Codemagic signing profile実値を正本へ記録
- [ ] root Codemagic workflow統合
- [ ] Signed IPA生成
- [ ] App Store Connect upload

Bundle ID命名はv2.4によりユーザー確認ゲートではない。Appleが発行する数値IDは実値のみを記録し推測しない。

## G. 早期試用・Internal TestFlight

- [x] 早期試用URLゲート適用可否を判定
- [x] 純SwiftUIネイティブでブラウザ実行可能な初期試作がないため、GitHub Pagesをアプリ試用URLと偽装しない
- [ ] Internal Testing only設定
- [ ] TestFlightへbuildを配置
- [ ] iPhone実機で起動・主要導線確認
- [ ] StoreKit Sandbox契約・復元・pending・cancel・更新・期限切れを確認
- [ ] 正本AppIcon表示確認
- [ ] 正式教材件数・模試構成表示確認

## H. 外部審査

- [ ] ユーザーの明示承認
- [ ] External Beta App Review（必要な場合）
- [ ] Add for Review
- [ ] Submit for Review

**ユーザー承認前にHを実行しない。**
