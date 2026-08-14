# #12 不動産鑑定士｜学びスプリント Release Status

更新日: 2026-08-14

## 現在地

**PRE-TESTFLIGHT / APP STORE CONNECT REGISTRATION**

初期試作品確認、製品240問、SwiftUIネイティブ統合、canonical監査、正本App Icon統合、無料24問／プレミアム240問のアクセス契約、申請資料整備まで完了済み。

標準手順 v2.5 を適用。Bundle ID命名はChatGPTへ恒久委任され、App Store本審査の最終提出だけはユーザー明示承認を必須とする。

## 確定識別情報

- Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- Codemagic profile: `kanteishishortanswer_appstore`
- App Store Connect App ID: Apple発行待ち・推測禁止
- App Store本審査自動提出: 禁止

## 課金・アクセス契約

- 採用方式: 自動更新サブスクリプション（月額）
- 日本向け基準価格: 200円
- アプリ内価格表示: StoreKit `Product.displayPrice` のみ。価格文字列をコードへ固定しない。
- 無料版: canonical 240問のうち24問。年度×科目の6セルごとに4問ずつ選定する。
- 無料24問は各セル内で分野を可能な限り分散させ、決定的アルゴリズムで選定する。
- プレミアム: 全240問、年度×科目40問演習、年度別80問模試。
- 初回無料期間: 標準では設定しない。
- planned Product ID: `jp.allsunday1122.kanteishishortanswer.monthly200`
- runtime Product ID: App Store Connectで実登録値を確認するまでは未設定。推測で有効化しない。
- StoreKit 2: verified transaction、Product ID一致、未取消の権利だけを解放し、購入復元を実装する。

## 最終機械ゲート

### 製品アプリCI
既存基準 run `31703594537`: **PASS**

- canonical 240問 shared validator
- production payload 240問 / 3年度 / 全5択
- XcodeGen / SwiftUI typecheck
- iPhone Simulator build
- `.app`内 production JSON 240問
- final Info.plist metadata
- XCTest / XCUITest
- clean install / actual launch
- full-screen / black letterbox gate
- runnable production artifact

AppIcon統合後・課金アクセス変更後は、影響するネイティブCIを再実行してPASSを再確定する。

### 公式問題再抽出・権利監査
GitHub Actions run `31703594505`: **PASS**

- 国土交通省公式PDF / 正解表から240問を再抽出
- 80問×3年度
- 行政法規120 / 鑑定理論120
- 第三者権利要確認0
- 表レイアウト監査PASS
- canonical差分なし

## 完了

- Phase 0 調査 / 権利 / 試験構成: PASS
- Phase 1 SwiftUI Golden Master系UI: PASS
- 初期試作品確認: PASS
- Phase 2 公式過去問240問: PASS
- canonical GitHub正本化: PASS
- 共通問題監査: PASS
- 第三者権利監査: PASS
- 表レイアウト監査: PASS
- 製品JSONアプリ同梱: PASS
- 年度別80問模試: 実装済み
- 年度×科目40問演習: 実装済み
- Privacy Manifest: 作成済み
- App Store原稿 / TestFlight Notes / Support / Privacy: 作成済み
- Bundle ID / Codemagic profile: 最上位Notion正本へ登録済み
- 正本App Icon: Assets.xcassetsへ実バイナリ統合済み
- AppIcon旧Base64分割搬送: 廃止・削除済み
- AppIcon永久SHA監査: PASS
- 月額StoreKit型: `.autoRenewable`へ変更済み
- 無料24問アクセス契約: 実装・テスト追加済み

## App Icon

Google Drive正本:
- `12_不動産鑑定士試験_短答式.png`
- Drive ID: `1wnnkFkere2-9OKXYSG3T_bS6NqS3xWMX`
- SHA-256: `679f3493524dd2cf71126303c998b15395c70ff19f224d158a760ee3c2a395f1`
- 1024×1024 RGB PNG / 668,457 bytes

統合結果:
- `KanteishiShortAnswer/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Git blob SHA: `6a12f42e3168a38bd419ed648ea08158176a0d9c`
- materialize run `31785258935`: PASS
- permanent AppIcon audit run `31785542708`: PASS

## 次工程

1. 課金アクセス変更後のXCTest / XCUITest / Simulator / AppIcon込みbuildをPASSへ戻す。
2. App Store Connectで#12新規アプリを作成し、Apple発行の数値App IDを実取得する。
3. App Store Connectで月額サブスクリプションを実登録し、Product ID実値を正本化する。
4. 実発行値・実登録値をNotion正本へ記録し、runtime Product IDを有効化する。
5. Codemagic署名設定、Archive / IPA、App Store Connect build upload。
6. Internal TestFlightへ配布。
7. TestFlight実機確認でユーザーへ戻す。

ユーザー操作が必要なのは、Apple/App Store Connect/Codemagicのログイン・2FA等の本人認証、TestFlight実機確認、最終Submit直前の承認のみとする。

App Store本審査の `Add for Review` / `Submit for Review` は、TestFlight確認後もユーザーの明示承認まで実行しない。
