# LANE-4 FINAL Evidence｜Review・Recovery・Long-run Reliability

Timestamp: 2026-08-23 16:11 JST
Worker: worker4
Lane: `LANE-4-RECOVERY`
Branch: `scanner-parity/worker4-review-recovery-lane`
Baseline integration HEAD: `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`

## Mission
低信頼ページ、OCR失敗、ページ監査異常、stage failure、処理中断を冊子全体のcrashへ波及させず、stable IDで隔離・修復・再処理し、200ページ級でもcheckpointから重複なく復旧できるReview/Recovery基盤を完成させる。

## Implemented
- `ReviewQueueCore.swift`
  - PageAudit / OCR / stageFailure 共通ReviewItem
  - book/page/source/reasonからstable review ID生成
  - pending item重複排除
  - source time順序保持
  - retry / reOCR / recapture / defer / exclude / accept decision
  - resolution冪等化
  - Codable/Hashable snapshot
- `RecoveryLedger.swift`
  - completed page set
  - review pending pageの通常再処理抑止
  - source time checkpoint
  - ReviewQueue snapshot統合
- `ReviewRecoveryAdapter.swift`
  - pipeline stage event -> completed/review isolation bridge
- `AppShellReviewAdapter.swift`
  - UI向けview state
  - decision -> retryStage/rerunOCR/requestRecapture/defer/exclude/accept action bridge
- `FileCheckpointStore.swift`
  - JSON checkpoint encode/decode
  - atomic temp-file replacement
- fixtures
  - Review Queue dedupe/order/resolution/snapshot resume
  - 240 page stress + interruption at page 123 + disk checkpoint + process recreation + resume + retry

## Bugs detected and fixed during real compile/run
1. `ReviewDecision.defer` was an illegal Swift identifier because `defer` is a reserved keyword. Serialization compatibility is preserved as `case deferred = "defer"`.
2. A review-pending page was processable again because `shouldProcess` checked only completed IDs. This could mark a page complete while an unresolved review item remained. `RecoveryLedger.shouldProcess` now rejects both completed and review-pending page IDs; retry/reOCR/recapture becomes possible only after the review resolution removes the pending item.
3. `RecoveryCheckpoint: Hashable` required its nested `ReviewQueueSnapshot` to be Hashable. Snapshot now conforms to Hashable.

## Executed fixture evidence
Environment:
`Swift 6.2.1 / x86_64-unknown-linux-gnu`

Review core command compiled `ReviewQueueCore.swift + ReviewQueueFixture.swift`.
Observed:
`ReviewQueueFixture PASS pending=2 resolved=1 dedupe=PASS resume=PASS`

Recovery stress command compiled:
`ReviewQueueCore.swift + RecoveryLedger.swift + ReviewRecoveryAdapter.swift + AppShellReviewAdapter.swift + FileCheckpointStore.swift + RecoveryStressFixture.swift`

Observed:
`RecoveryStressFixture PASS pages=240 interruptedAt=123 pending=8 completed=232 replayAccepted=0`

Interpretation:
- 240 source pages were handled.
- Process interruption was simulated after page 123.
- Checkpoint was written to disk and read into a newly constructed adapter.
- Replaying pages 1...123 accepted zero pages, proving no duplicate regeneration of completed or review-pending pages.
- Remaining pages 124...240 completed without whole-book failure.
- 9 synthetic review cases were isolated; one was resolved as retry and successfully reprocessed, leaving 8 pending and 232 completed.
- Review ordering by source time remained stable across checkpoint/resume.

## Long-run relation
The previously merged SCAN-006 harness already demonstrated 240-page sequential processing without holding all pages in memory. This lane adds user-facing review isolation and durable recovery semantics on top of that long-run base.

## Scope / contract audit
- Changes are limited to lane-owned `ReviewCore/**`, `Recovery/**`, corresponding tests, and lane Evidence.
- Shared contract was not modified.
- Golden Dataset availability or SHA mismatch was not used as a blocker.
- No external AI, analytics, network upload, secret, account, or third-party dependency was added.

## Remaining final-integration assumptions
- Product lane may call `AppShellReviewAdapter`; no shared-contract change is required.
- Concrete UI wording/layout remains Product lane ownership.
- Formal Golden PASS/FAIL remains HQ_GOLDEN_GATE ownership.
- Final PR must be merged by HQ/finalizer, not worker4.

## Lane disposition
`LANE_DONE / FINAL_PR_READY`
