# APP2-012｜ネットワークスペシャリスト｜App ID後工程へ

更新: 2026-08-19 15:13 JST

## 結果
Status: HUMAN_REQUIRED

## 正本
- App Store Connect App ID: `6799754573`
- Bundle ID: `jp.allsunday1122.networkspecialist`
- Codemagic profile canonical: `networkspecialist_appstore`
- IAP: 非消耗型 `jp.allsunday1122.networkspecialist.premium`
- 無料: 通常学習8問スプリント＋基本設定
- Premium: 全75出題枠、年度別25問模試、分野学習、苦手復習/3連続解除、記録/5週間ヒートマップ、JSONバックアップ/復元
- `Info.plist` PremiumProductID反映 / App ID旧記述訂正はmain統合済み。

## canonical AppIcon
- Drive canonical: `07_ネットワークスペシャリスト試験.png`
- Drive ID: `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`
- 678310 bytes / 1024x1024 / 8-bit RGB
- SHA-256: `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`
- `materialize_appicon.py` は同一SHA必須のfail-closed復元を実装済み。
- 過去PASS CI head `514928416bbb790dc7e6e4505b6889bc82dee8da` のAppIcon asset directoryも `APPICON_SOURCE.md` / `Contents.json` のみで、再利用可能なPNG blobは存在しなかった。

## Codemagic signed build attempt
- request: `app2-012-network-build-internal-20260819-1412`
- workflow: `network-specialist-native-ios`
- Codemagic build ID: `6a853ac7acf98143df9f85d1`
- terminal: FAILED
- build machine / source fetch / XcodeGen installはPASS。
- `Materialize and verify canonical AppIcon` でFAILED。Drive public download経路からcanonical PNGを取得できず、以降のnative regression / Release build / signing / IPAはSKIPPED。
- 誤画像で進ませず、bytes/SHA検証でfail-closedしている。

## Apple signing preflight
AppIconとは独立にApple認証・署名を監査するため、`network-specialist-signing-preflight` workflowを追加した。本審査・TestFlight uploadは行わない診断専用。

- start request: `app2-012-network-signing-preflight-start-20260819-1512`
- Codemagic build ID: `6a854936bad3b38fdec654e4`
- inspect request: `app2-012-network-signing-preflight-inspect-20260819-1513`
- terminal: FAILED
- `Verify canonical identifiers`: PASS
- `keychain initialize`: PASS
- `app-store-connect fetch-signing-files jp.allsunday1122.networkspecialist --type IOS_APP_STORE --create`: FAILED
- `keychain add-certificates`: SKIPPED

これにより、AppIcon以外にもApple signing files取得が独立したRelease blockerであることを機械確認した。

## 現在の真正な停止点
1. canonical AppIconをCIから取得可能な形で供給する必要がある。Drive public URLはCodemagicで取得失敗。GitHub mainにもcanonical PNG blobはない。
2. Codemagic/App Store Connectで `jp.allsunday1122.networkspecialist` のApp Store signing files取得が失敗する。integration権限 / Bundle ID signing resource / certificate-profile状態の追加診断が必要。
3. 上記2点未解決のためRelease Gate→signed IPA→ASC upload→Internal TestFlightには未到達。
4. App Store本審査への提出は禁止を維持。

## 次工程
- signing-files取得失敗のstderr/diagnosticを保存する専用Codemagic診断を実行し原因を確定する。
- canonical AppIconはDrive public downloadに依存しない搬送（repository Base64 transport等）へ切替し、同一SHAで復元する。
- 2 blocker解消後に `validate_native_release.py --require-icon --require-iap` → regression → signed IPA → Internal TestFlight。
