# RELEASE_CHECKLIST｜第二種衛生管理者｜学びスプリント

更新: 2026-08-09

## 1. 教材・構造
- [x] 全90問
- [x] 3試験回 × 3科目 = 9セット
- [x] 各セット10問
- [x] 全問5択
- [x] 問題ID重複0
- [x] 問題本文の完全一致0
- [x] 高類似0.90以上0
- [x] 数値だけを変えた水増し問題を再設計
- [x] 各10問セットで正答位置1〜5を各2回に均等化
- [x] 一文ポイント・解説・根拠・基準日・作問由来・権利根拠を保持
- [x] Codemagicビルド前に共通 `validate_questions.py` を自動実行

## 2. 法令・権利
- [x] 公表問題は論点確認に限定
- [x] 公開用の問題文・選択肢・解説は独自作成
- [x] 現行法と将来施行を分離
- [x] 法令基準日: 2026-08-09
- [x] 2026-08-01施行の産業医関連改正を反映
- [x] 2025-06-01施行の職場の熱中症対策を反映
- [x] 2027-04-01予定の健診改正を現行法として扱わない
- [x] 2028-04-01予定の50人未満ストレスチェック義務化を現行法として扱わない

## 3. UI・学習ロジック
- [x] Golden Master v2.1準拠
- [x] ユーザーSafari確認済み
- [x] 標準8問、設定4/8/16問
- [x] ホーム/模試/記録/設定の4タブ
- [x] 9セットを模試タブに配置
- [x] 回答タップで即時採点
- [x] ○×、ここだけ覚える、詳細解説
- [x] 中断→続きから再開
- [x] 苦手登録→3連続正解で卒業
- [x] 学習履歴・正答率・ヒートマップ
- [x] JSONバックアップ

## 4. iOS製品化
- [x] SwiftUI + WKWebView
- [x] Web教材をアプリ内へ完全同梱
- [x] 外部Webサイトを主要教材として読み込まない
- [x] ネイティブJSON共有シート
- [x] 正解/不正解/ボタン操作のネイティブハプティクス
- [x] PrivacyInfo.xcprivacy
- [x] 1024px AppIconをビルド時生成
- [x] iPhone portrait
- [x] Bundle ID `jp.allsunday1122.healthmanager2`
- [x] Version `1.0.0`, Build `1`

## 5. Privacy・通信
- [x] アカウントなし
- [x] 広告SDKなし
- [x] 解析SDKなし
- [x] クラッシュ解析SDKなし
- [x] 位置情報/カメラ/マイク/写真/連絡先なし
- [x] 学習データは端末内保存
- [x] Support/Privacy公開ページあり
- [x] App Store本審査前に実ビルドのPrivacy Manifest/SDKを再確認する

## 6. Codemagic/TestFlight
- [x] XcodeGen project.yml
- [x] Codemagic workflow
- [x] 学習問題のビルド前監査
- [x] iOS同梱ファイル存在検査
- [x] App Store distribution signing設定
- [x] TestFlight Internal Testing Only export option
- [x] `submit_to_testflight: false`（Internal Testing OnlyのためBeta App Reviewへ自動提出しない）
- [x] `submit_to_app_store: false`
- [ ] Apple Developer Explicit App ID登録
- [ ] App Store Connectアプリ作成
- [ ] Codemagic App Store Connect integration確認
- [ ] Distribution signing取得
- [ ] Build 1成功
- [ ] App Store Connect/TestFlightへBuild 1アップロード・処理完了

## 7. 次の人間品質ゲート
Build 1がTestFlightに到達後、iPhone 16で以下を確認する。
- [ ] 起動クラッシュなし
- [ ] 4タブ表示
- [ ] 9セット各10問
- [ ] 8問スプリント完走
- [ ] 即時採点・ハプティクス
- [ ] 中断再開
- [ ] 苦手3連続解除
- [ ] 再起動後の履歴保持
- [ ] JSON書き出し共有
- [ ] 機内モード学習
- [ ] レイアウト崩れなし

実機FAIL時は対象ループを再発火し、Build番号を上げて再配布する。
