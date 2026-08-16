# Scan Lab｜App Review / TestFlight Notes

更新日: 2026-08-16

## このビルドの目的

本ビルドはScaniverse個人向けiOS体験との機能・実用品質同等化を検証する開発版です。撮影と端末内3D生成に加え、D2のアカウント、クラウド保存、public / unlisted / private、ブラウザ共有、Map、Discover、報告・ブロック・削除を含みます。iPhoneホーム画面上の表示名は `Scan Lab` です。

ローカル撮影・生成はログイン不要で利用できます。ネットワーク送信は共有画面から利用者が明示的に実行した場合だけ開始します。

## ログイン情報

オンライン共有・クラウド保存にはメール認証が必要です。新規登録はアプリ内から可能です。本審査時はApp Store ConnectのApp Review Informationへ審査用アカウントを設定します。

## 公開サポート・連絡先

- Support URL: `https://allsunday1122.github.io/splat-native-ios/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/splat-native-ios/privacy.html`
- 公開問い合わせ先: `kohei3615@gmail.com`
- Account画面ではログイン前・ログイン後の双方に「サポート・お問い合わせ」「プライバシーポリシー」を表示します。
- 公開投稿に問題がある場合はアプリ内の報告・ブロックを利用でき、追加情報やアカウント・削除・privacyの問い合わせは公開サポート窓口から連絡できます。

## 権限

- Camera: 必須。3D生成用の撮影に使用します。
- Location When In Use: 任意。`public` を選び、利用者が「現在地を公開地点に設定」を押した場合だけ許可を確認して現在地を取得します。取得後も公開操作を実行するまでは送信しません。
- Photos: 要求しません。
- Microphone: 要求しません。
- Notifications: 要求しません。
- Tracking: 要求しません。

## データ取扱い

撮影画像、ARKitカメラ姿勢・特徴点・深度等は端末内3D生成に利用し、通常のローカル撮影・生成ではクラウドへ送信しません。

利用者がクラウド共有を明示的に実行した場合、現在の公開UIは次をSupabaseへ送信します。

- アカウント: メールアドレス、アカウントID
- プロフィール: 表示名、ユーザーID（ハンドル）
- 投稿メタデータ: タイトル、説明、公開範囲
- 3D共有パッケージ: `scene.spz`、`manifest.json`、生成できた場合はpreview画像
- `public` の場合のみ: 利用者が明示的に取得した緯度・経度、任意の場所名
- コミュニティ操作: いいね、報告理由、ブロック対象など、機能提供に必要な操作情報

公開UIから撮影元画像やraw再構成 `.splat` をアップロードする設計ではありません。広告SDK、行動解析SDK、ユーザートラッキングはありません。

## 公開範囲

- `private`: クラウドには保存しますが、所有者のアカウントからだけ確認できます。共有URLは発行しません。
- `unlisted`: Map / Discoverには掲載せず、専用URLを知る人だけが閲覧できます。
- `public`: Map / Discoverとブラウザ共有URLから閲覧できます。公開地点を必須とし、場所・プライバシー・権利確認を要求します。

`public` / `unlisted` は共有前のコンテンツ安全確認を要求し、不適切な投稿はサーバー側の公開guardや報告処理により拒否・非表示となる場合があります。

## UGC安全機能

- 共有前にコンテンツ安全確認を要求します。
- `public` では公開場所・プライバシー・権利の確認も要求します。
- 公開投稿には報告機能があります。
- 他ユーザーをブロックできます。
- Account画面と公開Support URLから開発者へ連絡できます。

## 削除・非公開化

所有者は公開中のクラウドスキャンを非公開化できます。スキャン削除ではクラウド上の3Dファイルと投稿レコードを削除します。アカウント画面には「アカウントとクラウドデータを削除」があり、サーバー上の当該ユーザー所有3Dと共有投稿を削除したうえで認証ユーザーを削除します。関連DBレコードは外部キーのcascadeで削除されます。端末内に保存・書き出したファイルは対象外です。

## Privacy Manifest / App Store Connect申告

現在のPrivacy ManifestはTracking=falseとし、App Functionality目的で、Name / Email Address / User ID / Precise Location / Other User Content / Environment Scanning / Product Interactionを申告します。

共有パッケージのファイルmetadata確認に対し、Required Reason APIのFile Timestamp categoryに `C617.1` を申告します。

App Store ConnectのApp Privacy回答は、このManifestと `privacy.html` の内容に合わせます。

## Internal TestFlight確認手順

1. 未ログインで `新しくスキャン` を開始し、カメラ許可後に撮影・端末内3D生成まで進められることを確認する。
2. Account画面を開き、未ログインでも「サポート・お問い合わせ」「プライバシーポリシー」を開けることを確認する。
3. 検証用アカウントで登録またはログインする。
4. `private` を選び、位置情報権限なしで非公開クラウド保存できることを確認する。
5. `unlisted` を選び、安全確認後に限定リンクを作成し、Map / Discoverには表示されずブラウザURLで閲覧できることを確認する。
6. `public` を選ぶ。位置情報が自動取得されないことを確認してから「現在地を公開地点に設定」を押し、位置情報権限を許可する。
7. 場所・プライバシー・権利・コンテンツ安全確認を完了し、Map・Discoverへ公開する。
8. Map / Discoverとブラウザ共有URLから対象3Dを開けることを確認する。
9. 別アカウントから、いいね・報告・ブロックを確認する。
10. 所有者アカウントで非公開化し、公開面から消えることを確認する。
11. クラウドスキャン削除後、共有URLが利用できず、所有者一覧からも消えることを確認する。
12. 検証用アカウントでアカウント削除を実行し、共有したクラウド3D・投稿・プロフィールが削除対象になることを確認する。

## 既知の審査前確認事項

- Internal TestFlight用の開発版であり、App Store本審査への自動提出は禁止しています。
- 本審査時はPrivacy Nutrition Label、審査用アカウント、公開Support URL、公開Privacy Policy URLを最終buildと突合します。
- 公開URLは統合・GitHub Pages反映後にHTTPSで到達できることを実確認します。
- 実auth、公開URL、Map / Discover、削除系は実バックエンドを使うため、審査時にSupabase環境が到達可能である必要があります。
