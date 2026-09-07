# L2-AW47｜Managed Path Boundary Validation

Date: 2026-08-27 JST
Lane: LANE-2-IO-LIBRARY
Worker: Moises-Worker-2
Implementation head before evidence: `6e15e7bf44b8685f0189ddc47607f0ac4e9cad23`
Result: `COMPLETED_NON_PARITY`

## Goal

Close the primary `IOFileStore` filesystem-boundary gap where lexical `standardizedFileURL` containment could still be redirected by an existing symbolic link in the configured root, `Imports`, `Exports`, `Staging`, or a managed leaf.

This Wave is intentionally narrower than a claim that every Lane-2 recovery/control directory is symlink-safe. Auxiliary ledgers that independently write below `.IORecovery` / `.LibraryRecovery` are listed as a residual gap below.

## Fresh canonical audit

The 2026-08-27 fresh Notion/GitHub read preserved the v4 autonomous Lane-2 ownership contract:

- Worker 2 owns only `tech-assets/moises-audio/IO/**`, `tech-assets/moises-audio/Library/**`, and `worker-status/worker-2.json`.
- `Shared/**`, `App/**`, `PARITY_MATRIX.json`, queue, work-package and resource-lock control remain HQ-owned.
- Portable implementation/test evidence cannot promote MOI-P001/P002/P017/P018/P019/P020/P024 to PARITY; device/reference/differential gates remain HQ-owned.

AW46 status was still canonical at the start of this Wave; branch head was the partially implemented AW47 chain ending at `b60d29905c398fa1946e8b1a7bdc49391ef84cf3`.

## Failure mode found

Before AW47, `IOFileStore` rejected lexical traversal such as `../escape`, but the managed root and managed directories were ordinary Foundation paths. If one of these nodes was a symbolic link, a path could remain lexically below `rootURL` while the actual filesystem operation targeted another location.

The same issue affected existing app-owned reads: `resolve(relativePath:)` only proved lexical containment. A managed-looking `Imports/foo.m4a` could therefore resolve through a symlinked `Imports` directory or symlink leaf.

A same-Wave compatibility audit also found that an intermediate implementation changed boundary failures back to the existing `.invalidRelativePath` contract while the new tests still expected an obsolete `UNSAFE_MANAGED_PATH` file-operation code. The tests were corrected before Evidence was finalized.

## Implementation

### `IOManagedPathBoundary.swift`

A Lane-2-local boundary guard now:

1. validates an existing root as a real directory and rejects a root symlink;
2. creates managed directories one component at a time only after validating the parent node;
3. validates every existing managed directory component as a real directory, not a symlink;
4. validates existing managed leaves as regular files, not symlinks;
5. validates destinations before a managed write/move and rejects a pre-existing destination.

Boundary failures caused by unsafe/path-escape/destination state are mapped through the existing `IOFileStore.StoreError.invalidRelativePath` contract. Actual directory-creation/filesystem-operation failures remain `fileOperationFailed(code:)`, avoiding an exhaustive-switch break in existing callers.

### `IOFileStore.swift`

Primary managed operations now use the boundary guard:

- `prepareDirectories`: root + `Imports` + `Exports` + `Staging` validation/creation;
- `stageCopy`: destination validation before copy and regular-file validation after copy;
- `moveDownloadedTemporaryFile`: destination validation before move/copy and regular-file validation after staging;
- `finalizeImport` / `finalizeExport`: staging source and destination directory validation, destination validation, revalidation immediately before rename, and final regular-file validation after rename;
- `removeIfExists`: refuses to remove a path unless it is a real regular managed file and its directory chain is safe;
- `preflight`: validates/creates the configured root before asking the filesystem for capacity;
- `resolve(relativePath:fileManager:)`: preserves source compatibility via a default `FileManager`, still resolves safe missing future paths lexically, but any **existing** managed artifact is required to be a regular non-symlink file beneath a non-symlink managed directory chain.

If post-move validation fails after a finalization rename, the publication intent is deliberately **not** cancelled. At that point a file may already be visible, so retaining durable recovery evidence is safer than erasing the intent.

## XCTest coverage committed

`IOManagedPathBoundaryTests.swift` contains 9 focused cases:

1. root symlink fails closed and does not create managed directories in the external target;
2. `Staging` symlink cannot redirect `stageCopy`;
3. `Imports` symlink cannot redirect import finalization;
4. `Exports` symlink cannot redirect export finalization;
5. symlink staging leaf cannot be finalized;
6. `removeIfExists` does not traverse a managed-directory symlink to delete an outside file;
7. `resolve` rejects an existing file reached through a managed-directory symlink;
8. `resolve` rejects an existing symlink leaf;
9. `resolve` preserves lexical behavior for a safe not-yet-created future path.

## Portable strict-concurrency self-check

Environment: Swift 6.2.1 Linux portable harness, `-strict-concurrency=complete -warnings-as-errors`.

The actual AW47 boundary/FileStore logic was compiled with the publication journal replaced only by a minimal type-compatible stub so the path boundary can be executed independently of unrelated recovery code.

Result:

`L2_AW47_SELF_TEST_PASS checks=10 root_symlink=true managed_dir_symlink=true leaf_symlink=true managed_read=true normal_stage_finalize=true missing_future_compat=true`

The portable run exercised real temporary directories, real symbolic links and real copy/move/read/remove behavior. It is not Apple-runtime or PARITY evidence.

## Portable microbenchmark

Optimized Swift 6.2.1 build, 7 rounds x 10,000 existing safe-file resolves:

`L2_AW47_PORTABLE_BENCH_PASS iterations=10000 rounds=7 median_ms=1613.064 per_resolve_us=161.306`

This is a Linux filesystem microbenchmark only. It shows the added validation is fixed-depth and operationally bounded for the primary resolver path; it is not an iPhone latency threshold or product performance claim.

## Residual gaps / limits

1. **Auxiliary recovery/control subdirectories are not covered by this Wave.** `IOStagingOwnershipRegistry` independently manages `.IORecovery/StagingOwnership`, and `Lane2ManagedArtifactPublicationJournal` independently manages `.LibraryRecovery/.../Publications`. Their nested directories require the same direct-node/symlink audit before Lane 2 can claim a comprehensive managed-filesystem boundary.
2. `IOExportBatchTransaction` owns deeper `Staging/ExportBatches` and `Exports/Batches` directories. Its top-level parents benefit from AW47 validation, but the nested directories themselves still need a dedicated direct-node audit.
3. Foundation path validation and the following copy/move/remove operation are separate syscalls. A malicious same-process actor able to swap nodes exactly between validation and use could still create a TOCTOU. Eliminating that class fully requires descriptor-relative/no-follow filesystem primitives or an equivalent Apple-runtime design. The current app-owned sandbox substantially narrows the practical actor set but does not make the race mathematically impossible.
4. A broken symlink leaf whose target does not exist is treated by `resolve` like a missing future path because `FileManager.fileExists` follows the link. A later target appearance before use is another form of the same TOCTOU class; existing-target symlinks are rejected now.
5. Physical iPhone/APFS, File Provider, ENOSPC, protection-class, force-termination and real share/export evidence remain pending.
6. No PARITY row is promoted from AW47 portable evidence.

## Acceptance conclusion

AW47 closes the primary `IOFileStore` managed-root / `Imports` / `Exports` / `Staging` redirection gap for normal creation, existing managed reads, staging, finalization and regular-file cleanup while preserving the existing public StoreError contract and missing-future-path resolver behavior.

The Wave is complete as a **portable non-PARITY hardening increment**. The next highest-value Lane-2 portable priority is to extend the same fail-closed invariant to auxiliary nested IO ledgers/batch directories without broadening into HQ-owned integration or Apple-only validation.
