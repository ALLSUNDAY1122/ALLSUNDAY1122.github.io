# 管理栄養士｜学びスプリント iOS

SwiftUI + WKWebView + StoreKit 2 の製品化基盤。

- Bundle ID: `jp.allsunday1122.kanrieiyoushi`
- Non-Consumable: `jp.allsunday1122.kanrieiyoushi.premium`
- Web UI Master: v2.1 / v0.6.2
- Question bank: 600 (3 × 200)
- Canonical AppIcon: Google Drive `04_管理栄養士国家試験.png` / file ID `11d72Dl76UH7QvU8Gxl-SgDjTV73GaxP4`

`prepare-ios.sh` で監査済みWeb資産を `Web/` へ同梱し、ネイティブ版だけ `native-storekit.js` を注入する。GitHub Pages版には課金制御を入れない。
