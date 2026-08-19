# APP2-011｜卓 TAKU CALC｜Store情報と申請準備

更新: 2026-08-19 12:32 JST

## 判定

`HUMAN_REQUIRED`

production buildのやり直しは不要。Version 1.5.0 / Build 7をそのまま使用し、APIで自動化可能なStore情報・Build選択・Review準備は完了した。残る真正な停止点は、実機スクリーンショット作成/登録とApp Store Connect UI上のApp Privacy「データを収集しない」確定。

## 正本再取得

- Notion「アプリ開発台帳」: 状態 `公開準備`。次作業はBuild 7を再Buildせず、申請画像・Store情報・Privacy/Review必須項目・Build紐付けを進める指示。
- GitHub app repo: `ALLSUNDAY1122/taku-calc-app` main。Version 1.5.0。既存release docsはBuild 6時点から更新が必要だった。
- Codemagic API inspect: `ALLSUNDAY1122/taku-calc-app` に一致するapplication candidateは0件。TAKU CALC現行production経路は既存EAS/ASCであり、Codemagic buildは起動していない。
- App Store Connect Apple ID: `6794350490`
- Bundle ID: `com.koheimorita.takucalc`

## App Store Connect 実状態（開始時）

- Version 1.5.0: `PREPARE_FOR_SUBMISSION`
- Build 7 resource id: `e88d3687-830a-476c-8c5a-7d7b04a5027d`
- Build 7: `VALID`, `expired=false`, `APP_STORE_ELIGIBLE`, `usesNonExemptEncryption=false`
- VersionへのBuild relationship: 未設定
- ja version localization: description/keywords/supportUrl等が未設定
- ja app info localization: subtitle/privacyPolicyUrlが未設定
- App Review detail: contact/notes未設定
- primary category: 未設定
- age rating declaration: 未回答
- App Store screenshot set: 0件
- TestFlight beta feedback screenshot: 0件

ASC read evidence:
- Issue #4247 / run `32211690656` / artifact `release-command-result-4247-32211690656`
- Issue #4251 / run `32211782859` / artifact `release-command-result-4251-32211782859`
- Issue #4255 / run `32211948514` / artifact `release-command-result-4255-32211948514`
- Issue #4261 / run `32212127064` / artifact `release-command-result-4261-32212127064`

## 自動反映したStore情報

Issue #4256 / run `32211966557` / artifact `release-command-result-4256-32211966557` でsemantic writeし、read-back成功。

- 日本語Store説明文: 登録済み
- キーワード: `電卓,関数電卓,税計算,単位変換,通貨換算,ローン,日付計算,BMI,進数,割引`
- Promotional Text: 登録済み
- Support URL: `https://allsunday1122.github.io/taku-calc/`
- Subtitle: `10機能を1つにまとめた多機能電卓`
- Privacy Policy URL: `https://allsunday1122.github.io/taku-calc/privacy-policy.html`
- Version 1.5.0へBuild 7をattach済み

Store説明には、税・ローン・BMI・通貨換算が参考値であり、専門的判断の代替ではないことを明記した。

## Review / Category / Age Rating

既存Beta App Review連絡先をApp Store Connect内部で本審査連絡先へコピーするAPP2-011専用処理を追加。個人情報はGitHubへ保存しない。

関連commit:
- `0002701cac59a048c89be453180a3922c09be1ba` scoped finalize helper追加
- `bb0986afbbd92b4d7d0e7db6d027a1c39359dd8e` workflow追加
- `118cb616a98c6e431fb707fb6890eccee016822c` age-rating read-back endpoint修正

初回run `32212213907` は、ageRatingDeclarationsのPATCH完了後、Appleが禁止しているGET_INSTANCEをread-backに使ったためfailure。反映済み値を巻き戻さず、read-backのみ許可されたApp Info relationship経由へ修正。

再実行:
- Issue #4268
- run `32212301982`
- artifact `app2-011-store-finalize-32212301982`
- status `success`

Sanitized read-back:
- App Review contact complete: `true`
- demo account required: `false`
- Review Notes present: `true`
- primary category: `UTILITIES`
- age rating `healthOrWellnessTopics=true`
- `medicalOrTreatmentInformation=NONE`
- advertising: `false`
- unrestricted web access: `false`
- user generated content: `false`
- selected build id: `e88d3687-830a-476c-8c5a-7d7b04a5027d`
- submission performed: `false`

## App repo正本更新

`ALLSUNDAY1122/taku-calc-app` の `RELEASE_STATUS.md` を2026-08-19実状態へ更新。

commit: `0425eaf54a3e1f8de63ae211b5a05d6f6265be67`

## 残る真正な停止点

1. App Store screenshot setが0件。File LibraryにもTAKU CALCの再利用可能な実機スクリーンショットを確認できず、TestFlight beta feedback screenshotも0件。虚偽/生成画像は使用しない。iPhone実機のBuild 7で最終受入とApp Store掲載用実画面の撮影が必要。
2. App PrivacyのPrivacy Policy URLは登録済みだが、データ収集申告はApp Store Connect UIで現在の実装どおり「データを収集しない」を確定する必要がある。ソース/Review Notes上は広告・解析・ログイン・外部APIなし、履歴等は端末内保存。
3. 上記完了後、最終App Review提出は人間承認ゲート。今回のtaskでは提出していない。

## 次アクション

iPhone実機でBuild 7を受入確認→6.9インチ系の実画面スクリーンショットを取得・登録→App Privacyを「データを収集しない」で確定→Submission audit→人間の最終提出承認。
