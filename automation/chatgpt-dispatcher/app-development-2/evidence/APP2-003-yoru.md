# APP2-003｜夜の書架｜Pattern C / 申請前preflight

更新: 2026-08-22 19:44 JST
セッション: 夜の書架②
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`

## 現在結論

Pattern C「紙面・温かみ」は `ALLSUNDAY1122/yoru-no-shoka` mainへ統合済み。現行ソースは `1.2.0 / Build 4`。

App Store Connect fresh preflightでは App Store Version `1.2.0 / PREPARE_FOR_SUBMISSION`、attached Buildなし、Review Submission 0件。Build 4はまだAppleへ未到着。最終 `Add for Review / Submit for Review` は実施していない。

申請手順はNotion正本「AIアプリ開発・公開フロー v2.7」および「申請手順」を再取得して確認した。標準順序は `API preflight → AUTO-FIX → Build → Apple processing → Internal TestFlight → 実機受入 → submission audit → 最終承認 → Add for Review / Submit for Review`。ログイン/2FA、契約・税務・銀行、実機受入、DSA自己判定/本人確認、最終Submit承認以外は原則AI/API/CI側で処理する。

## Pattern C 実装済み

- 紙面 / 深いセピア / 漆黒の3テーマ
- 明るさ 70–120%
- 本文文字サイズ・行間
- 明朝 / ゴシック
- 設定値端末保存
- ホーム主CTA「今夜の一話を読む」
- おまかせ / シリーズから選ぶ / 書架を見るを副導線化
- シリーズ/話者の役割・読み味ガイド
- 各作品カードの明示的「この話を読む」
- 検索 / 怖さ / 長さ / シリーズ絞り込み
- 保存済み / 読了状態
- 読書画面を 戻る / タイトル / Aa / その他 に整理
- 保存 / 共有 / 読了 / ホームをその他メニューへ集約
- 読書進捗バー

## App Store Connect fresh preflight｜2026-08-22

- App: 夜の書架
- App ID: `6794137637`
- Bundle ID: `io.github.allsunday1122.yorunoshoka`
- App Store Version: `1.2.0`
- State: `PREPARE_FOR_SUBMISSION`
- attached Build: なし
- Review Submission: 0件
- Apple上に存在するBuild: 1 / 2 / 3のみ
- Build 4: 未到着
- 日本語description: あり
- keywords: あり
- Support URL: あり
- Marketing URL: あり
- App Review contact: 必須4項目あり
- demo account: 不要
- Beta Review contact: 必須4項目あり
- Internal/Beta groups: 既存3グループ
- App Info subtitle / Privacy Policy URL: あり
- iPhone screenshot set: 4枚あり

ただし既存4枚はPattern C刷新前の画像である可能性を排除できないため、Build 4の実機受入後にPattern C現UIのホーム・書架・読書画面を含む画像へ差し替える。旧4枚の存在だけではScreenshot gateをPASSにしない。

## Age Rating fresh audit｜2026-08-22

App Store Connect APIのAge Rating Declarationを直接read-back。

- `horrorOrFearThemes = FREQUENT_OR_INTENSE`
- `matureOrSuggestiveThemes = NONE`
- `profanityOrCrudeHumor = NONE`
- cartoon/fantasy violence = INFREQUENT_OR_MILD
- realistic violence = INFREQUENT_OR_MILD
- prolonged graphic/sadistic violence = NONE
- sexual content = NONE
- simulated gambling = NONE
- drugs/alcohol/tobacco references = NONE
- guns/other weapons = INFREQUENT_OR_MILD
- unrestricted web access = false
- UGC / messaging / social media = false
- advertising = false
- override = NONE

AppInfoのlegacy `appStoreAgeRating` は `TWELVE_PLUS` が残っているが、territory age ratingは `THIRTEEN_PLUS`。提出時は新体系の13+を現行判定として扱い、legacy 12+を根拠にしない。ASCが質問移行を要求した場合のみ現行UIで再回答する。

証拠: `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-age-rating.json`

## Codemagic｜2026-08-22

GitHub側では Codemagic CI/CD GitHub App に `ALLSUNDAY1122/yoru-no-shoka` のprivate repository accessを許可済み。

以前API/URL方式で作成したCodemagic ApplicationはGitHub provider integrationに結合されず `branches=null` の空Applicationとなっていた。ユーザーの明示許可後、以下を削除した。

- 元の空Application `6a856ad0cfa731a85617d8fb`
- 検証用重複Application `6a89709c57ba683ac5fcdbe8`

削除後、Codemagic Applications API read-backで対象候補0件を確認済み。GitHub repositoryやApp Store Connectレコードは削除していない。

Codemagic公開REST Applications APIでは、GitHub App integrationで認可済みprivate repositoryをprovider-bound Applicationとして作成する方法は確認できない。`POST /apps` はURL追加、private repoのAPI追加はSSH key方式であり、GitHub App UI選択を代替しない。

したがって現在の唯一のBuild前UIゲートは、Codemagic上で新規ApplicationをGitHub App経由で作成する操作:

`Add application → GitHub → ALLSUNDAY1122/yoru-no-shoka → Other → Finish`

この1回が成立した後は、ChatGPT側のCodemagic Gatewayで新App IDを再取得し、mainの `codemagic.yaml` workflow `yoru-ios` を使用して以下を自動実行する。

1. 1.2.0 / Build 4署名Build
2. App Store Connect upload
3. Apple processing監視 / validation error解析
4. Internal TestFlight割当
5. App Store Version 1.2.0へBuild 4紐付け
6. submission audit再実行
7. Pattern C実機受入後、現UI screenshotsへ更新
8. Review Notes / Privacy / Age Rating / export compliance最終監査
9. `WAITING_FINAL_APPROVAL` まで進行

`submit_to_app_store` は禁止し、本審査Submitはユーザー最終承認後のみ実行する。

## 現在の人間ゲート

1. CodemagicでGitHub App経由の `yoru-no-shoka` Application新規作成（公開REST APIでは代替不能）
2. Build 4到着後のiPhone TestFlight実機受入
3. DSAトレーダー自己判定・該当時の本人確認
4. 最終 `Add for Review / Submit for Review` 承認

## Task判定

`HUMAN_REQUIRED`

理由: 申請前preflightと自動補完可能部分は実行済み。現在の停止点はCodemagicのGitHub App provider-bound Application新規作成という認証済みWeb UI操作であり、利用可能な公式API/接続ツールでは代替不能。その操作後はBuild 4→TestFlight→submission auditをAI側で継続できる。
