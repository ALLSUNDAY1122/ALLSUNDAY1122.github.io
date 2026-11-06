# L2-AW16 Concurrent Provider Import Ownership / Cancellation / Storage-Pressure Recovery Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. This wave hardens the AW15 File Provider snapshot path against concurrent imports, a concurrent staging sweeper, cancellation, process-death leftovers and storage reservation races without changing `Shared/**`, `App/**` or `PARITY_MATRIX.json`.

## Production changes

- Added `IOStagingOwnershipRegistry` under `.IORecovery/StagingOwnership`.
- Each provider acquisition obtains a durable token lease before creating `.provider-partial` bytes.
- Each lease records `reservedBytes`, materialized `writtenBytes`, staging filename, heartbeat and expiry.
- New admission is serialized in-process and preflights against the sum of other active **remaining** reservations plus the configured storage reserve, reducing same-process overcommit from multiple importer instances.
- Progress heartbeats reduce remaining reservations as bytes become real filesystem consumption.
- Corrupt active ownership ledger state blocks new admission rather than guessing free commitments.
- `IOStagingRecovery` now checks durable ownership before deleting an old direct Staging child. Active partial and ready files are preserved regardless of old mtime; expired/crash-abandoned leases allow convergence. Fresh corrupt lease records fail closed for destructive recovery.
- `IOProviderSnapshotAcquirer` now returns a production `IOProviderStagedSnapshot` carrying its ownership lease. The compatibility `stageProviderFile` seam remains, but immediately releases ownership and is not the production handoff.
- Provider copy checks cancellation before acquisition, during chunk copy, before ready publication and after retargeting.
- Mid-write Cocoa out-of-space is normalized to `IOProviderSnapshotAcquisitionError.insufficientStorage`; preflight `IOFileStore.StoreError.insufficientStorage` remains preserved.
- Partial -> ready rename retargets the same lease instead of opening an unowned publication window.
- `IOProviderSnapshotAudioImporter` retains the lease through downstream `.appOwnedFile` media/codec validation and runs a periodic keepalive until success/failure, then releases the lease and removes Staging.
- Existing base-import behavior remains the codec authority, preserving MP3/WAV/FLAC/M4A/MP4/MOV/WMA and the WMA compatibility decoder seam.

## Executed portable validation

Swift 6.2.1 Linux, `-swift-version 6 -warnings-as-errors`:

- production source strict typecheck: PASS
- `IOStagingOwnershipTests.swift` strict XCTest typecheck: PASS
- `IOProviderSnapshotAudioImporterOwnershipTests.swift` strict XCTest typecheck: PASS
- production wiring audit: `L2_AW16_STATIC_WIRING_PASS checks=18`
- executable core self-check, rerun from the exact committed source blob `c6cc3f20d1fcc3278d038de355227da63b583844`: `L2_AW16_SELF_TEST_PASS scenarios=10 lease_cycles=1000 elapsed_seconds=2.392056`
- executable wrapper self-check, committed source blob `7893720f5de5b94dcc6091be8416a99344b48751`: `L2_AW16_WRAPPER_SELF_TEST_PASS scenarios=2`

Core scenarios include:

1. remaining-reservation arithmetic,
2. second admission rejected when active reservations overcommit current free capacity,
3. progress reduces reservation commitment,
4. active old partial survives concurrent sweep,
5. retargeted old ready snapshot survives until release,
6. expired process-death lease permits stale partial recovery,
7. fresh corrupt lease blocks destructive sweep and new admission,
8. WMA snapshot publication retains extension and ownership,
9. pre-cancelled acquisition publishes no Staging bytes,
10. 1,000 acquire/progress/release cycles.

Wrapper scenarios run success and downstream-failure paths. The downstream importer intentionally waits longer than the initial short test lease, marks the ready snapshot old, invokes staging recovery, and verifies keepalive ownership prevents deletion. Both outcomes then verify Staging cleanup after lease release.

`2.392056s` is a Linux portable filesystem/JSON-ledger microbenchmark for 1,000 synthetic lease cycles. It is not iPhone/File Provider latency evidence.

## Negative / recovery invariants

- An active import is never eligible for age-only Staging cleanup.
- Partial bytes are non-authoritative and remain token-owned until verified ready publication.
- A ready snapshot remains owned while codec/media validation is using it.
- Cancellation before publication cannot leave a ready file; ordinary caught failures remove partial/ready and release the lease.
- Process termination may leave a partial/ready file and durable lease. The file becomes reclaimable only after lease expiry.
- Unknown/corrupt fresh reservation state stops destructive cleanup/new admission rather than risking user data or storage overcommit.
- Multiple Lane-2 importer instances in the same process share a process serialization lock around durable reservation mutations.

## Boundaries not proven by this wave

- `NSLock` admission serialization is same-process only. The durable ledger survives process death, but simultaneous independent OS processes were not tested and are not claimed.
- Reservation accounting protects participating Lane-2 imports. Other app modules, iOS, extensions or external processes can still consume disk after admission; mid-copy ENOSPC is mapped and cleaned up but requires Apple/device evidence.
- Real security-scoped access, `NSFileCoordinator`, iCloud download-on-demand, provider eviction/replacement, provider-specific errors and background suspension require supported iPhone execution.
- Force termination during lease atomic write, copy heartbeat, ready rename, downstream keepalive and release requires APFS/device testing.
- Apple Core Data, AVFoundation real codec/export/share, actual MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixtures, production WMA decoder/license audit, long-track RSS/thermal/battery and Differential Moises remain HQ gates.
- Legacy `IOSAudioIOService.importExternalFile` / `IOExternalFileAcquirer` and compatibility `stageProviderFile` remain callable. Product composition must route Files/iCloud/File Provider through `IOProviderSnapshotAudioImporter` (or equivalent leased AW16 seam) to receive this protection.

## PARITY statement

This wave does not promote MOI-P001, MOI-P002, MOI-P017, MOI-P018, MOI-P019 or MOI-P020. Portable correctness/hardening is not Apple runtime, real-audio, integrated iPhone or Differential Moises evidence. Final PARITY remains HQ-owned.
