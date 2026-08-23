# L2-AW09 Storage-Pressure / Export-Registration Compensation Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks.

Selected after re-reading the current Notion v4 canonical, Worker contract, Work Package, Lane Plan, Worker 2 status, Resource Locks and PARITY ledger. The highest-value lane-local post-AW08 gap was interruption/storage-pressure behavior when an exporter has already published bytes but lifecycle metadata cannot commit.

## Production change

`Lane2DurableLifecycleCoordinator.exportAndRecord(...)` now tracks whether returned export artifacts actually reached lifecycle metadata commit.

If export bytes exist but validation or `Lane2LifecycleMetadataStore.recordExports(...)` fails before metadata commit:

1. the coordinator attempts immediate compensation for exactly the returned artifact paths;
2. compensation accepts only regular files strictly below app-owned `Exports/`;
3. the entire candidate set is prevalidated before the first delete;
4. `Imports/**`, `Stems/**`, traversal, absolute paths and directory candidates fail closed and are never recursively deleted;
5. missing files are idempotently treated as already clean;
6. empty export parent directories are pruned without ever removing the `Exports` root;
7. the original operation failure is still persisted/thrown;
8. if compensation cannot safely complete, `EXPORT_COMPENSATION_INCOMPLETE` is persisted as an additional durable signal.

This specifically prevents a storage-pressure/corrupt-sidecar failure after audio publication from leaving large newly-generated untracked exports consuming the remaining capacity. It also avoids turning recovery into a destructive generic orphan sweep.

Existing ready -> deleting -> file remove -> metadata finish cleanup ordering remains unchanged. A crash after file removal but before metadata finish remains idempotently recoverable because relaunch sees deleting metadata and treats a missing file as already clean.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Executed in this Worker session:

- `LibraryArtifactLifecycle+UncommittedExport.swift` strict-concurrency / warnings-as-errors compile against a contract-equivalent `LibraryArtifactLifecycle` surface: PASS.
- executable filesystem self-check: PASS, marker `L2_AW09_SELF_TEST_PASS scenarios=6`.
- scenario: two produced batch artifacts are removed and the now-empty batch directory is pruned: PASS.
- scenario: already-missing artifact compensation is idempotent: PASS.
- scenario: a mixed safe `Exports/**` + unsafe `Imports/**` candidate set fails before deleting either path: PASS.
- scenario: traversal candidate is rejected and source content survives: PASS.
- scenario: directory candidate is rejected without recursive deletion: PASS.
- scenario: duplicate paths are deduplicated and never double-deleted: PASS.
- filesystem compensation benchmark: 500 files removed successfully in `0.688726 s` on this runner. This is informational Linux filesystem timing, not an iPhone performance claim.
- updated `Lane2DurableLifecycleCoordinator.swift` strict-concurrency / warnings-as-errors typecheck against frozen-contract-equivalent stubs: PASS.
- committed regression source `Lane2ExportCompensationTests.swift` syntax parse: PASS. It covers real v2 corrupt-export-shard registration failure -> produced export compensation, corrupt metadata preservation, unsafe returned path preservation and durable `EXPORT_COMPENSATION_INCOMPLETE` signaling when run in the Apple/package test target.

## Negative / edge / recovery invariants

- Compensation only runs when the export call returned artifacts and lifecycle metadata has not committed them.
- Exporter failure before returning artifacts never triggers deletion.
- A successful metadata commit is never compensated.
- Candidate safety is validated as one set before deletion; one unsafe candidate prevents partial destructive cleanup.
- Only regular files below `Exports/` are eligible.
- Corrupt lifecycle shards are not modified by export compensation; AW08 explicit quarantine remains the only corruption-recovery path.
- Compensation failure does not mask the original export/metadata error; the original error is still thrown.
- Compensation incompleteness is separately recorded when metadata storage remains writable enough to retain the diagnostic.

## Apple / HQ gates intentionally still open

The following remain unverified and are not marked PASS:

- actual ENOSPC / APFS low-storage behavior on supported iPhone hardware;
- forced process termination at each metadata atomic-write boundary;
- AVFoundation M4A encode plus real share/playback after compensation/retry;
- full integrated App recovery UX and user-visible messaging;
- Apple Core Data interruption/migration suites and physical large-library RSS/latency;
- real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixture execution;
- production WMA compatibility decoder selection/license/package audit if native decoding is unavailable;
- Differential Moises and final PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW09. The wave materially hardens storage-pressure/interruption cleanup inside Lane 2 and adds durable portable evidence, but MOI-P001/P002/P017/P018/P019/P020 remain HQ-owned PARITY decisions pending Apple/device/real-audio/integrated/differential gates.
