# Scan Lab｜App Review / TestFlight Notes

更新日: 2026-08-17

## このビルドの目的

本ビルドはScaniverse個人向けiOS体験との機能・実用品質同等化を検証する開発版です。撮影と端末内3D生成に加え、D2のアカウント、クラウド保存、public / unlisted / private、ブラウザ共有、Map、Discover、報告・ブロック・削除を含みます。iPhoneホーム画面上の表示名は `Scan Lab` です。

ローカル撮影・生成はログイン不要で利用できます。ネットワーク送信は共有画面から利用者が明示的に実行した場合だけ開始します。ただしオンライン認証を利用した場合、Supabase Authは認証・セキュリティ監査ログを自動記録します。

## ログイン情報

オンライン共有・クラウド保存にはメール認証が必要です。新規登録はアプリ内から可能です。本審査時はApp Store ConnectのApp Review Informationへ審査用アカウントを設定します。

## 公開サポート・連絡先

- Support URL: `https://allsunday1122.github.io/splat-native-ios/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/splat-native-ios/privacy.html`
- User Privacy Choices URL: `https://allsunday1122.github.io/splat-native-ios/privacy-choices.html`
- 公開問い合わせ先: `kohei3615@gmail.com`
- Account画面ではログイン前・ログイン後の双方に「サポート・お問い合わせ」「プライバシーポリシー」を表示します。
- 公開投稿に問題がある場合はアプリ内の報告・ブロックを利用でき、追加情報やアカウント・削除・privacyの問い合わせは公開サポート窓口から連絡できます。

## 権限

- Camera: 必須。3D生成用の撮影に使用します。
- Location When In Use: 任意。`public` を選び、利用者が「現在地を公開地点に設定」を押した場合だけ許可を確認して現在地を取得します。取得後も公開操作を実行するまでは送信しません。
- Photos: 権限は要求しません。
- Microphone: 要求しません。
- Notifications: 要求しません。
- Tracking: 要求しません。

App Privacy上の `Photos or Videos` はPhotosライブラリ権限を意味しません。3D生成完了時にtrainerがユーザーの3Dをレンダリングしたpreview画像を作成し、明示クラウド共有時に存在する場合だけ `preview.jpg` として保存するため申告します。

## データ取扱い

撮影画像、ARKitカメラ姿勢・特徴点・深度等は端末内3D生成に利用し、通常のローカル撮影・生成ではクラウドへ送信しません。

利用者がクラウド共有を明示的に実行した場合、現在の公開UIは次をSupabaseへ送信します。

- アカウント: メールアドレス、アカウントID
- プロフィール: 表示名、ユーザーID（ハンドル）
- 投稿メタデータ: タイトル、説明、公開範囲
- 3D共有パッケージ: `scene.spz`、`manifest.json`
- 生成できた場合のpreview画像: `preview.jpg`（ユーザー3Dからアプリ内生成）
- `public` の場合のみ: 利用者が明示的に取得した緯度・経度、任意の場所名
- コミュニティ操作: いいね、報告理由、ブロック対象など、機能提供・安全運用に必要な操作情報

公開UIから撮影元画像やraw再構成 `.splat` をアップロードする設計ではありません。広告SDK、行動解析SDK、ユーザートラッキングはありません。

SupabaseはAuth / Database / Storage / Edge Functionsの基盤として利用します。Supabase Authはsignup、login、password reset、email verification、token refresh、logout等の認証イベントを監査ログとして自動記録し、ユーザーID、認証操作、日時、IPアドレス、User-Agent、provider metadata等を保持する場合があります。用途は認証、セキュリティ、不正利用・不正アクセス防止、コンプライアンス、運用診断であり、広告・マーケティング・トラッキングには使用しません。

ユーザーデータへアクセスする第三者サービスは、本ポリシーおよび適用されるApple要件と同等以上の保護を行うものに限定し、広告トラッキング目的では共有しません。

## 保存期間・削除・同意撤回

- アカウント情報、プロフィール、クラウドスキャン、preview画像、投稿メタデータ、位置情報、コミュニティ操作情報は、アカウントまたは対象データが存在し、機能提供・安全運用に必要な間保持します。
- クラウドスキャン削除では、対象3Dファイル、preview画像、投稿レコード、対象スキャンに紐づく関連レコードを削除対象とします。
- 「アカウントとクラウドデータを削除」では、所有3Dとpreview画像を削除した後に認証ユーザーを削除し、プロフィール、投稿、アカウントに紐づくアプリDBレコードを削除対象とします。
- Supabase Authの監査ログは認証ユーザー・投稿とは別管理で、アカウント削除と同時に必ず消去されるとは限りません。Supabase側のログ保持設定・契約上の保持期間と、セキュリティ・不正利用防止・障害調査・法令対応に必要な範囲で保持します。
- 位置情報の同意はiOS設定から撤回できます。撤回後は新たな現在地取得を行いません。既に送信済みの位置情報を削除するには対象クラウドスキャンを削除します。
- 公開のみ停止したい場合は非公開化、クラウド上の投稿自体を消したい場合はスキャン削除、オンライン機能全体を終了したい場合はアカウント削除を利用します。
- 具体的な選択肢はUser Privacy Choices URLにまとめています。
- 法令または正当なセキュリティ上の義務により保持が必要な場合は、必要な範囲と期間に限定します。

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

所有者は公開中のクラウドスキャンを非公開化できます。スキャン削除ではクラウド上の3Dファイル、preview画像と投稿レコードを削除します。アカウント画面には「アカウントとクラウドデータを削除」があり、サーバー上の当該ユーザー所有3Dとpreview画像・共有投稿を削除したうえで認証ユーザーを削除します。アプリDBの関連レコードは外部キーのcascadeで削除されます。Supabase Authの監査ログはこのcascade対象ではありません。端末内に保存・書き出したファイルは対象外です。

## Privacy Manifest / App Store Connect申告

現在のアプリPrivacy ManifestはTracking=falseとし、Scan Labのアプリ実装が収集する次の8項目をApp Functionality目的で申告します。

- Name
- Email Address
- User ID
- Precise Location
- Photos or Videos
- Other User Content
- Environment Scanning
- Product Interaction

App Store Connectへの転記正本 `APP_STORE_PRIVACY_RESPONSES.json` は、上記8項目に第三者パートナーSupabase Authの認証監査ログ由来 `Other Diagnostic Data` を加えた9項目です。9項目すべて `Linked to User = YES`、`Used for Tracking = NO`、目的は `App Functionality` です。

`Other Diagnostic Data` はSupabase Authが認証・セキュリティ監査のため保持し得るIPアドレス、User-Agent、認証イベント等をAppleのIPアドレス追加ガイダンスに基づき診断情報として保守的に申告するものです。これはCrash SDKや行動解析SDKを導入したという意味ではありません。

CIではPrivacy ManifestとApp Store Connect回答の完全一致を要求せず、Manifestの8項目がApp Store Connect正本にすべて包含され、第三者パートナー由来の追加申告が明示されていることを検査します。

共有パッケージのファイルmetadata確認に対し、Required Reason APIのFile Timestamp categoryに `C617.1` を申告します。

## Internal TestFlight確認手順

1. 未ログインで `新しくスキャン` を開始し、カメラ許可後に撮影・端末内3D生成まで進められることを確認する。
2. Account画面を開き、未ログインでも「サポート・お問い合わせ」「プライバシーポリシー」を開けることを確認する。
3. 検証用アカウントで登録またはログインする。
4. `private` を選び、位置情報権限なしで非公開クラウド保存できることを確認する。
5. 生成済みpreviewがある場合、明示共有後にpreviewがクラウド共有パッケージの一部として扱われることを確認する。撮影元画像は送信されないことを維持する。
6. `unlisted` を選び、安全確認後に限定リンクを作成し、Map / Discoverには表示されずブラウザURLで閲覧できることを確認する。
7. `public` を選ぶ。位置情報が自動取得されないことを確認してから「現在地を公開地点に設定」を押し、位置情報権限を許可する。
8. 場所・プライバシー・権利・コンテンツ安全確認を完了し、Map・Discoverへ公開する。
9. Map / Discoverとブラウザ共有URLから対象3Dを開けることを確認する。
10. 別アカウントから、いいね・報告・ブロックを確認する。
11. 所有者アカウントで非公開化し、公開面から消えることを確認する。
12. クラウドスキャン削除後、共有URLが利用できず、所有者一覧からも消えることを確認する。
13. iOS設定で位置情報権限を取り消し、その後の現在地取得が行われないことを確認する。
14. 検証用アカウントでアカウント削除を実行し、共有したクラウド3D・preview画像・投稿・プロフィールが削除対象になることを確認する。監査ログは別保持であることをPrivacy Policyと一致させる。

## 既知の審査前確認事項

- Internal TestFlight用の開発版であり、App Store本審査への自動提出は禁止しています。
- 本審査時は `APP_STORE_PRIVACY_RESPONSES.json`、Privacy Nutrition Label、審査用アカウント、公開Support URL、Privacy Policy URL、User Privacy Choices URLを最終buildと突合します。
- 公開URLは統合・GitHub Pages反映後にHTTPSで到達できることを実確認します。
- 実auth、公開URL、Map / Discover、削除系は実バックエンドを使うため、審査時にSupabase環境が到達可能である必要があります。
- D2-W01のAuth callback / password recoveryが統合された後は、Supabase Auth URL Configurationで `jp.allsunday1122.splatlab://auth-callback` と `jp.allsunday1122.splatlab://password-recovery` の両方を許可し、確認・復旧メールのredirect/PKCE、実メール→アプリ復帰→session/パスワード更新までPASSしてから審査用導線を完成扱いにします。
