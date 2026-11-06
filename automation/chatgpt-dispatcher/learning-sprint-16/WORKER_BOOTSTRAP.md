# 学びスプリント #16｜自動Dispatcher Worker契約 v0.1

対象は **作業療法士国家試験｜学びスプリント（開発連番16）**。

## 正本
- Notion「アプリ開発台帳」の開発連番16
- Notion「🚀 【標準手順】AIアプリ開発・公開フロー」
- GitHub `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- 作業branch `learning-sprint-16-sagyo-dispatcher`
- Queue `automation/chatgpt-dispatcher/learning-sprint-16/queue.json`

## Worker原則
1. Codexは使用しない。
2. 会話履歴を正本にしない。毎Task開始時にNotion/GitHub/branchの最新状態を再取得する。
3. Queueの依存関係に従い、今回配車されたTask以外へ勝手に拡張しない。
4. 人間判断が不要なら質問せず、Macro Loopで大きく進める。
5. 調査・実装・test・監査の証拠をGitHubへ保存する。
6. 実装変更はローカルGitで管理し、3実装回答ごと、またはTask終了前に必ずGitHub checkpointする。
7. secret、token、`.p8`、署名鍵等は保存しない。
8. GitHub Queue更新は、Task終了時に最新queueを再取得して対象Taskだけを変更する。
9. `DONE` は観測可能な証拠があるときだけ付ける。
10. 真正なHUMAN_REQUIREDなら `queue.paused=true` にして停止する。

## 学びスプリント固有
- UIは現行の学びスプリント共通正本を優先し、旧アプリ固有UIをコピーして正本化しない。
- 問題・正解・解説・試験回・科目構成を作成/変更したら問題品質ループを必ず再起動する。
- 既存 `automation/learning-sprint-question-pipeline/` を再利用する。
- 過去問本文は権利根拠が明確な範囲だけ利用し、それ以外は一次資料を論点根拠に独自問題・独自解説を作る。
- #15 理学療法士の実装は REUSE_SCAN 対象だが、作業療法士固有の試験構成・問題領域を混同しない。

## 完了処理
Task完了時はQueueの対象Taskを `DONE` とし `completed_at` をUTC ISO8601で設定する。
証拠ファイルを各Taskの `evidence_path` へ保存する。

HUMAN_REQUIRED時はTaskを `HUMAN_REQUIRED`、Queueを `paused=true` とし、
`pause_reason` に「ユーザーが行う最小操作」を1〜3文で記載する。
