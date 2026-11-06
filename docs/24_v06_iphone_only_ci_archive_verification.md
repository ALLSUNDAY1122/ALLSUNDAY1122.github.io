# AI引継ぎ帳 v0.6 iPhone専用CI・Archive実測検証

検証日：2026年7月24日

## 対象

- Commit: `9d853c00b53d694307c11cfd08553d5f3082459f`
- GitHub Actions Run: `30042923385`
- Artifact ID: `8578508977`
- Artifact: `ai-handover-log-v06-device-release`

## CI結果

- Device Release CI: success
- Flutter 3.44.7
- 自動テスト16件: success
- iPhone実機向けarm64 Release: success
- unsigned generic iOS Archive: success

## Archive実測値

`Runner.app/Info.plist`とPrivacy ManifestをArtifactから展開して解析した。

- Display Name: `AI引継ぎ帳`
- Bundle ID: `jp.allsunday.aihandoverlog`
- Version: `0.6.0`
- Build: `6`
- Minimum iOS: `13.0`
- Architecture: `arm64`
- UIDeviceFamily: `[1]`（iPhone専用）
- Supported Orientation: `UIInterfaceOrientationPortrait`のみ
- iPad Orientation設定: なし
- `ITSAppUsesNonExemptEncryption`: `false`
- App-level `PrivacyInfo.xcprivacy`: あり
- Privacy Manifest総数: 7
- Tracking: すべてfalse
- Tracking Domains: なし
- Collected Data Types: なし

Flutter.frameworkはFile TimestampとSystem Boot Time、SDWebImageはFile TimestampのRequired Reason APIを承認理由付きで宣言している。

## SHA-256

- GitHub Artifact ZIP: `10e5c8ae0bce81cee9c63fe457f626371d5ed9fe7a1f5e1c9f96d8547efac052`
- Unsigned xcarchive ZIP: `d3f29e22f34319922793b3b94a09f6bb5610299f6e860aa1b77cf2dcd8f98565`
- Unsigned Runner.app ZIP: `b85f4729ce39ad310f0a30c8ecde810fd9a9d0b5629faa10f6813dd1c0ba7996`

GitHub Artifact digestとダウンロード後のSHA-256は一致した。

## 判定

iPhone専用化、縦画面固定、Privacy Manifest追加はmacOS/Xcodeで生成された実Archiveへ反映済み。

ただしArchiveはApple署名なしのためApp Store Connectへはアップロードしない。Apple DeveloperのApp ID、App Store Connectのアプリレコード、MacinCloud上のApple署名付き新規Archiveが引き続き必要。
