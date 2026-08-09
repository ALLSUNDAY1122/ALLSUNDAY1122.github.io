# CODEX HANDOFF｜ネットワークスペシャリスト｜学びスプリント

更新: 2026-08-09 17:08 JST

## 0. 現在地
ChatGPT側の開発ループは完了。Web試験利用URLをユーザーがiPhoneで操作確認し、**問題なし**を確認済み。

- GitHub正本: `main / network-specialist-sprint/`
- 採用PR: #4092 merged
- Version: `1.0.0`
- Build: `1`
- Bundle ID: `jp.allsunday1122.networkspecialist`
- iOS方式: SwiftUI + WKWebView（ローカルWeb資産同梱）
- ビルド方式: Codemagic + XcodeGen
- 現在の工程: **TestFlight申請実行ゲート**
- 本審査への自動提出は禁止。`submit_to_app_store: false` を維持する。

## 1. 変更禁止の正本
### UI
Notion最上位正本「学びスプリント UI要件定義 v2.1 Golden Master」に準拠済み。資格固有理由なく変更しない。

### 問題構成
- 2025・2024・2023年度 春期 科目A-2（旧午前II）各25問
- 模試出題枠: 75
- 通常学習ユニーク: 68
- 歴史的再出題・実質同一: 7出題をcanonical化
- 問題監査: PASS
- UI 30状態監査: PASS
- 実装・静的リリース監査: PASS

問題本文、正解、解説、出典、改変フラグ、試験構成を変更した場合は、問題生成・監査ループのPASSを失効させて再監査すること。

### AppIcon
**再生成禁止。**
Google Drive正本:
- ファイル: `07_ネットワークスペシャリスト試験.png`
- Drive file ID: `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`
- 1024×1024 RGB
- SHA-256: `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`

配置先:
`network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

`codemagic.yaml` はこのPNGが存在しない場合、Archive前に意図的にFAILする。

## 2. Web試験利用
公開URL:
`https://allsunday1122.github.io/network-specialist-sprint/`

ユーザー確認: **PASS（2026-08-09）**

公開ページ:
- Support: `https://allsunday1122.github.io/network-specialist-sprint/support.html`
- Privacy: `https://allsunday1122.github.io/network-specialist-sprint/privacy.html`

Codex側で未ログインHTTP 200、スマホ表示、リンク切れを再確認すること。

## 3. App Store Connect固定値
- App Store表示名: `ネットワークスペシャリスト｜学びスプリント`
- サブタイトル: `科目A-2を8問ずつ反復`
- Primary language: Japanese
- Primary category: Education
- Price: Free
- Bundle ID: `jp.allsunday1122.networkspecialist`
- Version: `1.0.0`
- Build: `1`
- SKU候補: `network-specialist-sprint-ios`
- サインイン: 不要
- アカウント登録: なし
- 広告: なし
- 解析: なし
- IAP: 初期版なし
- クラウド同期: なし
- 学習データ: 端末内保存

App Privacyは現行実装に基づき「データ収集なし」。Privacy ManifestはTracking=false / CollectedDataTypes=[]。
広告・解析・ログイン・課金・クラウド同期・クラッシュSDK等を追加したらPrivacy監査を再発火すること。

## 4. Content Rights / IPA
- IPA公開過去問題を一次資料に限定
- 年度・試験区分・問番号を出典として保持
- 改変問題は改変表示
- 解説は独自制作
- IPA公式アプリではない旨を表示
- 利用条件監査PASS済み

App Store ConnectのContent Rightsは、第三者コンテンツを扱う前提で、保有する利用根拠に基づき正確に回答すること。

## 5. Codemagic
Workflow: `network-specialist-ios`

現行安全設定:
- App Store distribution signing
- `submit_to_testflight: true`
- `submit_to_app_store: false`

`codemagic.yaml` のBundle ID、Xcode project/scheme、App Store Connect integration、signingを確認してから実行。
Apple/Codemagicの秘密鍵・APIキー・Issuer ID・Key ID・2FAコード・パスワードはGitHub/Notion/チャットへ保存しない。

## 6. Codexが次に行うループ
1. `python3 network-specialist-sprint/scripts/validate_release.py`
2. Support / Privacy URLを未ログインでHTTP 200確認
3. 正本AppIconを上記配置先へmaterializeし、SHA-256一致確認
4. Apple DeveloperでExplicit App ID `jp.allsunday1122.networkspecialist` を登録/確認
5. App Store Connectで新規Appレコード作成
6. Codemagic App Store Connect integration / signing設定
7. `cd network-specialist-sprint/ios && xcodegen generate`
8. Archive / Validate / TestFlight upload
9. TestFlight実機確認
   - 起動
   - 8問完走
   - 25問模試
   - 中断復帰
   - JSON export/import
   - 機内モードで再起動・学習
10. 実アプリ画面からApp Storeスクリーンショットを作成
11. App Privacy / Content Rights / Age Rating / Export Compliance / Support・Privacy URL / Review Notesを実装と照合
12. `Add for Review` 直前で停止し、ユーザーの最終確認を取る

## 7. スクリーンショット方針
iPhone縦向き 1290×2796 を標準候補とする。実アプリまたはSimulatorの実画面から取得し、架空UIは使わない。

提出候補5枚:
1. ホーム（今日の学習・8問スプリント）
2. 問題回答後（○×・ここだけ覚える・解説・出典）
3. 模試（2025/2024/2023 各25問）
4. 学習記録（達成度・分野・5週間ヒートマップ・苦手）
5. 設定（4/8/16問・文字サイズ・試験日・JSON）

## 8. STOP条件
以下はユーザー本人操作が必要:
- Apple ID / Apple Developer / App Store Connectログイン
- 2要素認証
- 本人確認
- 契約・税務・銀行情報が要求された場合
- `Add for Review` / `Submit for Review` 直前の最終確認

**App Store本審査への自動提出は禁止。**

## 9. FAIL時の戻り先
- 問題・解説・出典変更 → 問題生成・監査ループ
- UI/導線変更 → UI Golden Master監査 + 30状態監査
- Privacyに影響するSDK/機能追加 → Privacy・申請監査
- Bundle ID / signing / Archive失敗 → iOS/Apple署名ループ
- TestFlight実機不具合 → 該当実装修正 → 同じ実機確認項目を再実行

Codexはこのファイル、`RELEASE_STATUS.md`、`RELEASE_CHECKLIST.md`、`APP_STORE_METADATA_JA.md`、`codemagic.yaml` を最初に読むこと。