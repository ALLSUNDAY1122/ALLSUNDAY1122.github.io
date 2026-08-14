# #12 不動産鑑定士｜学びスプリント Release Status

更新日: 2026-08-14

## 現在地

**PRE-TESTFLIGHT / APP STORE CONNECT REGISTRATION**

初期試作品確認、製品240問、SwiftUIネイティブ統合、canonical監査、Simulator実行、申請資料整備まで完了済み。

2026-08-14の標準手順 v2.4 により、Bundle ID命名はChatGPTへ恒久委任され、ユーザー確認ゲートではなくなった。最上位Notion正本にも#12が登録済みのため、旧 `HUMAN IDENTIFIER GATE` は解除する。

## 確定識別情報

- Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- Codemagic profile: `kanteishishortanswer_appstore`
- App Store Connect App ID: Apple発行待ち・推測禁止
- App Store本審査自動提出: 禁止

## 最終機械ゲート

### 製品アプリCI
GitHub Actions run `31703594537`: **PASS**

- canonical 240問 shared validator
- production payload 240問 / 3年度 / 全5択
- XcodeGen / SwiftUI typecheck
- iPhone Simulator build
- `.app`内 production JSON 240問
- final Info.plist metadata
- XCTest（年度別80問・年度×科目40問を含む）
- XCUITest（通常学習・4タブ・年度/科目導線）
- clean install / actual launch
- full-screen / black letterbox gate
- runnable production artifact

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
- XCTest / XCUITest / Simulator clean launch: PASS
- Privacy Manifest: 作成済み
- App Store原稿 / TestFlight Notes / Support / Privacy: 作成済み
- 学びスプリント#12正本App Icon: Google Driveで特定・1024×1024 RGB・SHA-256固定済み
- Bundle ID / Codemagic profile: 最上位Notion正本へ登録済み

## App Icon

Google Drive正本:
- `12_不動産鑑定士試験_短答式.png`
- Drive ID: `1wnnkFkere2-9OKXYSG3T_bS6NqS3xWMX`
- SHA-256: `679f3493524dd2cf71126303c998b15395c70ff19f224d158a760ee3c2a395f1`

正本PNGは取得・検証済み。署名前工程でApp Icon Assetsへ統合し、signed `.app`で最終確認する。

## 次工程

1. App Store Connectで#12の新規アプリを作成し、Apple発行の数値App IDを取得する。
2. 実発行値を最上位Notion正本へ記録する。
3. App Icon Assets統合。
4. release preflight再監査。
5. Codemagic署名設定、Archive / IPA。
6. App Store Connect build upload。
7. Internal TestFlightへ配布。
8. TestFlight実機確認でユーザーへ戻す。

ユーザー操作が必要なのは、Apple/App Store Connect/Codemagicのログイン・2FA等の本人認証と、TestFlight実機確認、最終Submit直前の承認のみとする。

App Store本審査の `Add for Review` / `Submit for Review` は、TestFlight確認後もユーザーの明示承認まで実行しない。
