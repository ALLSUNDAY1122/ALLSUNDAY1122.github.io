# AI引継ぎ帳 v0.6 提出成果物ポリシー

作成日：2026年7月24日

## App Store Connectへアップロードしてよいもの

次の条件をすべて満たす、Apple署名付きの新規Archiveだけを使用する。

- Hardened v0.6ソースから作成
- Bundle ID `jp.allsunday.aihandoverlog`
- Version `0.6.0`
- Build `6`（未使用の場合）
- `UIDeviceFamily = [1]`
- Portraitのみ
- Runner.app直下に`PrivacyInfo.xcprivacy`
- Xcode OrganizerのPrivacy ReportでTrackingなし・Collected Dataなし
- Validate Appでエラー0件

## アップロード禁止

次の既存成果物は検証用であり、アップロードしない。

- `ai-handover-log-v06-final-30018698596`
- `AI_Handover_Log_v0.6_iPhone_Unsigned_Release_Runner.app.zip`
- `AI_Handover_Log_v0.6_Unsigned.xcarchive.zip`
- `AI_Handover_Log_v0.6_TestFlight_Handoff_Package.zip`内の旧バイナリ

禁止理由：

- Apple署名なし
- 修正前はiPhone＋iPad対応
- 修正前は横画面対応
- App-level Privacy Manifest追加前

## MacinCloudで使用する入口

`macincloud_testflight_submission.sh`を使用する。

このスクリプトは提出前ハードニングを適用し、署名Archive作成後にDevice Family、画面方向、Privacy Manifestを検査する。
