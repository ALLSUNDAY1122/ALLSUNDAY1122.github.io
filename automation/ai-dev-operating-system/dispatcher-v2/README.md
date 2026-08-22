# Portfolio Dispatcher v2.2

多数のChatGPT開発セッションを、Codexを通常配車に使わず、GitHubのPortfolio / Project正本から短命運転するManifest V3 Chrome拡張。

## 目的
- 人間が各セッションへ `次` を入力する運用を減らす。
- 登録セッション数と同時生成数を分離する。
- RAM/CPU/ChatGPTタブ圧力に応じて同時配車数を自動調整する。
- 1セッションを標準3 Macro WaveでROTATE対象にし、長文化・固着を抑える。
- Project固有のclaim/Lane契約をDispatcherが上書きしない。
- Codexは通常配車から外し、例外処理だけに限定する。

## Resource Governor
初期値:
- GREEN: 最大3セッション同時生成
- WARN: 最大2
- THROTTLE: 最大1
- STOP: 新規配車0
- RAM: 70/80/90%で段階制御
- CPU: 75/85/95%で段階制御
- ChatGPTタブ: 12超で警戒、20超で1本へ制限
- 直近20配車の失敗率30%以上で同時数を1段階削減
- heavy I/O workerは同時1本
- 既に生成中のbusy workerを先に数え、`maxActive - busyCount` の空き枠だけ新規配車する
- CPU baselineがない初回も500msの2点測定を行い、高負荷を0%と誤認しない

Chrome公式 `system.memory` / `system.cpu` APIを使用するため、初期実装ではWindows常駐Resource Governorを追加しない。

## セッション寿命
- 1セッション: 標準3 dispatch / Macro Wave
- 初回: Project契約に応じた起動指示
- 2〜3回目: 原則 `次`
- 3回送信後: `ROTATE_AFTER_RESPONSE`
- 次回tick以降はそのsessionへ送信しない

セッションの長寿命化を目的にしない。正本から再構築できることを前提とする。

## 配車アダプタ
### fixed_role_queue
アプリ開発②とScaniverse HQ-only controlで使用。roleに対応するTaskだけを起こし、HUMAN_REQUIRED / BLOCKED_HUMANを除外する。

### fixed_lane_plan
Moises v3で使用。Global Queue claimは行わない。Lane Planとworker-statusを読み、未完了Macro BundleがあるLaneだけを起動する。`CHECKPOINT_READY` Workerには`次`を送らない。checkpointがある場合は登録済みHQをLate Integrationのため起動できる。

### atomic_pool
HomeCourtで使用。DispatcherはREADY Taskを事前指名しない。空いているPool Workerだけを起こし、Worker自身がQueue CAS atomic claimする。

v2.2ではさらに:
- `CLAIMED/WORKING`でleaseが有効かつ`claimed_by == worker.id`なら同じWorkerへ継続を送る。
- lease期限切れTaskは通常継続せず、fenced再claim用Recovery Wakeへ切り替える。
- 同一stale Taskを同じtickで複数Workerへ配らない。
- READY数を超える新規Pool Workerを同一tickで起こさない。

## Portfolio接続状況
- app-development-2: ACTIVE / fixed_role_queue
- moises-parity: ACTIVE / fixed_lane_plan
- homecourt-parity: ACTIVE / atomic_pool
- scaniverse-parity: ACTIVE_HQ_ONLY / fixed_role_queue

Scaniverse A2/B2/C2/D2は2026-08-22観測時点でintegrationに対し全てahead=0・behindのみのため、旧Laneへ機械的に`次`を送らない。HQ control taskで最新integration HEADから新Lane Planを再発行するまで停止する。

## Worker登録
v2.2ではGitの`portfolio-workers.local.js`編集は必須ではない。

1. 対象ChatGPT会話をChromeで開く。
2. 拡張popupを開く。
3. project / Worker ID / role等を入力。
4. `このタブを登録`。
5. Preflightでcomposer/busy/eligible状態とResource Governorを確認。
6. Start。

Moises Workerは`remoteWorkerId=Moises-Worker-N`とLane IDを登録する。Moises HQは`role=HQ`。HomeCourt Pool WorkerはDispatcher上のWorker IDを、atomic claim時の`claimed_by` identityとして使用する。

## 安全な状態復旧
- 会話履歴は正本にしない。
- timeout/固着自体をHuman Gateにしない。
- Moises IN_PROGRESS Laneは再度起こせるがCHECKPOINT_READYは起こさない。
- HomeCourt有効claimは同一Workerで継続し、期限切れclaimは新epochのfenced recoveryへ移す。
- Scaniverse旧Laneは最新integrationへ完全包含済みなら勝手に再開しない。

## 現在の実証結果
ローカル静的/VM検証:
- Manifest / service-worker / content-script / popup JavaScript構文: PASS
- v2.1 core + v2.2 patch Service Worker load: PASS
- event listener registration: PASS
- 有効atomic claim continuation: PASS
- expired lease recovery selection: PASS
- stale Task same-tick duplicate reservation prevention: PASS
- `id` / `task_id` normalization: PASS
- Moises IN_PROGRESS eligible / CHECKPOINT_READY ineligible: PASS

## 残る実証Gate
1. **実際のログイン済みChatGPT UIで3 Waveを誤送信0で実行**。
2. busy中に二重送信しないことを実ブラウザで確認。
3. RAM/CPU高負荷時のthrottle/stopを実ブラウザで確認。
4. Chrome再起動後のstorage/alarms復旧。
5. **ROTATE後継sessionをプロジェクト内に自動生成する方法の実証**。
6. 後継sessionがProject instructions / files contextを確実に継承することの確認。
7. exact network bandwidth shapingは未実装。heavy I/O=1とfailure-based throttlingのみ。

## 後継チャットに関する禁止
ChatGPT Projectsではプロジェクト内で作成したチャットがProject instructions/files contextを継承する。したがって、通常の`chatgpt.com/`新規チャットを作るだけでROTATE完了扱いにしない。プロジェクト内新規チャット作成を実UIで証明するまではauto rotationを本番有効化しない。
