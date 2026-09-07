# L2-AW13 Metadata Quarantine Canonical Reconciliation Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks.

Selected after re-reading the current Notion v4 canonical, Worker contract, Work Package, Lane Plan, Worker 2 status, Resource Locks and PARITY ledger. Resource-lock ownership remained unchanged at assignment epoch 2 / integration epoch 8. MOI-P017/P018/P019 remained MISSING.

After AW08 added byte-preserving lifecycle-metadata quarantine and AW12 added canonical maintenance projections, the remaining corruption gap was the transition *after* quarantine: project ownership can be reconstructed from canonical Library data, but a corrupt export shard cannot be reconstructed from the frozen Project Library contract. If the corrupt export shard is simply moved away and normal orphan sweeping resumes, valid user export files can become untracked and later be deleted as apparent orphans.

## Production change

### Durable export-metadata quarantine barrier

`Lane2LifecycleQuarantineRecovery.swift` adds a lane-local fail-closed barrier outside the v2 metadata tree:

`.LibraryLifecycle/Recovery/export-metadata-quarantine-barrier.json`

The barrier is written atomically **before** the canonical coordinator calls `Lane2LifecycleMetadataStore.quarantineCorruptShards()` when a current v2 export shard is detected as corrupt.

The barrier records:

- the original corrupt export-shard relative paths;
- project UUIDs derivable from valid shard filenames;
- whether any corrupt shard cannot be attributed to a project;
- creation time and barrier schema version.

The file lives outside `.LibraryLifecycle/v2`, so a legacy-v1 corruption recovery that deletes/reinitializes the unmarked v2 tree cannot delete the barrier.

### Legacy corruption handling

A malformed legacy v1 lifecycle document cannot prove that it contained zero exports. Before `quarantineCorruptLegacyDocument()` is allowed to move/reinitialize that document, AW13 creates an **unattributed** export-recovery barrier. This is intentionally conservative: canonical Project Library can restore project/source ownership, but it cannot prove the complete historical export set.

Unsupported future lifecycle schema remains fail-closed and is not downgraded or auto-quarantined.

### Canonical ownership reconstruction

`Lane2DurableLifecycleCoordinator.quarantineAndReconcileLifecycleMetadata()` is now the production recovery entrypoint:

1. detect corrupt v2 export shards and persist the barrier first;
2. invoke the existing byte-preserving shard quarantine, or the existing explicit legacy quarantine when the legacy document is malformed;
3. rebuild all live project ownership shards from canonical `LibraryMaintenanceProjectProviding` / frozen-contract fallback data;
4. return the quarantine paths plus any active export-recovery barrier.

Ownership reconstruction is allowed while the export barrier is active because it writes only project ownership metadata and never deletes export bytes.

### Destructive/export operations blocked while uncertainty exists

The coordinator now checks the barrier before:

- starting a new export;
- recovering pending export registration;
- beginning or resuming export cleanup;
- canonical project delete + owned-artifact cleanup;
- deleted-project sidecar reconciliation;
- orphan sweeping;
- exposing a lifecycle snapshot as complete/canonical.

This prevents missing export metadata from being treated as evidence that export files are unreferenced.

Import/project creation, user edits and canonical ownership reconstruction remain available.

### Explicit recovery resolution

`resolveQuarantinedExportMetadata(...)` clears the barrier only after an explicit resolution:

- every attributed corrupt project must either provide restored export artifacts or be explicitly acknowledged as having no recoverable export metadata;
- restored artifacts must be non-empty regular files under `Exports/**`;
- duplicate restored paths are rejected;
- existing metadata must either be absent or exactly match the requested restore (supports idempotent retry after a partial recovery attempt);
- unattributed corruption requires a distinct `acknowledgeUnattributedMetadataLoss` decision;
- the complete lifecycle snapshot must decode after restoration before the barrier is removed.

The API intentionally does not infer or silently delete unknown exports. The user-facing choice and any decision to accept unrecoverable export metadata remain HQ/App integration responsibilities.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Executed in this Worker session:

- `Lane2LifecycleQuarantineRecovery.swift` strict-concurrency / warnings-as-errors typecheck against contract-equivalent `Lane2ExportRecord` surface: PASS.
- `Lane2LifecycleQuarantineRecoveryTests.swift` strict-concurrency / warnings-as-errors XCTest typecheck: PASS.
- updated `Lane2DurableLifecycleCoordinator.swift` strict-concurrency / warnings-as-errors typecheck against frozen-contract-equivalent coordinator stubs: PASS.
- updated coordinator Linux syntax parse: PASS.
- production wiring static audit: PASS 13/13 checks.
- executable filesystem self-check: PASS, marker:
  `L2_AW13_SELF_TEST_PASS scenarios=7 shards=1001 elapsed_seconds=0.881204`

The self-check covers:

1. a valid export shard does not create a barrier;
2. a corrupt UUID-attributed shard creates the barrier while the corrupt source shard still exists, proving barrier-before-move ordering;
3. the barrier blocks export metadata use after the corrupt shard is moved;
4. a malformed shard filename is represented as unattributed corruption;
5. a legacy barrier survives simulated v2 directory removal/reinitialization;
6. incomplete attributed resolution is rejected while complete explicit resolution is accepted;
7. 1,000 valid export shards plus one corrupt shard are scanned and the corrupt project is found.

The `0.881204 s` number includes portable filesystem fixture creation and JSON scanning on this Linux runner. It is not an iPhone/APFS/Core Data performance claim.

## Negative / recovery invariants

- No corrupt export shard is intentionally moved by the canonical AW13 coordinator path unless a durable barrier has first been written.
- A corrupt or unreadable barrier fails closed.
- A barrier is merged rather than overwritten if a later recovery attempt finds additional corrupt export shards.
- Project-only/failure-history corruption can still be quarantined and canonical ownership rebuilt without inventing export metadata.
- Unknown export metadata never causes automatic file deletion.
- An attributed project cannot be omitted from the explicit resolution.
- Restoring an `Imports/**`, `Stems/**`, absolute, traversal, missing, directory or zero-byte path is rejected.
- A project cannot simultaneously be restored and acknowledged empty.
- A partial recovery crash is retryable: existing restored export metadata must exactly match the requested recovery or the retry fails closed.
- Existing AW09/AW10 export compensation/registration semantics remain in place once the quarantine barrier is absent.

## Important remaining limitation

`Lane2LifecycleMetadataStore.quarantineCorruptShards()` remains a lower-level public recovery primitive from AW08. AW13 establishes `Lane2DurableLifecycleCoordinator.quarantineAndReconcileLifecycleMetadata()` as the production/canonical recovery path because it adds barrier-before-quarantine and canonical ownership reconstruction. HQ/App integration must not bypass the coordinator and call the low-level quarantine primitive directly for user-facing recovery.

A future Shared/App contract revision could hide/deprecate the low-level primitive, but Worker 2 does not change frozen Shared/App surfaces in this epoch.

## Gates intentionally still open

The following remain unverified and are not marked PASS:

- Apple Core Data execution of the accumulated L2-M01/L2-M02/L2-M03/L2-AW11/L2-AW12 suites;
- real iPhone/APFS interruption while the barrier is being written, shard quarantine is moving data, and explicit recovery is restoring export metadata;
- user-facing recovery UX for showing quarantined export uncertainty and obtaining explicit restore/empty/unattributed decisions;
- actual SQLite/Core Data wall time, query plan, RSS/fault churn and 1k/10k+ physical-device scale;
- real Files/iCloud/File Provider/camera-roll/direct URL/security-scoped flows;
- real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixture execution;
- production WMA compatibility decoder selection/license/package audit if native WMA decoding is unavailable;
- real AVFoundation M4A export/share/playback and storage pressure;
- Differential Moises and final PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW13.

The wave closes a concrete data-loss risk between metadata quarantine and later orphan/export maintenance and gives HQ/App an explicit recovery seam. It does not provide the required Apple/device/real-audio/Differential evidence, so MOI-P001/P002/P017/P018/P019/P020 remain HQ-owned PARITY decisions.
