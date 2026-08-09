# Release Checklist｜司法書士 学びスプリント v1.0.0

## 自動ゲート
- [ ] 210問共通validator PASS
- [ ] Apple preflight PASS
- [ ] 正本AppIcon SHA-256 PASS
- [ ] Native StoreKit UI実ブラウザ監査 PASS
- [ ] macOS/Xcode Release Simulator build PASS
- [ ] 生成`.app`に210問・native-storekit・Privacy Manifestを同梱
- [ ] R7午後33 `all_correct`維持
- [ ] Privacy / Support公開ページ
- [ ] 固定価格表記なし
- [ ] TestFlight/App Store自動提出OFF
- [ ] 辛口レビュー3回 PASS

### AppIcon搬送の扱い
Google Drive正本は `10_司法書士試験_択一式.png`、SHA-256 `c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506` を唯一の合格値とする。匿名Drive downloadが中間レスポンスを返すため、正本バイト未取得をRelease PASSとして扱わない。Simulatorのコンパイル確認だけは `SHOSHI_ICON_MODE=simulator-placeholder` を許可するが、これはTestFlight/Archiveへ使用禁止。

## Apple側の外部ゲート
- [ ] App Store Connect新規App `司法書士 学びスプリント`
- [ ] Bundle ID `jp.allsunday1122.shoshi`
- [ ] SKU `shoshi-sprint-ios`
- [ ] Non-Consumable `jp.allsunday1122.shoshi.premium`
- [ ] 正式価格設定
- [ ] IAP Review Screenshot登録
- [ ] Codemagic署名プロファイル取得
- [ ] 署名済みIPA作成・アップロード
- [ ] Internal TestFlightへ追加

## 人間確認点
- [ ] iPhone実機にTestFlight版をインストール
- [ ] 無料8問
- [ ] 科目・模試ロック
- [ ] Sandbox購入
- [ ] キャンセル
- [ ] pending
- [ ] 再起動後の購入維持
- [ ] 購入復元
- [ ] オフライン演習
- [ ] R7午後33全員正答
- [ ] 長文問題のUI/ホーム導線

**正本AppIcon未PASSおよび上記実機項目未PASSの状態でApp Store提出へ進まない。**
