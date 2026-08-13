# #12 不動産鑑定士｜学びスプリント Release Status

更新日: 2026-08-13

## 現在地

**PRE-TESTFLIGHT / HUMAN IDENTIFIER GATE**

初期試作品の人間確認は完了。製品240問・ネイティブアプリ統合・canonical監査・Simulator実行まで完了済み。

次の人間確認地点はTestFlight実機確認だが、その前にApple識別情報を最上位Notion正本へ確定する必要がある。

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
- XCTest / XCUITest / Simulator clean launch: PASS実績あり
- Privacy Manifest: 作成済み
- App Store原稿 / Support / Privacy: 作成済み
- 学びスプリント#12正本App Icon: Google Driveで特定済み

## Apple識別情報の不整合

### 最上位Notion正本
`【正本】対象アプリ識別情報｜App Store Connect / Codemagic`

2026-08-13現在、#12の行が存在しない。この正本は「未記載値を他アプリ・GitHub・過去チャット・命名規則から推測しない」と定めている。

### 現行コード
- Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`

Team IDは共通正本に一致。Bundle IDは#12の最上位正本登録がないため、**Apple側登録にはまだ使用しない**。

## 次の停止条件
ユーザーが次を明示した時点で再開する。

1. 現行Bundle ID `jp.allsunday1122.kanteishishortanswer` を#12の確定値として採用する、または別のBundle IDを明示する。
2. 採用値を最上位Notion正本へ登録する。
3. App Store Connect App IDはApple発行実値だけを追記する。

## その後の自動進行
識別情報確定後は、可能な限り次を連続実行する。
- App Icon Assets統合
- release preflight再監査
- Codemagic / 署名設定
- Archive / IPA
- App Store Connect build upload
- Internal TestFlight
- TestFlight実機確認でユーザーへ戻す

App Store本審査提出は、TestFlight確認後もユーザーの明示承認まで実行しない。
