# App Store Metadata｜理学療法士国家試験｜学びスプリント

## 表示情報
- App Store表示名：理学療法士国家試験｜学びスプリント
- サブタイトル候補：国試3回の範囲を8問ずつ反復
- Primary language：Japanese
- Primary category候補：Education
- Version：1.0.0
- Bundle ID：`jp.allsunday1122.rigakuryouhoushi`
- SKU：`rigakuryouhoushi-ios-001`
- サインイン：不要
- アカウント登録：なし
- 広告：なし
- 解析SDK：なし
- 独自クラウド同期：なし
- 学習データ：端末内保存＋利用者操作によるJSON書き出し/復元

## 課金正本
- 方式：自動更新サブスクリプション（月額）
- Product ID：`jp.allsunday1122.rigakuryouhoushi.monthly`
- 日本向け価格方針：月額200円
- アプリ内価格表示：StoreKit `Product.displayPrice` のみを使用し、固定価格文字列を持たない
- 無料版：8分野から決定的に選定した60問
- 月額プラン：全600問、第58〜60回ベース模試、全苦手復習
- 回答方法・正答判定・解説品質は無料/有料で変えない
- 購入復元：常設
- App Store Connectの商品登録・販売地域・価格設定は実登録後に最終確認する

## 外部正本待ち（推測禁止）
- App Store Connect Apple ID：Apple実発行待ち
- Copyright owner：未確定
- AppIcon：Drive正本 `15_理学療法士国家試験.png` を採用。GitHubへの正本PNG本体投入は未完。
- 公開してよいサポート問い合わせ先：未承認

## 公開URL
- Support：https://allsunday1122.github.io/rigaku-sprint/support.html
- Privacy：https://allsunday1122.github.io/rigaku-sprint/privacy.html
- Terms：https://allsunday1122.github.io/rigaku-sprint/terms.html
- Settingsから上記3ページへの導線：実装済み
- 3ページはmainへ独立公開済み。GitHub Pagesのデプロイ完了後にHTTP表示を最終確認する。

## App Store説明文案
理学療法士国家試験の学習を、毎日4・8・16問の短い反復へ分けて進める試験対策アプリです。

第60回・第59回・第58回の各200枠、合計600枠の出題範囲と公式採点情報を確認し、問題文・選択肢・解説は一次資料や診療ガイドライン等で内容を監査したうえで独自に再構成しています。間違えた問題と「わからない」を苦手へ戻し、3回連続正解で苦手から卒業します。

無料版では8分野から選んだ60問を利用できます。月額プランでは全600問、第58〜60回ベース模試、全苦手復習を利用できます。課金の有無で、利用できる問題そのものの回答・解説品質は変わりません。

主な機能：
- 標準8問の短時間スプリント（4／8／16問に変更可能）
- 解剖学・生理学・運動学・理学療法など分野別演習
- 第58〜60回ベース模試（月額プラン）
- 誤答・「わからない」の苦手自動記録
- 3回連続正解で苦手卒業
- 中断・途中再開
- 5週間の学習ヒートマップ
- 分野別正答率
- 試験日と1日あたり学習目安
- 学習データのJSON書き出し・復元
- 教材本体のオフライン利用

ベース模試は各回200枠の構成と公式配点をもとに集計しますが、公式試験問題の完全な再現ではありません。第三者権利が未解決の公式図版は収録せず、該当論点を文章問題へ再構成しています。厚生労働省が採点対象外とした枠は得点へ算入しません。

本アプリは厚生労働省の公式アプリではありません。また、国家試験の学習補助を目的とし、診断、治療、リハビリテーション実施その他の医療上の判断を提供するものではありません。

## キーワード候補
理学療法士,国家試験,国試,理学療法,PT,解剖学,生理学,運動学,資格,学習

## App Reviewメモ案
- SwiftUIネイティブ。WKWebView/UIWebViewを学習UIに使用しない。
- サインイン・アカウント登録・広告・解析SDK・独自クラウド同期なし。
- 学習状態は端末内に保存し、利用者操作時のみJSONバックアップを書き出し/復元する。
- 第60・59・58回の各200枠、計600枠を収録。公式採点の除外6枠、複数正答14枠は別の正答・採点台帳で管理。
- 権利未解決の第三者図版66枠は原図を収録せず、独自の文章問題へ再構成。
- ベース模試は公式配点を再現するが、問題文・図版は独自再構成であり、公式問題の完全複製ではない。
- PrivacyInfo.xcprivacyを同梱。現行実装は追跡・広告・解析なし、開発者によるデータ収集なし。
- SettingsからSupport / Privacy Policy / Termsへ直接到達できる。
- 自動更新サブスクリプション Product ID：`jp.allsunday1122.rigakuryouhoushi.monthly`。
- 無料60問。購読中は全600問、3回分ベース模試、全苦手復習を解放する。
- StoreKit 2のverified entitlementかつ未取消・対象Product ID一致のみで権利を有効化する。
- 購入・復元導線を常設し、価格表示は `Product.displayPrice` のみを使用する。

## 提出前確認
- 表示名・サブタイトルはApp Store Connectの現行文字数制限内で再検証する。
- Description、Keywords、Support/Privacy URL、年齢区分、App Privacy回答は提出時の実装と一致させる。
- App Store Connectで月額商品の登録、販売地域、日本向け価格、審査情報を確認する。
- Internal TestFlightで購入・復元・pending・cancel・期限切れ/失効時の権限制御を実機確認する。
