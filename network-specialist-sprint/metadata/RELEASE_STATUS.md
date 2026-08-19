# RELEASE STATUS

更新: 2026-08-19 12:25 JST

## 対象アプリ
- 資格名：ネットワークスペシャリスト試験｜学びスプリント
- Bundle ID：`jp.allsunday1122.networkspecialist`
- App Store Connect App ID：`6799754573`（Notion識別情報正本で再確認）
- Version：`1.0.0`
- Build番号：`1`
- Codemagic workflow：`network-specialist-native-ios`
- Codemagic署名プロファイル：`networkspecialist_appstore`
- Apple Team ID：`MN3D2ZM44N`
- Distribution：App Store
- TestFlight：Internal Testing only
- App Store本審査提出：禁止

## 2026-08-19 APP2-012 再監査
- App ID未確定という旧記述は失効。正本値は `6799754573`。
- IAPは非消耗型 `jp.allsunday1122.networkspecialist.premium` を正本化。
- 無料範囲：通常学習8問スプリント＋基本設定。
- Premium解放：全75出題枠、年度別25問模試、分野学習、苦手復習/3連続解除、記録/5週間ヒートマップ、JSONバックアップ/復元。
- StoreKit 2購入エンジンは既存実装を維持し、`Info.plist` の `PremiumProductID` を正本値へ設定。
- canonical AppIconはGoogle Drive `07_ネットワークスペシャリスト試験.png`（file ID `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`）を再取得。678310 bytes、SHA-256 `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729` で既存監査値と一致。
- GitHub Contents APIはUTF-8 text専用のため、このworkerからPNGバイナリを指定Asset Catalogへcommitできない。AppIcon materialize Gateは引き続き未完了。

## 既存PASS（再実装しない）
- 純SwiftUI native、WebKitなし。
- 75出題枠 / 68ユニーク、問題監査PASS。
- Unit 5/5、UI 3/3、iPhone 17 Pro Max / iPhone SE (3rd) PASS（Actions run `31360542268`）。
- StoreKit 2機構：Product.products、displayPrice、verified active transactionのみ解放、currentEntitlements、Transaction.updates、明示復元 AppStore.sync()。
- Internal Testing only / App Store auto-submit OFF のCodemagic構成。

## 現在のRelease blocker
1. canonical AppIcon PNGを `network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` へ同一SHAでcommitする。
2. App Store Connectに非消耗型IAP `jp.allsunday1122.networkspecialist.premium` が実登録済みかread-backし、未登録なら作成する。
3. Support / Privacy公開HTTP 200を証跡化する。
4. 上記後に `python3 scripts/validate_native_release.py --require-icon --require-iap` を含むRelease GateをPASSさせる。
5. Codemagic `network-specialist-native-ios` → signed IPA → App Store Connect upload → Internal TestFlight。
6. Internal TestFlight実機で無料/Premium境界、購入、復元、起動、学習導線を確認する。

## STOP
- App Store本審査へは提出しない。
- 外部TestFlight beta reviewへ自動提出しない。
