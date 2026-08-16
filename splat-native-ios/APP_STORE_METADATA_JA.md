# Scan Lab｜App Store Connect入力正本（Internal TestFlight用）

更新日: 2026-08-17

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
- User Privacy Choices URL: `https://allsunday1122.github.io/splat-native-ios/privacy-choices.html`
- Support URL: `https://allsunday1122.github.io/splat-native-ios/support.html`
- 公開問い合わせ先: `kohei3615@gmail.com`
- アプリ内のAccount画面から、ログイン前・ログイン後の双方でサポートとプライバシーポリシーへ到達できる。
- 本審査前に、統合・公開された上記URLがHTTPSで到達でき、最終buildと内容が一致することを確認する。

## TestFlight向け説明

iPhoneで撮影した静止物・シーンから端末内で3D Gaussian Splatを生成し、必要な場合だけ利用者の明示操作でクラウド保存・共有できる検証版です。ローカル撮影・端末内3D生成はログイン不要です。

D2ではメール認証、プロフィール、public / unlisted / private、ブラウザ共有URL、Map、Discover、いいね、報告、ブロック、非公開化、スキャン削除、アカウント削除を提供します。

## 実装と一致させる申告

- クラウド基盤: Supabase Auth / Database / Storage / Edge Functions。
- 広告・課金・行動解析SDK・クラッシュレポートSDK: なし。
- Camera: 使用する。
- Photos / Microphone / Notifications / Trackingの権限: 使用しない。
- `Photos or Videos` のApp Privacy申告はPhotosライブラリ権限を意味しない。ユーザー3Dからアプリ内生成した `preview.jpg` を明示クラウド共有時に保存するため申告する。
- Location When In Use: `public` 投稿で利用者が「現在地を公開地点に設定」を押した場合だけ取得する。自動取得・自動送信しない。
- 独自の非免除暗号化: なし。`ITSAppUsesNonExemptEncryption = NO`。

## App Privacy / Privacy Nutrition Label入力正本

機械可読な唯一の入力正本は `APP_STORE_PRIVACY_RESPONSES.json`。Privacy ManifestとこのJSONのdata type集合はCIで完全一致させる。

| Data Type | Collected | Purpose | Linked to User | Used for Tracking | 主な発生条件 |
|---|---|---|---|---|---|
| Name | YES | App Functionality | YES | NO | オンラインプロフィール |
| Email Address | YES | App Functionality | YES | NO | 認証・アカウント復旧 |
| User ID | YES | App Functionality | YES | NO | アカウント、所有権、コミュニティ安全機能 |
| Precise Location | YES | App Functionality | YES | NO | publicで現在地ボタンを明示操作し投稿した場合のみ |
| Photos or Videos | YES | App Functionality | YES | NO | 生成済み3D previewがあり明示クラウド共有した場合 |
| Other User Content | YES | App Functionality | YES | NO | 共有3D、タイトル、説明等をクラウド保存・共有した場合 |
| Environment Scanning | YES | App Functionality | YES | NO | `scene.spz` を明示クラウド保存・共有した場合 |
| Product Interaction | YES | App Functionality | YES | NO | いいね、報告、ブロック等のオンライン操作 |

- Tracking: NO
- Tracking domains: なし
- 8項目すべて `Linked to User = YES` / `Used for Tracking = NO`。
- `Photos or Videos` は、trainerがユーザー3Dから生成したpreviewをJPEGとして保存するための申告。撮影元画像やPhotosライブラリ画像をクラウドへ送るという意味ではない。
- App Store Connectへ入力する際は、上表ではなく `APP_STORE_PRIVACY_RESPONSES.json` を最終転記正本とし、最終統合buildで再検査する。

Required Reason API:
- File Timestamp category / `C617.1`: 共有パッケージのアップロード上限確認のため、アプリコンテナ内ファイルのmetadataを確認する。

## 端末内データとクラウド送信の境界

通常の撮影・生成では、撮影画像、ARKitの姿勢・特徴点・深度等をScan Labのクラウドへ送りません。利用者が共有フォームを明示的に送信した場合だけ、`scene.spz`、`manifest.json`、生成できた場合の `preview.jpg`、投稿メタデータを送信します。`public` の場合のみ、明示取得した位置情報も送信します。公開UIから撮影元画像やraw再構成 `.splat` は送信しません。

## 第三者サービス / 保存 / 同意撤回

- SupabaseをAuth / Database / Storage / Edge Functionsの基盤として利用し、オンライン機能に必要なデータを機能提供の範囲で送信・保存する。
- ユーザーデータへアクセスする第三者サービスは、公開Privacy Policyおよび適用されるApple要件と同等以上の保護を行うものに限定する。
- ユーザーデータを広告目的で販売せず、広告トラッキング目的で第三者へ提供しない。
- アカウント情報、プロフィール、クラウドスキャン、preview画像、投稿メタデータ、位置情報、コミュニティ操作情報は、アカウントまたは対象データが存在し、機能提供・安全運用に必要な間保持する。
- 位置情報同意はiOS設定から撤回可能。送信済み位置情報は対象クラウドスキャン削除で削除対象とする。
- 公開停止は非公開化、個別クラウドデータ削除はスキャン削除、オンライン機能全体の終了はアカウント削除で行う。
- 具体的なユーザー選択肢はUser Privacy Choices URLに集約する。
- 法令または正当なセキュリティ上の義務により保持が必要な場合は必要な範囲と期間に限定する。

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
- アプリ内からアカウントとクラウドデータを削除でき、当該アカウントが共有したクラウド3D・preview画像・投稿・プロフィール・関連レコードを削除対象とする。端末内に保存・書き出したファイルは対象外。

## App Review Information

本審査時はApp Store ConnectのApp Review Informationに審査用アカウントを設定し、具体的な審査手順とprivacy説明は `APP_REVIEW_NOTES_JA.md` を正本とする。

D2-W01のAuth callback / password recoveryが統合された場合は、Supabase Auth URL Configurationで次の両方を許可し、メールテンプレートのredirect/PKCEと実メールE2Eを確認してから審査可能な導線として完成扱いにする。

- `jp.allsunday1122.splatlab://auth-callback`
- `jp.allsunday1122.splatlab://password-recovery`
