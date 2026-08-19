# アプリ開発②｜13セッション再開 Worker契約 v0.1

対象は ChatGPTプロジェクト **「アプリ開発②」** 内で再開する13個のアプリ専用セッション。

## 正本
- Notion「アプリ開発台帳」
- 各アプリのNotion正本ページ
- Notion「🚀 【標準手順】AIアプリ開発・公開フロー v2.7」
- Notion「申請手順」
- GitHub `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App Store Connect / Codemagic の現在実状態
- Dispatcher control branch `automation/app-development-2-session-dispatcher`
- Queue `automation/chatgpt-dispatcher/app-development-2/queue.json`

## Worker原則
1. この会話は割り当てられた1アプリ専用とし、他アプリへ担当を拡張しない。
2. Codexは使わない。ChatGPTで進める。
3. 会話履歴を正本にしない。開始時にNotion / GitHub / App Store Connect / Codemagicの現在実状態を再取得する。
4. 完了済み作業を再実行しない。現在の最大未完了差分を選ぶ。
5. 人間判断が不要なら質問せず、調査→実装→test→監査→次工程までMacro Loopで進める。
6. 実装は対象アプリの現行branchを正本から解決して作業する。Dispatcher branchを実装branchとして使わない。
7. 意味のある実装変更は各実装回答でローカルcommitする。実装回答3回ごと、または人間Gate・Build・長時間離脱前にGitHubへcheckpoint pushしremote反映を確認する。
8. API化済みの作業は原則API-first。ASC / Codemagic / GitHubは read → canonical比較 → write → read-back の順で行う。
9. コード/UI/問題/法令/購入/Privacyに変更が入ったら旧PASSは失効。変更後のBuild・TestFlight・実機確認を新たに行う。
10. secret、token、`.p8`、署名鍵等をGitHub/Notionへ保存しない。
11. App Store最終提出・公開、契約/税/銀行、2FA、iPhone実機でしか判断できない最終価値確認など真正なHUMAN_REQUIREDだけで停止する。
12. Task終了時は証拠を `evidence_path` へ保存し、Queueの自分のTaskだけをDONE/HUMAN_REQUIREDへ更新してread-backする。

## 起動時に必ず行うこと
- Notion台帳の状態・次の作業を取得
- 各アプリ正本を取得
- GitHubの対象branch / recent PR / CI / mainとの差分を確認
- Apple到達済みアプリはASCのBuild/TestFlight/App version状態を確認
- 直近ユーザー実機報告を「未解決の可能性がある観測」として扱い、コード・Build・実機証拠で解消済みか判定
- その結果に基づき、今回のセッションで進める最大未完了差分を決定する
