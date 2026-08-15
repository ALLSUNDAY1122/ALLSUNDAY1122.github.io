# 看護師国家試験｜学びスプリント CODEX HANDOFF 正本

更新日: 2026-08-15 17:43 JST

このファイルはCodexが「看護師国家試験｜学びスプリント」を引き継ぐ際に最初に読む現在地の正本です。過去工程を最初からやり直さず、未完了ゲートから継続してください。

## 0. 正本の優先順位

1. この `CODEX_HANDOFF.md` — 現在地・再開順・停止点
2. `COORDINATOR_STATUS.json` — 機械的な最新進捗
3. `app-store/RELEASE_IDENTITY.json` — App Store / Bundle / IAP正本
4. `app-store/RELEASE_CHECKLIST.md` — 申請前チェック
5. `codemagic.yaml` / `ios/` — 実装・署名ビルド経路
6. GitHub `main` の最新実装
7. Notion「看護師国家試験｜学びスプリント」開発正本

Notion開発正本:
https://app.notion.com/p/3b609c10697d8157887bcf481e1acb38?pvs=204

共通のアプリ開発標準手順は v2.5、停滞時ルールは `NO_PROGRESS v2.0`。GitHub側の実値とApple実発行値を、過去チャットの推測値より優先する。

## 1. リポジトリ・固定識別子

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App folder: `kangoshi-sprint/`
- Branch: `main`
- App name: `看護師国家試験｜学びスプリント`
- Bundle ID: `jp.allsunday1122.kangoshi`
- SKU: `kangoshi-sprint-ios-001`
- App Store Connect Apple ID: `6801792293`
- Native: SwiftUI-native
- WebView: 不使用
- Planned Product ID: `jp.allsunday1122.kangoshi.monthly`
- Monetization: 自動更新サブスクリプション、月額200円方針
- StoreKit: StoreKit 2、表示価格は `Product.displayPrice`
- Codemagic workflow: `kangoshi-ios`
- Codemagic profile: `kangoshi_appstore`

Bundle ID / SKU / Apple IDを独断で変更しない。Product IDはApp Store Connect実登録値で最終確定する。Apple側の数値App IDは推測しない。

## 2. 完了済み工程

以下は再実行を目的化しない。コード変更が影響する場合のみ必要な品質ゲートを再実行する。

### コンテンツ
- 720問をRelease対象として監査済み
- 必修150 / 一般390 / 状況設定180
- 60症例
- 動的必修85問を検証済み
- content concerns 0
- expert review pending 0
- release quarantine 0
- Content PASS

### 図版
- 対象38問
- 公式PDL1解決15
- 独自vector redraw解決23
- pending 0
- runtime missing 0
- Media PASS

### Native iOS
- SwiftUI-native
- WebView 0
- StoreKit 2実装済み
- restore purchases実装済み
- Privacy Manifest準備済み
- Debug simulator build PASS
- Release simulator build PASS
- session dismissal crash修正済み
- Xcode project generation PASS

### UI品質
ネイティブUI 2サイズ監査はPASS済み。

- latest verified workflow run: `31858624555`
- devices: `iPhone SE (3rd generation)` / `iPhone 16 Pro`
- UI smoke / accessibility / 2-size audit: PASS

この完了済みrunを無意味にポーリングし続けない。

### App Store準備
- metadata ready
- review notes ready
- support page ready
- privacy page ready
- public pages HTTP 200 PASS
- App Store screenshot ready
- screenshot visual review PASS
- Codemagic workflow prepared

スクリーンショット既存証跡:
- workflow run: `31858045423`
- artifact: `9239701132`
- screens: home / question / mock / settings

## 3. 2026-08-15 17:43 引継ぎ時点のApple側現在地

**App Store ConnectのAppレコード作成まで完了。ここをやり直さない。**

ユーザーのApp Store Connect画面で次を実確認済み:

- App Store Connect App record: 作成済み
- Apple ID: `6801792293`
- SKU: `kangoshi-sprint-ios-001`

この実値は `COORDINATOR_STATUS.json` と `app-store/RELEASE_IDENTITY.json` に反映済み。

ただし、ユーザーが最後に共有した画面ではBundle ID欄がまだ `ロード中…` 表示だったため、`jp.allsunday1122.kangoshi` が画面上で解決したこと自体は未確認。したがって `explicitBundleIdVerified` は false のまま維持する。

同画面で未確定 / 未確認の項目:

- Bundle ID表示が `jp.allsunday1122.kangoshi` に解決すること
- プライマリ言語 = 日本語
- プライマリカテゴリ = 教育
- セカンダリカテゴリ = メディカル
- コンテンツ配信権の回答
- 自動更新サブスクリプション実登録
- Paid Apps Agreement / Tax / Banking状態

CodexはAppレコードを再作成せず、この未完了点から続行する。

## 4. 現在のrelease blocker

現在のrelease blockerは主に次の3系統。

1. App Store Connectの残設定とIAP実登録
2. 正本AppIconバイナリのGitHub投入
3. Apple契約 / 署名 / Internal TestFlight

ここを越えたら、Prepared Codemagic `kangoshi-ios` でsigned App Store build → Internal TestFlightへ進む。

## 5. AppIcon — 絶対に再生成・加工しない

正本:
- Google Drive file: `03_看護師国家試験.png`
- Drive file ID: `1VDnbT0s9gEPde4baCfw9kXYfnEHLQrp3`
- dimensions: 1024 x 1024
- RGB PNG
- canonical byte size: 683,924 bytes
- SHA-256: `6afe16483852c98e0e030874ce7829f0e1a42fe017bb2f854eee1d9410f8ee80`

GitHub配置先:
`kangoshi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

重要:
- 画像生成し直さない
- ImageMagick等で再エンコードしない
- リサイズしない
- metadata cleanup等も行わない
- 正本バイト列をそのまま配置する
- 配置後にSHA-256と1024x1024を必ず検証する

公開Google Drive URL経由の自動取得は、正本とは異なるバイト列を返したため既に失敗確認済み。SHA不一致を無視して進めない。失敗した一時取得workflowは削除済みで、誤画像はGitHubへ入っていない。

Codex環境に正本バイナリが見えない場合は、この1ファイルだけを人間ゲートとしてユーザーに渡してもらう。ファイルが入ったら機械検証から自動再開する。

## 6. Apple / App Store Connect gate — 次に行う順番

CodexはApple実値だけを記録すること。未確認値を埋めない。

1. 最新 `main` を取得し、このHandoff・`COORDINATOR_STATUS.json`・`app-store/RELEASE_IDENTITY.json` を確認
2. App Store Connect Appレコードは作成済みとして扱う
3. ユーザー画面でBundle IDが `jp.allsunday1122.kangoshi` に解決していることを確認
4. App情報の残項目を設定/確認
   - Primary Language: Japanese
   - Primary Category: Education
   - Secondary Category: Medical
   - Content Rights: 実際の収録内容・利用権監査に一致する回答をする。第三者由来の公的資料等を含む場合、権利保有を前提に適切に回答する
5. 自動更新サブスクリプションを作成
   - planned Product ID: `jp.allsunday1122.kangoshi.monthly`
   - duration: 1 month
   - Japan price policy: 月額200円
6. 実登録Product IDを確認し、planned valueと一致することを確認
7. Paid Apps Agreement / Tax / Banking stateを確認
8. 正本AppIconを所定パスへ投入しSHA検証
9. Codemagic App Store Connect integration / signing profile `kangoshi_appstore` を確認
10. signed IPA生成
11. Internal TestFlightまでアップロード
12. iPhone実機で起動・無料導線・購入・復元・再起動後entitlementを確認

Appleログイン・2FA・契約/税務/銀行情報・App Store Connectでの最終登録操作など、人間しかできない箇所だけユーザーへ依頼する。それ以外は止まらず進める。

## 7. 課金ルール

- StoreKit 2
- entitlementは verified transaction + Product ID一致 + revokedでないこと
- user-facing価格を `200円` の固定文字列から出さない
- 実表示は `Product.displayPrice`
- 復元導線を残す
- IAP登録前の仮値で成功扱いしない

## 8. Codemagic / TestFlight安全ルール

workflow: `kangoshi-ios`

必須:
- distribution type = `app_store`
- bundle identifier = `jp.allsunday1122.kangoshi`
- `testFlightInternalTestingOnly` を維持
- Internal TestFlightまでに限定する
- `submit_to_app_store: false` を維持する

**App Store本審査へのAdd for Review / Submit for Reviewは、ユーザーの明示承認があるまで絶対に実行しない。**

Apple password / 2FA / `.p8` / API secret / certificate private key等をGitHub・Notion・ログへ保存しない。

## 9. 再実行禁止・停滞時処理

以下を変更なしで最初からやり直さない:
- 720問コンテンツ監査
- 38図版監査
- Debug / Release simulator build
- UI 2サイズ監査 run `31858624555`
- App Store screenshot生成 / 視覚監査
- support/privacyページ作成
- App Store Connect Appレコード作成
- Apple ID / SKUの再決定
- 公開Drive URLからのAppIcon取得

同一手法で進展がない場合は `NO_PROGRESS v2.0` に従い、その処理のみ中止して別の未完了工程へ切り替える。

## 10. Codex再開時の最初の行動

1. `git pull` して最新 `main` を取得
2. `kangoshi-sprint/CODEX_HANDOFF.md`
3. `kangoshi-sprint/COORDINATOR_STATUS.json`
4. `kangoshi-sprint/app-store/RELEASE_IDENTITY.json`
5. `kangoshi-sprint/app-store/RELEASE_CHECKLIST.md`
6. `codemagic.yaml` の `kangoshi-ios`

を読み、記録と実装が一致するか確認する。

最初のApple側確認点は **App Store ConnectのBundle ID欄が `jp.allsunday1122.kangoshi` に解決しているか**。Appレコード作成は完了済みなので再作成しない。

その後はIAP実登録・契約状態確認・AppIcon投入・signed Internal TestFlightへ進む。人間しか操作できない画面だけ最短指示を出す。

## 11. 完了条件

この引継ぎの次の到達点は **Internal TestFlight**。

完了扱いには最低限以下が必要:
- exact canonical AppIcon integrated + SHA PASS
- App Store Connect App record verified — 完了済み
- numeric Apple App ID recorded — `6801792293` 完了済み
- SKU recorded — `kangoshi-sprint-ios-001` 完了済み
- Bundle ID UI verification
- monthly subscription registered
- Paid Apps Agreement / Tax / Banking ready
- signed App Store IPA build PASS
- Internal TestFlight upload PASS
- iPhone actual-device smoke PASS
- purchase / restore / entitlement PASS

本審査提出は別ゲート。

**現在地から続行し、過去工程を最初からやり直さないこと。人間確認が不要な工程は停止せず進めること。**
