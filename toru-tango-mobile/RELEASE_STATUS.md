# 撮る単語帳 リリース状況

更新日: 2026-08-19

## 現在の段階

2026-08-19承認済みのUX再設計を実装し、Internal TestFlight用ビルドを再送中。
App Review本審査にはまだ提出しない。

## 正本

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- 実装branch: `feature/on-device-ai-card-generation`
- PR: `#4064`
- iOS app: `toru-tango-mobile/`
- UX仕様書: `toru-tango-mobile/UX_REDESIGN_SPEC_20260819.md`

## リリース識別情報

- App: 撮る単語帳
- Bundle ID: `com.allsunday1122.torutango`
- Version: `1.0.0`
- 現在のbuildNumber: `8`
- EAS project: `@allsunday1122/toru-tango`
- EAS project ID: `96443b56-fef4-4a25-b5e9-831eaa4ec854`
- App Store Connect App ID: `6795968222`
- App Store version: `1.0`
- App Store state: `PREPARE_FOR_SUBMISSION`
- App Review: 未提出

## 2026-08-19 UX再設計

- 起動直後をフォルダ一覧へ変更
- フォルダを2列グリッド表示
- フォルダ名、枚数、進捗、未学習、弱点を一覧表示
- 空フォルダの作成・永続保存
- フォルダ検索
- フォルダ内で表/裏を同じカード行に同時表示
- カード検索
- 未学習 / 苦手 / 表示中 / 非表示フィルター
- 更新順 / 新しい順 / 弱点順 / 問題順ソート
- カードの表示/非表示を永続化
- 表/裏の個別読み上げ
- 一覧から直接編集・削除
- UIをティール系へ統一

## 読み上げ学習

- 表→裏 / 裏→表
- 通常順 / ランダム
- 表示中 / 全カード
- 全カード / 弱点 / 定期確認 / 確認不要 / 未学習
- 音声ON/OFF
- 全文読み上げON時は表と裏を連続読み上げ
- 読み上げ完了後の自動送り: オフ / 1秒 / 2秒 / 3秒 / 5秒
- 既定値: 3秒
- 手動操作・画面離脱で音声と待機タイマーを停止
- 自動送りのみでは学習履歴を変更しない

## データ互換

- `Card.isHidden?: boolean` を後方互換で追加
- 明示的フォルダ名を別AsyncStorageキーで保存
- Backup version 1を維持
- 旧Backup version 1を復元可能
- 新バックアップでは任意の `decks` を保持

## OCR / 作問

- Apple Vision OCR
- 写真撮影 / 写真選択
- OCR編集 / 再撮影
- Foundation Modelsによる端末内作問
- Foundation Models非対応時の端末内決定的フォールバック
- Gemini OCR / Gemini作問は外部送信前確認を維持
- 候補編集・選択・削除・保存

## 最新自動検査

対象HEAD: `b3d2876d8704155731d0f25ebaa60164c53a2de2`

Toru Tango Mobile CI:
- Run: `32231050357`
- Run number: `248`
- Result: `success`

PASS:
- dependency install
- TypeScript
- ESLint
- Expo Doctor
- Expo config
- Web semantic generator regressions
- Mobile OCR-aware generator regressions
- Native OCR module / Expo autolinking
- Expo iOS prebuild
- Worker syntax / API tests

## App Store Connect実確認

2026-08-19 17:01〜17:05 JSTにRelease API Command BusからApp Store Connectを読み取り専用で確認。

確認結果:
- App ID `6795968222` = 撮る単語帳
- Bundle ID = `com.allsunday1122.torutango`
- Build 1〜6はすべて `VALID`
- Build 7は未到達
- App Store version `1.0` は `PREPARE_FOR_SUBMISSION`

Build 7未到達を受け、2026-08-19 17:07 JSTにbuildNumberを`8`へ更新してEAS production workflowを再発火した。
Build 7が遅れて到達してもBuild 8と番号衝突しない。

## 次工程

1. App Store ConnectでBuild 8到達をread-back
2. Build 8のprocessingStateが`VALID`であることを確認
3. Internal TestFlightでiPhone実機QA
   - フォルダ作成・再起動後保持
   - フォルダ一覧→カード一覧
   - 表/裏の視認性と編集
   - 表示/非表示と出題範囲
   - 全文読み上げ→読み上げ完了→3秒→次カード
   - 手動操作時の音声/タイマー停止
   - OCR→作問→保存→フォルダ表示
   - バックアップ/復元
4. P0/P1が0件なら申請資料を最終化
5. App Review本提出はユーザー承認後に実施

## 禁止

- Build 6以前を今回の最終候補として扱わない
- TestFlight実機QA前にApp Reviewへ提出しない
- Bundle ID / App Store Connect App IDを変更しない
- Secret値をコード、Markdown、Issue、PRコメントへ保存しない
