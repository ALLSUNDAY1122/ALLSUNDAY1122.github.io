# RELEASE_STATUS｜第二種衛生管理者｜学びスプリント

更新: 2026-08-19

## 現在地
**2026-08-19 15:51 JST、ユーザー指示で課金を「月額200円＋買い切り800円」の併売へ正式変更した。Build 16は300問・UI・AppIconの実機確認済みだが、課金なしbinaryのため最終申請Buildとしては失効。StoreKit 2実装をmainへ反映済みで、新署名Buildが必要。**

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
- Product ID候補: `jp.allsunday1122.healthmanager2.monthly` / `jp.allsunday1122.healthmanager2.lifetime`。App Store Connect作成後の実登録値を最終正本とする
- 価格表示: StoreKit `Product.displayPrice`
- 購入復元: 必須
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
- [x] 追加210問は公開候補＋内容監査済み
- [x] 法令基準日 `2026-08-18`

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
- [!] 2026-08-19の課金仕様変更により最終申請Buildとして失効

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

## 次工程
1. App Store Connectで月額200円相当のAuto-Renewable Subscriptionを作成
2. App Store Connectで買い切り800円相当のNon-Consumableを作成
3. Product IDをread-backし、GitHub/Notionの実装値と一致確認
4. Release Gate再実行
5. 新署名BuildをCodemagicで生成
6. App Store Connect / Internal TestFlightへupload
7. iPhone実機で無料ロック、月額購入、買い切り購入、復元、再起動後権利を確認
8. IAP審査情報・スクリーンショット・Review Detailを整え、本申請へ進む

App Store本審査Submitは最終承認前に実行しない。
