# L2-AW50｜Export Registration Path Authority Validation

Date: 2026-08-27 JST
Lane: LANE-2-IO-LIBRARY / Moises-Worker-2
Result: COMPLETED_NON_PARITY

## Canonical starting point

Fresh canonical read reported HQ Canonical Epoch 44. Lane 2 AW49 was already integrated at source integration `a93ef6b058db89fa57d8ee0a8064e5df019af331`; Run #316 `33030546532` succeeded with SwiftPM 462/462 PASS and Lane2 IO+Library full portable source typecheck PASS. Product PARITY remained at zero promotions.

Worker branch started this Wave at AW49 status commit `f3e1f30b69189c9a48b02650c40d5824e2d021ed`. Under v4 independent-lane operation the Worker continued on its owned branch rather than rebasing onto moving integration.

## Why AW50

AW49 protected `.LibraryLifecycle`, but its status explicitly left `Lane2ExportRegistrationJournal` and prejournal export quarantine authority for separate re-audit.

The fresh audit found a direct compatibility bypass in `Lane2ExportRegistrationJournal`:

- AW35+ batches are integrity-verified only when `.lane2-batch-integrity-v1.json` is present.
- The prior implementation used `FileManager.fileExists(atPath:)` to decide whether the integrity manifest existed.
- `fileExists` reports false for a dangling symlink.
- Therefore a dangling manifest could be misclassified as a genuinely absent pre-AW35 manifest and enter the legacy compatibility path without integrity verification.

The same journal also directly created/read/removed `.LibraryRecovery/ExportRegistration` intents, read/removed publication markers, and moved finalized batches into `.LibraryRecovery/PrejournalExport` without the AW49 Library path authority boundary.

## Implementation

### 1. Export-registration journal now uses LibraryManagedPathBoundary

`Lane2ExportRegistrationJournal` now guards:

- `.LibraryRecovery/ExportRegistration` directory creation and enumeration;
- intent JSON existing-leaf validation before atomic overwrite;
- post-write intent validation;
- intent reads and completion removal;
- `exists(intentID:)` so symlink leaves are not treated as valid intents;
- `Exports/Batches` recovery root and each candidate batch directory;
- pre-registration marker existence/read/removal;
- marker size, non-empty session and NUL rejection during recovery;
- `.LibraryRecovery/PrejournalExport` creation and move destination nonexistence;
- source batch revalidation before move and destination directory validation after move;
- pruning of the ExportRegistration directory.

Public API and the existing failure enum were preserved.

### 2. Integrity-manifest compatibility branch distinguishes absent from unsafe

`validatePublishedBatchIntegrityIfPresent` now uses non-following `LibraryManagedPathBoundary.nodeExists` semantics.

- genuinely absent manifest -> historical pre-AW35 compatibility remains available;
- real manifest -> AW48 `IOExportBatchTransaction.verifyPublishedBatch` gate remains authoritative;
- dangling/symlink/non-regular manifest -> treated as present/unsafe and fails integrity verification rather than entering compatibility mode.

### 3. Same-Wave ancestor authority gap closed centrally

A second audit found that leaf-aware existence was still insufficient if an ancestor itself was a symlink and the external leaf did not exist.

Example class:

`root/Exports -> external-directory`, then query `root/Exports/Batches/x/.lane2-batch-integrity-v1.json` where the external target leaf is absent.

The old `LibraryManagedPathBoundary.nodeExists` could report false for the missing leaf before proving the ancestor chain was real.

AW50 therefore strengthened `nodeExists` centrally:

1. validate lexical containment;
2. validate the configured root when present;
3. walk every existing parent component;
4. require each parent to be a real directory;
5. only then classify the final leaf as present or genuinely missing.

A missing parent remains a normal missing path. A symlink/non-directory ancestor fails closed.

This benefits current and future Library-owned users of the AW49 boundary instead of adding a one-off registration-journal exception.

## Portable validation

### Strict typecheck

Environment:

- Swift 6.2.1
- `-swift-version 6`
- `-warnings-as-errors`
- `-strict-concurrency=complete`

The exact AW50 `Lane2ExportRegistrationJournal` and exact `LibraryManagedPathBoundary` source typechecked successfully in a focused harness. Minimal IO symbol stubs were used only to satisfy `IOFileStore` / `IOExportBatchTransaction` references; the Library authority code under test was the production source.

`ExportRegistrationPathAuthorityTests.swift` also passed focused strict typecheck under the same isolated symbol setup.

This is not a substitute for full integrated package compilation.

### Real filesystem self-check

The focused harness used actual temporary directories and symbolic links.

Final output:

`L2_AW50_SELF_TEST_PASS checks=7 legacy_absent=true dangling_manifest=true parent_symlink=true registration_symlink=true intent_symlink=true marker_symlink=true batch_root_symlink=true`

Cases:

1. genuinely missing pre-AW35 integrity manifest remains compatible;
2. dangling integrity manifest fails closed;
3. missing manifest through a symlink ancestor fails closed;
4. symlink `ExportRegistration` directory cannot redirect intent writes;
5. symlink intent leaf cannot be atomically overwritten and external bytes remain unchanged;
6. symlink publication marker is not removed and the already-durable Library intent remains;
7. symlink `Exports/Batches` recovery root fails closed.

A separate exact-boundary check produced:

`L2_AW50_ANCESTOR_SELF_TEST_PASS checks=2 safe_missing=true symlink_ancestor=true node_probe_10000_ms=505.494`

### Portable timing

After ancestor-aware `nodeExists` was enabled, 1,000 normal journal cycles of:

`prepare -> exists -> complete`

produced:

`L2_AW50_PORTABLE_BENCH_PASS prepare_exists_complete_1000_ms=2899.457 per_cycle_us=2899.457`

This is Linux/container timing only. It is not an iPhone/APFS performance claim or a product threshold.

## Durable regression sources

Added:

- `Library/Tests/ExportRegistrationPathAuthorityTests.swift` — 8 journal-focused regression cases.
- `Library/Tests/LibraryManagedPathBoundaryAncestorTests.swift` — 2 ancestor/missing-node regressions.
- `Library/benchmarks/L2AW50ExportRegistrationAuthoritySelfCheck.swift`.
- `Library/benchmarks/L2AW50AncestorAuthoritySelfCheck.swift`.

The Worker branch has no automatic CI run for these commits. The XCTest sources are committed for HQ/integrated CI but are not claimed as executed XCTest PASS in this Wave.

## Same-Wave review result

The first implementation closed direct intent/marker/quarantine paths and dangling manifest leaves. Re-audit then found the parent-symlink + missing-leaf class. AW50 did not stop at the first checkpoint; the common boundary was strengthened and the self-check expanded before Evidence finalization.

## Scope / non-claims

AW50 does not claim:

- syscall-atomic no-follow safety between validation and subsequent Foundation operations;
- complete hardening of `Lane2PrejournalExportQuarantineManager` disposition/preserve/purge roots;
- full package/XCTest PASS on the Worker branch;
- Apple/APFS/File Provider/protection-class or force-termination evidence;
- real audio/export/share validity;
- product PARITY.

`Lane2PrejournalExportQuarantineManager` remains the next high-value path-authority target because it owns durable preserve/purge dispositions and destructive batch removal.

## Commits

- `be5435709a68368c59f49aa8223897c52d0abe39` — harden export-registration journal path authority.
- `28b0a5d2b2c06382c3fe42465977d8cfe5fdbe4d` — journal path-authority regression XCTest source.
- `91e8b890469c5a1bdf03eb9c6f6673ff5a5a6850` — export-registration self-check source.
- `3217b6873b11608bc30a34e67a8f02cf151d6f36` — make Library missing-node classification ancestor-aware.
- `0d3e2d42e2bf12093a462c392d2d72cefa181882` — ancestor authority self-check source.
- `6b353f4b960d6e205da319e5091fb761d371e9d7` — ancestor missing-node XCTest regressions.

## Result

`COMPLETED_NON_PARITY`

No Shared/App/PARITY/Core Data schema changes were made. MOI-P001/P002/P017/P018/P019/P020/P024 remain HQ-gated and MISSING until physical-device/reference/differential requirements are satisfied.
