# APP2-003｜夜の書架｜Pattern C UI刷新後の現在状態

更新: 2026-08-20 17:30 JST
セッション: 夜の書架②
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`

## 結論

ユーザー採用のパターンC「紙面・温かみ」は `ALLSUNDAY1122/yoru-no-shoka` mainへ統合済み。現行ソースは `1.2.0 / Build 4`。App Store Connectも `1.2.0 / PREPARE_FOR_SUBMISSION` へ整合し、旧Build 3のrelationshipは解除済み。本審査Review Submissionは0件で、最終提出操作は実施していない。

2026-08-20、ユーザーがGitHubの Codemagic CI/CD GitHub App に `ALLSUNDAY1122/yoru-no-shoka` を6件目の許可repositoryとして追加しSaveした。GitHub側repository access authorizationは解消した。

ただしCodemagicで以前API作成したApplication `6a856ad0cfa731a85617d8fb` 自体がGitHub repository integrationへ結合されていない。API read-backでは `appName=yoru-no-shoka` だが `branches=null`、repository URL/ID/provider情報なし。GitHub認可後のBuild再試行 `6a86b9c3f0e709353c165efe` も `started_at=null / commit=null / branch=null / artifacts=0` でsource checkout前に即時failedした。

Codemagic公式仕様ではGitHub App連携アプリはCodemagic UIの Add application → GitHub → repository選択で作成するか、既存GitHub連携アプリなら App settings → Repository settings → Update repository URL で再結合する。REST Applications APIのprivate repository追加はSSH key方式 `/apps/new` であり、現在のAPI作成済み空ApplicationをGitHub App統合へ変更する公開APIは確認できない。

EAS fallbackとして `yoru-no-shoka/.github/workflows/eas-build4.yml` を追加したが、private repositoryのGitHub Actions hosted runnerは以前と同様にStep開始前で停止する状態が継続。直近既知run `32232306085` はjob failure、steps 0件。EAS_BUILD4_STATUS.jsonも生成されず、GitHub Actions経由のEAS起動は現時点では使用できない。

## Pattern C 実装済み

- 紙面 / 深いセピア / 漆黒の3テーマ
- 明るさ 70–120% 調整
- 本文文字サイズ・行間調整
- 明朝 / ゴシック切替
- 設定値を端末内保存
- ホーム主CTAを「今夜の一話を読む」に一本化
- おまかせ / シリーズから選ぶ / 書架を見るを副導線化
- シリーズ/話者の役割・読み味ガイド追加
- 各作品カードに「この話を読む」明示
- 検索 / 怖さ / 長さ / シリーズ絞り込み明示
- 保存済み / 読了状態可視化
- 読書画面上部を 戻る / タイトル / Aa / その他 に整理
- 保存 / 共有 / 読了 / ホームをその他メニューへ集約
- 読書進捗バー追加

## GitHub

- repository: `ALLSUNDAY1122/yoru-no-shoka`
- Pattern C PR #1: main統合済み
- Release status PR #2: main統合済み
- `app.json`: `1.2.0 / Build 4`
- Build用version sync: `scripts/sync-ios-release-version.mjs`
- Codemagic workflow: `codemagic.yaml` / `yoru-ios`
- EAS fallback workflow: `.github/workflows/eas-build4.yml`

## App Store Connect

- App Store Version: `1.2.0`
- State: `PREPARE_FOR_SUBMISSION`
- 旧Build 3 relationship: 解除済み
- Review Submission: 0件
- Build 4: Appleへ未到着
- 最終App Review提出: 未実施

## Codemagic 2026-08-20再監査

GitHub側:

- Codemagic CI/CD GitHub Appはインストール済み
- repository accessは `Only select repositories`
- `ALLSUNDAY1122/yoru-no-shoka` を追加しSave済み

既存Codemagic Application:

- App ID: `6a856ad0cfa731a85617d8fb`
- `appName`: `yoru-no-shoka`
- `branches`: null
- repository integration識別情報: API read-backで確認できず

認可後Build retry:

- Build ID: `6a86b9c3f0e709353c165efe`
- status: `failed`
- `started_at`: null
- `commit`: null
- `branch`: null
- artifacts: 0

したがってGitHub Appのrepository permission不足は解消したが、Codemagic内のApplication repository bindingが残る停止点。

## 次の真正な人間操作

Codemagic UIで既存 `yoru-no-shoka` ApplicationをGitHub repository integrationへ結び直す。

推奨順:
1. Codemagic → Applications → `yoru-no-shoka` → App settings → Repository settings。
2. `Update repository URL` がある場合は実行し、GitHub上の `ALLSUNDAY1122/yoru-no-shoka` を選択/再結合。
3. 更新できない場合は既存の空ApplicationをArchive/Deleteし、Add application → GitHub → `ALLSUNDAY1122/yoru-no-shoka` → codemagic.yaml を使用して再追加。

repository bindingが成立すれば、ChatGPT側でBuild 4開始→監視→ASC/Internal TestFlight到着確認まで再開できる。

その後の人間ゲート:
- iPhone TestFlightでPattern C実機受入確認
- DSAトレーダー自己判定・必要な本人確認
- App Store本審査の最終 `Add for Review` / `Submit for Review` 承認

## Task判定

`HUMAN_REQUIRED`

理由: GitHub App repository authorizationは解消済み。残る技術停止点はCodemagic UI内のApplication repository bindingで、公開REST APIからの更新手段を確認できないため。
