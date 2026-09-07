# L2-AW15 Provider Snapshot Acquisition / Mutation-Race Recovery Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks.

The current Notion v4 canonical, Worker contract, Work Package, Lane Plan, Worker 2 status, Resource Locks and PARITY ledger were re-read before selection. Assignment epoch remained 2; integration epoch advanced to 10. MOI-P001/MOI-P002 remained MISSING.

AW14 hardened public/direct URL transport. AW15 focuses on picker / Files / iCloud / File Provider acquisition, where the external file can be a leased provider-backed object and can change or be replaced around copy time.

## Gap found

The pre-AW15 `IOExternalFileAcquirer` checks the provider file's byte count before copy and then checks only the staged byte count after copy. That catches size drift but cannot distinguish a same-size content replacement or an in-place mutation that produces a mixed copy. It also writes the copy directly as an ordinary Staging file, so an interrupted copy is only distinguishable later by age, not by transaction state.

## Production change

### `IOProviderSnapshotAcquisition.swift`

Adds `IOProviderSnapshotAcquirer` as the snapshot-safe acquisition boundary.

- external file must be a non-empty regular non-symlink file outside the app root;
- maximum file bytes and storage reserve are checked before copying;
- bytes are copied in bounded chunks into `Staging/<uuid>.provider-partial`;
- copy loop enforces the size cap while bytes are being read, so provider growth past the limit fails before ready publication;
- a two-lane 128-bit consistency fingerprint is computed while copying;
- immediately after copy, the coordinated source is re-read and fingerprinted;
- initial byte count, copied byte count and post-copy source fingerprint must agree;
- same-size content replacement therefore fails with `sourceChangedDuringAcquisition` rather than publishing a ready snapshot;
- only after coherence validation does the partial file move atomically to a ready Staging filename carrying the source extension;
- errors/cancellation remove current-process partial/ready files;
- a process death can leave `.provider-partial`, which the existing direct-child `IOStagingRecovery` sweep can remove after its grace interval.

The fingerprint is a mutation-consistency detector, not a cryptographic authenticity proof.

### File Provider coordination

For Apple `securityScoped` mode the entire inspect/copy/post-read verification stays inside the existing security-scope lease plus `NSFileCoordinator` read coordination. This means coordinated provider writes should serialize with acquisition, while the fingerprint additionally detects content drift visible during the read window.

Apple security-scoped / File Provider runtime behavior is not claimed PASS from this Linux Worker.

### `IOProviderSnapshotAudioImporter.swift`

Adds a product-composition seam for picker/File Provider imports:

1. acquire a coherent app-owned Staging snapshot through `IOProviderSnapshotAcquirer`;
2. pass only that snapshot to the existing `AudioImporting` implementation as `.appOwnedFile`;
3. let the existing media probe / compatibility path perform codec validation;
4. remove the handoff Staging snapshot on both base-import success and failure.

Because the base importer receives `.appOwnedFile`, existing MP3/WAV/FLAC/M4A/MP4/MOV/WMA routing remains intact, including the existing WMA native-first + compatibility decoder seam.

Provider mutation is mapped to stable retryable code `PROVIDER_SOURCE_CHANGED_DURING_ACQUISITION`.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Executed in this Worker session:

- `IOProviderSnapshotAcquisition.swift` + `IOProviderSnapshotAudioImporter.swift`: strict-concurrency / warnings-as-errors typecheck against fetched/frozen contract-equivalent IO/Shared surfaces: PASS.
- `IOProviderSnapshotAcquisitionTests.swift` + `IOProviderSnapshotAudioImporterTests.swift`: strict XCTest typecheck: PASS.
- all AW15 source/test/self-check files Linux syntax parse: PASS.
- production wiring static audit: PASS 17/17 checks.
- executable filesystem self-check: PASS, marker:
  `L2_AW15_SELF_TEST_PASS scenarios=8 files=200 bytes_per_file=65536 elapsed_seconds=0.927484`

The self-check covers:

1. stable WMA-named provider file publishes byte-identical ready Staging and preserves extension;
2. same-size different-content fingerprints are rejected;
3. initial-size drift is rejected even when final source and copied fingerprints match;
4. oversize source is rejected;
5. empty source is rejected;
6. an interrupted `.provider-partial` direct child is reclaimed by the existing Staging recovery policy;
7. the wrapper hands byte-identical app-owned staging to the base importer and removes the lease afterward;
8. 200 files x 65,536 bytes are copied + post-verified through the portable direct-mode path.

The `0.927484 s` result is a Linux filesystem microbenchmark, not an iPhone/iCloud/File Provider latency claim.

## Negative / recovery invariants

- A provider file is never published as ready Staging before the copy and post-copy source fingerprints agree.
- Same-size replacement is not accepted based on size alone.
- Provider growth beyond the configured cap fails during streaming.
- Partial acquisition uses a recognizable `.provider-partial` state and never moves into Imports directly.
- Process-local failures remove both partial and ready candidates.
- Process-death leftovers remain Staging-only and are recoverable by the existing grace-based Staging sweep.
- Source URLs inside the app root, symlinks, directories, empty files and oversize files fail closed.
- Base importer failure does not leak the wrapper's Staging handoff.
- WMA remains in scope and is not downgraded or removed.

## Important remaining limitation / integration requirement

The older `IOSAudioIOService.importExternalFile(...)` / `IOExternalFileAcquirer` path remains source-compatible and can bypass AW15 snapshot verification if App/HQ calls it directly.

For production late integration, picker / Files / iCloud / File Provider imports should use `IOProviderSnapshotAudioImporter.importExternalFile(...)` (or an equivalent HQ adapter built on `IOProviderSnapshotAcquirer`) rather than the legacy raw external-file method.

A future HQ-owned App/Shared integration revision can make this the single user-facing route. Worker 2 does not edit frozen App/Shared surfaces in this epoch.

## Gates intentionally still open

- real iPhone security-scoped URL access lifecycle;
- real iCloud / File Provider materialization, eviction, download-on-demand and provider error semantics;
- real concurrent provider mutation/replacement while NSFileCoordinator owns the read lease;
- force termination during `.provider-partial` copy, after fingerprint verification and immediately around partial->ready rename on APFS;
- large cloud-file cancellation latency and storage-pressure behavior on device;
- actual Apple media probe with MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixtures;
- production WMA compatibility decoder selection/license/package audit if native decoding is unavailable;
- current-Moises cloud/import route inventory and Differential Moises comparison;
- final MOI-P001/MOI-P002 PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW15.

AW15 closes a concrete provider-file same-size mutation and interrupted-partial publication gap inside Lane 2, but actual File Provider/iPhone/codec/reference evidence remains required before MOI-P001 or MOI-P002 can move from MISSING.
