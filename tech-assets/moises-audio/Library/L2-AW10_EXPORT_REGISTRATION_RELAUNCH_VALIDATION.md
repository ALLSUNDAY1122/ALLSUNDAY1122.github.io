# L2-AW10 Export Registration Relaunch Recovery Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks.

Selected after re-reading the current Notion v4 canonical, Worker contract, Work Package, Lane Plan, Worker 2 status, Resource Locks and PARITY ledger. Resource-lock ownership remained unchanged while the HQ integration epoch advanced to 6. The highest-value post-AW09 lane-local gap was process termination around the export-publication -> lifecycle-metadata-registration boundary.

## Production change

`Lane2ExportRegistrationJournal` adds a durable handoff intent under `.LibraryRecovery/ExportRegistration/` after an exporter has returned validated app-owned artifacts and before `Lane2LifecycleMetadataStore.recordExports(...)` is awaited.

The intent contains only stable project UUID, `Exports/**` relative paths, media types and creation time. It rejects empty sets, path traversal, absolute/non-export paths and duplicate paths before a journal is created. Corrupt or identity-mismatched journal files fail closed and are never silently discarded.

`Lane2DurableLifecycleCoordinator.exportAndRecord(...)` now:

1. validates produced artifacts;
2. persists a registration intent before metadata registration;
3. keeps the intent in an in-memory active set while the actor is awaiting metadata, preventing actor-reentrancy recovery from deleting an active export in the same process;
4. commits lifecycle metadata;
5. retires the intent after metadata commit, with intent cleanup itself allowed to recover on a later relaunch;
6. preserves AW09 immediate compensation if registration fails before metadata commit;
7. leaves the durable intent present if safe compensation is incomplete so relaunch can retry instead of losing the recovery signal.

`recoverPendingExportRegistrations()` runs before pending-export cleanup / deleted-project reconciliation during `relaunchState(...)`, and before orphan sweeping. It first reads the canonical lifecycle snapshot before any destructive recovery.

For each non-active intent:

- **all intended paths registered**: metadata won before termination; validate audio still exists, preserve audio, retire only the intent;
- **no intended paths registered**: metadata did not commit; reuse AW09 exact-path safe compensation and retire the intent only after complete cleanup;
- **partial path registration**: fail closed with `partialRegistration`; delete nothing and retain the intent because `recordExports` is expected to commit one project shard atomically;
- **metadata snapshot corrupt/unreadable**: fail before destructive work and retain all intents/artifacts;
- **compensation incomplete**: retain intent and record `EXPORT_COMPENSATION_INCOMPLETE` when metadata remains writable enough to retain diagnostics.

This closes the relaunch gap that AW09 could not cover: a process can now terminate after export publication without relying on an in-process catch block to reclaim unregistered bytes.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Executed in this Worker session:

- `Lane2ExportRegistrationJournal.swift` strict-concurrency / warnings-as-errors compile: PASS.
- `Lane2ExportRegistrationJournalTests.swift` strict-concurrency / warnings-as-errors XCTest typecheck: PASS.
- journal executable self-check: PASS, marker `L2_AW10_SELF_TEST_PASS scenarios=6`.
- self-check covers reopen persistence, registered/unregistered/partial classification, unsafe path rejection, duplicate path rejection, corrupt-intent fail-closed retention and idempotent completion.
- 500 durable intent create/list/complete benchmark: PASS in `0.565492 s` on this runner. This is Linux filesystem timing only and is not an iPhone performance claim.
- updated `Lane2DurableLifecycleCoordinator.swift` strict-concurrency / warnings-as-errors typecheck against frozen-contract-equivalent stubs: PASS.
- executable coordinator recovery harness against contract-equivalent lane interfaces: PASS, marker `L2_AW10_COORDINATOR_RECOVERY_PASS scenarios=3`.
- coordinator scenario 1: unregistered relaunch intent -> exact export reclaimed -> intent retired: PASS.
- coordinator scenario 2: metadata already registered -> export preserved -> only intent retired: PASS.
- coordinator scenario 3: partial metadata registration -> throws/fails closed -> both artifacts and recovery intent preserved: PASS.

## Negative / edge / recovery invariants

- No broad filesystem orphan scan is needed to decide export-registration recovery.
- Only the exact paths captured in a validated durable intent can be passed to AW09 compensation.
- An intent cannot contain `Imports/**`, `Stems/**`, absolute paths, traversal paths or duplicate paths.
- Actor reentrancy cannot recover an intent still marked active by the current coordinator process.
- A crash after metadata commit but before journal deletion preserves the audio and is converged by deleting the journal only.
- A crash before metadata commit is converged by safe exact-path compensation on relaunch.
- Partial registration is treated as an impossible/diagnostic state rather than guessing which artifact to delete.
- Corrupt journal bytes are retained for diagnosis; normal recovery never silently drops them.
- Corrupt lifecycle metadata prevents destructive recovery until the explicit AW08 corruption path is used.

## Apple / HQ gates intentionally still open

The following remain unverified and are not marked PASS:

- actual APFS durability/fsync semantics and forced termination at each physical metadata write boundary;
- actual ENOSPC / low-storage behavior on supported iPhone hardware;
- Apple Core Data migration/interruption suites and physical large-library RSS/latency;
- AVFoundation M4A encode plus real share/playback/retry after relaunch recovery;
- actual Files/iCloud/File Provider/camera-roll/direct URL flows;
- real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixture execution;
- production WMA compatibility decoder selection/license/package audit if native decoding is unavailable;
- integrated App recovery UX and user-visible diagnosis for partial/corrupt recovery states;
- Differential Moises and final PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW10. The wave materially closes an in-process-only recovery gap and adds deterministic relaunch convergence for export registration, but MOI-P001/P002/P017/P018/P019/P020 remain HQ-owned PARITY decisions pending Apple/device/real-audio/integrated/differential gates.
