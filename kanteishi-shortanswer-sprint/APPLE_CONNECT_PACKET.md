# 不動産鑑定士｜学びスプリント App Store Connect / TestFlight 入力票

更新日: 2026-08-14

このファイルはApple登録時に使う入力票です。秘密鍵・Issuer ID・Key ID・証明書・パスワード・2FAコードはGitHubへ保存しません。

## 0. Release Gate — Apple識別情報

最上位Notion正本 `【正本】対象アプリ識別情報｜App Store Connect / Codemagic` に#12を登録済み。

- Apple Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- App Store Connect App ID: Apple発行待ち・推測禁止
- Codemagic profile: `kanteishishortanswer_appstore`
- 課金方式: 月額200円基準・自動更新サブスクリプション
- planned IAP Product ID: `jp.allsunday1122.kanteishishortanswer.monthly200`
- runtime Product ID: App Store Connect実登録確認までは未設定

Bundle IDは標準手順v2.5に基づき確定済みで、ユーザー確認ゲートではない。Appleが発行する数値App IDと実際に登録したIAP Product IDだけは推測せず、実値を取得後に正本化する。

## 1. 新規Appレコード

- Platform: iOS
- Name: `不動産鑑定士｜学びスプリント`
- Primary Language: Japanese (Japan)
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- SKU: `kanteishi-shortanswer-sprint-ios`
- User Access: Full Access
- Version: `1.0.0`
- Build: CI/Codemagic側で一意化

App Store Connect App IDはAppleが発行した実値だけをNotion最上位正本とこのファイルへ記録する。

## 2. App Store表示

- Subtitle: `公式過去問240問を8問ずつ`
- Primary Category: Education
- Secondary Category: Reference
- Support URL: `https://allsunday1122.github.io/kanteishi-shortanswer-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/kanteishi-shortanswer-sprint/privacy.html`
- Marketing URL: 初回は空欄可

説明文・キーワード等は `APP_STORE_METADATA_JA.md` を使用する。

## 3. 課金・無料範囲

### 無料版
- canonical 240問のうち24問
- 3年度×2科目の6セルごとに4問
- 各セル内で可能な限り分野を分散
- 今日のスプリント、分野学習、年度×科目学習、苦手復習は無料24問の範囲内だけを使用
- 年度別80問模試はロック

### プレミアム
- 自動更新サブスクリプション
- 日本向け基準価格: 月額200円
- アプリ内価格文字列は固定せずStoreKit `Product.displayPrice` を使用
- 全240問
- 年度×科目40問演習
- 年度別80問模試
- 初回無料期間: 標準では設定しない

### IAP登録
- planned Product ID: `jp.allsunday1122.kanteishishortanswer.monthly200`
- App Store Connectで同一IDを実登録できたことを確認してから実値として正本化
- StoreKit 2
- verified transaction・対象Product ID一致・未取消の場合だけ権利解放
- 購入復元必須
- pending / cancelled / unverified / revoked は権利を解放しない

## 4. App Privacy / Content Rights

現行実装の申告案:
- Tracking: No
- Third-party advertising: No
- Third-party analytics SDK: No
- Developer account/login: No
- 学習データの開発者サーバー自動送信: No
- 学習状態: 端末内保存
- JSONバックアップ: ユーザーが手動操作した場合のみファイルへ書き出し／読み込み
- StoreKit 2: 自動更新サブスクリプションを使用
- 公式問題: 国土交通省公表資料をPDL1.0に基づき構造化して同梱
- 第三者権利要確認: 0件
- 一次資料リンク: 外部ブラウザで国土交通省ページを開く

提出直前の最終バイナリで再監査する。

## 5. App Icon

学びスプリント正本資産を使用し、製品Assetsへ統合済み。

- Google Drive file: `12_不動産鑑定士試験_短答式.png`
- Drive file ID: `1wnnkFkere2-9OKXYSG3T_bS6NqS3xWMX`
- 1024×1024 RGB PNG / 668,457 bytes
- SHA-256: `679f3493524dd2cf71126303c998b15395c70ff19f224d158a760ee3c2a395f1`
- Git blob SHA: `6a12f42e3168a38bd419ed648ea08158176a0d9c`
- `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` へ統合済み
- 旧Base64分割搬送は削除済み
- 永久SHA監査あり

一覧画像からの切り出しや再生成は禁止。

## 6. Codemagic / TestFlight方針

- Distribution: App Store
- TestFlight: Internal Testing only
- App Store本審査への自動提出: 禁止
- 外部Beta App Review: 初回は使用しない
- Codemagic signing: `distribution_type: app_store` + Bundle IDで一致する署名資産を使用
- `xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'`
- publishing: `submit_to_testflight: true`
- publishing: `submit_to_app_store: false`
- Product IDはApp Store Connect実登録後の値をRelease buildへ注入し、通常CIでは空のままにする

Apple側Appレコード作成、App Store署名資産、App Store Connect連携が揃うまで署名付き配布は開始しない。

## 7. TestFlight実機合格条件

- インストール・初回起動
- 正本App Icon表示
- ホーム／模試／記録／設定の表示
- 無料状態で24問だけが利用可能
- 年度×科目ごとに無料4問が利用可能
- 無料状態で年度別80問模試がロックされる
- App Storeから月額プランの実価格が表示される
- Sandbox/TestFlight購入でプレミアム解放
- 全240問が利用可能になる
- 年度別80問模試を開始できる
- 年度×行政法規40問／鑑定理論40問を開始できる
- 購入復元でプレミアム状態を回復できる
- 未検証・取消済み取引では解放しない
- 「わからない」・誤答・苦手登録・3連続正解解除
- 中断復帰
- 記録・5週間ヒートマップ
- JSONバックアップ書き出し／読み込み
- 国土交通省一次資料リンク
- 機内モードで既取得問題学習可能
- クラッシュなし
- 主要画面の表示崩れなし
- Dynamic Island / Safe Area / ホームインジケータ周辺の崩れなし

## 8. 人の操作が必要な停止点

1. Appleログイン / 2FA / 契約同意
2. App Store Connectで新規Appレコードを作成
3. Apple発行の数値App IDを取得
4. 月額サブスクリプションを作成し、Product ID実登録を確認
5. 必要な場合のみCodemagicのApp Store Connect連携・署名資産へ本人認証情報を入力
6. iPhoneでInternal TestFlight実機確認
7. App Store本審査 `Add for Review` / `Submit for Review` 直前の最終承認

秘密情報や2FAコードをGitHub / Notion / チャットへ保存しない。App Store本審査はユーザー明示承認まで実行しない。
