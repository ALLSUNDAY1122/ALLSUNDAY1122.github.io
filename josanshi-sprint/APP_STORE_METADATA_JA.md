# 助産師国家試験｜学びスプリント App Store Metadata（ja-JP）

更新日: 2026-08-14

## 固定識別子
- App名: 助産師国家試験｜学びスプリント
- Bundle ID: `jp.allsunday1122.josanshi`
- Version: `1.0.0`
- 初回Build: `1`（配布ビルドではCIのBuild番号へ更新）
- In-App Purchase: `jp.allsunday1122.josanshi.premium`
- IAP種別: Non-Consumable / 買い切り
- Codemagic workflow/profile: `josanshi_appstore`
- App Store Connect numeric App ID: Apple発行待ち・推測禁止
- SKU候補: `josanshi-sprint-ios`

## App Store表示
### 名前
助産師国家試験｜学びスプリント

### サブタイトル
8問ずつ、助産師国試を反復

### プロモーションテキスト
毎日4・8・16問。妊娠・分娩・産褥・新生児・地域母子保健・助産管理まで、短い反復と独自模試で積み上げる助産師国家試験対策アプリです。

### 説明
助産師国家試験の学習を、毎日続けやすい短い単位にまとめた「学びスプリント」です。

令和5年版の出題基準を学習設計の基準とし、基礎助産学、助産診断・技術学、地域母子保健、助産管理を横断する独自問題330問を収録しています。

【主な機能】
・今日のスプリント：4問／8問／16問から1日の目標を設定
・独自問題330問：4分野を反復
・独自模試3回：各110問（一般75問＋状況設定35問）
・状況設定：36の症例を複数設問で連結
・苦手復習：誤答や「わからない」を記録し、3回連続正解で復習対象から外す
・学習記録：達成度、分野別正答率、5週間の学習履歴、苦手一覧、直近の演習を表示
・試験日設定：残日数と必要な学習ペースの目安を表示
・文字サイズ、出題順、選択肢順を設定可能
・JSON書き出し／読み込み：学習データを手動でバックアップ

【無料で利用できる範囲】
4分野から15問ずつ、合計60問を「今日のスプリント」で反復できます。1日の目標設定、基本の学習進捗、試験日カウントダウンも利用できます。

【Premium】
App内の買い切りPremiumを購入すると、全330問、4分野別演習、苦手だけ復習、独自模試3回、詳細な学習記録、JSONバックアップ・復元を利用できます。価格はApp Storeから取得した金額を購入画面に表示します。

【教材方針】
問題・解説は、厚生労働省、こども家庭庁、e-Gov法令検索、専門学会・専門団体等の一次・権威資料を確認し、独自に作成・監査しています。公式試験問題の本文をそのまま収録することを基本方針としていません。

本アプリは厚生労働省その他の公的機関・学会・団体の公式アプリではありません。制度、法令、ガイドライン等は更新されることがあるため、重要な判断では最新の公式情報も確認してください。

本アプリは国家試験の学習補助を目的とし、診断、治療、妊娠・分娩管理その他の医療上の判断を提供するものではありません。

### キーワード候補
国試,助産学,母性,周産期,妊娠,分娩,産褥,新生児,母子保健,資格,学習

## カテゴリ候補
- Primary: Education
- Secondary: Reference

## URL
- Support URL: `https://allsunday1122.github.io/josanshi-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/josanshi-sprint/privacy.html`
- Terms URL: `https://allsunday1122.github.io/josanshi-sprint/terms.html`
- Marketing URL: 初回は未設定可

## App Privacy入力案
現行実装:
- 開発者独自アカウント: なし
- サインイン: なし
- 広告: なし
- 第三者解析SDK: なし
- トラッキング: なし
- 開発者サーバーへの学習データ自動送信: なし
- 学習履歴・苦手・設定: 端末内保存
- JSONバックアップ: 利用者が明示的に書き出し／読み込み
- StoreKit 2: Appleが購入処理。本アプリは検証済み購入権利とApp Storeの商品表示価格を機能解放に利用
- クレジットカード番号等の決済情報を本アプリが取得する実装: なし

App Store Connectでは提出直前の実装と一致する回答を入力し、Releaseビルドで再監査する。

## 年齢制限
App Store Connectの提出時点の質問票へ実装どおり回答し、Appleの算定値を採用する。Kidsカテゴリには設定しない。

## Content Rights
- 問題・解説: 独自作成
- 根拠: 公的機関・一次資料・専門学会等の現行資料を監査用に登録
- 公式試験問題: 原則として本文を直接転載しない
- JSOG CQ/Answer/図表、NCPRアルゴリズム図等の転載制限対象: 直接収録しない
- 330問・36症例のrights/source auditをCIで必須化

## IAP登録案
- Reference Name: `助産師国家試験 Premium解放`
- Product ID: `jp.allsunday1122.josanshi.premium`
- Type: Non-Consumable
- Display Name: `Premium解放`
- Description: `全330問、分野別演習、苦手復習、独自模試3回、詳細記録、バックアップ機能を買い切りで解放します。`
- Price: **未決定。App Store Connectで人間判断後に設定する。**
- App Review Screenshot: Sandbox/TestFlightで購入画面を実機確認後に作成

## App Reviewメモ案
- サインイン不要、アカウント登録なし、広告・解析なし。
- 無料状態では4分野×15問＝60問を「今日のスプリント」で利用可能。
- PremiumはApple StoreKit 2のNon-Consumableのみ。外部決済導線なし。
- 購入画面ではStoreKitから取得した`displayPrice`だけを価格表示に使用。
- 「購入を復元」操作では`AppStore.sync()`を実行し、検証済みのcurrent entitlementで機能を解放。
- 購入保留、ユーザーキャンセル、商品取得失敗をそれぞれUIで処理。
- Premiumでは全330問、分野別、苦手復習、模試3回、詳細記録、JSONバックアップを解放。
- アプリ内教材は330問・36症例を端末へ同梱し、監査済みバンクだけを読み込む。
- 本アプリは厚生労働省等の公式アプリではなく、医療上の判断を提供しない。

## 人間入力・Apple側作業として残る項目
- App Store ConnectでApp recordを作成し、Apple発行numeric App IDを正本へ記録
- IAP `jp.allsunday1122.josanshi.premium` の作成
- IAP価格
- Paid Apps Agreement / 税務・銀行情報の状態
- App Review連絡先
- 年齢制限質問票の最終回答
- 配信地域
- スクリーンショット最終選定
