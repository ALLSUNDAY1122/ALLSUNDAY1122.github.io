# Scan Lab｜App Store Connect入力正本（Internal TestFlight用）

更新日: 2026-08-16

## 識別情報

- プラットフォーム: iOS
- App Store Connect表示名: `Scan Lab`（技術検証・Scaniverse同等化用）
- iPhoneホーム画面表示名: `Scan Lab`
- 主言語: 日本語
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- Version: `1.0.0`
- Build: CIの `CM_BUILD_NUMBER` を使用
- 配布: Internal TestFlight only
- 本審査への自動提出: 禁止

## TestFlight向け説明

Scaniverse個人向けiOS体験との機能・実用品質同等化を目的に、iPhoneで撮影した静止物・シーンから端末内で3D Gaussian Splatを生成し、必要な場合だけ利用者の明示操作でクラウド保存・共有できる検証版です。

ローカル経路は「撮影 → 端末内3D生成 → 3D表示」で、ログイン不要です。D2ではこれにメール認証、プロフィール、public / unlisted / private、ブラウザ共有URL、Map、Discover、いいね、報告、ブロック、非公開化、スキャン削除、アカウント削除を追加しています。

おもちゃばこ固有のUI・思い出メタデータは、Scaniverse同等化が完了するまで本アプリへ混ぜません。

## 実装と一致させる申告

- ログイン: あり。メールアドレス / パスワード。ローカル撮影・端末内生成はログイン不要。
- クラウド基盤: Supabase Auth / Database / Storage / Edge Functions。
- 広告: なし。
- 課金: なし。
- 行動解析SDK: なし。
- クラッシュレポートSDK: なし。
- カメラ: 使用する。
- 写真ライブラリ権限: 使用しない。
- マイク: 使用しない。
- 位置情報: `public` 投稿で利用者が「現在地を公開地点に設定」を押した場合だけWhen In Useで取得する。自動取得・自動送信しない。
- 通知: 使用しない。
- ユーザートラッキング: なし。
- 独自の非免除暗号化: なし。`ITSAppUsesNonExemptEncryption = NO`。

## App Privacy / Privacy Manifest

現在の実装でApp Functionality目的として申告するデータ種別:

- Name: プロフィール表示名。
- Email Address: アカウント認証。
- User ID: auth user ID、公開ハンドル、所有者・いいね・報告・ブロックの紐付け。
- Precise Location: `public` 投稿で利用者が明示的に取得・送信した緯度経度。
- Other User Content: タイトル、説明、場所名、報告理由等。
- Environment Scanning: 明示共有された3D scene package。
- Product Interaction: いいね、報告、ブロック等のサーバー保存される操作情報。

全項目 `Linked to User = YES`、`Used for Tracking = NO`、Purposeは `App Functionality` とします。Trackingはfalse、tracking domainはありません。

Required Reason API:

- File Timestamp category / `C617.1`: 共有パッケージのアップロード上限確認のため、アプリコンテナ内ファイルのサイズmetadataを確認します。

## 端末内データとクラウド送信の境界

撮影画像、ARKitのカメラ姿勢・特徴点・深度等は端末内3D生成に利用します。通常のローカル撮影・生成ではScan Labのクラウドへ送りません。

利用者が共有フォームの送信ボタンを押した場合だけ、現在の公開UIはブラウザ共有用の `scene.spz`、整合性情報を含む `manifest.json`、生成できた場合はpreview画像、および投稿メタデータを送信します。`public` の場合のみ、明示的に取得した位置情報も送信します。公開UIから撮影元画像やraw再構成 `.splat` を送信する設計ではありません。

## 公開範囲

- `private`: クラウド保存のみ。所有者からだけ確認でき、共有URLは発行しない。
- `unlisted`: Map / Discoverには出さず、専用URLを知る人だけ閲覧可能。
- `public`: Map / Discoverとブラウザ共有URLで閲覧可能。位置情報と公開前安全確認が必須。

## UGC安全・削除

- `public` / `unlisted` は共有前のコンテンツ安全確認を要求する。
- `public` は公開場所・プライバシー・権利の確認を要求する。
- ログインユーザーは公開投稿を報告・ブロックできる。
- 所有者は公開投稿を非公開化できる。
- 所有者はクラウドスキャンを削除できる。
- アプリ内からアカウントとクラウドデータを削除できる。端末内に保存・書き出したファイルは対象外。

## App Review Information

Internal TestFlightではテスター自身の検証用アカウントを使用できます。本審査へ提出する場合は、審査用アカウントをApp Store ConnectのApp Review Informationへ入力し、認証情報をGitHubへ保存しません。

具体的な審査手順とprivacy説明は `APP_REVIEW_NOTES_JA.md` を正本とします。
