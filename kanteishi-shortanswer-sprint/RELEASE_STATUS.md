# #12 不動産鑑定士｜学びスプリント Release Status

更新日: 2026-08-14

## 現在地

**PRE-TESTFLIGHT / APP STORE CONNECT HUMAN GATE**

製品240問、SwiftUIネイティブ統合、canonical監査、正本App Icon、無料24問／プレミアム240問、月額StoreKit 2、release時Product ID注入、ネイティブCIまで機械工程はPASS済み。

## 確定識別情報
- Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- Codemagic profile: `kanteishishortanswer_appstore`
- App Store Connect App ID: Apple発行待ち・推測禁止
- App Store本審査自動提出: 禁止

## 課金・アクセス
- 自動更新サブスクリプション（月額）
- 日本向け基準価格: 200円
- 価格表示: StoreKit `Product.displayPrice`
- 無料: canonical 240問中24問（3年度×2科目ごと4問）
- プレミアム: 全240問・年度別80問模試・年度×科目40問演習
- 初回無料期間: なし
- planned Product ID: `jp.allsunday1122.kanteishishortanswer.monthly200`
- actual Product ID: App Store Connect実登録値のみを正本化
- verified transaction + Product ID一致 + 未取消のみ権利付与
- 購入復元実装済み
- 通常ソースではProduct ID空、release時にCodemagic環境から注入

## 最終機械ゲート
### Kanteishi Short Answer
GitHub Actions run `31788327068`: **PASS**
- Swift core tests
- 240-slot / canonical / production payload監査
- SwiftUI typecheck
- XcodeGen / iPhone Simulator build
- `.app`内240問
- Info.plist metadata
- XCTest / XCUITest
- clean install / actual launch
- full-screen visual gate

### Official 240
同HEAD: **PASS**
- 国土交通省公式資料から240問
- 80問×3年度 / 行政法規120 / 鑑定理論120
- 第三者権利要確認0
- canonical差分なし

### AppIcon Contract
同HEAD: **PASS**
- 正本PNG 1024×1024 RGB
- SHA-256 `679f3493524dd2cf71126303c998b15395c70ff19f224d158a760ee3c2a395f1`
- AppIcon asset catalog統合済み

## 完了済み
- Phase 0 調査 / 権利 / 試験構成
- Golden Master系SwiftUI UI
- 初期試作品確認
- 公式過去問240問と正答・権利監査
- 製品JSON同梱
- 年度別80問 / 年度×科目40問
- 苦手復習 / 中断復帰 / 履歴 / バックアップ
- Privacy Manifest / Support / Privacy / Store原稿 / TestFlight Notes
- Bundle ID / Codemagic profile正本化
- 正本App Iconバイナリ統合・永久SHA監査
- 無料24問アクセス制御
- StoreKit 2月額自動更新サブスクリプション
- 購入復元
- release Product ID注入経路
- 課金アクセス変更後ネイティブCI PASS

## 次工程
1. App Store Connectで新規Appレコードを作成。
2. Apple発行の数値App IDを実取得し正本化。
3. 月額自動更新サブスクリプションを実登録し、Product ID実値を正本化。
4. Codemagicへ実登録Product IDとApple署名接続を設定。
5. signed IPAを作成しInternal TestFlightへアップロード。
6. iPhone実機で無料24問、購入、復元、再起動、失効を含む確認。

Apple/App Store Connect/Codemagicのログイン・2FA・契約同意など本人操作が必要な箇所だけユーザーが担当する。

App Store本審査の `Add for Review` / `Submit for Review` は、TestFlight確認後もユーザーの明示承認まで実行しない。
