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


## 10. 2026-11-21｜本番申請準備の最新判定（従前チェック欄より優先）

**申請状態：BLOCKED。** 従前の[x]は構造・旧時点の実装確認であり、現行SHAの専門家最終承認・Apple実機適合を意味しない。

- [x] 300問の監査版 SHA-256 `8540991f1a75a9eaa640d695fe7ee1c54dc57861141c5d19514f43311f455fb0` を固定
- [x] 300問・5肢・問題ID、生成決定性、現行価格表示の静的検査を追加
- [x] StoreKit 2にローカライズ済み実価格 `Product.displayPrice` と月額契約期間検証を実装
- [x] 申請前に実名承認・権利・CSV・実スクリーンショット・現行ビルド証跡が足りない場合、停止する安全検査を追加
- [x] 既存`HM2_RELEASE_REVIEW_BLOCKED`を変更せず保持
- [ ] **独立専門家による178問・5肢ずつの最終承認：0/178**
- [ ] **300問の権利・出典の最終判定**
- [ ] Claude側CSV（300ID→最終変更コミット、SHA `a4404d36387f13c39ad13d06f30a437f78f4f5c763ddb1d5c2b31570fc5aed19`）のユーザー承認後取込・実体照合
- [ ] 最新SHAを含む新Codemagic署名ビルド→App Store Connect VALID/対象Version紐付け
- [ ] 現行ビルドのTestFlight・実機・購入／復元／価格の動作検証
- [ ] 実際のアプリ画面から取得した新スクリーンショットと価格表示の検証
- [ ] App Privacy、年齢評価、IAP表示・価格・審査資料のApple側fresh read-back
- [ ] **上記PASS後、提出ビルド固定のうえユーザーが最終承認**

監査スナップショットの再生成PASSはリリース用エクスポートPASSではない。過去のApp Store Build 22は2026-09-25付read-backに存在するが、2026-11-12に確定した300問を含む新候補ではないため本審査に転用しない。現行`project.yml`はiPhone専用設定だが、対象デバイスは新ビルドread-backでも要検証。

詳細・証跡と正しい再開手順：[PRODUCTION_SUBMISSION_READINESS_20261121.md](audit/PRODUCTION_SUBMISSION_READINESS_20261121.md)。
