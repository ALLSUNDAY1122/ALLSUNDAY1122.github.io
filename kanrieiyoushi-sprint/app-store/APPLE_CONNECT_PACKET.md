# App Store Connect 入力票｜管理栄養士 学びスプリント

- App名: 管理栄養士 学びスプリント
- Bundle ID: `jp.allsunday1122.kanrieiyoushi`
- SKU: `kanrieiyoushi-sprint-ios`
- Version: `1.0.0`
- Build: CI build number
- Primary language: Japanese
- Category: Education
- IAP: Non-Consumable / `jp.allsunday1122.kanrieiyoushi.premium`
- IAP表示名: 管理栄養士 プレミアム
- 価格: App Store Connectで正式設定。アプリ内表示はStoreKit `Product.displayPrice`のみを使用し固定額を埋め込まない。
- Privacy URL: `https://allsunday1122.github.io/kanrieiyoushi-sprint/privacy/`
- Support URL: `https://allsunday1122.github.io/kanrieiyoushi-sprint/support/`
- Canonical AppIcon: Google Drive `04_管理栄養士国家試験.png`
- Drive file ID: `11d72Dl76UH7QvU8Gxl-SgDjTV73GaxP4`
- Canonical PNG: 726223 bytes / 1024×1024 / SHA-256 `294481351106502f20958359d02bb2fb117ae18399654388425aad0e264fe31f`
- Release gateはサイズ・PNG寸法・SHA-256を一致条件とし、匿名Drive URLが別レスポンスを返す場合はReleaseを停止する。

## 課金範囲
無料版：第1回の10分類それぞれ6問、合計60問。今日のスプリント、無料範囲の分野別演習、無料範囲の苦手復習、基本記録、途中復帰。

プレミアム：第1〜第3回の全600問、200問模試×3、全苦手復習、詳細記録。

## 外部ゲート
App Store ConnectのAppレコード作成、IAPの商品作成・正式価格設定、Appleログイン/2FA、署名プロファイル、Codemagic App Store Connect integration、Sandbox/TestFlight実機購入・復元確認はApple側の人間確認点。

正本AppIconはGoogle Driveコネクタで実体取得済みだが、リポジトリの自動Release環境へ正本バイト列を配置する輸送経路は別途確立する。仮アイコンでTestFlight/Archiveへ進まない。

自動Beta Review・自動App Store提出は行わない。
