# L2-AW07 Export Batch Atomicity / Naming / Recovery Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Lane Plan/Resource Locks.

Implemented:

- `IOExportBatchTransaction` stages all stems for one export request under one batch directory.
- Publication uses one same-volume directory move from `Staging/ExportBatches/<batch-id>` to `Exports/Batches/<batch-id>`.
- Files inside the batch use sanitized user-facing names (`Vocals.m4a`, duplicate `Vocals (2).m4a`) with no UUID in the filename.
- Commit validates every output exists, is a regular file, and is non-empty before publication.
- Cancellation/failure can abort the unpublished batch without touching prior finalized exports.
- Relaunch recovery removes abandoned unpublished batch directories only.
- `IOSAtomicM4AExporter` is a separately injectable `AudioExporting` implementation compatible with the frozen App coordinator's independent importer/exporter dependencies. It performs cumulative storage preflight, AVFoundation M4A encode, post-encode playable/audio/PCM-sample validation, then one batch commit.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Command-equivalent validation:

`swiftc -warnings-as-errors -strict-concurrency=complete IOFileStore.swift IOExportBatchTransaction.swift L2AW07ExportBatchSelfCheck.swift ...`

Result:

- strict concurrency / warnings-as-errors compile: PASS
- functional self-check: PASS (4 scenario groups)
- clean naming + duplicate disambiguation: PASS
- three-stem whole-batch publication: PASS
- missing output before commit => no final batch: PASS
- zero-byte output => rejected before commit: PASS
- abandoned staging recovery => removes 2 unpublished batches while prior finalized batch survives: PASS
- 200 batches x 2 stems filesystem transaction benchmark: 0.485964206 s on this runner (~2.43 ms/batch transaction overhead; excludes audio encoding)
- `IOExportBatchTransactionTests.swift` strict-concurrency typecheck with XCTest: PASS
- `IOSAtomicM4AExporter.swift` syntax parse: PASS

A separate first self-check run also passed at 0.422497298 s for 200 x 2-stem batches. The benchmark is informational only; Linux filesystem timing is not an iPhone performance claim.

## Negative / edge / recovery behavior

- empty batch and invalid extension fail closed.
- path-like/unsafe stem characters are sanitized by the existing `IOFileStore` policy.
- case/diacritic-equivalent duplicate stems are deterministically suffixed within the batch.
- partial batch output cannot be published because every item is validated before the directory move.
- a crash before publication leaves only an abandoned staging batch, removed on next exporter initialization.
- a crash after the same-volume directory move leaves the complete batch directory, not a stem-by-stem partial publication.
- destination batch directory uses a random internal id, avoiding overwrite of an existing finalized batch while keeping UUIDs out of shared filenames.

## Apple / HQ gates intentionally still open

The following are not executable in this Linux worker environment and are **not** marked PASS:

- AVFoundation M4A encoder runtime execution on the supported Apple target.
- real exported artifact playback/share on iPhone.
- interruption exactly across the filesystem rename boundary on APFS/device storage.
- physical low-storage behavior.
- integrated App selection of `IOSAtomicM4AExporter` and cross-lane export flow.
- real codec fixture matrix MP3/WAV/FLAC/M4A/MP4/MOV/WMA.
- production WMA compatibility decoder selection/license/package audit where native decoding is unavailable.
- Differential Moises and final PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW07. This is production hardening plus portable filesystem evidence only. MOI-P001/P002/P017/P018/P019/P020 remain HQ-owned PARITY decisions.
