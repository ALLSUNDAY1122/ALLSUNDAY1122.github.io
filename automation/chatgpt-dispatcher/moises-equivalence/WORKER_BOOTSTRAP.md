# Moises同等化｜Fixed Work Package Worker契約 v2

このセッションはMoises同等化の固定Work Package担当である。Worker Poolから自由にTaskを取得する方式は廃止した。

## 正本
開始時および各「次」受信時に必ず以下を最新取得する。
- Notion正本
- GitHub integration branch `tech/moises-separation`
- `automation/chatgpt-dispatcher/moises-equivalence/work-packages.json`
- `automation/chatgpt-dispatcher/moises-equivalence/queue.json`
- 自分専用 `automation/chatgpt-dispatcher/moises-equivalence/worker-status/worker-N.json`
- `resource-locks.json`
- `tech-assets/moises-audio/PARITY_MATRIX.json`
会話履歴を正本にしない。

## 最重要ルール
1. Workerは `queue.json` を編集しない。Global Queueの唯一のwriter/finalizerはHQ。
2. Workerは他Workerのstatus fileを編集しない。
3. Workerは自分に固定されたWork Package以外のTaskをclaim/実装しない。
4. Workerは `Shared/**`, `App/**`, `PARITY_MATRIX.json`, `resource-locks.json` を編集しない。契約変更要求は自分のstatus/evidenceへ記録する。
5. 実装branchはWork Package manifestの `work_branch` を継続使用し、Taskごとの自由なattempt branch生成は行わない。

## 作業開始
1. `work-packages.json` で自分のWorker IDとWork Packageを照合する。
2. Queueで自分のpackageに割り当てられ、dependenciesがHQにより解放済みのTaskだけを対象にする。
3. 自分のstatus fileで `current_task` を確認する。別Taskが進行中ならそれを継続する。
4. 最新integrationとの差分を確認し、自分のowned scopeと競合するcanonical変更があれば実装を止めてstatusを `NEEDS_HQ_REBASE` にする。競合しないmetadata更新だけを理由に成果を破棄しない。
5. status fileを `IN_PROGRESS` に更新してから作業する。status fileだけは自分専用writerとしてintegration branchへ直接更新してよい。

## 実装
- 1 Macro Wave = 自分のWork Package内の1 assigned Task。
- `owned_resources` / `write_scope` の外を変更しない。
- 他Packageのコードを便宜上編集しない。
- 意味のある変更ごとにcommitする。
- fake/mockだけでAcceptanceを満たした扱いにしない。
- PoC、compile PASS、synthetic-only成功をPARITY扱いしない。
- 依存が成立している範囲は質問せずAcceptanceまで進める。

## Worker status
Workerの進捗報告はGlobal Queueではなく、自分専用status fileに書く。
最低限:
- `state`: ASSIGNED / IN_PROGRESS / INTEGRATION_READY / BLOCKED / NEEDS_HQ_REBASE
- `current_task`
- `work_branch`
- `base_integration_sha`
- `head_sha`
- `commits`
- `tests`
- `evidence`
- `known_gaps`
- `hq_requests`

## 完了
Acceptanceを満たしたら、自分のstatus fileを `INTEGRATION_READY` にする。WorkerはQueue状態やPARITYを確定しない。
HQがsemantic review、merge、regression、PARITY判定、Queue更新を行う。
HQが次Taskを解放するまでは他Packageへ移動しない。

## 再配分
担当変更はPhase境界またはHQの明示的rebalanceだけで行う。空いたWorkerが自律的に他packageへ移動することは禁止。

## 完全同等化ルール
- 本家のin-scope機能を勝手に対象外化しない。
- 明白な品質劣位が残ればPARITYではない。
- Engine抽出は製品PARITY後。
