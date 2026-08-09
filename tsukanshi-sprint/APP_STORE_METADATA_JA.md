# 通関士｜学びスプリント App Store Metadata（ja-JP）

更新日: 2026-08-09

## 固定識別子
- App名: 通関士｜学びスプリント
- Bundle ID: `jp.allsunday1122.tsukanshi`
- Version: `1.0.0`
- 初回Build: `1`（配布ビルドではCIのBuild番号へ更新）
- In-App Purchase: `jp.allsunday1122.tsukanshi.premium`
- IAP種別: Non-Consumable / 買い切り
- SKU: `tsukanshi-sprint-ios`

## App Store表示
### 名前
通関士｜学びスプリント

### サブタイトル
8問ずつ、通関士試験を反復

### プロモーションテキスト
通勤や休憩時間に8問ずつ。法令知識から計算・申告書演習まで、短い反復を積み重ねる通関士試験対策アプリです。

### 説明
通関士試験の学習を、毎日続けやすい短い単位にまとめた「学びスプリント」です。

【主な機能】
・今日のスプリント：4問／8問／16問から学習量を設定
・独自学習問題480問：通関業法、関税法等、通関実務を分野別に反復
・計算演習：式 → 代入 → 答えの順で確認
・申告書演習12セット：資料から必要事項を読み取る独自演習
・苦手復習：誤答や「わからない」を記録し、連続正解で克服
・学習記録：達成度、分野別進捗、5週間の学習履歴を表示
・試験日設定：残日数と未学習問題の目安を表示
・JSON書き出し／読み込み：学習データを手動でバックアップ

【過去問題について】
アプリ内の模試は監査済みの独自問題です。第59回・第58回・第57回の公式問題本文は転載せず、税関ホームページの公式問題ページを外部ブラウザで確認できる導線を設けています。

【教材方針】
2026年7月1日現在で施行されている法令等を基準に、税関・財務省などの一次情報を確認して独自に作成・監査しています。

本アプリは税関・財務省の公式アプリではありません。制度・法令の最新情報は必ず公式情報もご確認ください。

### キーワード候補
通関業法,関税法,通関実務,資格試験,一問一答,関税,貿易,輸入,輸出

上記はUTF-8で100バイト以内。App名に含まれる「通関士」はキーワードでは重複させない。

## カテゴリ候補
- Primary: Education
- Secondary: Reference

## URL
- Support URL: `https://allsunday1122.github.io/tsukanshi-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/tsukanshi-sprint/privacy.html`
- Marketing URL: 任意。初回は未設定可。

## App Privacy案
実装確認時点:
- 開発者独自のアカウント: なし
- 広告: なし
- 第三者解析SDK: なし
- トラッキング: なし
- 開発者サーバーへの学習データ自動送信: なし
- StoreKit: Appleが購入処理。アプリは購入権利状態を利用。
- 学習状態: 端末内localStorage / UserDefaultsに保存

App Store Connectでは実装と一致する回答を入力し、提出直前に再監査する。

## 年齢制限指定
App Store Connectの現行アンケートを実装どおり回答してAppleの算出値を採用する。Kidsカテゴリには設定しない。

現行実装に、暴力、性的内容、恐怖表現、ギャンブル、ルートボックス、ユーザー生成コンテンツ、チャット、広告はない。

## Content Rights
- アプリ内教材: 独自作成・一次情報根拠
- 第59〜57回公式問題: 本文をアプリに同梱しない。税関公式ページへの外部リンクのみ。
- 実務別冊に含まれるWCO由来資料: アプリへ転載しない。
- `past-exam-rights-audit-59-57.md` を権利監査記録とする。

## IAP登録案
- Reference Name: `通関士 プレミアム解放`
- Product ID: `jp.allsunday1122.tsukanshi.premium`
- Type: Non-Consumable
- Display Name: `プレミアム解放`
- Description: `模擬試験・苦手復習・申告書演習などのプレミアム機能を買い切りで解放します。`
- Price: App Store Connectで正式設定後、StoreKit表示価格と実機で一致確認する。
- App Review Screenshot: Sandbox動作確認後に作成。

## 申請入力票
App Store Connect / Codemagicで人が入力する固定値は `APPLE_CONNECT_PACKET.md` を正本とする。

## 申請時に人が確定する項目
- App Store Connect App ID
- IAP価格
- Paid Apps Agreement / 税務・銀行情報の状態
- App Review連絡先
- 年齢制限アンケートの最終回答
- 配信地域
- スクリーンショット最終選定
