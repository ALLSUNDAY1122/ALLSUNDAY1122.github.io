# APP2-003｜夜の書架｜Pattern C UI刷新後の現在状態

更新: 2026-08-19 17:42 JST
セッション: 夜の書架②
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`

## 結論

ユーザー採用のパターンC「紙面・温かみ」を実装し、`ALLSUNDAY1122/yoru-no-shoka` mainへ統合した。UI変更により旧 `1.1.0 / Build 3` の実機PASSは失効扱いとした。

現行ソースは `1.2.0 / Build 4`。App Store Connectは旧Build 3のrelationshipを解除し、App Store Versionを `1.2.0 / PREPARE_FOR_SUBMISSION` へ整合済み。本審査Review Submissionは0件のままで、最終提出操作は実施していない。

新署名Build 4の作成については、Codemagic Application登録とworkflow追加までは自動完了したが、Codemagicはprivate GitHub repositoryをcloneする前に失敗した。EAS GitHub AppのPRラベル経路も試行したがBuild checkが生成されず、現時点では外部GitHub Appのrepository access authorizationが真正な停止点。

## Pattern C 実装

- 紙面 / 深いセピア / 漆黒の3テーマ
- 明るさ 70–120% 調整
- 本文文字サイズ 16–24px
- 行間 1.6–2.5
- 明朝 / ゴシック切替
- 設定値を端末内へ保存
- ホーム主CTAを「今夜の一話を読む」へ一本化
- 「おまかせ」「シリーズから選ぶ」「書架を見る」を副導線へ整理
- 夜語り / 真壁夜話 / 境界観測記 / 黒瀬蒐集録 / 榊家異聞の語り口・役割ガイドを追加
- 各作品カードへ明示的な「この話を読む」ボタンを追加
- 検索 / 怖さ / 長さ / シリーズ絞り込みを明示
- 保存済み / 読了状態をカード上で可視化
- 読書画面上部を 戻る / タイトル / Aa / その他 に整理
- 保存 / 共有 / 読了 / ホームをその他メニューへ集約
- 読書進捗バーを追加
- 読書画面にも同一の表示設定を追加
- 紙面テーマで読書CTAのコントラストを補強
- 明るさfilterのreader二重適用を防止

## GitHub

- Pattern C作業branch: `ui/pattern-c-paper-warm`
- UI PR: `#1 夜の書架｜パターンC 紙面・温かみUIへ刷新`
- PR #1: squash merge済み
- Pattern C merge commit: `0e88fa394be5952099e1912a59b5cea2195c0d03`
- Build用version sync script追加: `scripts/sync-ios-release-version.mjs`
- Codemagic workflow追加: `codemagic.yaml` / workflow `yoru-ios`
- Release status PR #2もmerge済み
- 現行main: `92205849e7df1290933983cc20af5df167673bfa`
- `app.json`: `1.2.0 / Build 4`

## 検証

GitHub Actions hosted runnerはprivate repository側でテストStep開始前に終了し、ジョブログ/Stepが生成されなかったためコードのtest failureとは判定していない。

代替検証:

- TypeScript / JSX 構造チェック: PASS
- CSS parser構文チェック: PASS
- PR差分監査: PASS
- 既存SSR回帰テストのUI契約をPattern Cへ更新
- 最終差分でbrightness二重適用と紙面CTA contrastを追加修正

## App Store Connect｜Pattern C整合

UI刷新前read-back:

- App Store Version: `1.1.0`
- State: `PREPARE_FOR_SUBMISSION`
- Build relationship: Build 3
- Review Submission: 0件

専用semantic actionで以下を実行:

1. App / Bundle ID固定preflight
2. `PREPARE_FOR_SUBMISSION` を確認
3. Review Submission 0件を確認
4. attached Buildが既知Build 3であることを確認
5. Build 3 relationshipをPATCH `data: null` で解除
6. build relationship read-back = null
7. Versionを `1.2.0` へ更新
8. `1.2.0 / PREPARE_FOR_SUBMISSION` をread-back

証拠: `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-pattern-c-asc-align.json`

## Codemagic

Codemagic Applications APIで夜の書架を登録:

- Application ID: `6a856ad0cfa731a85617d8fb`
- workflow: `yoru-ios`
- branch: `main`

Build 4開始:

- Build ID: `6a856b0d619d73e29453c47f`
- 結果: `failed`
- `started_at`: null
- `commit`: null
- `branch`: null
- artifacts: 0

以上から、コンパイルや署名stepへ入る前のsource checkout/repository connection停止と判定。private repositoryをCodemagicへ追加する正式APIはSSH key付き `/apps/new` が必要だが、GitHub側deploy key追加は現在の接続ツールで自動実行できないため、外部repository authorizationが必要。

## EAS fallback

- EAS Project ID: `f1a46391-1511-49ef-bfc6-846e4df70735`
- 過去のiOS production build成功実績あり
- Expo公式GitHub Appの `eas-build-ios:production` PRラベル経路をPR #2で試行
- label付与は成功したがEAS build check / statusは生成されなかった
- PR #2は正本更新としてmainへmerge済み

現時点ではExpo GitHub Appが当該private repositoryへ接続済みである証拠を取得できない。

## Notion

- アプリ開発台帳: `開発中`
- 正本ページ: Pattern C / 1.2.0 Build 4へ更新済み
- ASC 1.2.0整合・旧Build 3解除・Codemagic登録/Build停止点を反映済み

## 現在の真正な停止点

新Build 4をcloud buildするには、次のどちらか一方のprivate repository authorizationが必要。

1. Codemagicに `ALLSUNDAY1122/yoru-no-shoka` のGitHub private repository accessを許可する。
2. Expo GitHub Appを同repositoryへ接続し、EAS project `f1a46391-1511-49ef-bfc6-846e4df70735` とrepositoryをリンクする。

この認可が成立すれば、ChatGPT側でBuild開始→監視→ASC/Internal TestFlight到着確認まで再開可能。

その後の人間ゲート:

- iPhone TestFlightでPattern C実機受入確認
- DSAトレーダー自己判定・必要な本人確認
- App Store本審査の最終 `Add for Review` / `Submit for Review` 承認

## Task判定

`HUMAN_REQUIRED`

理由: Pattern C実装、main統合、ASC version/build整合、Build automation準備までは完了。新署名Build 4だけが外部GitHub Appのprivate repository access authorizationで停止しているため。
