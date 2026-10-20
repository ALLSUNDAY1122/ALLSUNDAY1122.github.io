# T37–T39 Worker2 step14 — 2026-10-20

Task SCANLAB-W2-001 owner WORKER_2 epoch1, viewer-library-publish-privacy lock epoch1 validated. PR #5619 Draft, not merged.

Prior Native CI 39362812776 SUCCESS, 245 XCTest 0 failures. New tests at HEAD 067902285e71c15af5d53623b66b9d06688d622f failed iOS build 39367669968 (ScanLibraryReadOnlyCensus invisible to XCTest target). Fixed by extracting helper from ScanLibraryView.swift to ScanLibraryReadOnlyCensus.swift (commit 65fa6ee8438c3ab32533cf1682a3b6282b1a2cc4), removing duplicate (3545dc023e6245b7ffa5a9bfc610e9156ed15508), explicitly listing new helper as XCTest source in project.yml (df22ea56047e14ec61437dfaef42a3c82999bc1f). Three blobs read back remotely. New Native iOS CI 39369595794 in progress at report creation; cannot assert PASS yet.

Remaining: explicit safe export repair separate from viewer load, realistic lost ACK receipt/outbox server gates, staging quota and restart reconciliation, revoke/regrant QRS signer, real PG/Storage/iPhone evidence. No merge/deploy/upload/delete.
