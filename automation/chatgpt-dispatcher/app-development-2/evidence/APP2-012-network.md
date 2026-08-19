# APP2-012｜ネットワークスペシャリスト｜App ID後工程へ

更新: 2026-08-19 12:27 JST

## 結果
Status: HUMAN_REQUIRED

## 起動時再取得
- Worker契約 / Dispatcher Queueをcontrol branchからread-back。
- Notion #7正本、横断同期2026-08-19、識別情報正本を再取得。
- GitHub mainの `network-specialist-sprint` release metadata / audit / StoreKit / Codemagicを再取得。
- App Store Connect App IDは正本で `6799754573` と確定済み。GitHub旧metadataの「未記載」は古い記述と判定。

## 実施
- Notion識別情報正本 #7 を更新：
  - IAP: 非消耗型 `jp.allsunday1122.networkspecialist.premium`
  - 無料: 通常学習8問スプリント＋基本設定
  - Premium: 全75出題枠、年度別25問模試、分野学習、苦手復習/3連続解除、記録/5週間ヒートマップ、JSONバックアップ/復元
- #7台帳「次の作業」をApp ID確定済み前提へ更新。
- GitHub branch `agent/app2-012-network-release` をmainから作成。
- `Info.plist` に `PremiumProductID=jp.allsunday1122.networkspecialist.premium` を設定。
- `metadata/RELEASE_STATUS.md` のApp ID旧記述を訂正し、2026-08-19再監査を記録。
- PR #4258を作成し、squash merge。main commit `937e3364935cf6afa760751a85ba2dab6823bdef`。
- main read-backで `PremiumProductID` 反映を確認。

## canonical AppIcon再監査
- Google Drive file: `07_ネットワークスペシャリスト試験.png`
- file ID: `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`
- size: 678310 bytes
- SHA-256再計算: `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`
- 既存canonical SHAと一致。

## 停止理由
接続中GitHub Contents APIのcreate/updateはUTF-8 text専用で、取得したcanonical PNGバイナリを `network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` へcommitできない。ローカル環境には対象repo checkout/gh CLIも存在しないため、同一SHA AppIcon配置を完了できない。このため `--require-icon --require-iap` Release Gate、Codemagic署名Build、ASC upload、Internal TestFlightへ進む前提が未充足。

また、このworker環境ではApp Store Connect / Codemagicの専用接続ツールが利用できず、IAP実登録・最新Build状態のAPI read-backも実行不能。

## 次工程
1. canonical PNGを上記Asset Catalogへバイナリそのままcommit（SHA一致必須）。
2. App Store Connectで非消耗型IAP `jp.allsunday1122.networkspecialist.premium` の存在をread-backし、未作成なら作成。
3. Release Gate `python3 scripts/validate_native_release.py --require-icon --require-iap` をPASS。
4. Codemagic `network-specialist-native-ios` → signed IPA → ASC upload → Internal TestFlight。
5. 無料/Premium境界、購入、復元、起動/学習導線を実機確認。
6. App Store本審査には提出しない。
