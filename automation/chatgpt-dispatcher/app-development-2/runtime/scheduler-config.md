# アプリ開発② Dispatcher scheduler configuration

- Worker数: 13
- Queue: APP2-001〜APP2-013
- Role固定: SHIWAKE, NOMIDOKORO, YORU, YAKUZAISHI, HM1, HM2, OTSU4, ITPASS, KANGOSHI, TOUHAN, TAKU, NW, SAGYO16
- Round 1: オペレーターが拡張機能の開始ボタンを押した時点で即時
- Round 2〜5: Round 1開始時刻を基準に40分間隔
- run_count: 0 → 1 → 2 → 3 → 4 → 5
- 自動停止: run_count=5
- 送信条件: composer検出、busy=false、stop button非表示、send可
- busy / composer不可: 該当WorkerのみSKIP。他Workerは継続
- HUMAN_REQUIRED / DONE: 該当Roleのみ継続送信を停止
- 二重送信防止: Round内の送信試行を送信前に永続化し、service worker中断時は同Roundを再送しない
- 永続化: chrome.storage.local と chrome.alarms

ChromeまたはWindowsが停止している間は送信できない。Chrome再起動後は保存済みの時刻を確認し、未完了Roundを1回だけ安全に再開する。
