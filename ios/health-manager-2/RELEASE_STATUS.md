# RELEASE_STATUS｜第二種衛生管理者｜学びスプリント

更新: 2026-08-19

## 現在地
**300問化後の製品Build 16はCodemagicで署名・生成・Apple upload済み。App Store Connect APIの2026-08-19 read-backで `VALID / APP_STORE_ELIGIBLE`、App Store Version 1.0への紐付け、Internal Testingグループからの参照を確認済み。**

PR #4216で90問から300問へ拡張した後、10回相当 × 3科目 × 各10問、構造、完全重複、高類似、必須メタデータ、追加210問の内容監査、現行法の高リスク数値、approved AppIconをRelease Gateで検査した。申請用BuildはCodemagic `health-manager-2-ios` Build index 16。旧Build 1はInternal TestFlight履歴としてのみ扱い、現行申請Buildへ戻さない。

本審査Submitは人間の最終承認まで実行しない。次の人間品質ゲートはBuild 16のiPhone実機回帰。

## 固定値
- App Store Version: `1.0`
- Product version: `1.0.0`
- Current release Build: `16`
- Apple Build ID: `b53250d3-e005-4da4-bbc0-319c86a321ee`
- Codemagic Build ID: `6a842f4fb381e0b3a3e7a246`
- Bundle ID: `jp.allsunday1122.healthmanager2`
- iOS: SwiftUI + local WKWebView
- Web教材: アプリ内同梱
- 問題数: 300問
- 構成: 10回相当 × 3科目 × 各10問 = 30セット
- クイック学習: 標準8問、設定4/8/16問
- TestFlight: Internal Testing利用可能
- Beta App Review自動提出: しない
- App Store本審査自動提出: しない
- 課金: v1.0ではなし
- 広告/解析/ログイン/クラウド同期: なし

## 300問 Release Gate
- [x] 全300問
- [x] 10回相当 × 3科目 × 各10問
- [x] 全問5択
- [x] 各10問セットで正答位置1〜5を各2回に均等化
- [x] 問題ID重複0
- [x] 問題本文の完全一致を禁止
- [x] 高類似0.90以上を機械検査
- [x] 一文ポイント・解説・一次根拠・基準日・作問由来・権利根拠を必須化
- [x] 追加210問は公開候補＋内容監査済み。法令問題は一次資料照合済みを必須化
- [x] 法令基準日 `2026-08-18`
- [x] 2026-08-01施行の産業医の辞任・解任・退任報告を監査
- [x] 熱中症対策、労働時間、休憩、時間外上限、事務所環境など高リスク数値をRelease Gateへ固定
- [x] Codemagicビルド前に `export-audit-data.cjs` → `validate_questions.py` を実行

## approved AppIcon
- [x] ユーザー承認済みArtworkのみをrelease sourceとして使用
- [x] `approved-icon-v4` transportは4分割固定
- [x] transport SHA-256: `4cefe840198dde91fddb6c5fe0fdece7d41a8bebfed415eb034752491cd7977c`
- [x] placeholder `icon.svg` へのfallback禁止
- [x] 1024 / 120 / 152 / 167 / 180 px PNGを承認済みsourceから生成
- [x] Apple側Build 16にiconAssetTokenが存在することをAPI read-backで確認

## Codemagic / App Store Connect機械ゲート
- [x] Codemagic App ID `6a769d81a1add9d06020b524` をAPIで解決
- [x] `health-manager-2-ios` Build 16 finished
- [x] Distribution signing
- [x] IPA archive/export
- [x] App Store Connect upload
- [x] Build 16 `processingState=VALID`
- [x] Build 16 `buildAudienceType=APP_STORE_ELIGIBLE`
- [x] `usesNonExemptEncryption=false`
- [x] App Store Version 1.0 (`c0372f0c-c99a-4e4f-a8a3-28d13969091a`) へBuild 16が現在も紐付く
- [x] Internal Testingグループ `sun` (`168d820a-3671-446d-9918-d75a4dad5b1e`) のbuild一覧にBuild 16が存在
- [x] 旧Build 1も履歴として保持

## Build 16以降のソース差分監査
Codemagic Build 16を生成したcommit `f29557c61f7898707f513dc1c1385baa6a6c87c2` 以降、2026-08-19のmainとの比較で第二種衛生管理者の問題バンク・UI・AppIcon release sourceに変更はない。後続差分は共通API gatewayや他アプリ作業が中心で、Build 16の300問品質PASSを失効させる第二種教材変更は確認されていない。

## App Reviewでの残存リスク
- Guideline 4.2: WKWebView主体だが、300問完全同梱、短時間学習、30セット、30問模試、履歴、苦手卒業、中断再開、JSON共有、ネイティブ触覚を備え、単純な外部Web再包装ではない構成を維持する。
- Guideline 4.3(a): 第一種衛生管理者と共通UI/基盤を共有するため、本審査では第二種固有の対象範囲、30問模試、科目別40%判定、有害業務除外、独自作問300問をReview Detailとスクリーンショットで明示する。
- Metadata accuracy: 「5年分の過去問」「過去問300問」と誤認させる表現は禁止。300問は公式一次資料・公表問題の論点傾向を根拠にした独自作問・独自解説として表示する。

## 次の人間品質ゲート
Build 16をiPhone実機で確認する。

### 実機合格条件
- [ ] 起動クラッシュなし
- [ ] approved AppIconが期待どおり表示
- [ ] ホーム/模試/記録/設定の4タブ
- [ ] 10回相当・30セット・全300問への導線
- [ ] 30問模試と科目別40%判定
- [ ] 8問スプリント完走
- [ ] 即時採点・ハプティクス
- [ ] ○×・ここだけ覚える・詳細解説
- [ ] 中断→続きから
- [ ] 苦手3連続正解で解除
- [ ] 学習記録永続化
- [ ] JSON書き出し→iOS共有シート
- [ ] アプリ再起動後も履歴保持
- [ ] 機内モードでも教材利用可能
- [ ] レイアウト崩れなし

この実機確認をPASSするまでApp Store本審査へ進めない。
