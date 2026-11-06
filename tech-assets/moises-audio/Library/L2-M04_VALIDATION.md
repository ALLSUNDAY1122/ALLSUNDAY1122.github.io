# L2-M04 — IO / Library durable lifecycle validation

Captured: 2026-08-22 JST
Worker: Moises-Worker-2
Lane: `LANE-2-IO-LIBRARY`
Branch: `moises/wp2-io-library`
Frozen epoch contract: `a5389c8ffba6c1186a076b0c0ab3ee560aad5c8f`

## Bundle goal

Complete Lane 2's durable IO/Library lifecycle without depending on the iOS shell:

`import -> app-owned ready file -> project persistence -> user edits -> export -> export metadata -> cleanup/relaunch recovery`

This bundle does **not** claim product PARITY. Actual iPhone picker/File Provider/direct URL/share UI, AVFoundation runtime codec behavior, Apple Core Data runtime migration/interruption tests, and Moises differential evidence remain HQ late-integration gates.

## Implemented

### 1. Durable imported-file ownership handoff

`Lane2DurableLifecycleCoordinator.importAndCreateProject`:
1. calls the frozen `AudioImporting` seam;
2. rejects a missing/empty/non-ready returned artifact before metadata exposure;
3. creates the canonical Library project through `ProjectLibraryPersisting`;
4. records only `project UUID + source asset UUID + app-owned relative path` in the Lane-2 lifecycle sidecar.

If process death occurs after canonical project creation but before the sidecar write, `reconcileProjectOwnership()` rebuilds the sidecar from canonical Library snapshots. External provider URLs/bookmarks and runtime objects are never persisted.

### 2. Export bookkeeping and cleanup

Exports are accepted into lifecycle metadata only after each returned relative path resolves to a non-empty app-owned ready file.

Export cleanup is stateful and idempotent:
- `ready -> deleting` is persisted first;
- files are removed second;
- metadata records are removed last;
- relaunch calls `recoverPendingExportCleanup()` to finish an interrupted cleanup.

Canonical project deletion can converge export/ownership cleanup with `deleteProjectAndOwnedArtifacts` and `reconcileDeletedProjectArtifacts`. If canonical Library enumeration fails, cleanup stops before deleting sidecar-owned files.

### 3. Storage-pressure / preflight behavior

`IOStorageBudget` and `IOStoragePreflightPolicy` provide a deterministic seam for exact-capacity, insufficient-capacity, invalid-budget and integer-overflow cases.

Safety rules:
- one byte short fails;
- negative inputs fail closed;
- `required + reserve` overflow cannot be treated as available capacity;
- insufficient storage maps to the stable persisted code `INSUFFICIENT_STORAGE`.

The pre-existing production `IOFileStore.preflight` remains the real filesystem-capacity check used by `IOSAudioIOService`; the new overload makes the same boundary testable deterministically.

### 4. Unsupported codec/error-state persistence

Lane-local failure metadata stores:
- attempt UUID;
- optional project UUID;
- operation (`importAudio`, `exportAudio`, `storagePreflight`);
- stable failure code;
- retryable flag;
- timestamp.

Mapped stable codes include `UNSUPPORTED_MEDIA`, `PROTECTED_MEDIA`, `CORRUPT_MEDIA`, `NO_AUDIO_TRACK`, `INSUFFICIENT_STORAGE`, network/provider codes, cancellation and explicit processing/export codes.

Import failures are durable even before a project exists. Failure history preserves insertion order rather than depending on timestamp precision, after a self-check exposed same-second ordering ambiguity.

### 5. Orphan retention

Lane-2 orphan sweep retains:
- canonical source relative paths;
- canonical stem relative paths;
- export relative paths still represented by lifecycle metadata.

Untracked finalized files remain orphan candidates after the grace period, including the crash window where export finalization succeeded but lifecycle metadata did not commit.

## Tests and executable evidence

Executed in the current environment:

- Swift: `6.2.1`, Linux x86_64.
- New source + test surface typechecked with frozen-contract-equivalent stubs: **PASS**.
- Executable Lane-2 self-check: **PASS**.

The executable self-check covers:
- exact storage budget success;
- one-byte storage failure;
- import -> project persistence -> user edits -> export metadata;
- ready -> deleting export cleanup interruption and relaunch completion;
- unsupported media persisted across metadata-store reopen;
- stable insufficient-storage failure persistence;
- corrupt lifecycle document fail-closed.

Committed XCTest coverage additionally includes:
- durable ownership/export/failure round trip;
- path traversal rejection;
- corrupt sidecar rejection;
- interrupted import ownership handoff reconciliation from canonical Library;
- canonical project delete -> export/ownership cleanup convergence;
- end-to-end import -> persist -> edit -> export -> relaunch metadata lifecycle.

## Boundary / deferred Apple evidence

Not executed here because the current runtime is Linux:
- actual `IOSAudioIOService` AVFoundation decode/export path;
- actual supported/unsupported current-iOS codec matrix;
- system Files / File Provider / camera-roll acquisition;
- physical iPhone storage-pressure behavior;
- UIActivityViewController/document-export sharing;
- Core Data-backed `CrashSafeProjectLibraryStore` composed with this coordinator under Xcode/iOS.

These are explicit late-integration evidence requirements, not assumed PASS.

## PARITY statement

No PARITY row is promoted by Worker 2. `MOI-P001`, `MOI-P002`, `MOI-P017`, `MOI-P018`, `MOI-P019`, `MOI-P020`, and product-quality rows remain HQ-owned and must stay `MISSING` until their full real-device / real-audio / differential gates are satisfied.

## Checkpoint recommendation

All four preloaded Lane-2 Macro Bundles are now implemented on the long-lived branch:
- `L2-M01` Core Data contract adapter;
- `L2-M02` destructive/crash-safe file lifecycle;
- `L2-M03` migration/corruption user-data preservation;
- `L2-M04` IO/Library durable lifecycle integration.

Lane 2 is therefore coherent enough to signal `CHECKPOINT_READY` for HQ semantic integration and Apple-runtime validation. HQ should preload the next four Lane-2 Macro Bundles before Worker 2 resumes after this checkpoint.
