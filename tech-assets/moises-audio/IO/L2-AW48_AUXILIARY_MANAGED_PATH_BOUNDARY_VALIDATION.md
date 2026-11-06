# L2-AW48｜Auxiliary Managed Path Boundary Validation

Date: 2026-08-27 JST
Lane: LANE-2-IO-LIBRARY / Moises-Worker-2
Result: COMPLETED_NON_PARITY

## Canonical starting point

Fresh Notion canonical read reported HQ Canonical Epoch 41 with Lane 2 AW47 final integrated at integration commit `121c3f8b...` and Run #294 SUCCESS. The canonical page still reports zero PARITY promotions and explicitly forbids treating portable evidence as product PARITY.

Per the independent-lane contract, this Worker did not rebase/sync its long-lived work branch to moving integration state during the normal Wave. The Worker branch was exactly at AW47 status commit `4e634430f872b644e910503e64a8f06c6fdf4387` when AW48 started.

## Why AW48

AW47 protected the primary `IOFileStore` root plus `Imports`, `Exports`, `Staging`, and existing managed leaves from symlink redirection. Its own status deliberately left these portable data-safety gaps:

- `.IORecovery/StagingOwnership`
- `.LibraryRecovery/.../Publications`
- `Staging/ExportBatches`
- `Exports/Batches`
- dangling/broken symlink leaves that `FileManager.fileExists(atPath:)` reports as absent

Those paths carry lease authority, publication intent, recovery cursor state, batch integrity metadata, and destructive cleanup authority. Redirecting any of them outside the app-owned root could undermine recovery or cause external file writes/deletes, so they outrank optional UX/performance work.

## Implementation

### 1. Boundary primitive now sees dangling symlinks

`IOManagedPathBoundary` now uses `FileManager.attributesOfItem(atPath:)` as its node-existence primitive rather than relying only on `fileExists(atPath:)`.

This provides three distinct states:

1. genuinely missing node -> eligible for safe creation/future destination semantics;
2. existing regular/directory node -> validated according to the required node type;
3. symlink, including a dangling symlink -> existing unsafe authority, fail closed.

The boundary adds:

- `nodeExists(...)`
- `requireRegularFileOrMissing(...)`
- component-by-component directory creation after parent validation
- regular-file validation before overwrite/read/remove

### 2. Self-detected missing-node classification bug fixed in the same Wave

The first focused runtime check exposed a defect in AW48 itself: Linux Foundation surfaced a missing `attributesOfItem` path as Cocoa code `260` (`NSFileReadNoSuchFileError`), while the initial implementation checked only `NSFileNoSuchFileError` (`4` on this runtime). That made a legitimate absent directory fail closed before creation.

AW48 was corrected before Evidence finalization to accept both Foundation no-such-file constants while leaving every other attribute failure fail closed. The complete self-check was then rerun from scratch and passed.

### 3. `.IORecovery/StagingOwnership` hardened

`IOStagingOwnershipRegistry` now:

- creates `.IORecovery/StagingOwnership` through `IOManagedPathBoundary`;
- rejects symlink/non-directory ledger components;
- requires every JSON lease candidate to be a real regular file;
- rejects dangling/symlink lease records as corrupt authority rather than treating them as absent;
- validates existing lease records before atomic replacement;
- revalidates the record after atomic write;
- validates before release/expired-record removal;
- never follows a symlink record merely because the lease is old.

This preserves the existing fail-closed recovery rule: unsafe ownership metadata cannot authorize cleanup.

### 4. `.LibraryRecovery/.../Publications` hardened

`Lane2ManagedArtifactPublicationJournal` now routes its nested layout through the same boundary:

- `.LibraryRecovery/ArtifactInventory/v1/Publications/Shards`
- shard JSON files
- `cursor.json`

Missing safe layout may be created; a symlink/non-directory layout fails as `corruptShard`. Shard files must be regular files or genuinely absent. The recovery cursor must be a regular file or genuinely absent, and is revalidated after atomic persistence.

Published artifact completion also requires a regular managed file under the configured root before its publication intent can be retired.

### 5. Export batch staging/final paths hardened

`IOExportBatchTransaction` now validates:

- `Staging/ExportBatches`
- each UUID staging batch directory
- `Exports/Batches`
- final batch destination nonexistence, including dangling symlink occupancy
- output leaves before fingerprinting
- integrity manifest before/after atomic write
- pre-registration marker before sync
- source and destination directories immediately before same-volume rename
- final directory after rename
- all verified children during relaunch verification

Compensation and abandoned-batch recovery never traverse a replacement symlink. A symlink child in `Staging/ExportBatches` causes recovery to fail closed rather than deleting its target.

### 6. Primary resolver dangling-symlink gap closed

`IOFileStore.resolve(relativePath:fileManager:)` now asks the boundary whether any filesystem node occupies the candidate path. A dangling symlink is therefore validated and rejected rather than being treated as a missing future path.

`removeIfExists` also uses non-following node existence before removal and after removal before retiring publication metadata.

## Regression tests added

`IO/Tests/IOAuxiliaryManagedPathBoundaryTests.swift` adds focused coverage for:

1. dangling managed leaf rejected by resolver;
2. `.IORecovery` symlink fails ownership acquire without writing externally;
3. dangling lease record is corrupt authority, not a missing lease;
4. publication `Shards` symlink fails without external write;
5. dangling publication cursor fails closed;
6. `Staging/ExportBatches` symlink fails prepare;
7. `Exports/Batches` symlink fails prepare;
8. abandoned-batch recovery never traverses a symlink child;
9. normal multi-item export batch still commits and verifies.

These are portable regression cases. Apple/XCTest execution remains an HQ/device integration responsibility.

## Focused Swift 6.2.1 verification

Compiler/runtime:

- Swift 6.2.1
- `-strict-concurrency=complete`
- `-warnings-as-errors`

Focused isolated source typechecks:

- `AW48_BASE_TYPECHECK_PASS`
- `AW48_OWNERSHIP_TYPECHECK_PASS`
- `AW48_PUBLICATION_TYPECHECK_PASS`
- `AW48_BATCH_TYPECHECK_PASS`

The ownership/publication/batch checks compile the changed production logic against a minimal lane-local `IOFileStore` dependency stub so the newly changed source can be isolated from the full package. This is not a substitute for HQ's full-source/package build.

After correcting the self-detected Cocoa error-code bug, the real temporary-filesystem/symlink harness passed:

`L2_AW48_SELF_TEST_PASS checks=15 dangling=true ownership=true publication=true cursor=true export_root=true export_normal=true recovery=true`

The harness exercised actual directory creation, regular-file writes, symlink creation, dangling symlinks, atomic JSON writes, export batch directory rename, verification, and recovery cleanup on the portable runtime.

## Portable benchmark

Optimized (`-O`) focused benchmark:

`L2_AW48_PORTABLE_BENCH_PASS ownership_1000_ms=1578.671 publication_1000_ms=2450.632 batch_prepare_abort_500_ms=343.005`

Interpretation:

- ownership: 1,000 acquire+release cycles;
- publication: 1,000 begin+cancel cycles across deterministic shards;
- export batch: 500 prepare+abort cycles.

These Linux timings are regression/reference data only. They establish that the new validation does not create an obvious unbounded scan in these paths. They are not iPhone/APFS performance evidence and carry no PARITY weight.

## Residual gaps / limits

AW48 does not eliminate all filesystem races.

1. Validation and subsequent Foundation read/write/move/remove remain separate syscalls. A hostile same-process/path replacement between them is still a TOCTOU class. Eliminating it fully may require descriptor-relative/no-follow primitives or an Apple-specific equivalent.
2. Parent components above the configured app-owned root are treated as trusted sandbox/container infrastructure; AW48 validates the configured root and descendants, not arbitrary ancestors outside it.
3. Other Library-owned recovery/index/quarantine directories use their own guards and remain subject to their existing evidence, not this IO-specific claim.
4. iPhone/APFS/File Provider/protection-class/force-termination behavior remains unmeasured here.
5. Real import/export/share, AVFoundation media validity/synchronization, real codec fixtures, and current-Moises differential evidence remain pending.

## PARITY statement

No PARITY_MATRIX row is promoted by AW48.

`MOI-P001`, `MOI-P002`, `MOI-P017`, `MOI-P018`, `MOI-P019`, `MOI-P020`, and `MOI-P024` remain subject to HQ real-device/reference/differential gates. Portable filesystem hardening is necessary evidence, not product equivalence.
