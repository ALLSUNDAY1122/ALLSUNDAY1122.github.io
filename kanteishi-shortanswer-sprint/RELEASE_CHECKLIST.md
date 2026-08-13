# #12 不動産鑑定士｜学びスプリント Release Checklist

更新日: 2026-08-13

## A. 問題データ / 権利
- [x] 本試験構成固定：3年度×（行政法規40＋鑑定理論40）= 240問
- [x] 国土交通省公式問題・正解表から再現可能に抽出
- [x] 年度別canonical JSONをGitHub正本化
- [x] canonical正本に対して共通validator再実行
- [x] 問題ID重複 0
- [x] 人工的な水増し 0
- [x] 公式再出題ポリシー適用
- [x] 正答表との対応付け
- [x] 根拠URL / 基準日 / origin / rights_basis
- [x] 第三者権利要確認 0
- [x] 令和8年鑑定理論39・40の表レイアウト再構成

## B. アプリ実装
- [x] SwiftUIネイティブ
- [x] WebView禁止
- [x] iPhone専用 / iOS 17+
- [x] portrait固定
- [x] 公式240問を製品JSONから優先読込
- [x] 全問題5択
- [x] 今日のスプリント 4/8/16問
- [x] 年度別80問模試
- [x] 年度×科目40問演習
- [x] 苦手復習 / 3連続正解解除
- [x] 中断復帰
- [x] 学習記録 / 5週間ヒートマップ
- [x] JSONバックアップ
- [x] 一次資料外部リンク
- [x] Application Supportへ端末内保存

## C. 自動テスト / CI
- [x] Swift core tests
- [x] canonical 240問監査
- [x] production payload contract
- [x] SwiftUI typecheck
- [x] XcodeGen生成
- [x] iPhone Simulator build
- [x] `.app`内production JSON 240問確認
- [x] 最終Info.plist metadata監査
- [x] XCTest
- [x] XCUITest
- [x] clean install / actual launch
- [x] full-screen / black letterbox gate
- [ ] **最終HEADで上記CIを再PASS**

## D. Privacy / Store資料
- [x] PrivacyInfo.xcprivacy
- [x] 現行実装に広告SDKなし
- [x] 第三者解析SDKなし
- [x] アカウント / ログインなし
- [x] 開発者サーバーへの学習データ自動送信なし
- [x] `privacy.html` 作成
- [x] `support.html` 作成
- [x] `APP_STORE_METADATA_JA.md` 作成
- [x] `APPLE_CONNECT_PACKET.md` 作成
- [x] App Store本審査の自動提出禁止を明記
- [ ] PR/main反映後、Support / Privacy URLを未ログインHTTP 200で確認

## E. アイコン / スクリーンショット
- [x] Google Drive正本 `12_不動産鑑定士試験_短答式.png` を特定
- [x] 1024×1024 / RGB確認
- [ ] 正本PNGをXcode Assetsへ原寸配置
- [ ] App Iconを最終`.app`で確認
- [ ] App Store用スクリーンショット最終作成・選定

## F. Apple識別情報 — HUMAN GATE
- [x] Team ID共通正本：`MN3D2ZM44N`
- [ ] **最上位Notion識別情報正本へ#12を登録**
- [ ] 現行Bundle ID候補 `jp.allsunday1122.kanteishishortanswer` をユーザー確定
- [ ] Explicit App ID作成 / 既存確認
- [ ] App Store Connect新規Appレコード作成
- [ ] Apple発行App Store Connect App IDを正本へ記録
- [ ] Codemagic profile / 署名設定を確定
- [ ] IAPを初回版に含めるか決定

## G. TestFlight — HUMAN GATE
- [ ] signed Archive / IPA
- [ ] App Store Connectへアップロード
- [ ] Internal Testingグループへ追加
- [ ] iPhone実機インストール
- [ ] ホーム / 模試 / 記録 / 設定
- [ ] 年度別80問
- [ ] 年度×科目40問
- [ ] 通常学習・途中復帰・苦手復習
- [ ] 機内モード学習
- [ ] JSONバックアップ
- [ ] 一次資料リンク
- [ ] 表39・40の読みやすさ
- [ ] クラッシュ / 表示崩れなし

## H. App Store本審査
- [ ] TestFlight実機確認完了
- [ ] App Privacy最終回答
- [ ] 年齢評価最終回答
- [ ] Content Rights入力
- [ ] スクリーンショット登録
- [ ] Review Notes / 連絡先
- [ ] 価格 / 配信地域
- [ ] **ユーザーが明示承認するまで Add for Review / Submit for Review を実行しない**
