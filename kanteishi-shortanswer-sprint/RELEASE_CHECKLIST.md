# #12 不動産鑑定士｜学びスプリント Release Checklist

更新日: 2026-08-14

## A. 問題データ / 権利
- [x] 3年度×（行政法規40＋鑑定理論40）= 240問
- [x] 国土交通省公式問題・正解表から再現可能に抽出
- [x] 年度別canonical JSONをGitHub正本化
- [x] 共通validator PASS
- [x] 問題ID重複0 / 人工水増し0
- [x] 正答表との対応付け
- [x] 根拠URL / 基準日 / origin / rights_basis
- [x] 第三者権利要確認0
- [x] 令和8年鑑定理論39・40の表レイアウト再構成・監査PASS

## B. アプリ実装
- [x] SwiftUIネイティブ / WebView禁止
- [x] iPhone専用 / iOS 17+ / portrait
- [x] 公式240問・全5択
- [x] 今日のスプリント4/8/16問
- [x] 年度別80問模試 / 年度×科目40問演習
- [x] 苦手復習 / 3連続正解解除 / 中断復帰
- [x] 学習記録 / 5週間ヒートマップ / JSONバックアップ
- [x] 一次資料外部リンク / 端末内保存
- [x] 無料24問アクセス
- [x] プレミアム240問アクセス
- [x] StoreKit 2 自動更新サブスクリプション
- [x] verified・Product ID一致・未取消のみ権利付与
- [x] 購入復元
- [x] Product IDをrelease時に注入できる構成

## C. 自動テスト / CI
- [x] Swift core tests
- [x] canonical 240問監査
- [x] production payload contract
- [x] SwiftUI typecheck
- [x] XcodeGen生成 / Simulator build
- [x] `.app`内production JSON 240問確認
- [x] 最終Info.plist metadata監査
- [x] XCTest / XCUITest
- [x] clean install / actual launch
- [x] full-screen / black letterbox gate
- [x] AppIcon永久SHA監査
- [x] 課金アクセス変更後 **Kanteishi Short Answer run 31788327068 PASS**
- [x] 同HEADで **Kanteishi Official 240 PASS**
- [x] 同HEADで **Kanteishi AppIcon Contract PASS**

## D. Privacy / Store資料
- [x] PrivacyInfo.xcprivacy
- [x] 広告SDKなし / 第三者解析SDKなし / アカウントなし
- [x] 開発者サーバーへの学習データ自動送信なし
- [x] `privacy.html` / `support.html`
- [x] `APP_STORE_METADATA_JA.md`
- [x] `APPLE_CONNECT_PACKET.md`
- [x] `TESTFLIGHT_NOTES_JA.md`
- [x] App Store本審査の自動提出禁止
- [ ] main反映後、Support / Privacy URLを未ログインHTTP 200で最終確認

## E. アイコン / スクリーンショット
- [x] Google Drive正本 `12_不動産鑑定士試験_短答式.png`
- [x] 1024×1024 RGB
- [x] SHA-256 `679f3493524dd2cf71126303c998b15395c70ff19f224d158a760ee3c2a395f1`
- [x] 正本PNGをAppIcon asset catalogへ原寸統合
- [x] CIでAppIcon SHAを永久監査
- [ ] signed `.app` / IPAでAppIcon最終確認
- [ ] App Store用スクリーンショット最終作成・選定

## F. Apple識別情報 / 課金 — HUMAN GATE
- [x] Team ID `MN3D2ZM44N`
- [x] Bundle ID `jp.allsunday1122.kanteishishortanswer`
- [x] Codemagic profile名 `kanteishishortanswer_appstore`
- [x] 月額自動更新サブスク + 無料24問を採用
- [x] 初回無料期間なし
- [ ] App Store Connect新規Appレコード作成
- [ ] Apple発行App Store Connect数値App IDを正本へ記録
- [ ] 月額サブスクリプションをApp Store Connectへ実登録
- [ ] 実登録Product IDを正本へ記録
- [ ] Codemagicへ実登録Product ID・署名接続を設定

## G. TestFlight — HUMAN GATE
- [ ] signed Archive / IPA
- [ ] App Store Connectへアップロード
- [ ] Internal Testingグループへ追加
- [ ] iPhone実機インストール
- [ ] 無料24問が購入なしで解ける
- [ ] 25問目以降がプレミアム制御される
- [ ] 月額サブスク購入 / 復元 / 再起動後権利維持
- [ ] 解約・失効時に無料24問へ戻る
- [ ] ホーム / 模試 / 記録 / 設定
- [ ] 年度別80問 / 年度×科目40問
- [ ] 通常学習 / 途中復帰 / 苦手復習
- [ ] 機内モード学習 / JSONバックアップ / 一次資料リンク
- [ ] 表39・40の読みやすさ
- [ ] クラッシュ / 表示崩れなし

## H. App Store本審査
- [ ] TestFlight実機確認完了
- [ ] App Privacy / 年齢評価 / Content Rights最終回答
- [ ] スクリーンショット登録
- [ ] Review Notes / 連絡先 / 配信地域
- [ ] **ユーザーが明示承認するまで Add for Review / Submit for Review を実行しない**
