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

## Release Gate
- [ ] macOS Release Simulator build PASS
- [ ] 生成.appにWeb/Privacy/Assetsを同梱
- [ ] 正本AppIcon `04_管理栄養士国家試験.png` を配置

## Apple側の人間確認点
- [ ] App Store Connect Appレコード
- [ ] Bundle ID登録
- [ ] IAP商品作成・正式価格
- [ ] Codemagic App Store Connect連携と署名
- [ ] Signed IPAをInternal TestFlightへアップロード
- [ ] iPhone実機で起動・60問無料範囲
- [ ] Sandbox購入成功
- [ ] 購入復元
- [ ] pending/cancel確認
- [ ] 600問解放と模試解放

App Store本審査・Beta Reviewへの自動提出は禁止。実機確認後に人間が次ゲートを承認する。
