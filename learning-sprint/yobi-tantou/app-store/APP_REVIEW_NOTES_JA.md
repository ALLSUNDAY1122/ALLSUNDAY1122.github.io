# App Review Notes｜司法試験予備試験・短答式｜学びスプリント

更新: 2026-08-14
状態: DRAFT / External Beta App Review・App Store本審査への提出は禁止

## 審査担当者向け説明案

本アプリは司法試験予備試験・短答式の学習支援アプリであり、法務省その他の公的機関の公式アプリではありません。

アカウント登録・ログインはありません。学習履歴、苦手状態、設定等は端末内に保存されます。第三者広告・分析SDK・独自サーバーへの学習データ送信はありません。

初回は「今日のスプリント」を最大8問まで利用できます。これはサブスクリプションの無料トライアルではありません。プレミアムは月額のAuto-Renewable Subscriptionとして実装し、分野別演習、模試、苦手復習等を解放します。日本向け基準価格は標準手順v2.4に従い200円/月ですが、アプリ内には価格文字列を固定せず、StoreKit `Product.displayPrice` を表示します。

Bundle IDは `jp.allsunday1122.yobishikentantou`。planned Product IDは `jp.allsunday1122.yobishikentantou.monthly` です。App Store Connectへ同一Product IDを実登録して取得確認するまではruntime設定を空のままにし、購入導線をfail-closedにします。

購入・復元はStoreKit 2を利用し、verified transactionかつProduct ID一致・未取消の現在権利だけをPremiumとして扱います。StoreKitから取得した商品種別がAuto-Renewable Subscriptionでない場合は商品を採用しません。

正式教材データはオフライン利用できるようアプリに同梱します。正式教材へ収録する問題は一次資料、正答、法令基準日、利用条件を監査したものだけとし、監査未完了問題はReleaseバンクへ入らない構造にしています。

## 審査時の確認手順案

1. アプリを起動する。
2. ホーム画面で4タブ（ホーム／模試／記録／設定）を確認する。
3. 「今日のスプリント」を開始し、解答→解説→次問の導線を確認する。
4. 「わからない」記録、途中再開、学習記録を確認する。
5. 設定画面で学習データのJSON書き出し／読み込みを確認する。
6. App Store Connect上のSandbox契約を行い、プレミアム機能の解放を確認する。
7. 「購入を復元」を実行し、同じApple Accountの有効契約資格が復元されることを確認する。
8. Sandboxで契約期限切れ・取消を再現し、Premiumが維持されないことを確認する。

## 重要な非公式表示

- 本アプリは法務省その他の公的機関の公式アプリではありません。
- 法務省のCBT体験版の画面・画像・操作素材は使用していません。

## Review提出前の差し込み項目

- Bundle ID: `jp.allsunday1122.yobishikentantou`（確定）
- App Store Connect Apple ID: 実発行値待ち
- IAP Product ID: planned `jp.allsunday1122.yobishikentantou.monthly`。App Store Connect実登録一致確認後に最終固定
- サブスクリプショングループ: App Store Connect作成時の実値
- Review用連絡先: App Store Connect側でユーザーが入力
- 正式教材の収録内容: 417題完成・監査後の実値だけを記載
- 特殊採点・訂正がある年度: 最終教材とサポートページへ反映後に記載

## 提出ゲート

このファイルが完成していても、次の条件を満たすまでExternal Beta App Review／App Store本審査へ提出しない。

- 正式3回分canonical化と全監査PASS
- 正本AppIcon SHA一致
- App Store Connect Apple ID実発行値、IAP実登録一致、署名profile確定
- StoreKit Sandbox実機確認
- Internal TestFlight実機確認
- ユーザーの明示承認
