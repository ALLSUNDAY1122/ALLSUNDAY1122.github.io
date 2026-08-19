# APP2-010｜登録販売者｜App record反映とTestFlight準備

- Worker: `TOUHAN`
- Session: `登録販売者③`
- Result: `HUMAN_REQUIRED`
- Date: `2026-08-19 JST`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App Store review submission: **NOT PERFORMED / PROHIBITED**

## 1. 正本識別情報の再照合

Notion/GitHubの現行正本を再取得し、古い「App record未作成」扱いを破棄した。

- Bundle ID: `com.allsunday1122.tourokuhanbaisha`
- App Store Connect App ID: `6802119268`
- Apple Team ID: `MN3D2ZM44N`
- Codemagic profile ref: `tourokuhanbaisha_appstore`
- Version: `1.0.0`
- Codemagic repository app id: `6a769d81a1add9d06020b524`

Notion対象ページ `3b309c10-697d-8184-8b61-ff06ea73eaf7` と識別情報正本 `3b709c10-697d-8138-a352-c422d4dd5c47` を更新し、次工程を署名identity gateへ訂正した。

## 2. AppIcon正本

学びスプリントAppIcon正本ルールに従い、登録販売者の個別PNGを正本化した。

- Drive file: `登録販売者.png`
- Drive file id: `1mIyCAdiiTBXYe-kjDdbrdKmsrIf4VkTo`
- Size: `1024x1024`
- SHA-256: `c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03`
- 官公庁章・公認表示なし

GitHubのiOS Release gateとCodemagic buildは上記SHAを署名前に照合する。

## 3. 履歴カレンダー直近実機指摘の再検証

現行mainの `touroku-hanbaisha-sprint/history-calendar-v02.js` をNode VM上で直接実行する回帰テスト `touroku-hanbaisha-sprint/validate-history-calendar.mjs` を追加済み。

検証対象:
- 完了履歴の日別集計
- 当日の途中回答 `inProgress` の反映
- 完了履歴＋途中回答の合算
- 0問途中状態の除外

Codemagic Build #2/#3/#4 の Release input auditで継続PASS。360問canonical監査もPASS。2026-08-15 iPhone Safari実機再確認PASSというNotion記録とも整合した。

## 4. Native iOS / XcodeGen

PR #4305でSwiftUI + WKWebView native wrapper、Privacy Manifest、AppIcon gate、Release validatorをmainへ統合。

PR #4330でXcodeGen ProjectSpecを修正し、Assets/Privacy Manifestをtarget `sources` + `buildPhase: resources`へ移行。

Codemagic Build #2/#3で `Set CI build number and generate native project` が失敗したため、macOS GitHub ActionsでXcodeGen 2.46.0を実行して `project.yml` 自体は生成可能・Bundle/Team grep PASSを確認した。

その後、Codemagic build number参照を `CM_BUILD_NUMBER` 必須から `CM_BUILD_NUMBER or BUILD_NUMBER`へ修正し、Build #4では以下がPASSした。

- Release input audit
- history calendar regression
- AppIcon SHA gate
- XcodeGen generation
- generated project Bundle ID / Team ID verification

## 5. Codemagic build evidence

### Build #4

- request: `app2-010-touhan-build-internal4-20260819-1524`
- build id: `6a854b9aea6ced5835d96b07`
- result: `failed`
- evidence: `automation/codemagic-results/app2-010-touhan-build-internal4-20260819-1524.json`

PASS:
- native tools install
- release input audit
- XcodeGen generation
- native input verification
- keychain initialize

FAIL:
- `app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create`

同じ署名取得CLIはAPP2-012でも同様に失敗しており、登録販売者固有のアプリコード障害ではない。

### Build #5

Codemagic公式の保存済みCode signing identity自動解決方式へ変更した。

- `environment.ios_signing.distribution_type: app_store`
- `environment.ios_signing.bundle_identifier: com.allsunday1122.tourokuhanbaisha`
- manual `keychain initialize / fetch-signing-files / add-certificates` を登録販売者workflowから除去
- `submit_to_testflight: true`
- `submit_to_app_store: false`

Installer evidence:
`automation/codemagic-results/app2-010-touhan-install-autosign-20260819-1529.json`

Build:
- request: `app2-010-touhan-build-internal5-20260819-1530`
- build id: `6a854cd4783ac97e9935da72`
- result: `failed`
- `started_at: null`
- `instance_type: null`
- actions: empty
- evidence: `automation/codemagic-results/app2-010-touhan-build-internal5-20260819-1530.json`

この挙動はrunner起動前のCodemagic signing/config preflightで止まっているため、保存済みCode signing identitiesから当該Bundle用App Store署名identityを解決できていないと判定する。

## 6. App Store Connect再監査

Apple ID `6802119268` を対象にGitHub App Store Connect API Gatewayへ再監査を投入した。

最終投入 request:
`app2-010-touhan-asc-minimal-20260819-1535`

対象:
- `/v1/apps/6802119268`
- `/v1/apps/6802119268/builds`
- `/v1/apps/6802119268/appStoreVersions`
- `/v1/apps/6802119268/betaGroups`

本Worker終了時点ではrequest-scoped結果ファイルが未生成。既存ASC Gatewayは成功時のみsummaryを永続化するため、この再監査は「最新Apple API read-back PASS」の証拠としては採用しない。

識別情報はNotion横断監査でApp record存在・Apple ID `6802119268`として正本化済みだが、今回の署名Buildが未成立のため新BuildはASCへ未uploadであり、Internal TestFlightへは未到達。

## 7. 真正な人間ゲート

現時点で自動化可能なコード・CI・Codemagic workflow差分は処理済み。残る停止点はCodemagicアカウント内のApple署名identityで、現在利用可能なGitHub/Codemagic Build APIから安全に作成・アップロードできる管理APIは確認できなかった。

必要な人間操作は次の1点群のみ。

1. Codemagic Team settings → **Code signing identities** を開く。
2. Bundle ID `com.allsunday1122.tourokuhanbaisha` 用の有効な **Apple Distribution certificate（private key付き）** と **App Store provisioning profile** を利用可能にする。
3. 必要なら Team settings → integrations / Developer Portal のApp Store Connect API key権限を修復してから、Code signing identities画面でcertificate/profileをFetch/Generateする。
4. provisioning profile referenceは正本 `tourokuhanbaisha_appstore` と整合させる。

`.p8`、private key、certificate password、API token等をチャット・Notion・GitHubへ貼らない。

このidentityが利用可能になれば、次回は既存 `touhan-ios` を再実行するだけで、signed IPA → App Store Connect upload → Internal TestFlightへ進める。App Store本審査submit/releaseは実行しない。

## 8. 最終判定

`HUMAN_REQUIRED`

理由: アプリコード、履歴回帰、360問、AppIcon、Bundle/App ID、XcodeGen、Codemagic workflowは機械的に整合確認済み。Internal TestFlight未到達の唯一の実停止点はCodemagicのApple signing identity availability。
