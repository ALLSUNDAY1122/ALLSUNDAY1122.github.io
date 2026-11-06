# App Store Connect｜月額サブスクリプション正本

対象：理学療法士国家試験｜学びスプリント
更新基準日：2026-08-14

## Appレコード
- Platform：iOS
- Primary language：Japanese
- Bundle ID：`jp.allsunday1122.rigakuryouhoushi`
- SKU：`rigakuryouhoushi-ios-001`
- App Store Connect Apple ID：Appレコード作成後の実発行値のみ記録する

SKUは内部管理用でユーザーには表示されない。App Store ConnectでAppレコードを作成した後は変更できないため、この値を正本として固定する。

## Subscription Group
- Reference name：`rigakuryouhoushi-manabi-sprint`
- グループ数：1
- 方針：同一サービスに複数グループを作らない

## Auto-Renewable Subscription
- Reference name：`rigakuryouhoushi-monthly-200`
- Product ID：`jp.allsunday1122.rigakuryouhoushi.monthly`
- Display name（ja-JP）：`月額プラン`
- Duration：1 month
- 日本向け価格方針：月額200円
- Availability：初回はApp Store Connectで配信対象地域を確認して設定
- Introductory Offer：初回リリースでは設定しない。別途明示承認がある場合のみ追加する
- Family Sharing：初回リリースでは有効化しない

## 月額プランで提供する価値
無料版：
- 8分野から決定的に選定した60問
- 4 / 8 / 16問スプリント
- 無料60問内の分野別演習
- 学習記録・ヒートマップ・JSONバックアップ

月額プラン：
- 全600問
- 第58・59・60回ベース模試（各200問）
- 全苦手復習
- 今後の新試験回・医療情報更新を継続提供する前提

無料/有料で、同じ問題の正答判定・解説品質を変えない。

## App内表示の必須条件
購入を促す画面では、以下を同じ購入導線で確認できる状態にする。
- 商品名：月額プラン
- 期間：1か月
- 利用できる内容：全600問・第58〜60回ベース模試・全苦手復習
- 実際の請求価格：StoreKit `Product.displayPrice`
- 1か月ごとの自動更新であり、解約まで継続する旨
- 購入の復元
- プライバシーポリシーへの機能するリンク
- 利用条件への機能するリンク
- Apple Accountから購読を管理・解約できる旨

価格文字列 `200円` を購入ボタンへ直接ハードコードしない。App Store Connectで設定された価格を正とする。

## App Review用
- 初回の自動更新サブスクリプションはアプリの新バージョンと同時に審査へ提出する。
- Review Informationに、無料60問と購読後600問の違い、購入導線、復元導線を具体的に記載する。
- 購入・復元・pending・cancel・権利失効をInternal TestFlight / Sandboxで確認する。

## 一次資料
- Apple App Store Connect Help：Offer auto-renewable subscriptions
- Apple App Store Connect Help：Manage pricing for auto-renewable subscriptions
- Apple App Review Guidelines 3.1.2
- Apple Auto-renewable Subscriptions guidance
