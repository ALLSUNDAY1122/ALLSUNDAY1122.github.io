# Portfolio Dispatcher v2

多数のChatGPT開発セッションを、Codexを通常配車に使わず、GitHub Queueから短命運転するManifest V3 Chrome拡張。

## 目的
- 人間が各セッションへ `次` を入力する運用を減らす。
- 登録セッション数と同時生成数を分離する。
- RAM/CPU/ChatGPTタブ圧力に応じて同時配車数を自動調整する。
- 1セッションを標準3 WaveでROTATE対象にし、長文化・固着を抑える。
- Codexは通常配車から外し、例外処理だけに限定する。

## Resource Governor
初期値:
- GREEN: 最大3セッション配車
- WARN: 最大2
- THROTTLE: 最大1
- STOP: 新規配車0
- RAM: 70/80/90%で段階制御
- CPU: 75/85/95%で段階制御
- ChatGPTタブ: 12超で警戒、20超で1本へ制限
- 直近20配車の失敗率30%以上で同時数を1段階削減
- heavy I/O workerは同時1本
- 既に生成中のbusy workerを先に数え、`maxActive - busyCount` の空き枠だけ新規配車する

Chrome公式 `system.memory` / `system.cpu` APIを使用するため、Windows常駐Resource Governorは不要。

## セッション寿命
- 同一Taskの初回: Task詳細を送信
- 2〜3回目: `次`
- 3回送信後: `ROTATE_AFTER_RESPONSE`
- 次回tick以降はそのsessionへ送信しない

**注意:** v0.2時点では新規ChatGPT会話の自動生成・プロジェクトへの自動所属は未実証。ROTATE検出までは自動。安全性を確認せずDOMクリックで会話生成を実装しない。

## セットアップ
1. `portfolio-workers.example.js` を `portfolio-workers.local.js` にコピー。
2. 各Workerの conversation URL / projectId / roleを設定。
3. Chrome `chrome://extensions` → Developer mode → Load unpacked。
4. popupでPreflight。
5. RAM/CPU/タブ数、composer接続を確認後Start。

`portfolio-workers.local.js` はGitへ保存しない。

## Queue
DispatcherはPortfolio正本の `project_registry[].queue_locator` がHTTPS URLのprojectだけを読む。
Queue taskは `READY` を新規配車し、`CLAIMED` / `WORKING` は `claimed_by` が同一Workerなら継続可能。human gateは配車しない。

## 残る実証Gate
1. 現行ChatGPT UIで3 Waveを誤送信0で実行。
2. busy中に二重送信しない。
3. RAM/CPU高負荷時のthrottle/stop。
4. Chrome再起動後のstate復旧。
5. ROTATE後継sessionの自動生成方法を実証してから追加。
6. 多project時のrepo write lockとheavy I/O gateをQueue側と統合。
