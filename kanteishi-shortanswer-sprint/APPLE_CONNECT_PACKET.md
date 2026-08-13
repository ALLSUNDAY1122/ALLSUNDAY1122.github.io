# 不動産鑑定士｜学びスプリント App Store Connect / TestFlight 入力票

更新日: 2026-08-13

このファイルはApple登録時に使う入力票です。秘密鍵・Issuer ID・Key ID・証明書・パスワード・2FAコードはGitHubへ保存しません。

## 0. Release Gate — Apple識別情報

最上位Notion正本 `【正本】対象アプリ識別情報｜App Store Connect / Codemagic` に、2026-08-13現在 **#12の行が存在しない**。

現行iOS実装には次の値が入っているが、Apple側登録へ使用する前にユーザー確認と最上位正本への登録を必須とする。

- Apple Team ID: `MN3D2ZM44N`（共通設定として最上位正本に記載済み）
- Bundle ID候補 / 現行実装値: `jp.allsunday1122.kanteishishortanswer`
- App Store Connect App ID: 未発行・推測禁止
- Codemagic profile: 未確定・推測禁止
- IAP Product ID: 未設定・推測禁止

**このGateを通過するまでExplicit App ID作成、App Store Connect新規App作成、署名付き配布、TestFlight送信を実行しない。**

## 1. 新規Appレコード案
- Platform: iOS
- Name: `不動産鑑定士｜学びスプリント`
- Primary Language: Japanese (Japan)
- Bundle ID: 上記Release Gate確定後の値
- SKU案: `kanteishi-shortanswer-sprint-ios`
- User Access: Full Access（特別な制限が必要な場合のみ変更）
- Version: `1.0.0`
- Build: `1`から開始し、配布ビルドではCI側で一意化する

App Store Connect App IDはAppleが発行した実値だけをNotion最上位正本とこのファイルへ記録する。

## 2. App Store表示
- Subtitle案: `公式過去問240問を8問ずつ`
- Primary Category: Education
- Secondary Category: Reference
- Support URL: `https://allsunday1122.github.io/kanteishi-shortanswer-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/kanteishi-shortanswer-sprint/privacy.html`
- Marketing URL: 初回は空欄可

説明文・キーワード等は `APP_STORE_METADATA_JA.md` を使用する。

## 3. App Privacy / Content Rights
現行実装の申告案:
- Tracking: No
- Third-party advertising: No
- Third-party analytics SDK: No
- Developer account/login: No
- 学習データの開発者サーバー自動送信: No
- 学習状態: 端末内保存
- JSONバックアップ: ユーザーが手動操作した場合のみファイルへ書き出し／読み込み
- StoreKit: Product ID未設定。初回版で採用する場合は別途再監査
- 公式問題: 国土交通省公表資料をPDL1.0に基づき構造化して同梱
- 第三者権利要確認: 0件
- 一次資料リンク: 外部ブラウザで国土交通省ページを開く

提出直前の最終バイナリで再監査する。

## 4. App Icon
学びスプリント正本資産を使用する。
- Google Drive file: `12_不動産鑑定士試験_短答式.png`
- Drive file ID: `1wnnkFkere2-9OKXYSG3T_bS6NqS3xWMX`
- 1024×1024 / RGB
- 一覧画像からの切り出しや新規生成はしない

GitHubコネクタではバイナリPNGを書き込めないため、Xcode Assetsへの原寸PNG配置は配布署名前の残タスクとして管理する。

## 5. TestFlight方針
- Distribution: App Store
- TestFlight: Internal Testing only
- App Store本審査への自動提出: 禁止
- 外部Beta App Review: 初回は使用しない

署名・アップロード前にWindows/Linux/macOS CIで落とせる不具合をすべて排除する。

## 6. TestFlight実機合格条件
- インストール・初回起動
- ホーム／模試／記録／設定の表示
- 今日のスプリントが公式240問から出題される
- 5択表示
- 年度別80問模試を開始できる
- 年度×行政法規40問／鑑定理論40問を開始できる
- 「わからない」・誤答・苦手登録・3連続正解解除
- 中断復帰
- 記録・5週間ヒートマップ
- JSONバックアップ書き出し／読み込み
- 国土交通省一次資料リンク
- 機内モードで問題学習可能
- クラッシュなし
- 主要画面の表示崩れなし
- Dynamic Island / Safe Area / ホームインジケータ周辺の崩れなし

## 7. 人の操作が必要な停止点
1. #12 Bundle IDを最上位Notion正本へ確定登録
2. Appleログイン / 2FA / 契約同意
3. Explicit App ID / App Store Connect Appレコード作成
4. Apple発行のApp Store Connect App IDを記録
5. Codemagic等の署名接続に秘密情報を入力
6. 初回signed IPA / TestFlight処理のApple側確認
7. iPhoneでTestFlight実機確認
8. 本審査 `Add for Review` / `Submit for Review` 直前の最終承認

IAPを初回版へ含める場合のみ、Product ID・価格・Sandbox購入/復元を別の人間確認項目として追加する。
