# RELEASE_CHECKLIST｜第二種衛生管理者｜学びスプリント

更新: 2026-09-16

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
- [x] 総合60%以上 + 全3科目40%以上の合格判定
- [x] 回答タップで即時採点
- [x] ○×、ここだけ覚える、詳細解説
- [x] 中断→続きから再開
- [x] 苦手登録→3連続正解で卒業
- [x] 学習履歴・正答率・ヒートマップ
- [x] JSONバックアップ
- [x] StoreKit entitlement更新時に全画面再描画ループを起こさない部分更新方式

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
- [x] ユーザー承認済みAppIconを唯一のrelease sourceとして固定
- [x] approved icon transport SHA-256 `4cefe840198dde91fddb6c5fe0fdece7d41a8bebfed415eb034752491cd7977c`
- [x] placeholder iconへのfallback禁止
- [x] 1024/120/152/167/180pxを承認sourceから生成・寸法検査
- [ ] **現HEADを含む新Release Buildを生成する**

## 5. Privacy・通信
- [x] アカウントなし
- [x] 広告SDKなし
- [x] 解析SDKなし
- [x] クラッシュ解析SDKなし
- [x] 位置情報/カメラ/マイク/写真/連絡先なし
- [x] 学習データは端末内保存
- [x] Support/Privacy公開ページあり
- [ ] 新Release BuildのPrivacy Manifest/SDKを再確認する

## 6. Codemagic / App Store Connect / Internal TestFlight
過去のBuild 16は2026-08-19時点のrelease evidenceとしてのみ保持する。現HEADの製品差分を含まないためRelease候補に戻さない。

### Historical evidence: Build 16
- [x] Codemagic App ID `6a769d81a1add9d06020b524` API解決
- [x] Workflow `health-manager-2-ios`
- [x] Codemagic Build ID `6a842f4fb381e0b3a3e7a246`
- [x] Build index 16 finished
- [x] Distribution signing
- [x] IPA archive/export
- [x] App Store Connect upload
- [x] Apple Build ID `b53250d3-e005-4da4-bbc0-319c86a321ee`
- [x] Build 16 `VALID`（当時）
- [x] Build 16 `APP_STORE_ELIGIBLE`（当時）
- [x] 非免除暗号化なし
- [x] App Store Version 1.0へBuild 16紐付け read-back（当時）
- [x] Internal Testingグループ `sun` のbuild一覧にBuild 16をread-back（当時）
- [x] App Store本審査自動提出OFF

### Current release candidate
- [x] AI Preflight PASS — run `35096193594`, source head `ed0cd9dea290ac15b103137a79001fc0b1114885`
- [x] Learning Acceptance Contract PASS
- [x] StoreKit UI Regression Gate PASS
- [ ] Visual Gate PASS
- [ ] current HEADを含む新Build生成
- [ ] 新Build `VALID / APP_STORE_ELIGIBLE / expired=false` read-back
- [ ] App Store Version 1.0への新Build紐付け read-back
- [ ] Internal Testing対象の新Build read-back
- [ ] App Store本審査自動提出OFF再確認

## 7. Release Build失効監査
旧記録「Build 16生成commit `f29557c61f7898707f513dc1c1385baa6a6c87c2` 以降、製品差分なし」は失効した。

2026-09-13時点で少なくとも `apps/sanitary-manager-2/gm2.js` / `gm3.js` / `gm4.js` 等に製品差分が存在し、30問模試・合格判定・StoreKit UI更新・学習循環に関わる変更が入っている。このためBuild 16を現行Release GateのPASS根拠として使用しない。

- [x] 旧Build 16のRelease適格性を失効扱いへ変更
- [ ] 新Release Buildのcommit SHAを記録
- [ ] 新Release Build以降の製品差分0を再監査

## 8. 次の人間品質ゲート
人間品質ゲートへ渡すのは、AI Preflight / Visual Gate / Release Gateを通過した**新Release Buildのみ**とする。Build 16では実施しない。

- [ ] 起動クラッシュなし
- [ ] approved AppIcon表示
- [ ] 4タブ表示
- [ ] 10回相当・30セット・300問への導線
- [ ] 30問模試と「総合60%以上 + 全科目40%以上」判定
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
- [ ] Lifetime IAP metadata / availability / price / review screenshotのfresh read-back
- [ ] 新Release Build実機最終確認
- [ ] Submit for Review直前のユーザー最終承認

実機FAIL時は対象品質ループへ戻り、Root Cause分類→同種全探索→横断修正→Regression Rule追加→Preflight再実行を行う。本審査Submitは人間の最終承認前に実行しない。
