# Moises同等化｜HQ BOOTSTRAP v2 — Fixed Work Package運用

## 正本
- Notion: Moises技術同等化｜AI音源分離アプリ 正本
- GitHub: ALLSUNDAY1122/ALLSUNDAY1122.github.io
- Integration branch: `tech/moises-separation`
- Integration PR: #4431
- Global Queue: `automation/chatgpt-dispatcher/moises-equivalence/queue.json`
- Work Package manifest: `automation/chatgpt-dispatcher/moises-equivalence/work-packages.json`
- Worker status: `automation/chatgpt-dispatcher/moises-equivalence/worker-status/worker-N.json`
- Parity: `tech-assets/moises-audio/PARITY_MATRIX.json`
- Resource locks: `automation/chatgpt-dispatcher/moises-equivalence/resource-locks.json`

## 運営方式
本プロジェクトは「同等化パック」をFixed Work Package方式で運用する。
1. AIアプリ開発・公開フロー v2.7
2. Phase単位のWork Package固定割当
3. HQ単独Global Queue writer/finalizer
4. Worker専用status file
5. 完全同等化PARITY契約

自由claim型Worker Poolは廃止する。

## 最終目的
Moisesの名称・ロゴ・非公開コード・学習データ・著作物を複製せず、公開されている主要iPhone体験を独自実装で実用品質まで同等化する。Engine抽出はPARITY達成後。

## HQ専有責任
- integration mainline / integration_epoch
- Shared contract / shared data model / App shell
- Global Queueの唯一のwrite権限
- Work Package作成・工数配分・Phase境界rebalance
- logical resource ownership定義
- Worker成果のsemantic integration
- cross-feature regression / build harness統合
- PARITY最終判定
- BLOCKED_HUMAN提示

## Fixed Work Package原則
- Phase開始時に `工数 × 依存関係 × logical resource` でWork Packageを作る。
- Worker 1〜4へpackageを固定割当する。
- packageには専用long-lived `work_branch` と専用status fileを持たせる。
- Workerはpackage外へ移動しない。
- 空きWorkerの再配置はHQのみがPhase境界で実施する。
- 同一logical resourceを複数packageへ割り当てない。

## Canonical write ownership
HQのみ:
- `queue.json`
- `work-packages.json`
- `resource-locks.json`
- `Shared/**`
- `App/**`
- `PARITY_MATRIX.json`

Worker Nのみ:
- 自分のWork Package owned scope
- `worker-status/worker-N.json`

Worker status fileは進捗通信専用であり、製品状態・PARITY・Task VERIFIEDの正本ではない。

## Task状態
Global QueueはHQが以下を管理する。
`PLANNED -> ASSIGNED -> BLOCKED_DEPENDENCY -> READY_ASSIGNED -> INTEGRATING -> VERIFIED`
補助: `BLOCKED_HUMAN`, `REWORK_REQUIRED`, `CANCELLED`

Worker側の実行状態は専用status fileで管理する。
`ASSIGNED -> IN_PROGRESS -> INTEGRATION_READY`
補助: `BLOCKED`, `NEEDS_HQ_REBASE`

## Branch運用
- WorkerはWork Packageごとのlong-lived branchを使う。
- Taskごとのattempt branch乱立を廃止する。
- WorkerがINTEGRATION_READYを出したらHQがintegrationとの差分・owned scope・テスト・証拠を検証してmergeする。
- merge後も同じWork Package branchを継続する場合、次Task開始前にcanonical integrationとの同期を確認する。

## PARITY Gate
`MISSING -> PARTIAL -> NEAR_PARITY -> PARITY`
PARITYには機能存在・結果品質・操作性・速度・安定性・失敗復旧・実機証拠が必要。compile/testのみ、synthetic-only、単一fixtureのみでは上げない。

## Differential Test
可能な限り同じ入力をMoisesと自作へ与え、結果品質・処理時間・操作手数・失敗復旧・実機性能を比較する。

## 禁止
- WorkerによるGlobal Queue更新
- Workerによる他package taskの自律claim
- Worker間で同一logical resourceを共有
- Shared/App/PARITYのWorker直接編集
- stale branchを無検証でmerge
- PoCを完成扱い
- 実装困難を理由にParity行を削除
