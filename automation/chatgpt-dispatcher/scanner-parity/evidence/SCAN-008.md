# SCAN-008 Evidence｜STALE ATTEMPT（worker2）

更新: 2026-08-23 14:47 JST
Worker: worker2
Former claim epoch: 1
Attempt branch: `task/SCAN-008/attempt-1`
Baseline: `1bb35c1070477fdc34d0082291e64e48a84abf91`
Canonical owner at final read-back: `worker1`

> **NON-CANONICAL / STALE ATTEMPT**
> Queue read-backでSCAN-008のcanonical ownerがworker1へ変更されたため、worker2はfencing契約に従いINTEGRATION_READY確定を行わない。このEvidenceはworker2がclaim保持中に作成した成果の記録であり、worker1/HQが再検証して採用するまでcanonical PASSではない。

## worker2実装成果

- `scanner-parity/PipelineCore/PipelineAuditBridge.swift`
  - `PageCandidate` を保持したまま `PageAuditInput` へ接続。
  - `candidateID / bookID / sourceTimeMS / sourceRangeMS / source flags` を `PipelinePageLineage` へ保持。
  - `CorrectedPageMetadata.pageID/candidateID` のlineage mismatchを `reviewRequired` へ送る。
  - correction stage failureをページごと破棄せず、元時刻を持つ監査入力として残し `stage_failure:` reviewへ送る。
  - `lowBoundaryConfidence` または boundary confidence < 0.72 をreviewへ伝播。
  - Shared Contractおよび既存FrameExtraction/ImageCorrection/PageAudit型は変更していない。
- `scanner-parity/Tests/PipelineCore/PipelineAuditBridgeTests.swift`
  - lineage保持 / 正常順 / 重複 / 欠落 / 隣接逆転 / stage failure / low confidence / ID mismatch のfixtureを実装。
- `scanner-parity/Tests/PipelineCore/run-fixtures.sh`
  - integration済みsourceとbridge/fixtureを同一swiftc invocationで実行する再現runner。

## 検証済み範囲

- attempt branchはbaselineより4 commits ahead / 0 behind。
- 変更は `scanner-parity/PipelineCore/**` と `scanner-parity/Tests/PipelineCore/**` のみ。
- 現行public signatureと同一の最小Swift fixtureで `PASS typecheck+lineage+review propagation`。
- production auditor条件の独立検算で duplicate / missing / reversal / low-confidence 条件成立。
- containerから `raw.githubusercontent.com` のDNS解決ができず、repository checkout相当の全sourceをその場で取得して `run-fixtures.sh` を完走する経路は未実行。

## Fencing判断

worker2の最終Queue確定試行前にQueueが更新され、最新read-backではSCAN-008が次の状態になった。

- status: `CLAIMED`
- claimed_by: `worker1`
- claim_token: `883a50de-f68a-4f89-ad44-dc546bbbd0a9`
- claim_epoch: `1`
- attempt_branch: `task/SCAN-008/attempt-1`

したがってworker2はQueue、canonical branch、INTEGRATION_READYを確定しない。worker1/HQは既存attempt branch上の成果を内容確認したうえで利用・修正・破棄を判断すること。
