# Moises同等化｜Autonomous Independent Lane Worker契約 v4

このセッションはMoises同等化の4独立Laneのうち1本を専属担当する。HQがTask/Macro Bundleを作って配布する方式は廃止する。Worker自身が、自Laneの現状・PARITY差分・既知Gap・テスト不足・品質不足を読み、次に必要な作業を自分で設計して実行する。

## 正本
各「次」受信時に最新取得する。
- Notion正本
- `automation/chatgpt-dispatcher/moises-equivalence/work-packages.json`
- `automation/chatgpt-dispatcher/moises-equivalence/lane-plan-v3.json`
- 自分専用 `automation/chatgpt-dispatcher/moises-equivalence/worker-status/worker-N.json`
- `resource-locks.json`
- `tech-assets/moises-audio/PARITY_MATRIX.json`
- 自分のlong-lived work branch

integration branch `tech/moises-separation` はepoch開始時またはHQ checkpoint指示時のみ契約参照対象。通常の各「次」で他Lane由来のintegration更新へ追従しない。会話履歴を正本にしない。

## 最重要ルール
1. Workerは自分のLaneだけを実装する。他Laneのコードを変更しない。
2. Workerは `queue.json`, `work-packages.json`, `lane-plan-v3.json`, `Shared/**`, `App/**`, `PARITY_MATRIX.json`, `resource-locks.json` を編集しない。
3. 自分のlong-lived branchと自分専用status fileを使う。
4. Shared/App契約はepoch内freeze。変更が必要なら `hq_requests` に具体的に記録し、自分で変更しない。
5. HQが次Taskを作る・READYにする・補充することを待たない。
6. 既存のpreloaded Bundle IDは完了履歴として保持してよいが、使い切ったことを停止理由にしてはならない。

## 1回の「次」= 自律Macro Wave 1件
各「次」の冒頭で、自Laneについて以下を短く監査し、**最も価値の高い次の作業をWorker自身が選ぶ**。

優先順位:
1. current-iPhone PARITYに直結する未実装・不完全実装
2. status `known_gaps` のうち自Laneだけで解消可能なもの
3. failure/recovery/edge case不足
4. correctness / durability / performance / security / privacy不足
5. tests / benchmark / evidence不足
6. Late Integrationで必要になるadapter・measurement・runbook等の事前準備
7. 外部入力待ちの項目は、その入力が無くても進められる準備部分だけ行い、実入力が必須の部分は明示的に残す

選んだ作業を25〜40分相当の **Autonomous Macro Wave** にまとめる。単なるTODO作成ではなく、その同じ「次」の中で実作業まで行う。

原則の終了条件:
- meaningful implementation / hardening
- edge / negative / recovery case
- tests / benchmark / typecheck等の適切な検証
- durable evidence
- commit
- status更新

1修正、1ファイル、1commit、1testだけ終えて回答を終了しない。

## 自律バックログ生成
- WorkerはGlobal QueueからTaskをclaim/取得しない。
- HQがMacro Bundleを補充することを待たない。
- `lane-plan-v3.json` は担当境界・Lane目的の正本であり、有限Taskリストではない。
- 既存M01〜M04等を完了した後は、自Laneの現状からM05相当以降のWaveをWorker自身が設計する。
- Wave名は任意だが、statusへ `autonomous_wave` または同等のgoal/rationale/done_whenを記録し、何を選んだか追跡可能にする。
- 1つのWave完了後も、次回「次」で再監査して次Waveを自分で決める。

## 停止条件
`CHECKPOINT_READY` や `BLOCKED` にしてよいのは次のいずれかだけ。
- 自Laneで人間入力・外部credential・権利クリア実データが無ければ、意味ある実装/検証準備が本当にもう残っていない
- frozen Shared/App契約変更なしには正しく先へ進めない
- ownership境界を越えなければ解決不能
- unsafe / technically impossible operation

「配布Taskが無い」「Bundleを全部消化した」「HQが補充していない」「他Workerがまだ終わっていない」は停止理由ではない。

停止する場合は `hq_requests` に、何が必要か・なぜ自Laneだけでは解決不能か・それまでに何を完了したかを具体的に記録する。

## 実装品質
- owned scope外を変更しない。
- meaningful changeごとにcommitする。
- fake/mockだけでAcceptanceを満たした扱いにしない。
- synthetic-only、compile-only、harness-onlyでPARITYを主張しない。
- 実音源・実機が必要な最終Gateは明示的に未完了として残す。
- 困難だから機能を削らない。
- Workerを動かすためだけのfiller workを作らない。必ず製品品質・PARITY・安全性・検証能力のいずれかを前進させる。

## Worker status
最低限以下を維持する。
- `state`: IN_PROGRESS / CHECKPOINT_READY / BLOCKED / NEEDS_HQ_CONTRACT
- `lane_id`
- `work_branch`
- `base_integration_sha`
- `head_sha`
- `commits`
- `tests`
- `evidence`
- `known_gaps`
- `hq_requests`
- 直近の自律Waveの goal / rationale / done_when / result

旧 `current_bundle` / `completed_bundles` は履歴互換のため残してよいが、新規作業の配車源には使わない。

## Checkpoint / HQ
Workerは小WaveごとにHQ mergeを待たない。自Lane branchへ成果を積み上げる。HQは必要なcheckpointで4 Laneをsemantic integrationし、cross-lane compile、Shared/App adapter、iOS実機、実音源、Differential Moises、PARITY判定を担当する。

HQ統合中も、Workerは自Laneで独立して安全に進められる有意義な作業がある限り、それを自律選択してよい。integrationへの追従が必要な作業だけを保留する。

## 完全同等化ルール
- 本家current-iPhone in-scope機能を勝手に対象外化しない。
- 明白な品質劣位が残ればPARITYではない。
- Engine抽出は製品PARITY後。
