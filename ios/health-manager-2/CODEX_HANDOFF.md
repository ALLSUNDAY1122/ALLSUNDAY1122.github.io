# CODEX_HANDOFF｜第二種衛生管理者｜学びスプリント

更新: 2026-08-09
担当移行: ChatGPT → Codex

## 0. 最重要指示
この案件は、ユーザー確認を極力挟まず、Notion「AIアプリ開発 標準手順 v2.2」のループエンジニアリングで進める。

実装・機械検証・修正・再検証は、PASSまで自律反復する。ユーザーへ確認を求めるのは原則として以下だけ。

1. Apple / Codemagicのログイン、2FA、本人確認、契約など本人しかできない操作
2. BuildがTestFlightへ到達した後のiPhone 16実機確認
3. App Store本審査の `Add for Review` / `Submit for Review` 直前

仕様確認、軽微な実装判断、CI失敗、問題監査FAILでは止まらないこと。

## 1. 必読Notion正本
作業開始時に必ず確認する。

- 標準手順 v2.2: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- 申請手順: https://app.notion.com/p/3b009c10697d81eba325f86d8af55481
- 学びスプリント UI Golden Master: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 第二種衛生管理者 台帳: https://app.notion.com/p/3b309c10697d81d5967adbd4f88ba864
- 第二種衛生管理者 開発計画: https://app.notion.com/p/3b309c10697d81759ea6c8ce91f32567

UIは現行Golden Master v2.1を最優先する。旧FP2 v1.3、旧12問仕様、旧3タブ仕様へ戻さない。

## 2. GitHub正本
Repository:
`ALLSUNDAY1122/ALLSUNDAY1122.github.io`

### Web / Safari価値検証版
`apps/sanitary-manager-2/`

公開URL:
`https://allsunday1122.github.io/apps/sanitary-manager-2/`

重要ファイル:
- `apps/sanitary-manager-2/index.html`
- `apps/sanitary-manager-2/gm-style.css`
- `apps/sanitary-manager-2/q1.js` ～ `q9.js`
- `apps/sanitary-manager-2/audit-patch-v2.js`
- `apps/sanitary-manager-2/audit-fixes.js`
- `apps/sanitary-manager-2/question-order-v1.js`
- `apps/sanitary-manager-2/gm1.js` ～ `gm4.js`

### iOS製品版
`ios/health-manager-2/`

重要ファイル:
- `ios/health-manager-2/project.yml`
- `ios/health-manager-2/HealthManager2/HealthManager2App.swift`
- `ios/health-manager-2/HealthManager2/WebView.swift`
- `ios/health-manager-2/HealthManager2/PrivacyInfo.xcprivacy`
- `ios/health-manager-2/prepare-web-assets.sh`
- `ios/health-manager-2/export-audit-data.cjs`
- `ios/health-manager-2/learning-sprint-audit.json`
- `ios/health-manager-2/RELEASE_STATUS.md`
- `ios/health-manager-2/RELEASE_CHECKLIST.md`
- `ios/health-manager-2/APP_STORE_METADATA_JA.md`

Root build config:
- `codemagic.yaml`

公開申請ページ:
- `health-manager-2/support.html`
- `health-manager-2/privacy.html`

## 3. 現在の確定仕様
アプリ名: `第二種衛生管理者｜学びスプリント`
Bundle ID: `jp.allsunday1122.healthmanager2`
Version: `1.0.0`
Build: `1`
iOS方式: SwiftUI + local WKWebView
ビルド: Codemagic
TestFlight: Internal Testing Only
App Store本審査自動提出: OFF
課金: v1.0ではなし
広告 / 解析 / ログイン / クラウド同期: なし

### UI
Golden Master v2.1準拠。

- 生成り紙＋方眼背景
- 標準8問、設定4 / 8 / 16問
- 下部4タブ: ホーム / 模試 / 記録 / 設定
- 9セットは模試タブ
- 選択肢タップで即時採点
- 朱の○×
- 「ここだけ覚える」
- 詳細解説
- 苦手は3連続正解で卒業
- 5週間ヒートマップ
- 中断→続きから
- JSONバックアップ

ユーザーはこのUIをSafariで「問題なし」と確認済み。初期試作品の人間ゲートは通過扱い。

## 4. 問題データの現在地
90問。

- 令和8年4月 × 関係法令 10
- 令和8年4月 × 労働衛生 10
- 令和8年4月 × 労働生理 10
- 令和7年10月 × 関係法令 10
- 令和7年10月 × 労働衛生 10
- 令和7年10月 × 労働生理 10
- 令和7年4月 × 関係法令 10
- 令和7年4月 × 労働衛生 10
- 令和7年4月 × 労働生理 10

= 3試験回 × 3科目 × 10問 = 90問。

監査済み状態:
- ID重複 0
- 本文完全重複 0
- 類似度0.90以上 0
- 同一論点高類似警告 0
- 数値だけ変えた水増し問題を別能力問題へ再設計済み
- 各「試験回×科目」10問で正答位置1～5を各2回に均等化済み
- 法令基準日: 2026-08-09
- 公表問題本文を転載せず、公式公表問題は論点抽出のみ。問題文・選択肢・解説は独自作成方針

共通監査:
`automation/learning-sprint-question-pipeline/validate_questions.py`

CodemagicではmacOS/Xcodeビルド前に監査を自動実行する。

### Notion問題台帳について
`第二種衛生管理者｜問題・論点台帳` は古い管理ミラーが残っている。
令和7年10月・令和7年4月の60行などは本文/解説未同期のため、現時点のリリース生成元にしない。
製品化後のリリース正本はGitHubの監査済み90問。
Notionの古い行を理由にビルドを止めないこと。

## 5. 法令・権利監査
2026-08-09基準。

確認済み例:
- 2026-08-01施行の産業医辞任・解任等の報告関連改正
- 2025-06-01施行の職場の熱中症対策
- 2027-04-01予定の健康診断項目改正は将来施行として分離
- 2028-04-01予定の50人未満事業場ストレスチェック義務化は将来施行として分離

公表問題が公開されていることを、自由転載許諾とは扱わない。
競合アプリが使っていることも許諾根拠にしない。

## 6. iOS版で実装済み
- SwiftUI + WKWebView
- 90問Web教材をアプリ内へ完全同梱
- 外部サイトを主要教材として読み込まない
- 学習状態localStorage保存
- JSONバックアップをiOS共有シートへブリッジ
- 正解 / 不正解 / ボタン操作のネイティブハプティクス
- Privacy Manifest
- App Iconのビルド時生成
- iPhone portrait
- 外部HTTPSリンクはSafariへ出す

Apple Guideline 4.2対策として、単なる外部Webラッパーではなく、教材・履歴・復習・バックアップ・ネイティブ触覚を端末内実装している。

Guideline 4.3は第一種等の同シリーズとの類似アプリ判定リスクが残る。Internal TestFlightは止めない。本審査前に再評価する。

## 7. Codemagic現行設定
Workflow:
`health-manager-2-ios`

`codemagic.yaml` を正本とする。

重要:
- `distribution_type: app_store`
- Bundle ID `jp.allsunday1122.healthmanager2`
- XcodeGenでproject生成
- `testFlightInternalTestingOnly: true`
- `submit_to_testflight: false`
  - これはInternal Testing OnlyでBeta App Reviewへ自動提出しないため。App Store ConnectへのIPA publishing自体を無効にする意味ではない。
- `submit_to_app_store: false`

## 8. Codexが次に行うこと
上から順に実行する。確認質問を挟まない。

### Step 1: 正本再確認
- 上記Notion 3正本を読む
- `RELEASE_STATUS.md`
- `RELEASE_CHECKLIST.md`
- `APP_STORE_METADATA_JA.md`
- `codemagic.yaml`
を読む。

### Step 2: GitHub / 静的検査
Windows/Linuxで可能な検査をすべて先に行う。

最低限:
- JS構文
- 90問監査
- shell `bash -n`
- plist parse
- YAML parse
- Web資産の同梱対象確認
- Bundle ID / Version / Buildの相互一致
- Privacy Manifestと実装の一致

FAILなら修正→同じ検査をPASSまで繰り返す。

### Step 3: Apple / Codemagic状態確認
可能ならブラウザ操作で確認する。

必要項目:
- Apple Developer Explicit App ID `jp.allsunday1122.healthmanager2`
- App Store Connectアプリ
- Codemagic App Store Connect integration `codemagic`
- Apple Distribution証明書
- App Store provisioning profile

ログイン、パスワード、2FA、API秘密鍵など本人しか入力できない地点だけユーザーへ依頼する。
秘密情報はGitHub / Notion / チャットへ保存しない。

### Step 4: Codemagic Build 1
`health-manager-2-ios` workflowを実行する。

期待ループ:
1. 90問監査
2. Privacy / shell / 同梱検査
3. xcodegen
4. profile適用
5. Swift compile
6. Archive / IPA
7. App Store Connect upload
8. Apple処理
9. TestFlight Internal TestingへBuild 1到達

FAILした場合:
- ログから原因特定
- GitHub修正
- ローカルで落とせる検査を追加
- Build番号が必要な段階なら上げる
- 再ビルド

ユーザーへ「次」を要求しない。

### Step 5: TestFlight到達で停止
Build 1がTestFlightへ到達したら、ここが次の人間品質ゲート。
ユーザーへiPhone 16で実機確認を依頼する。

確認項目:
- 起動クラッシュなし
- ホーム / 模試 / 記録 / 設定
- 9セット各10問
- 8問スプリント完走
- 即時採点
- ハプティクス
- ○× / ここだけ覚える / 詳細解説
- 中断→続きから
- 苦手3連続正解で解除
- 再起動後の履歴保持
- JSON書き出し→iOS共有シート
- 機内モードで教材利用
- レイアウト崩れなし

実機FAILなら、原因に対応するループへ戻り、修正→Build番号更新→再TestFlight。

## 9. やってはいけないこと
- 旧12問UIへ戻す
- 旧FP2 UIを現行Golden Masterより優先する
- 3試験回を30問ずつの3カードにまとめて、9セット導線を消す
- Notionの古い60行をリリース正本としてGitHub90問を上書きする
- 公表問題本文をそのまま転載する
- App Store本審査をユーザー最終確認なしでSubmitする
- Apple認証情報を保存する
- CIのFAILをユーザーへ丸投げする
- 「次」と送らせて小刻みに進める

## 10. 完了定義
Codex担当の今回フェーズは、以下で完了。

1. CodemagicのビルドループをPASS
2. IPAがApp Store Connectへアップロード
3. BuildがTestFlight Internal Testingへ到達
4. `RELEASE_STATUS.md` とNotion台帳をその状態へ更新
5. ユーザーへiPhone 16実機確認だけを依頼

App Store本審査はまだ実行しない。
