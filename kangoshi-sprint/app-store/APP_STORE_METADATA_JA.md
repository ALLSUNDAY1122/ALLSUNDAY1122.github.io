# 看護師国家試験｜学びスプリント — App Store Metadata

更新: 2026-08-15

## 固定識別情報
- Version: `1.0.0`
- Bundle ID: `jp.allsunday1122.kangoshi`
- App Store Connect Apple ID: **未発行・推測禁止**
- IAP: 月額200円 自動更新サブスクリプション
- Product ID: `jp.allsunday1122.kangoshi.monthly`（App Store Connect実登録待ち）
- Distribution: Internal TestFlight → 人間実機確認後に本審査判断

## 日本語メタデータ
- App名: `看護師国試 学びスプリント`
- サブタイトル: `3年分720問を短時間で反復`
- Primary Category: `Education`
- Secondary Category: `Medical`
- 年齢区分想定: `4+`（App Store Connect質問票の実回答を優先）
- 著作権: `© 2026 Kohei Morita`
- Support URL: `https://allsunday1122.github.io/kangoshi-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/kangoshi-sprint/privacy.html`
- Marketing URL: `https://allsunday1122.github.io/kangoshi-sprint/`

### プロモーションテキスト
必修・一般・状況設定を、今日の短いスプリントで反復。3回連続正解で苦手を卒業し、本番形式まで一つのアプリで進められます。

### 説明
看護師国家試験の過去3回分、第115・114・113回を学習用に整理した問題演習アプリです。

収録は720問。必修150問、一般390問、状況設定180問（60症例）を、短時間で繰り返し学べます。

主な機能:
- 今日のスプリント: 4・8・16問から学習量を設定
- 必修・一般・状況設定のお試し問題
- 苦手復習: 3回連続正解で苦手から卒業
- 分野別学習
- 第115・114・113回の本番形式
- 学習履歴・正答率・苦手一覧
- 図表・模式図を含む問題に対応
- 公式採点上の除外・複数正答などの特殊採点を反映

無料版では今日の学習と各区分のお試し問題、基本的な学習記録を利用できます。プレミアムでは苦手復習、分野別学習、本番形式、詳細記録を利用できます。

制度・統計・ガイドラインなど更新が必要な項目は一次資料を確認して整備しています。本アプリは厚生労働省その他の公的機関が提供・承認する公式アプリではありません。

### キーワード
`看護師,国家試験,国試,過去問,必修,一般問題,状況設定,看護,勉強,模試`

## App Privacy 整合メモ
現行実装では開発者サーバーへの個人データ送信、広告、解析、ログイン、位置情報、カメラ、マイク、連絡先、独自クラッシュ収集を使用しない。学習記録は端末内UserDefaults。課金はApple StoreKit 2。App Store Connectの質問票は実装変更がないことを再確認して回答する。

## 輸出コンプライアンス
`ITSAppUsesNonExemptEncryption = NO` を実装済み。App Store Connect上の実質問に対して最終回答する。
