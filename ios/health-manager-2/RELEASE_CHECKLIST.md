# RELEASE_CHECKLIST｜第二種衛生管理者｜学びスプリント

更新: 2026-08-19

## 1. 教材・構造
- [x] 全300問
- [x] 10回相当 × 3科目 = 30セット
- [x] 各セット10問
- [x] 全問5択
- [x] 問題ID重複0
- [x] 問題本文の完全一致を禁止
- [x] 高類似0.90以上を機械監査
- [x] 追加210問を独自作問・独自解説として監査
- [x] 各10問セットで正答位置1〜5を各2回に均等化
- [x] 一文ポイント・解説・一次根拠・基準日・作問由来・権利根拠を保持
- [x] Codemagicビルド前に `export-audit-data.cjs` と `validate_questions.py` を実行

## 2. 法令・権利
- [x] 公表問題は論点・傾向確認に限定
- [x] 公開用の問題文・選択肢・解説は独自作成
- [x] 現行法と将来施行を分離
- [x] 法令基準日: 2026-08-18
- [x] 2026-08-01施行の産業医関連改正を反映
- [x] 2025-06-01施行の職場の熱中症対策を反映
- [x] 高リスク法令数値をRelease Gateへ固定
- [x] 「5年分の過去問」「過去問300問」と誤認させるStore表現を禁止

## 3. UI・学習ロジック
- [x] Golden Master v2.1準拠
- [x] 標準8問、設定4/8/16問
- [x] ホーム/模試/記録/設定の4タブ
- [x] 10回相当・30セットをデータ駆動表示
- [x] 30問模試
- [x] 科目別40%判定
- [x] 回答タップで即時採点
- [x] ○×、ここだけ覚える、詳細解説
- [x] 中断→続きから再開
- [x] 苦手登録→3連続正解で卒業
- [x] 学習履歴・正答率・ヒートマップ
- [x] JSONバックアップ

## 4. iOS製品化 / AppIcon
- [x] SwiftUI + WKWebView
- [x] 300問Web教材をアプリ内へ完全同梱
- [x] 外部Webサイトを主要教材として読み込まない
- [x] ネイティブJSON共有シート
- [x] 正解/不正解/ボタン操作のネイティブハプティクス
- [x] PrivacyInfo.xcprivacy
- [x] iPhone portrait
- [x] Bundle ID `jp.allsunday1122.healthmanager2`
- [x] Version `1.0.0`
- [x] Current release Build `16`
- [x] ユーザー承認済みAppIconを唯一のrelease sourceとして固定
- [x] approved icon transport SHA-256 `4cefe840198dde91fddb6c5fe0fdece7d41a8bebfed415eb034752491cd7977c`
- [x] placeholder iconへのfallback禁止
- [x] 1024/120/152/167/180pxを承認sourceから生成・寸法検査

## 5. Privacy・通信
- [x] アカウントなし
- [x] 広告SDKなし
- [x] 解析SDKなし
- [x] クラッシュ解析SDKなし
- [x] 位置情報/カメラ/マイク/写真/連絡先なし
- [x] 学習データは端末内保存
- [x] Support/Privacy公開ページあり
- [x] App Store本審査前に実ビルドのPrivacy Manifest/SDKを再確認する

## 6. Codemagic / App Store Connect / Internal TestFlight
- [x] Codemagic App ID `6a769d81a1add9d06020b524` API解決
- [x] Workflow `health-manager-2-ios`
- [x] Codemagic Build ID `6a842f4fb381e0b3a3e7a246`
- [x] Build index 16 finished
- [x] Distribution signing
- [x] IPA archive/export
- [x] App Store Connect upload
- [x] Apple Build ID `b53250d3-e005-4da4-bbc0-319c86a321ee`
- [x] Build 16 `VALID`
- [x] Build 16 `APP_STORE_ELIGIBLE`
- [x] 非免除暗号化なし
- [x] App Store Version 1.0へBuild 16紐付け read-back
- [x] Internal Testingグループ `sun` のbuild一覧にBuild 16をread-back
- [x] App Store本審査自動提出OFF
- [x] 旧Build 1は履歴として維持し、現行release Buildへ戻さない

## 7. Build 16後の失効監査
- [x] Build 16生成commit `f29557c61f7898707f513dc1c1385baa6a6c87c2` 以降、第二種の問題バンク・UI・approved AppIcon sourceに変更なし
- [x] したがって300問/アイコン/Build 16のPASSを失効させる製品差分なし

## 8. 次の人間品質ゲート
Build 16をiPhone実機で確認する。
- [ ] 起動クラッシュなし
- [ ] approved AppIcon表示
- [ ] 4タブ表示
- [ ] 10回相当・30セット・300問への導線
- [ ] 30問模試と科目別40%判定
- [ ] 8問スプリント完走
- [ ] 即時採点・ハプティクス
- [ ] 中断再開
- [ ] 苦手3連続解除
- [ ] 再起動後の履歴保持
- [ ] JSON書き出し共有
- [ ] 機内モード学習
- [ ] レイアウト崩れなし

## 9. 本審査前の残作業
- [ ] Primary Category / 年齢評価
- [ ] App Storeスクリーンショット
- [ ] Review Detail（第二種固有価値とGuideline 4.3(a)対策）
- [ ] Build 16実機最終確認
- [ ] Submit for Review直前のユーザー最終承認

実機FAIL時は対象品質ループへ戻り、修正後にBuild番号を上げて再配布する。本審査Submitは人間の最終承認前に実行しない。
