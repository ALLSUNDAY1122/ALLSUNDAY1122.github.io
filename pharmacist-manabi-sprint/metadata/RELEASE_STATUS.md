# RELEASE STATUS｜薬剤師国家試験｜学びスプリント

更新：2026-11-05 JST
最終判定：BLOCKED（正式提出は未実行）

## 対象とApple正本
- App ID：6799753724
- Bundle ID：jp.allsunday1122.yakuzaishi
- ソースVersion：1.0.0 / ASC versionString：1.0
- ASC Version ID：430ba445-fae0-4d1d-9301-95d1ea342ac7
- 2026-11-05T03:33:20.678249Z読戻し：PREPARE_FOR_SUBMISSION、reviewSubmissionsは0件
- 最新Apple Build：20261105002905、VALID、INTERNAL_ONLY
- Apple Build ID：0ed211f5-60c9-4fde-adad-3ba16c1601a5
- Codemagic Build ID：6aebcd99f5f3c51e569a2f3e
- 対応ソース：82591fe0174f26df006271cd5ba267c38a8d7735
- 本番APP_STORE_ELIGIBLE新規Build：品質ゲート未通過のため未生成
- 価格：無料 / IAPなし / 1035レコード・採点対象1031問・除外4問

## 品質判定
|Gate|判定|理由|
|---|---|---|
|Q0|BLOCKED|第三者4問の権利、法令107候補の時点照合、旧B7との対応証跡が未完了|
|Q1|FAIL|全問の内容監査、画像154問の最終目視監査が未完了|
|Q2|FAIL|画像問題の汎用的な解説が残る。問220の反応選択の根拠説明が不足|
|Q3|NOT_TESTED|今回の修正候補に対する全機能・実機の最終動作確認は未実施|
|Q4|BLOCKED|独立内容レビューと全機能の実機受入証跡が不足|
|Q5|BLOCKED|上記未解決事項と本番対象バイナリ未生成|

## 今回の修正
- 問220の旧処方表記画像を参照から除去。訂正済み共通文と反応・選択肢画像を残す。
- メディア再生成とnative教材生成に回帰防止チェックを追加。
- 問220・221の公式訂正URL、P110-140の現行環境基準URLを教材生成へ追加。
- 古いBuild 5指定とStoreKit課金に関する記載を更新。
- ソース修正は最新の内部TestFlightバイナリへ未反映。再配信確認済みとは扱わない。

## 検証の範囲
ローカルの構造検証と教材生成は成功。1035レコード、採点1031、除外4、特殊採点3、画像154問、同梱画像290件を確認し、問220の旧画像は新規生成先に存在しない。正答・採点条件に差分なし。これは医学・薬学・権利適合の保証ではない。
従前のCodemagic内部テストビルドのXCTest・Release工程成功は旧ソースの証跡であり、今回修正後の署名済みRelease検証ではない。
ユーザーの画面確認と自動テストを全機能の実機受入と混同しない。

## 次工程
内容・権利・法令の独立監査を完了し、Q0〜Q5を再判定する。通過後にpharmacist-iosで新しいAPP_STORE_ELIGIBLEビルドを生成し、VALID・commit・配布区分と実機動作を確認して正式提出する。原則手動リリース。内部専用ビルドや古いBuild 5を流用しない。
詳細は automation/pharmacist-q0-q1-audit/2026-11-05-final-release-audit.md を参照。
