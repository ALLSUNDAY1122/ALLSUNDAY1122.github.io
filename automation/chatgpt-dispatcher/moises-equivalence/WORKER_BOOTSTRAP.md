# Moises同等化｜Independent Lane Worker契約 v3

このセッションはMoises同等化の4独立Laneのうち1本を専属担当する。HQからTaskを都度取得する方式、他Worker待ち、各小Taskごとの統合待ちは廃止した。

## 正本
各「次」受信時に最新取得する。
- Notion正本
- `automation/chatgpt-dispatcher/moises-equivalence/work-packages.json`
- `automation/chatgpt-dispatcher/moises-equivalence/lane-plan-v3.json`
- 自分専用 `automation/chatgpt-dispatcher/moises-equivalence/worker-status/worker-N.json`
- `resource-locks.json`
- `tech-assets/moises-audio/PARITY_MATRIX.json`
- integration branch `tech/moises-separation` はepoch開始時またはHQ checkpoint指示時のみ契約参照対象。通常の各「次」で他Lane由来のintegration更新へ追従しない。

会話履歴を正本にしない。

## v2 -> v3 移行保全
1. epoch 2の最初の「次」で、現work branchとlatest integrationを比較する。
2. work branchに未統合のowned-scope commitが無い場合だけ、安全にlatest integrationへ同期してよい。
3. 未統合のowned-scope commitがある場合は **reset / force update / discard禁止**。既存成果を保持したままv3契約とLane Planを読み、内容が次Macro Bundleに重なる場合はその成果をbundleへ引き継ぐ。
4. statusへ `epoch_contract_sha` と、その時点の `base_integration_sha` / existing unintegrated commits を記録する。
5. v3移行そのものを理由に既存の正しい実装をやり直さない。

## 最重要ルール
1. Workerは自分のLaneだけを実装する。他Laneのコードを変更しない。
2. Workerは `queue.json`, `work-packages.json`, `lane-plan-v3.json`, `Shared/**`, `App/**`, `PARITY_MATRIX.json`, `resource-locks.json` を編集しない。
3. 自分のlong-lived branchと自分専用status fileを使う。
4. epoch開始時に最新integrationのShared/App契約を一度読み、そのSHAをstatusへ固定する。その後はLane checkpointまで他Laneのintegration更新を理由にrebase/停止しない。
5. Shared/App契約はepoch内freezeとして扱う。契約変更が必要ならstatusの `hq_requests` に具体的に記録し、自分で変更しない。

## 1回の「次」
- **1回の「次」 = lane-plan-v3.json の次の未完了Macro Bundleを1件完遂する。**
- Macro Bundleは従来の小Task約4件分をまとめた作業量として設計する。目標粒度は約25〜40分相当の意味ある作業。
- bundle内の1 subtaskや1 commitが終わっただけでは回答を終了しない。
- 実装 → negative/edge cases → tests/benchmark → evidence保存 → status更新まで進め、`done_when` を満たして初めて1回分を完了とする。
- 早期停止を許すのは hard external blocker / ownership conflict / unsafe or impossible operation のみ。
- 外部入力が必要なbundleがblockedなら、自分のLane内で外部入力不要の次のpreloaded bundleへ進んでよい。HQのtask解放は不要。

## Task取得禁止・Lane自動継続
- Global QueueからTaskをclaim/取得しない。
- `READY_ASSIGNED` を待たない。
- `lane-plan-v3.json` の自分の `macro_sequence` が実行列である。
- bundle完了時はstatusへ `completed_bundles` と次の `current_bundle` を記録する。
- 次回「次」ではその `current_bundle` を続行する。
- 4件を使い切る前にHQが次checkpoint分を補充する。Workerは他Laneへ仕事を探しに行かない。

## 実装品質
- owned scope外を変更しない。
- meaningful changeごとにcommitする。
- fake/mockだけでAcceptanceを満たした扱いにしない。
- synthetic-only、compile-only、harness-onlyでPARITYを主張しない。
- 実音源・実機が必要な最終Gateは明示的に未完了として残す。
- 困難だから機能を削らない。

## Worker status
最低限以下を維持する。
- `state`: IN_PROGRESS / CHECKPOINT_READY / BLOCKED / NEEDS_HQ_CONTRACT
- `lane_id`
- `current_bundle`
- `completed_bundles`
- `work_branch`
- `epoch_contract_sha`
- `base_integration_sha`
- `head_sha`
- `commits`
- `tests`
- `evidence`
- `known_gaps`
- `hq_requests`

小Bundleごとに `INTEGRATION_READY` を出してHQを待つ必要はない。複数Bundleを同じLane branchへ積み、coherent checkpointになったら `CHECKPOINT_READY` にする。

## Checkpoint
- 原則として複数Macro Bundleをまとめて後でHQ統合する。
- HQは4 Laneをsemantic integrationし、cross-lane compile、iOS実機、差分A/B、PARITY判定を担当する。
- HQ統合中に他Lane実装を自分のbranchへ取り込まない。

## 完全同等化ルール
- 本家current-iPhone in-scope機能を勝手に対象外化しない。
- 明白な品質劣位が残ればPARITYではない。
- Engine抽出は製品PARITY後。
