# App Store Connect入力正本｜保健師国家試験｜学びスプリント

更新: 2026-08-14
用途: App Store Connectの新規App作成後に、入力判断を増やさず同じ回答を再現するための正本。

## 1. App Information
- Platform: iOS
- Name: `保健師国家試験｜学びスプリント`
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.hokenshi`
- SKU: `hokenshi-sprint-13-ios`
- Primary Category: Education
- Secondary Category: なし
- Made for Kids: いいえ
- Version: `1.0.0`
- Copyright: `2026 ALLSUNDAY1122`
- Content Rights: 本アプリの問題・解説は独自作成。法令、厚生労働省資料、公的統計等を根拠として参照し、公式国家試験問題の転載は収録しない。第三者著作物をアプリ内コンテンツとして転載しない。一次根拠は外部リンクで確認できる設計。

## 2. Age Rating
現行Apple質問票へ次の実装実態で回答する。
- User-Generated Content: None
- Messaging and Chat: None
- Advertising: None
- Unrestricted Web Access: None（任意URLを閲覧する内蔵ブラウザはない。一次根拠の特定URLを外部ブラウザで開くのみ）
- Gambling / Simulated Gambling / Loot Boxes / Contests: None
- Profanity / Crude Humor: None
- Horror / Fear Themes: None
- Alcohol / Tobacco / Drug Use or References: None
- Sexual Content / Nudity / Mature or Suggestive Themes: None
- Cartoon / Fantasy / Realistic Violence / Guns or Weapons: None
- Medical or Treatment Information: Infrequent

注: 国家試験教材として疾患・保健指導・健康危機等を扱うため、診療機能がなくてもMedical or Treatment InformationをNoneとは申告しない。最終RatingはApp Store Connectが現行質問票の回答から自動算出する値を採用する。

## 3. App Privacy
- Privacy Policy URL: `https://allsunday1122.github.io/hokenshi-sprint/privacy.html`
- User Privacy Choices URL: 空欄
- Data Collection: `No, we do not collect data from this app`

根拠:
- アカウント登録なし
- 広告SDKなし
- 第三者分析SDKなし
- トラッキングなし
- 位置情報なし
- 連絡先なし
- 健康情報の収集・外部送信なし
- 回答履歴、苦手、設定は端末内保存
- JSONバックアップはユーザーが明示的に書き出した場合のみユーザー選択先へ保存
- StoreKit決済情報・Apple Account認証情報は開発者が取得・保存しない

## 4. Export Compliance
- `ITSAppUsesNonExemptEncryption`: `false`
- 独自暗号・非免除暗号を実装しない。
- Apple OSが提供する通常の通信機能以外に独自暗号ライブラリを組み込まない。
- 現行構成では追加の暗号輸出書類は不要として申告する。

## 5. Support / Review URLs
- Support URL: `https://allsunday1122.github.io/hokenshi-sprint/support.html`
- Privacy URL: `https://allsunday1122.github.io/hokenshi-sprint/privacy.html`

## 6. In-App Purchase
- Type: Non-Consumable
- Reference Name: `保健師国家試験 プレミアム解放`
- Product ID: `jp.allsunday1122.hokenshi.premium`
- Display Name (Japanese): `プレミアム問題・模試解放`
- Description (Japanese): `残り300問と独自模試3回分を買い切りで解放します。`
- Pricing standard: 標準手順 v2.4「買い切り800円」
- Japan price: `800円`
- App内価格表示: StoreKit `Product.displayPrice` のみ。`800円`をコードへ固定しない。
- Restore: 常設
- Family Sharing: 初回提出時はオフを既定とし、必要性を別途判断する
- Review Screenshot: Internal TestFlight前後に実AppのPaywall画面から作成。StoreKit実価格が取得できた画面を提出する。

## 7. IAP Review Notes
`ホーム、模試、設定からプレミアム画面を開けます。無料版では10分野から各3問、合計30問を利用できます。非消耗型の買い切りPremium購入後は残り300問と独自模試3回分が解放されます。日本向け価格は標準手順に基づき800円で設定し、設定およびプレミアム画面に「購入を復元」があります。アプリ内価格はStoreKitから取得したApp Store表示価格のみを表示します。`

## 8. App Review Notes
`保健師国家試験の学習用アプリです。診断・治療・個別の医療判断を提供する医療機器アプリではありません。問題と解説は独自作成で、公的な一次根拠への外部リンクを問題単位で確認できます。アカウント登録、広告、第三者分析SDK、トラッキングはありません。回答履歴等は端末内に保存します。無料30問を利用でき、非消耗型Premiumで残り300問と模試を解放します。`

## 9. Regulated Medical Device
- Primary CategoryはEducation。
- アプリは診断、予防、モニタリング、治療を行う医療機器機能を持たない。
- 現状、Regulated Medical Deviceとしての申告対象になる実装はない。
- Appleの現行質問票で追加設問が表示された場合は実装事実に基づき回答し、医療機器であるとの虚偽申告はしない。

## 10. Submission Gates
- Internal TestFlightまでは自動化対象。
- TestFlight実機確認 = 人間確認地点 #3。
- App Store本審査提出 = 人間確認地点 #4の明示承認後のみ。
- 人間確認地点 #4では800円という既決定価格を再判断せず、App Store Connectの商品価格とStoreKit表示の一致だけを確認する。
- 数値App Store Connect App IDはApple実発行値のみを正本へ登録し、仮値は禁止。
