# AI引継ぎ帳 v0.6 iOS提出前静的監査

作成日：2026年7月24日

## 監査結果

修正前のBuild 6は`UIDeviceFamily = [1, 2]`で、iPhoneとiPadの両方へ対応する設定だった。現在準備済みのApp Store画像はiPhone 6.9インチ用5枚のみで、iPad実機・レイアウト・スクリーンショットは未検証である。

初回版は以下へ修正する。

- Device Family：iPhoneのみ
- 対応方向：Portraitのみ
- App-level Privacy Manifest：追加
- 最終Privacy Report：署名ArchiveからXcode Organizerで生成

## 合格済み

- Bundle ID：`jp.allsunday.aihandoverlog`
- Version：`0.6.0`
- Build：`6`
- Minimum iOS：`13.0`
- Architecture：arm64
- `ITSAppUsesNonExemptEncryption=false`
- App Icon：必要寸法一致、alphaなし
- 追加Capability／Entitlementなし
- カメラ、写真、マイク、位置情報などの権限要求なし
- Flutter、file_picker、share_plus等のPrivacy ManifestをArchive内で確認

## 追加ファイル

- `scripts/harden_v06_ios_submission.py`
- `scripts/macincloud_testflight_submission.sh`
- `.github/workflows/ai-handover-log-v06-submission-hardening.yml`

## 旧Archive

既存の署名なしArchiveは次の理由でアップロード禁止。

- Apple署名なし
- Device FamilyがiPhone＋iPad
- 横画面対応のまま
- App-level Privacy Manifest追加前

## 新Archiveの提出条件

- Xcode 16以降
- UIDeviceFamily `[1]`
- Portraitのみ
- Runner.app直下に`PrivacyInfo.xcprivacy`
- 全Privacy Manifestが`plutil -lint`合格
- Generate Privacy ReportでTrackingなし、Collected Dataなし
- Validate Appでエラー0件
- TestFlight & App StoreへUpload
