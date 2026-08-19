# アプリ開発② Dispatcher log

| 時刻 | run_count | セッション | Role | 結果 | skip理由 | 二重送信 |
|---|---:|---|---|---|---|---|
| 2026-08-19T11:55:49.5638327+09:00 | 0 | - | - | PREPARED | 拡張機能の有効化待ち。ChatGPTへは未送信。 | 0 |

実行時のWorker別ログは、拡張機能の chrome.storage.local に最大300件を保存する。回答本文、secret、token、署名鍵は保存しない。
