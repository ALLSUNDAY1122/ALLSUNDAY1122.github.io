# APP2-010｜登録販売者｜App record反映とTestFlight準備

- Worker: `TOUHAN`
- Session: `登録販売者③`
- Result: `HUMAN_REQUIRED`
- Date: `2026-08-20 JST`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App Store review submission: **NOT PERFORMED / PROHIBITED**

## 1. 正本識別情報

- Bundle ID: `com.allsunday1122.tourokuhanbaisha`
- App Store Connect App ID: `6802119268`
- Apple Team ID: `MN3D2ZM44N`
- Codemagic profile ref: `tourokuhanbaisha_appstore`
- Version: `1.0.0`
- Codemagic repository app id: `6a769d81a1add9d06020b524`

Notion対象ページ `3b309c10-697d-8184-8b61-ff06ea73eaf7` と識別情報正本 `3b709c10-697d-8138-a352-c422d4dd5c47` はBuild #10実績へ更新済み。

## 2. 品質ゲート

- canonical question bank: 3試験回 × 120問 = 360問 PASS
- 各回分野配分: 20 / 20 / 40 / 20 / 20 PASS
- history calendar regression: completed / same-day inProgress / completed+inProgress / zero-answer exclusion PASS
- 2026-08-15 iPhone Safari受入: PASS
- AppIcon: Drive `登録販売者.png` / 1024x1024
- AppIcon SHA-256: `c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03`
- Privacy Manifest / Bundle ID / Team ID / XcodeGen generation / release validator: PASS

## 3. Apple / Codemagic署名基盤

旧HUMAN_REQUIREDだった署名identity不足は自動整備で解消した。

### Apple Developer

- 新Apple Distribution certificate: `K2A3VCP583`
- registration seller App Store profile: `7B328C2DU4`
- profile name: `tourokuhanbaisha_appstore`
- profile state: `ACTIVE`
- 共有certificate `MLDDAKTU69` は変更していない。
- 旧孤立certificate `27TTVLZ65A` は、AI Handover Logの代替profile `4Z25F68APA` を先に作成・ACTIVE確認した後にのみローテーションした。

### Codemagic

- secure variable group: `app2_010_touhan_signing`
- secure variables:
  - `CERTIFICATE_PRIVATE_KEY`
  - `APP_STORE_CONNECT_PRIVATE_KEY`
  - `APP_STORE_CONNECT_KEY_IDENTIFIER`
  - `APP_STORE_CONNECT_ISSUER_ID`
- secret値はGitHub / Notion / chatへ保存していない。
- signing fetch / certificate import / profile applyはBuild #10で実動PASS。

## 4. Apple validation 90474修正

Build #9はsigned IPA生成後、Apple validationで `90474` を返した。

原因:
- generated Info.plistに `UISupportedInterfaceOrientations` が未指定。

修正:
- `touroku-hanbaisha-ios/native-ios/project.yml` に4方向を追加。
  - `UIInterfaceOrientationPortrait`
  - `UIInterfaceOrientationPortraitUpsideDown`
  - `UIInterfaceOrientationLandscapeLeft`
  - `UIInterfaceOrientationLandscapeRight`
- `touroku-hanbaisha-ios/scripts/validate_release.py` に同設定を必須gateとして追加。

main commits:
- `592951fcc391e9e7a667b437c409e59234321315` — orientation fix
- `6c425010c8cf0cee895c05695a48fdc4d334fec6` — release validator gate

## 5. Codemagic Build #10

- request: `app2-010-touhan-build-orientation-fix-20260820-0624`
- Codemagic build id: `6a861f2e68c24c24844d3f66`
- build index: `10`
- workflow: `touhan-ios`
- version: `1.0.0`
- build number: `10`
- result: `finished`
- IPA: `TouhanSprint.ipa`

PASS actions:
- Install native build tools
- Release input audit
- history calendar regression
- AppIcon SHA gate
- XcodeGen generation
- Bundle/Team/native input verification
- signing keychain initialization
- managed App Store signing files fetch
- Apple Distribution certificate import
- provisioning profile apply
- signed IPA build
- direct App Store Connect upload for Internal TestFlight

Evidence:
- `automation/codemagic-results/app2-010-touhan-build-orientation-fix-20260820-0624.json`

## 6. Apple upload acceptance

Build #10のsanitized ContentDelivery logをCodemagic artifact bundleから回収した。

Evidence:
- `automation/codemagic-results/app2-010-upload-log-build10-20260820-0637.json`
- `automation/codemagic-results/app2-010-upload-log-build10-20260820-0637.txt`

Apple uploader final result:

- `Upload succeeded.`
- `UPLOAD SUCCEEDED with no errors`
- Delivery UUID: `d59a0d3d-5aeb-455d-ba9a-cfb193b9a84c`
- transferred: `131282 bytes`

したがって旧90474は解消し、signed IPAはApp Store Connectへ正常delivery済み。

補助的なApp Store Connect Build resource API read-backはrequest-scoped summaryが本Evidence更新時点で未永続化のため、`processingState` の最新値は推測しない。Apple uploaderの成功ログとCodemagic workflow `finished` をupload成立の証拠とする。

## 7. 残る真正な人間gate

自動化可能な実装・署名・IPA生成・Apple uploadは完了した。残るのはTestFlight処理完了後のiPhone実機受入のみ。

Build 10をInternal TestFlightからiPhoneへインストールして以下を確認する。

1. 起動して白画面・クラッシュがない。
2. 12問スプリントを開始できる。
3. 回答→解説→次問が正常。
4. 途中終了→再開が正常。
5. 履歴カレンダーに当日回答と完了履歴が正しく反映される。

実機PASS後にのみApp Store本申請準備へ進める。**本審査submit/releaseはこのTaskでは実行しない。**

## 8. 最終判定

`HUMAN_REQUIRED`

理由: 旧署名identity gateは解消済み。Build #10はsigned IPA生成とApple uploadまで成功。残件はiPhone/TestFlightでしか判定できない最終実機受入のみ。
