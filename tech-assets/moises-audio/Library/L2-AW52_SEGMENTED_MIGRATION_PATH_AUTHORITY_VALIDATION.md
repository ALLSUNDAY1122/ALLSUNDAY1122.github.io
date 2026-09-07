# L2-AW52｜Segmented Migration Path Authority Validation

Date: 2026-08-27 JST  
Worker: Moises-Worker-2 / LANE-2-IO-LIBRARY  
Result: `COMPLETED_NON_PARITY`

## Scope

AW52 hardens the migration/cleanup authority in `Lane2ManagedArtifactSegmentedShardStore` only.

The wave does **not** claim that the steady-state `Lane2ManagedArtifactSegmentedRuntime`, `Lane2ManagedArtifactSegmentedBoundedMutation`, streaming traversal, inventory marker/bridge, Apple runtime, or product PARITY are hardened by this change.

## Fresh audit finding

The pre-AW52 migration substrate still used direct Foundation path authority in several places:

- `fileExists` decided whether a segmented manifest or legacy shard existed.
- `Segmented` was enumerated directly during uncommitted-generation cleanup.
- matching JSON entries were removed directly.
- segment and manifest reads used local resource-value checks but did not validate the full managed ancestor chain.
- final authority publication removed an existing final manifest and then moved the pending manifest, creating a remove/move authority gap.
- `segmentCount(for:)` used `entryCount + entriesPerSegment - 1`, allowing corrupt extreme metadata to reach integer addition overflow.
- `reserveCapacity(manifest.entryCount)` trusted an untrusted manifest count before segment verification.

The highest-risk concrete case was a symlinked `.LibraryRecovery/ArtifactInventory/v1/Segmented` directory: cleanup could enumerate and remove matching external JSON files.

## Implementation

`ManagedArtifactSegmentedShardStore.swift` now reuses `LibraryManagedPathBoundary` for migration-owned authority.

### Manifest authority

- A manifest is considered genuinely absent only through ancestor-aware `boundary.nodeExists`.
- Existing manifest authority must be a regular file under the real `Segmented` directory.
- A dangling manifest or symlinked ancestor is corruption, not legacy fallback.

### Legacy migration source

- A legacy shard is considered absent only after ancestor-aware validation.
- Existing legacy shard bytes must be a regular file under the real `Shards` directory.
- A symlinked `Shards` ancestor cannot source external legacy inventory bytes.

### Segment authority

- Every committed segment read is preceded by `requireExistingRegularFile` under the real `Segmented` directory.
- New generation segments require an absent destination before atomic write and are revalidated as regular files after write.

### Cleanup authority

`removeUncommittedGenerations` now:

1. requires `Segmented` to be a real directory inside the configured Library root;
2. derives exact committed segment filenames from the committed manifest;
3. enumerates only that validated directory;
4. preserves the final manifest and exact committed segments;
5. requires every deletion candidate to be a direct-child regular file;
6. rejects symlink/dangling/non-regular candidates instead of deleting through them.

### Publication ordering

For migration, a final committed manifest must be genuinely absent before publication. After segments and pending manifest are read-back verified, the final manifest is atomically written directly to the absent final path and then revalidated. The previous explicit `remove final -> move pending` sequence is gone.

The fixed pending manifest remains staging/evidence only. After final authority is visible, cleanup of a still-regular pending file is best-effort; an unsafe replacement is not removed and does not roll final authority back.

### Corrupt-count hardening

`segmentCount(for:)` now uses quotient/remainder arithmetic rather than `entryCount + 511`, avoiding addition overflow for extreme corrupt metadata. `loadCommittedEntries` also no longer reserves memory directly from untrusted `manifest.entryCount`.

## Portable validation

Environment: Swift 6.2.1 / Linux container.

The exact AW52 `Lane2ManagedArtifactSegmentedShardStore` production source was compiled with:

- `-swift-version 6`
- `-warnings-as-errors`
- `-strict-concurrency=complete`

The focused executable used a small type-compatible copy of the already-established ancestor-aware `LibraryManagedPathBoundary` behavior because the repository is not locally cloneable in this environment. This is not a full package compile and is not Apple runtime evidence.

Final committed-selfcheck-equivalent execution:

```text
L2_AW52_SELF_TEST_PASS checks=8 segmented_symlink=true dangling_manifest=true legacy_parent=true segment_symlink=true pending_symlink=true cleanup=true overflow_guard=true cleanup_1000_ms=277.732
```

Checks exercised real temporary directories, symbolic links, file reads/writes/removals and migration publication:

1. normal 1,300-entry legacy migration publishes three segments, reads back exactly and retires pending staging;
2. symlinked `Segmented` cannot redirect cleanup and external JSON remains intact;
3. dangling final manifest does not fall back to legacy migration;
4. symlinked legacy `Shards` ancestor cannot source external authority;
5. a committed manifest cannot authorize a symlink segment;
6. a symlink pending leaf is not removed by cleanup;
7. normal cleanup removes regular uncommitted files and preserves the committed generation;
8. `Int.max`-scale corrupt `entryCount` fails closed without integer addition overflow.

Portable benchmark: deleting 1,000 regular uncommitted JSON candidates from one validated shard namespace took `277.732 ms` in the final rerun. This is Linux/container timing only and is not an iPhone/APFS performance claim.

## Regression source

Added `ManagedArtifactSegmentedMigrationPathAuthorityTests.swift` with eight XCTest regressions matching the negative and normal scenarios above.

The production ShardStore + focused boundary + new XCTest source passed strict Swift 6.2.1 typecheck after one test-only type-inference correction. This Worker branch does not automatically execute XCTest, so XCTest execution PASS is **not** claimed here.

Added `L2AW52SegmentedMigrationAuthoritySelfCheck.swift` as a durable focused self-check/benchmark source. Its first committed simplification accidentally placed throwing file reads directly inside `precondition` autoclosures; it was corrected to match the already executed harness and recompiled/re-executed before this Evidence was written.

## Residual risk / non-claims

- Foundation validation and subsequent read/write/remove remain separate syscalls. Same-path replacement TOCTOU is not eliminated; descriptor-relative/no-follow or Apple-equivalent primitives are required for stronger closure.
- Atomic Foundation writes still depend on platform implementation details and require APFS/force-termination evidence.
- `Lane2ManagedArtifactSegmentedRuntime`, `Lane2ManagedArtifactSegmentedBoundedMutation`, `Lane2ManagedArtifactSegmentedStreamingTraversal`, inventory marker/bridge and other deletion/recovery metadata retain independent path-authority audit requirements.
- Physical iPhone/APFS/File Provider/protection-class/ENOSPC evidence is pending.
- Real import/export/share/audio validity and current-Moises Differential evidence are pending.
- MOI-P001/P002/P017/P018/P019/P020/P024 remain MISSING. No PARITY promotion is justified by AW52 portable evidence.

## HQ integration request

When integrating AW52:

- run the full Lane2/package compile and existing segmented migration tests plus `ManagedArtifactSegmentedMigrationPathAuthorityTests.swift`;
- preserve ancestor-aware absence semantics for manifests and legacy shards;
- preserve exact committed-segment protection during cleanup;
- preserve final-authority publication without the old remove/move gap;
- do not interpret AW52 as hardening steady-state segmented runtime/mutation paths or as eliminating syscall-level TOCTOU;
- do not promote PARITY from this evidence.
