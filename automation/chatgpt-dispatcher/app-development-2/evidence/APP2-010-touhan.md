# APP2-010｜登録販売者｜App record反映とTestFlight準備

- Worker: `TOUHAN`
- Session: `登録販売者③`
- Result: `HUMAN_REQUIRED`
- Date: `2026-08-20 JST`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App Store review submission: **NOT PERFORMED / PROHIBITED**
- External TestFlight Beta Review: **NOT PERFORMED / PROHIBITED**

## 1. 正本識別情報

- Bundle ID: `com.allsunday1122.tourokuhanbaisha`
- App Store Connect App ID: `6802119268`
- Apple Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- Codemagic app id: `6a769d81a1add9d06020b524`
- Codemagic workflow: `touhan-ios`
- Codemagic profile ref: `tourokuhanbaisha_appstore`
- Apple Distribution certificate: `K2A3VCP583`
- App Store provisioning profile: `7B328C2DU4` / ACTIVE

## 2. 品質ゲート

- canonical question bank: 3試験回 × 120問 = 360問 PASS
- 各回分野配分: 20 / 20 / 40 / 20 / 20 PASS
- history calendar regression: PASS
- AppIcon SHA-256: `c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03`
- Privacy Manifest / Bundle ID / Team ID / XcodeGen / release validator: PASS
- 2026-08-15 Safari実機受入: PASS

## 3. 署名基盤

旧Codemagic signing identity不足は自動整備で解消済み。

- secure variable group: `app2_010_touhan_signing`
- `CERTIFICATE_PRIVATE_KEY`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_ISSUER_ID`
- secret値はGitHub / Notion / chatへ保存していない。
- 共有certificate `MLDDAKTU69` は変更していない。

## 4. Build #9 Apple validation修正

Build #9はApple validation `90474` で失敗し、TestFlight Build resourceにはならなかった。

原因:
- generated Info.plist の `UISupportedInterfaceOrientations` 不足。

修正:
- iPhone向け4方向をXcodeGen設定へ追加。
- release validatorに同設定を必須gate化。

main commits:
- `592951fcc391e9e7a667b437c409e59234321315`
- `6c425010c8cf0cee895c05695a48fdc4d334fec6`

## 5. Codemagic Build #10

- request: `app2-010-touhan-build-orientation-fix-20260820-0624`
- Codemagic build id: `6a861f2e68c24c24844d3f66`
- build index / CFBundleVersion: `10`
- version: `1.0.0`
- result: `finished`
- artifact: `TouhanSprint.ipa`

PASS:
- release input audit
- history calendar regression
- AppIcon SHA gate
- XcodeGen generation
- native verification
- signing keychain / certificate / profile
- signed IPA build
- App Store Connect direct upload

Apple ContentDelivery evidence:
- `automation/codemagic-results/app2-010-upload-log-build10-20260820-0637.json`
- `automation/codemagic-results/app2-010-upload-log-build10-20260820-0637.txt`
- `UPLOAD SUCCEEDED with no errors`
- Delivery UUID: `d59a0d3d-5aeb-455d-ba9a-cfb193b9a84c`

## 6. App Store Connect Build監査

request:
`app2-010-internal-audit-20260820-2005`

evidence:
`automation/asc-results/app2-010-internal-audit-20260820-2005.json`

実状態:
- App Store Connect上の登録販売者Buildは **Build #10のみ**。
- Build #4〜#8はApple TestFlight Buildとして成立していない。
- Build #9はApple validation失敗で成立していない。
- Build #10:
  - `processingState = VALID`
  - `buildAudienceType = INTERNAL_ONLY`
  - initial `internalBuildState = MISSING_EXPORT_COMPLIANCE`

したがって「別BuildがTestFlightへ配布されている」状態ではない。

## 7. Export Compliance解消

ネイティブsourceを再監査し、`SwiftUI / WebKit / UIKit` のみで独自暗号化・CryptoKit/CommonCrypto等を使用していないことを確認。Web通信はOS/WebKitのHTTPS機能のみ。

AppleのBuild #10へApp Store Connect APIで:
- `usesNonExemptEncryption: null → false`
- HTTP 200

を反映した。

結果:
- `MISSING_EXPORT_COMPLIANCE → READY_FOR_BETA_TESTING`

future build再発防止:
- `project.yml`: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO`
- `validate_release.py`: 同キー必須gate

main commits:
- `4bd269d8f40cd7bf98bdd90545fe916a428b6b27`
- `a4b82058627e50f003c8e4580bc96ff6e1165454`

evidence:
`automation/asc-results/app2-010-compliance-route-20260820-2010.json`

## 8. Internal TestFlight routing / tester

Internal group:
- name: `sum`
- `isInternalGroup = true`
- `hasAccessToAllBuilds = true`
- tester count: `1`

Build #10は上記groupの自動配布対象となり、read-backで:
- `assigned_after = true`
- `internalBuildState = READY_FOR_BETA_TESTING`

その後の最終read-back:
- `internalBuildState = IN_BETA_TESTING`
- tester state: `INVITED`
- App Store review submitted: `false`
- External Beta Review submitted: `false`

evidence:
- `automation/asc-results/app2-010-compliance-route-20260820-2010.json`
- `automation/asc-results/app2-010-invite2-20260820-2016.json`

## 9. 残る真正な人間gate

Internal TestFlight配布は完了。残件はiPhoneでしか判定できない実機受入のみ。

1. Apple公式TestFlightアプリをiPhoneへインストール。
2. 登録販売者の内部テスト招待を承諾。
3. `1.0.0 (10)` をインストール。
4. 起動して白画面・クラッシュがないことを確認。
5. 12問スプリント開始、回答→解説→次問を確認。
6. 途中終了→再開を確認。
7. 履歴カレンダーの当日回答・完了履歴を確認。

実機PASS後に次工程を再監査する。**App Store本審査submit/releaseはこのTaskでは実行しない。**

## 10. 最終判定

`HUMAN_REQUIRED`

理由: 自動化可能なBuild、署名、Apple upload、processing、export compliance、Internal TestFlight group routing、tester invitationまで完了。残件はiPhone/TestFlight実機受入のみ。
