# Scan Lab｜App Store Connect入力正本（Internal TestFlight用）

更新日: 2026-08-16

## 識別情報

- プラットフォーム: iOS
- App Store Connect表示名: `Scan Lab`
- iPhoneホーム画面表示名: `Scan Lab`
- 主言語: 日本語
- Bundle ID: `jp.allsunday1122.splatlab`
- Version: `1.0.0`
- 配布: Internal TestFlight only
- 本審査への自動提出: 禁止

## 公開URL / 連絡先

- Privacy Policy URL: `https://allsunday1122.github.io/splat-native-ios/privacy.html`
- Support URL: `https://allsunday1122.github.io/splat-native-ios/support.html`
- 公開問い合わせ先: `kohei3615@gmail.com`
- アプリ内のAccount画面から、ログイン前・ログイン後の双方でサポートとプライバシーポリシーへ到達できる。
- 本審査前に、統合・公開された上記2 URLがHTTPSで到達でき、最終buildと内容が一致することを確認する。

## TestFlight向け説明

iPhoneで撮影した静止物・シーンから端末内で3D Gaussian Splatを生成し、必要な場合だけ利用者の明示操作でクラウド保存・共有できる検証版です。ローカル撮影・端末内3D生成はログイン不要です。

D2ではメール認証、プロフィール、public / unlisted / private、ブラウザ共有URL、Map、Discover、いいね、報告、ブロック、非公開化、スキャン削除、アカウント削除を提供します。

## 実装と一致させる申告

- クラウド基盤: Supabase Auth / Database / Storage / Edge Functions。
- 広告・課金・行動解析SDK・クラッシュレポートSDK: なし。
- Camera: 使用する。
- Photos / Microphone / Notifications / Tracking: 使用しない。
- Location When In Use: `public` 投稿で利用者が「現在地を公開地点に設定」を押した場合だけ取得する。自動取得・自動送信しない。
- 独自の非免除暗号化: なし。`ITSAppUsesNonExemptEncryption = NO`。

## App Privacy / Privacy Manifest

App Functionality目的として申告するデータ種別:

- Name
- Email Address
- User ID
- Precise Location
- Other User Content
- Environment Scanning
- Product Interaction

全項目 `Linked to User = YES`、`Used for Tracking = NO`。Trackingはfalse、tracking domainはありません。

Required Reason API:
- File Timestamp category / `C617.1`: 共有パッケージのアップロード上限確認のため、アプリコンテナ内ファイルのmetadataを確認する。

## 端末内データとクラウド送信の境界

通常の撮影・生成では、撮影画像、ARKitの姿勢・特徴点・深度等をScan Labのクラウドへ送りません。利用者が共有フォームを明示的に送信した場合だけ、`scene.spz`、`manifest.json`、任意のpreview画像、投稿メタデータを送信します。`public` の場合のみ、明示取得した位置情報も送信します。公開UIからraw再構成 `.splat` は送信しません。

## 公開範囲

- `private`: 所有者のみ。
- `unlisted`: Map / Discoverには出さず、専用URLを知る人だけ閲覧可能。
- `public`: Map / Discoverとブラウザ共有URLで閲覧可能。位置情報と公開前安全確認が必須。

## UGC安全・削除

- `public` / `unlisted` は共有前のコンテンツ安全確認を要求する。
- `public` は公開場所・プライバシー・権利の確認を要求する。
- ログインユーザーは公開投稿を報告・ブロックできる。
- Account画面から公開サポート窓口へ到達できる。
- 所有者は公開投稿を非公開化・削除できる。
- アプリ内からアカウントとクラウドデータを削除でき、当該アカウントが共有したクラウド3D・投稿・プロフィール・関連レコードを削除対象とする。端末内に保存・書き出したファイルは対象外。

## App Review Information

本審査時はApp Store ConnectのApp Review Informationに審査用アカウントを設定し、具体的な審査手順とprivacy説明は `APP_REVIEW_NOTES_JA.md` を正本とする。
