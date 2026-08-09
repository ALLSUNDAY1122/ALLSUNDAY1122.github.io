# 危険物乙4｜標準手順 v2.2 / 申請手順 リリースチェック

更新: 2026-08-09

## A. 受入・専門監査
- [x] 360問コンテンツ監査: 360 / 法令144 / 物化96 / 性消120
- [x] 完全重複 0
- [x] learningObjective重複 0
- [x] 解説パッケージ重複 0
- [x] anti-padding 0
- [x] 法令基準日と監査日を分離
- [x] 公式過去問本文の転載をしない方針
- [x] regulation watcher対象へ乙4一次資料を追加
- [x] StoreKit 2: 購入、currentEntitlements、Transaction.updates、復元導線
- [x] 未検証取引でPremiumを解放しない

## B. UI正本 v2.1
- [x] 標準8問、4/8/16問設定
- [x] ホーム / 模試 / 記録 / 設定
- [x] 生成り紙面、藍、朱、緑、金のデザイントークン
- [x] 問題・結果の明朝系主見出し
- [x] 28pxグリッド背景
- [x] 82px進捗リング
- [x] ○/×の朱色オーバーレイ
- [x] 「ここだけ覚える」黄色ブロック
- [x] 苦手3連続正解解除
- [x] 続きから再開
- [x] 記録: 達成度 / 分野別 / 5週間ヒートマップ / 苦手
- [x] JSONバックアップ/復元
- [x] 試験日と残日数
- [x] 模擬試験3回、各35問・120分、15/10/10、3セット相互重複なし
- [x] 模試中は即時正誤を出さない
- [x] 模試タイマーはstartedAt基準で中断後も戻らない

## C. 反復品質ループ
- [x] 辛口レビュー1: 模試120分タイマー欠落を発見→修正
- [x] 辛口レビュー2: 試験日までの必要ペース算出に必要なユニーク既出数が未保持→seenIDsを追加
- [x] 辛口レビュー3: Xcode build成功でもJSON/Privacy Manifestがapp bundleに入らないことを検出→Xcode resource phaseへ移行
- [ ] 最終CIで Content Audit / Native Typecheck / Xcode Release Simulator Build の3本すべてPASS

## D. 申請ファイル
- [x] Info.plist
- [x] PrivacyInfo.xcprivacy
- [x] App Store日本語メタデータ案
- [x] Review Notes案
- [x] Support pageソース
- [x] Privacy Policyソース
- [ ] 1024x1024 App Store icon最終版
- [ ] App Store screenshot最終版（TestFlight実機から取得を優先）
- [ ] 公開Support/Privacy URL HTTP 200確認（main反映後）

## E. App Store Connect / 課金
- [ ] Explicit App ID / Bundle ID `jp.allsunday1122.otsu4` の登録確認
- [ ] App Store Connectアプリレコード作成
- [ ] Apple ID記録
- [ ] 非消耗型IAP `jp.allsunday1122.otsu4.premium` 作成
- [ ] IAP価格最終設定
- [ ] Paid Apps Agreement等、必要契約の有効状態確認
- [ ] App Privacy回答を実装と再照合
- [ ] 年齢区分回答

## F. Codemagic / TestFlight
- [ ] codemagic.yamlを現行公式仕様に合わせて固定
- [ ] App Store Connect API key / signing資格情報をCodemagicへ設定（秘密情報はGitHubへ置かない）
- [ ] 無料ビルド枠残量を確認
- [ ] 署名付きArchive / IPA
- [ ] Validate
- [ ] `submit_to_testflight: true`
- [ ] `submit_to_app_store: false`
- [ ] TestFlight内部テストへ反映

## G. 人間チェックポイント
- [ ] iPhone実機でTestFlightを確認
- [ ] 購入成功
- [ ] 購入キャンセル
- [ ] pending
- [ ] 購入復元
- [ ] 再インストール後のentitlement
- [ ] 8問学習 / 苦手 / 3模試 / 記録 / 設定
- [ ] 大きい文字で切れ・重なり・横スクロールなし
- [ ] 最終スクリーンショット承認
- [ ] App Store最終提出をユーザーが承認

## STOP条件
App Store本番審査への自動提出は禁止。ユーザーの最終承認前は `submit_to_app_store: false` を維持する。
