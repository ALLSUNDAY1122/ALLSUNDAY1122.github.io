# Release Checklist - 第一種衛生管理者

更新: 2026-09-13

> このファイルに残っていた「132問」「App Store Connect App未作成」「買い切り980円」は旧工程の履歴であり、現行Release判定には使用しない。現行の申請自動化 `scripts/app2_005_hm1_prepare_submit.py` は App ID `6799581662` / Bundle ID `jp.allsunday1122.healthmanager1`、独自作問264問、月額200円、買い切り800円を正本契約としている。以下は現行HEADを再検証してからのみPASS化する。

## 1. 教材・学習契約
- [ ] 全264問を現行HEADから機械監査
- [ ] 公表回対応3セット + 追加演習3セットを確認
- [ ] 1セット44問、関係法令・労働衛生・労働生理の構成を確認
- [ ] 今日のスプリント4/8/16問を確認
- [ ] 回答→解説→進捗→苦手復習→再挑戦の学習循環をPreflightで確認
- [ ] 中断・続きから再開を確認
- [ ] 苦手登録・解除条件を確認
- [ ] 問題本文・正答・解説・意味的重複・出典・法令基準日を再監査

## 2. StoreKit / Premium
- [x] 月額Product ID `jp.allsunday1122.healthmanager1.monthly`
- [x] 買い切りProduct ID `jp.allsunday1122.healthmanager1.lifetime`
- [ ] currentEntitlements / Transaction.updates / 購入 / 復元 / revocationを現HEADで再監査
- [ ] 月額200円のfresh ASC read-back
- [ ] 対象者7日無料トライアルのfresh ASC read-back
- [ ] 買い切り800円のfresh ASC read-back
- [ ] 月額・買い切りReview Screenshotのfresh ASC read-back
- [ ] Sandbox購入・復元・失効は新Release BuildのHuman Testで確認

## 3. App Store Connect / Release identity
- [x] App ID `6799581662`
- [x] Bundle ID `jp.allsunday1122.healthmanager1`
- [ ] Version stateをfresh ASC read-back
- [ ] 現行Release Buildをfresh ASC read-back
- [ ] 現HEADとの差分0を確認
- [ ] 新Buildが必要な場合はAI Preflight / Visual Gate後に生成
- [ ] Build `VALID / APP_STORE_ELIGIBLE / expired=false`をread-back
- [ ] App Store VersionへのBuild紐付けをread-back
- [ ] Internal TestFlight対象をread-back
- [ ] App Store本審査自動提出OFFを確認

## 4. Metadata / 法令・権利
- [x] 現行Store原稿は独自作問264問として記述
- [x] 「公表回対応」とし、公式過去問そのものと誤認させない
- [x] 非公式アプリであることを明記
- [x] Support / Privacy URLを申請自動化で固定
- [ ] Support / Privacy URLの公開到達性をfresh確認
- [ ] Primary Category / 年齢評価をfresh ASC read-back
- [ ] App Store screenshotをVisual Gateで確認
- [ ] Review Detailと実製品UIの価格・機能説明を一致確認

## 5. AI Preflight / Visual Gate
- [ ] P0=0
- [ ] P1=0
- [ ] 主要Journey未確認=0
- [ ] 既知表示欠落=0
- [ ] Learning Acceptance Contract PASS
- [ ] StoreKit Regression Gate PASS
- [ ] Visual Gate PASS
- [ ] Release drift Gate PASS

## 6. Human Gate
AI Preflight / Visual Gate / Release Gateを通過した新Release Buildのみ人間確認へ渡す。

- [ ] 起動クラッシュなし
- [ ] 主要学習Journey完走
- [ ] 中断復帰
- [ ] 学習履歴保持
- [ ] 月額購入 / Trial表示 / 買い切り / 復元 / 失効
- [ ] 実機レイアウト崩れなし
- [ ] Submit for Review直前のユーザー最終承認

Human Testで不具合が出た場合は対象箇所だけを直さず、Root Cause分類→同種全探索→横断修正→Human Defect LibraryへRegression Rule追加→Preflight再実行を行う。
