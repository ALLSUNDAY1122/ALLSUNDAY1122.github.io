# T37–T39 Worker2 step14 — 2026-10-20

Task SCANLAB-W2-001 owner WORKER_2 epoch1, viewer-library-publish-privacy lock epoch1 validated. PR #5619 Draft, not merged.

Prior Native CI 39362812776 SUCCESS, 245 XCTest 0 failures. New tests at HEAD 067902285e71c15af5d53623b66b9d06688d622f failed iOS build 39367669968 (ScanLibraryReadOnlyCensus invisible to XCTest target). Fixed by extracting helper from ScanLibraryView.swift to ScanLibraryReadOnlyCensus.swift (commit 65fa6ee8438c3ab32533cf1682a3b6282b1a2cc4), removing duplicate (3545dc023e6245b7ffa5a9bfc610e9156ed15508), explicitly listing new helper as XCTest source in project.yml (df22ea56047e14ec61437dfaef42a3c82999bc1f). Three blobs read back remotely. New Native iOS CI 39369595794 in progress at report creation; cannot assert PASS yet.

Remaining: explicit safe export repair separate from viewer load, realistic lost ACK receipt/outbox server gates, staging quota and restart reconciliation, revoke/regrant QRS signer, real PG/Storage/iPhone evidence. No merge/deploy/upload/delete.

## Follow-up — export read-only backup proof and CI diagnosis
Latest prior Native CI 39369794864 FAILED after compilation, 248 XCTest / 2 assertions in 1 unexpected test: SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity. All 3 new Library census tests PASSED. Commit 85ee7a3ce3d66ce1083644d83435c8909d8e54bf augments Export preflight sidecar test to ensure the recovered backup remains byte-identical after export preflight, in addition to checking edited settings are read. Source blob f866e330d77e3f8ace4a6d94bb0322ac5f53c2ff read back. Full Native run 39373772965 IN_PROGRESS at readback. This test does NOT implement server-side immutable export repair; that gate remains pending. PR remains unmerged; no TestFlight upload.
