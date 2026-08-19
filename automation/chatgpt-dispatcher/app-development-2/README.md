# アプリ開発②｜13セッション起動手順

ChatGPTプロジェクト **「アプリ開発②」** の中に、以下13個の新規チャットを作成する。

| セッション | Worker Role |
|---|---|
| 仕訳スワイプ② | SHIWAKE |
| 呑み処アーケード② | NOMIDOKORO |
| 夜の書架② | YORU |
| 薬剤師国試② | YAKUZAISHI |
| 第一種衛生管理者② | HM1 |
| 第二種衛生管理者② | HM2 |
| 危険物乙4② | OTSU4 |
| ITパスポート② | ITPASS |
| 看護師国試② | KANGOSHI |
| 登録販売者③ | TOUHAN |
| 卓 TAKU CALC② | TAKU |
| ネットワークスペシャリスト② | NW |
| 作業療法士国試② | SAGYO16 |

## 登録
1. プロジェクト「アプリ開発②」を開く。
2. 上記13個の新規チャットを作る。本文は空でよい。
3. 各チャットを開き、Dispatcherの `Worker label` にセッション名、`Role` に上表の値を入力して「現在のタブを登録」。
4. Queue URLに以下を設定する。
   `https://raw.githubusercontent.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/refs/heads/automation/app-development-2-session-dispatcher/automation/chatgpt-dispatcher/app-development-2/queue.json`
5. 最初は `maxActive=3`、確認間隔1〜2分で開始する。安定確認後に5/8/13へ増やせる。
6. 「Worker診断」で13タブがcomposer接続済みであることを確認する。
7. 自動配車ON → 保存 → 今すぐ確認。

各Taskはworker_roleが一致する専用タブにだけ配車される。Task開始後は会話履歴ではなくNotion/GitHub/ASC/Codemagicを再取得し、最新実状態から再開する。

## 注意
- Dispatcherは現状、ChatGPTプロジェクト内の新規チャットそのものを自動生成しない。13チャット作成と各タブ登録だけはUI操作が必要。
- Task完了時はWorkerがQueueの自分のTaskだけDONE/HUMAN_REQUIREDへ更新する。
- 旧作業療法士PoCのbranch/Queueは変更しない。
