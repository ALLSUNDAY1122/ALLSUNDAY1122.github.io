# 看護師国家試験｜学びスプリント CODEX HANDOFF 正本

更新日: 2026-08-15 14:48 JST

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

## 1. リポジトリ

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App folder: `kangoshi-sprint/`
- Branch: `main`
- Bundle ID: `jp.allsunday1122.kangoshi`
- App name: `看護師国家試験｜学びスプリント`
- Native: SwiftUI-native
- WebView: 不使用
- Planned Product ID: `jp.allsunday1122.kangoshi.monthly`
- Monetization: 自動更新サブスクリプション、月額200円方針
- StoreKit: StoreKit 2、表示価格は `Product.displayPrice`
- Codemagic workflow: `kangoshi-ios`
- Codemagic profile: `kangoshi_appstore`

Bundle ID / Product IDを独断で変更しない。Apple側の数値App IDは推測しない。

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

## 3. 現在地

**コード側はAppIconを除きPre-TestFlight準備完了。現在はHuman / Apple gate。**

現在のrelease blockerは主に次の2系統。

1. 正本AppIconバイナリのGitHub投入
2. App Store Connect / Apple契約側の実登録

ここを越えたら、Prepared Codemagic `kangoshi-ios` でsigned App Store build → Internal TestFlightへ進む。

## 4. AppIcon — 絶対に再生成・加工しない

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

## 5. Apple / App Store Connect gate

CodexはApple実値だけを記録すること。未確認値を埋めない。

確認・実施順:

1. Apple Developer側で `jp.allsunday1122.kangoshi` のExplicit App IDが存在するか確認
2. App Store Connectに `看護師国家試験｜学びスプリント` のAppレコードを作成/確認
3. Apple発行の数値App IDを取得
4. 数値App IDを `app-store/RELEASE_IDENTITY.json` と `COORDINATOR_STATUS.json` に記録
5. 自動更新サブスクリプションを作成
   - planned Product ID: `jp.allsunday1122.kangoshi.monthly`
   - 期間: 1 month
   - 日本向け価格: 月額200円方針
6. 実登録Product IDを確認し、planned valueと一致することを確認
7. Paid Apps Agreement / Tax / Banking stateを確認
8. Codemagic App Store Connect integration / signing profile `kangoshi_appstore` を確認
9. signed IPA生成
10. Internal TestFlightまでアップロード
11. iPhone実機で起動・無料導線・購入・復元・再起動後entitlementを確認

Appleログイン・2FA・契約/税務/銀行情報・App Store Connectでの最終登録操作など、人間しかできない箇所だけユーザーへ依頼する。

## 6. 課金ルール

- StoreKit 2
- entitlementは verified transaction + Product ID一致 + revokedでないこと
- user-facing価格を `200円` の固定文字列から出さない
- 実表示は `Product.displayPrice`
- 復元導線を残す
- IAP登録前の仮値で成功扱いしない

## 7. Codemagic / TestFlight安全ルール

workflow: `kangoshi-ios`

必須:
- distribution type = `app_store`
- bundle identifier = `jp.allsunday1122.kangoshi`
- `testFlightInternalTestingOnly` を維持
- Internal TestFlightまでに限定する
- `submit_to_app_store: false` を維持する

**App Store本審査へのAdd for Review / Submit for Reviewは、ユーザーの明示承認があるまで絶対に実行しない。**

Apple password / 2FA / `.p8` / API secret / certificate private key等をGitHub・Notion・ログへ保存しない。

## 8. Codex再開時の最初の行動

1. `git pull` して最新 `main` を取得
2. `kangoshi-sprint/CODEX_HANDOFF.md`
3. `kangoshi-sprint/COORDINATOR_STATUS.json`
4. `kangoshi-sprint/app-store/RELEASE_IDENTITY.json`
5. `kangoshi-sprint/app-store/RELEASE_CHECKLIST.md`
6. `codemagic.yaml` の `kangoshi-ios`

を読み、記録と実装が一致するか確認する。

その後:
- AppIcon正本が所定パスにある → SHA検証 → AppIcon gate → release auditへ進む
- AppIconがない → その一点のみ人間ゲートとして扱い、他の進められるApple preflightを先に処理
- Apple側実登録値が取れる → 正本JSONを更新
- Apple側で人間操作が必要 → 最短手順だけユーザーへ提示

同一の失敗取得や完了済みCIをループしない。`NO_PROGRESS v2.0` に従い、進展がない処理は別の未完了工程へ切り替える。

## 9. 完了条件

この引継ぎの次の到達点は **Internal TestFlight**。

完了扱いには最低限以下が必要:
- exact canonical AppIcon integrated + SHA PASS
- App Store Connect App record verified
- numeric Apple App ID recorded
- monthly subscription registered
- Paid Apps Agreement / Tax / Banking ready
- signed App Store IPA build PASS
- Internal TestFlight upload PASS
- iPhone actual-device smoke PASS
- purchase / restore / entitlement PASS

本審査提出は別ゲート。

**現在地から続行し、過去工程を最初からやり直さないこと。人間確認が不要な工程は停止せず進めること。**
