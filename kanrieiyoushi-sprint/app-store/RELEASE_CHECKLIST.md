# Release Checklist｜管理栄養士 学びスプリント

## コード側
- [x] 600問監査を再実行するRelease Gate
- [x] SwiftUI + WKWebViewローカル同梱
- [x] StoreKit 2 Non-Consumable
- [x] Product.displayPriceのみで価格表示
- [x] Transaction.currentEntitlements / Transaction.updates
- [x] 購入 / キャンセル / pending / 復元 / revocation
- [x] 無料60問 / Premium600問の権限制御
- [x] Privacy Manifest
- [x] Privacy / Support URL
- [x] App Review Notes / metadata / StoreKit test plan
- [x] Codemagic Internal TestFlight設定（自動提出OFF）
- [x] 辛口レビュー3回と修正

## Release Gate
- [x] macOS Release Simulator build PASS（GitHub Actions run 31311911002）
- [x] 生成.appにWeb / native StoreKit bridge / Privacy / Assetsを同梱
- [x] IAP CapabilityをXcode projectへ反映
- [x] 600問・既存Web UI回帰監査PASS（run 31311911011）
- [ ] 正本AppIcon `04_管理栄養士国家試験.png` を署名Release環境へ配置
  - Drive ID: `11d72Dl76UH7QvU8Gxl-SgDjTV73GaxP4`
  - 1024×1024 / 726223 bytes
  - SHA-256: `294481351106502f20958359d02bb2fb117ae18399654388425aad0e264fe31f`
  - Google Driveコネクタで正本実体は確認済み。匿名Drive URLは別レスポンスになるため、仮アイコンでArchiveしない。

## Apple側の人間確認点
- [ ] App Store Connect Appレコード
- [ ] Bundle ID登録
- [ ] IAP商品作成・正式価格
- [ ] Codemagic App Store Connect連携と署名
- [ ] 正本AppIconをRelease環境へ安全に配置
- [ ] Signed IPAをInternal TestFlightへアップロード
- [ ] iPhone実機で起動・60問無料範囲
- [ ] Sandbox購入成功
- [ ] 購入復元
- [ ] pending/cancel確認
- [ ] 600問解放と模試解放

技術実装ゲートはPASS。App Store本審査・Beta Reviewへの自動提出は禁止。Signed Internal TestFlightと実機課金確認後に次ゲートを承認する。
