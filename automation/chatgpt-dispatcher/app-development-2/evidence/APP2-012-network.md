# APP2-012｜ネットワークスペシャリスト｜App ID後工程へ

更新: 2026-08-19 14:11 JST

## 結果
Status: HUMAN_REQUIRED

## 正本再取得
- Worker契約 / Dispatcher Queue / Notion #7正本 / 識別情報正本 / GitHub mainを再取得。
- App Store Connect App ID: `6799754573`。
- Bundle ID: `jp.allsunday1122.networkspecialist`。
- IAP canonical: 非消耗型 `jp.allsunday1122.networkspecialist.premium`。
- 無料: 通常学習8問スプリント＋基本設定。
- Premium: 全75出題枠、年度別25問模試、分野学習、苦手復習/3連続解除、記録/5週間ヒートマップ、JSONバックアップ/復元。
- `Info.plist` への `PremiumProductID` 反映とApp ID旧記述訂正はPR #4258でmain統合済み。

## canonical AppIcon
- Google Drive canonical file: `07_ネットワークスペシャリスト試験.png`
- Drive ID: `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`
- bytes: `678310`
- SHA-256: `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`
- 1024x1024 / 8-bit RGBの既存canonical値と一致。
- 既存 `materialize_appicon.py` がBase64 transportまたはcanonical local sourceを同一SHAで復元するfail-closed設計であることを再確認。

## 2026-08-19 continuation
- PR #4313で `.github/workflows/network-specialist-icon-bootstrap.yml` をmainへ追加。固定Drive IDから取得したPNGについてbytes/SHA/PNG metadataを検証し、`validate_native_release.py --require-icon --require-iap` PASS時だけAppIconをcommitするfail-closed bootstrapを実装。
- push実行の結果をGitHub connectorから直接列挙できないため、診断JSON保存とPR event観測経路も追加。観測専用PR #4314はruntime差分を持たないため未mergeでclose。
- ルート `codemagic.yaml` にネットワークスペシャリストworkflowが未登録であることを再監査。
- `scripts/prepare_network_specialist_codemagic.py` をmainへ追加。既存Codemagic Build Gatewayが要求時に `network-specialist-native-ios` をルート設定へ追加できるようにした。
- 追加予定workflowはApp ID `6799754573`、IAP Product ID、canonical AppIcon SHAを固定検証し、native unit/UI回帰→unsigned Release→signing files fetch/create→signed IPA→Internal TestFlightを実行し、`submit_to_app_store: false` を固定する。
- `.github/workflows/codemagic-build-gateway.yml` を拡張し、`prepare_network_specialist=true` の要求で上記workflowをmainへ準備してからCodemagic APIを呼ぶ構成にした。
- Build command `app2-012-network-build-internal-20260819-1412` をmainへ保存。workflow `network-specialist-native-ios` / branch `main` / wait=true / Internal TestFlight向け。

## 現在の停止点
- Build Gateway requestはGitHubへ保存済みだが、この回答内のread-back時点では `automation/codemagic-results/app2-012-network-build-internal-20260819-1412.json` がまだ生成されておらず、Codemagic Build ID / terminal statusは未確認。
- canonical PNGのmain Asset Catalogへのcommitもread-back時点では未確認。
- App Store Connect上の非消耗型IAP実登録はこのworkerから直接read-backできていない。
- したがってInternal TestFlight到達をPASSとは記録しない。

## 次工程
1. Build Gateway resultをread-backしBuild ID / action diagnosticsを確認。
2. canonical AppIconが同一SHAでmaterializeされRelease Gate PASSしたことを確認。
3. Codemagic signed IPA / ASC upload / Internal TestFlightのterminal stateを確認。
4. IAP実登録を確認し、未登録ならApple側で作成が必要。
5. TestFlight実機で無料/Premium境界、購入、復元、起動、8問/模試/履歴を確認。
6. App Store本審査には提出しない。
