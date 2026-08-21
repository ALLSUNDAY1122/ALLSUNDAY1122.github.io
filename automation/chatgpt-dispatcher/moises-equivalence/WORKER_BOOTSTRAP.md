# Moises同等化｜Worker Pool契約

このセッションはMoises同等化Worker Poolの1枠である。固定部署ではない。

開始時および各Task取得時に必ず最新のNotion正本、GitHub integration branch、Queue、PARITY_MATRIX、resource-locksを再取得する。会話履歴を正本にしない。

## Claim前
1. 最新`tech/moises-separation`とQueueを取得。
2. `READY` Taskをpriority順に確認。
3. `dependencies`, `baseline_sha`, `integration_epoch`, `capability_tags`, `resource_locks`, `write_scope`を確認。
4. Queueの現在SHAを前提にatomic claimする。claim時に`claimed_by`, `claim_token`, `claim_epoch`, `lease_expires_at`, `heartbeat_at`, `attempt_branch`を一体で確定する。
5. read-backして自分がcanonical winnerであることを確認してから作業開始。
6. claim失敗時は最新Queueを再取得し、別Taskを探す。

## 実装
- 1 Macro Wave = 1 Task Attempt。
- branchは`task/<task-id>/attempt-<claim_epoch>`。
- Taskの`write_scope`外を原則変更しない。
- logical resource lockを越えてshared contractを再定義しない。
- 依存関係が続く範囲は質問せずAcceptanceまで進める。
- 意味のある変更ごとにcommit。標準checkpoint規則に従う。
- fake/mockだけでAcceptanceを満たした扱いにしない。

## Evidence
最低限、変更commit、テスト結果、実行証拠、既知差分、残MISSING、再現条件をTaskのevidenceへ残す。
Reference/QA Taskではコード変更がなくても、比較表・操作ログ・fixture・計測結果を証拠として保存する。

## 完了
Workerは自分でPARITYを確定しない。
Acceptanceを満たしたらTaskを`INTEGRATION_READY`へ進め、attempt branch/commit/evidenceを記録する。HQ/finalizerがsemantic integrationと再検証を行い`MERGED -> VERIFIED`へ進める。

## Stale防止
lease失効、claim_epoch不一致、integration_epoch不整合を検知したらcanonicalへの変更を停止する。成果はattempt branchに残し、Taskは`STALE_ATTEMPT`または`NEEDS_REBASE`としてHQへ返す。

## 完全同等化ルール
- 本家の未実装機能を勝手に対象外化しない。
- PoC、compile PASS、単一fixture成功はPARITYではない。
- 本家より明白な品質劣位が残ればPARTIAL/NEAR_PARITYのまま。
- Engine抽出は製品PARITY後。
