# アプリ開発② Dispatcher Extension v0.2.0

この独立したMV3拡張は、旧 chatgpt-queue-dispatcher-ls16-v0.1.2 を変更しない。

## 動作

- app2-workers.local.js の13 WorkerをRoleとconversation IDで固定する。
- 起動前診断では13会話を別タブで開き、ChatGPT composer / busy / send可否だけを確認する。
- Round 1はQueueの同Role Taskを1件ずつ送る。
- Round 2〜5は前回回答が完了しているWorkerへだけ 次 を送る。
- stop-button、busy、composer不可、HUMAN_REQUIRED、DONEは該当Workerだけskipする。
- 各RoundでWorkerごとの送信試行を先に永続化するため、service worker中断時も同一Roundの二重送信を防ぐ。
- chrome.alarms と chrome.storage.local でrun_countと絶対時刻を保存し、run_count=5で停止する。

## ローカルWorker設定

app2-workers.example.js を app2-workers.local.js にコピーして、13件のURLをローカルだけに保存する。後者はGit管理外とする。

## 制約

Chrome自体またはWindowsが停止している間は配車できない。Chrome再起動後は保存済みの次回時刻を確認し、未実行のRoundを1回だけ安全に再開する。
