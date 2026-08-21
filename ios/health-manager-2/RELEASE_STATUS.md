# RELEASE_STATUS｜第二種衛生管理者｜学びスプリント

更新: 2026-08-21

## 現在地
**300問の試験難易度再監査を実施し、知識なし・一般常識・明らかな消去だけで解ける問題を不合格とする基準へ変更。追加210問を本試験型の近接「項目―内容」5肢判定へ一括変換し、令和7年10月・令和7年4月の労働衛生／労働生理40問を手修正した。合計250問を難易度再構成し、GitHub ActionsのDifficulty Release GateはPASS。**

2026-08-19の課金仕様変更によりBuild 16は最終申請Buildとして失効。StoreKit 2の月額200円＋買い切り800円併売実装はmainへ反映済み。App Store Connect上の商品自体も作成済みで、新署名Buildが必要。

課金後の無料範囲は最新1回相当30問＋今日のスプリント。月額・買い切りは同一のプレミアム権利を付与し、全300問、全30セット、全分野、苦手復習を解放する。月額は継続学習のきっかけ、買い切りは期限なし利用の選択肢として併売する。

## 固定値
- App Store Version: `1.0`
- Product version: `1.0.0`
- Bundle ID: `jp.allsunday1122.healthmanager2`
- iOS: SwiftUI + local WKWebView + StoreKit 2
- Web教材: アプリ内同梱
- 問題数: 300問
- 構成: 10回相当 × 3科目 × 各10問 = 30セット
- 無料範囲: 最新1回相当30問＋今日のスプリント
- Premium: 全300問・全30セット・全分野・苦手復習
- 月額: 200円相当 / Auto-Renewable Subscription
- 買い切り: 800円相当 / Non-Consumable
- 月額 Product ID: `jp.allsunday1122.healthmanager2.monthly`
- 買い切り Product ID: `jp.allsunday1122.healthmanager2.lifetime`
- 価格表示: StoreKit `Product.displayPrice`
- 購入復元: 必須
- 広告/解析/ログイン/クラウド同期: なし

## 300問 Release Gate
- [x] 全300問
- [x] 10回相当 × 3科目 × 各10問
- [x] 全問5択
- [x] 各10問セットで正答位置1〜5を各2回に均等化
- [x] 問題ID重複0
- [x] 高類似・構造・権利・法令基準日の既存監査を維持
- [x] 法令基準日 `2026-08-18`
- [x] 易しすぎる問題を「知識なしで解けるか」の観点で再監査
- [x] 追加210問を `exam-paired-judgment-v1` へ変換
- [x] 令和7年10月 労働衛生10問を本試験型へ手修正
- [x] 令和7年10月 労働生理10問を本試験型へ手修正
- [x] 令和7年4月 労働衛生10問を本試験型へ手修正
- [x] 令和7年4月 労働生理10問を本試験型へ手修正
- [x] 難易度由来情報付き250問をRelease Gateで固定
- [x] `release-questions.json`は難易度変換後の実出題データを再出力
- [x] `DIFFICULTY_GATE_PASS.md`: Total 300 / paired 210 / manual 40 / covered 250 / PASS

## 難易度方針
- 専門知識なしで常識だけから選べる誤答肢を置かない
- 正答だけが長い・具体的・専門的になる選択肢構造を避ける
- 法令は近い人数・期限・閾値・例外条件を比較させる
- 労働衛生は同一領域の指標・管理方法・病態・対策を比較させる
- 労働生理は同じ器官系・ホルモン・機序・作用の近接概念を比較させる
- 追加210問は同じ10問ブロック内の実在用語・実在内容を組み替えた4誤答＋正しい1組で構成し、語感だけで解けないようにする

## approved AppIcon
- [x] ユーザー承認済みArtworkのみをrelease sourceとして使用
- [x] transport SHA-256: `4cefe840198dde91fddb6c5fe0fdece7d41a8bebfed415eb034752491cd7977c`
- [x] placeholder fallback禁止
- [x] 1024 / 120 / 152 / 167 / 180 px生成

## Build 16の扱い
- [x] Codemagic Build 16 finished
- [x] App Store Connect upload
- [x] `VALID / APP_STORE_ELIGIBLE`
- [x] Version 1.0へ紐付け済み
- [x] Internal Testingグループ `sun` で確認済み
- [x] ユーザー実機確認でホーム・問題・学習記録の主要画面に問題なし
- [!] 課金追加および難易度修正により最終申請Buildとして失効

## StoreKit 2実装
- [x] 月額・買い切り2商品を取得する`StoreKitManager`を追加
- [x] verified transactionのみ権利付与
- [x] `Transaction.currentEntitlements`で月額・買い切り双方を確認
- [x] revocationを考慮
- [x] 月額または買い切りのどちらかでPremium解放
- [x] pending / cancelで誤解放しない
- [x] `AppStore.sync()`による購入復元
- [x] 月額のサブスクリプション管理導線
- [x] 価格は`displayPrice`を表示
- [x] WKWebViewとのStoreKit bridgeを追加
- [x] 無料30問 / Premium全300問の導線制御を追加
- [x] 設定画面・Paywallに月額/買い切り/復元を追加

## App Store Connect IAP
- [x] Subscription Group「第二種衛生管理者 プレミアム」作成
- [x] 月額商品作成（Apple商品ID `6802988571`）
- [x] 買い切り商品作成（Apple商品ID `6802989207`）
- [ ] 月額200円相当の価格設定
- [ ] 買い切り800円相当の価格設定
- [ ] 日本語表示名・説明・審査情報・IAPスクリーンショット

## 次工程
1. App Store Connectで月額200円／買い切り800円の価格・日本語メタデータを完成
2. 300問Release Gateを新ソースで再実行
3. 新署名BuildをCodemagicで生成
4. App Store Connect / Internal TestFlightへupload
5. iPhone実機で無料ロック、月額購入、買い切り購入、復元、再起動後権利を確認
6. IAP審査情報・スクリーンショット・Review Detailを整え、本申請へ進む

App Store本審査Submitは最終承認前に実行しない。
