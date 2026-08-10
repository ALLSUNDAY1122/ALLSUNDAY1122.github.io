# RELEASE CHECKLIST｜薬剤師国家試験｜学びスプリント

## ChatGPT自動ループ
- [x] Notion 標準手順 v2.2／申請手順／UI Master v2.1／資格正本を再確認
- [x] Bundle ID `jp.allsunday1122.yakuzaishi`を維持
- [x] App Store Connect App ID `6799753724`を維持
- [x] Codemagic profile正本名 `yakuzaishi_appstore`を維持
- [x] 1,035問問題監査／採点対象1,031／blocked 0
- [x] SwiftUIネイティブ化。`WKWebView`を学習UIから除外
- [x] 標準8問、4／8／16問設定
- [x] 4タブ：ホーム／模試／記録／設定
- [x] 即時採点／「わからない」／苦手登録
- [x] 苦手3連続正解で卒業
- [x] 中断→続きから
- [x] 35マスヒートマップ
- [x] 達成度をユニーク着手率、正答率を別指標として実装
- [x] 不正解でも当日回答数を加算してヒートマップへ反映
- [x] JSON書き出し／読み込み
- [x] 問題・図版をアプリ内同梱するオフライン設計
- [x] Reduce Motion対応
- [x] StoreKit 2 月額＋買い切り
- [x] `currentEntitlements`／`Transaction.updates`／pending／cancel／restore／manage subscriptions
- [x] 価格は`Product.displayPrice`。コードへ固定価格を書かない
- [x] Intro OfferはApp Store設定＋eligibilityが成立した場合のみ無料体験表示
- [x] 無料90問／プレミアム1,031問ゲート
- [x] Privacy Manifest（tracking false / collected data [] / accessed API []）
- [x] Support／Privacy／Terms公開ファイル
- [x] AppIcon正本のDrive ID・寸法・RGB・SHA-256固定
- [x] ネイティブ問題資産生成：1,035／採点対象1,031／無料90／媒体154／multiple accepted 3
- [x] Swift構文・XcodeGen・IAP capability監査
- [x] XCTest PASS
- [x] Release iOS Simulator build PASS
- [x] ユーザー実機指摘「達成度・5週間学習」のXCTest回帰テスト化
- [x] Codemagic `pharmacist-ios`をSwiftUIネイティブ用へ更新
- [x] `submit_to_app_store: false`／Internal TestFlight onlyを維持

## 最新PRゲート
- [x] PR #4128 最新コミットでStatic Gateを再PASS
- [x] PR #4128 最新コミットでXCTestを再PASS
- [x] PR #4128 最新コミットでRelease Simulator buildを再PASS
- [x] PR #4128 をmainへ統合

## Apple / App Store Connect / Codemagic側で確認する項目
- [ ] Explicit App ID `jp.allsunday1122.yakuzaishi` が有効
- [ ] App Store Connect App ID `6799753724` がBundle IDと一致
- [ ] Paid Apps Agreement／税務／銀行情報が有料販売に必要な状態
- [ ] Subscription Group「薬剤師国家試験 プレミアム」を確認／設定
- [ ] `jp.allsunday1122.yakuzaishi.monthly` をAuto-Renewable Subscriptionとして確認／設定
- [ ] 月額の価格をApp Store Connectで決定（コードへ固定しない）
- [ ] 必要なら月額へIntroductory Offer / Free Trial 1 Weekを設定
- [ ] `jp.allsunday1122.yakuzaishi.lifetime` をNon-Consumableとして確認／設定
- [ ] 買い切り価格をApp Store Connectで決定（コードへ固定しない）
- [ ] 両商品のローカライズ・審査用情報を設定
- [ ] Codemagic App Store Connect integration `codemagic` を確認
- [ ] Codemagic provisioning profile `yakuzaishi_appstore` と対応するApple Distribution証明書を確認
- [ ] `pharmacist-ios` workflowを実行し、署名付きIPAをInternal TestFlightへ送信

## Internal TestFlight人間確認
- [ ] 起動／クラッシュなし
- [ ] WebViewシェルではなくSwiftUIネイティブ画面で起動
- [ ] 無料状態：第111回必須90問のみ
- [ ] 4／8／16問スプリント
- [ ] 選択肢タップで即時採点
- [ ] 「わからない」で苦手登録
- [ ] 中断→続きから。回答済み問題を二重加算しない
- [ ] 苦手3連続正解で卒業
- [ ] 0問正解でも、回答した問題分だけ達成度の着手数が進む
- [ ] 0問正解でも、5週間ヒートマップの当日セルへ回答数が反映
- [ ] 記録：未着手は`—`、着手済み0%は`0%`
- [ ] 35マスヒートマップの今日枠・色階調
- [ ] 通常テキスト問題
- [ ] 公式画像問題
- [ ] 任意2肢正答3問
- [ ] 症例共有文
- [ ] 月額価格がStoreKit表示価格
- [ ] 無料体験はeligible時だけ表示
- [ ] 月額購入／cancel／pending
- [ ] 買い切り購入
- [ ] 購入復元
- [ ] 再起動後の権利維持
- [ ] プレミアムで採点対象1,031問・9区分解放
- [ ] サブスクリプション管理導線
- [ ] JSONバックアップ書き出し／読み込み
- [ ] 機内モードで教材・図版・記録が利用可能
- [ ] 文字サイズ16／18／20
- [ ] Reduce Motion ONで不要な進捗アニメーションが抑制
- [ ] iPhone portraitで横はみ出し・レイアウト崩れなし

## 今回の停止地点
Internal TestFlightの実機確認までが対象。本審査への提出は行わない。

`Add for Review` / `Submit for Review`は実行しない。`submit_to_app_store: false`を維持する。
