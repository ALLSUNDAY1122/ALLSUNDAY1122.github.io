# L2-AW53｜Segmented steady-state path authority validation

Date: 2026-08-27 JST
Worker: Moises-Worker-2 / LANE-2-IO-LIBRARY
Result: COMPLETED_NON_PARITY

## Canonical starting point

- Fresh Notion canonical remained HQ Canonical Epoch 44: L1 A23 / L2 AW49 / L3 AW49 / L4 W52.
- Product PARITY promotions remained zero; portable evidence must not be interpreted as product PARITY.
- Worker branch started this Wave at AW52 status commit `bac37222dde10404e4b7a5f91e54fccbcdd9b1c6`.
- AW52 explicitly left steady-state `Lane2ManagedArtifactSegmentedRuntime` and `Lane2ManagedArtifactSegmentedBoundedMutation` path authority for the next independent Wave.

## Fresh audit findings

The AW40/AW44 steady-state paths still used direct `FileManager.fileExists`, leaf-only resource-value checks, direct recursive directory creation, and direct atomic segment/manifest writes. This left four concrete authority gaps:

1. A dangling committed manifest could be observed as `fileExists == false` and enter legacy-v1 fallback.
2. A managed artifact such as `Imports/a.m4a` could be reached through a symlinked `Imports` ancestor while its leaf appeared to be a regular file.
3. A symlinked `.LibraryRecovery/ArtifactInventory/v1/Segmented` directory could redirect new segment or manifest publication outside the configured Library root.
4. Existing or replacement segment/manifest nodes were not uniformly proven to be regular nodes beneath a validated real directory before read or overwrite.

The Runtime path also trusted manifest `entryCount` for `reserveCapacity` and used `(entryCount + 511) / 512`, which could overflow on a corrupt extreme count.

## Implementation

### `ManagedArtifactSegmentedRuntime.swift`

- Manifest absence is now ancestor-aware through `LibraryManagedPathBoundary.nodeExists`; dangling/symlinked manifest authority fails closed as `corruptManifest` instead of falling back to legacy.
- Legacy shard reads validate the complete `Shards` ancestor chain and require a real regular shard file.
- Managed-artifact snapshots validate the complete managed path under the configured root and require a real regular leaf; parent symlinks are rejected as `unsafeManagedArtifact`.
- Committed segment reads require a real regular segment under a validated `Segmented` directory.
- Publication creates/validates the `Segmented` directory component-by-component, requires each new generation segment destination to be truly absent, revalidates the segment after atomic write, validates all segments before manifest publication, then requires the final manifest to be a real regular file or genuinely missing before atomic replacement and revalidates/reloads it afterward.
- Removed direct `reserveCapacity(manifest.entryCount)` from untrusted committed metadata.
- Segment-count arithmetic now uses division/remainder and cannot overflow by adding `entriesPerSegment - 1` to an untrusted count.
- Public API and existing failure enum are unchanged.

Final Git blob SHA: `6417592498e24fc131ad3034fe62f10a68a48f01`.

### `ManagedArtifactSegmentedBoundedMutation.swift`

- Managed-artifact snapshot authority now uses the same ancestor-aware root validation.
- Manifest load treats dangling/symlinked authority as corruption, never as missing fallback.
- Source and newly generated segments must be real regular files under a validated `Segmented` directory.
- Republish validates/creates the `Segmented` directory, requires new generation segment destinations to be absent, and revalidates them after write.
- Final manifest replacement requires the existing final node to be a real regular file or genuinely absent, performs atomic write, then revalidates and exact-read-backs the manifest.
- Segment-count arithmetic is overflow-safe.
- Public API and existing failure enum are unchanged.

Final Git blob SHA: `258319223f684ade8d2f34bd5108162e32671ee8`.

## Verification

### Focused strict compile

The exact production sources were checked with Swift 6.2.1 Linux using:

`-swift-version 6 -warnings-as-errors -strict-concurrency=complete`

Result:

`AW53_TYPECHECK_PASS`

The final Git production blob SHAs were compared against the exact locally validated source bytes and matched exactly.

### Regression source

Added `Library/Tests/ManagedArtifactSegmentedSteadyStatePathAuthorityTests.swift` with eight XCTest regressions covering:

1. Runtime dangling manifest refuses legacy fallback.
2. Runtime rejects a symlinked managed-artifact ancestor and preserves the external target.
3. Runtime rejects a symlinked Segmented publication root.
4. Runtime rejects a committed segment replaced by a symlink and preserves the external target.
5. Bounded mutation dangling manifest refuses fallback.
6. Bounded mutation rejects a symlinked managed-artifact ancestor.
7. Bounded mutation rejects manifest symlink replacement and preserves the external target.
8. Normal Runtime seed -> bounded update -> bounded remove remains convergent and retains zero-entry segmented authority.

Exact production + test source passed focused strict typecheck. XCTest execution itself is **not claimed** on this Worker branch.

Final test blob SHA: `c0ed2ef9a12a48235f64d7993c79742cf6aea131`.

### Real-filesystem / symlink self-check

The final durable self-check source is `Library/benchmarks/L2AW53SegmentedSteadyStateAuthoritySelfCheck.swift`, final blob SHA `bc8106eed3cacbebe6869ed575a64d449dc24cc7`.

The first self-check draft exposed only harness compile problems: throwing calls were placed directly inside `precondition` autoclosures and one enum comparison used an invalid shorthand. Those harness defects were corrected before final execution; production sources had already passed strict typecheck.

Final execution result:

`L2_AW53_SELF_TEST_PASS checks=8 dangling_manifest=true artifact_parent=true segmented_root=true segment_symlink=true bounded_dangling=true bounded_parent=true manifest_symlink=true normal=true bounded_update_200_ms=4573.861`

The self-check used actual temporary directories, real regular files, dangling symlinks, directory symlinks, symlink replacement, atomic JSON writes, committed generation reads, bounded mutation, and removal. External targets remained intact in all symlink scenarios.

Portable benchmark observation: 200 successive one-artifact bounded updates took `4573.861 ms` on Swift 6.2.1 Linux. This is a portable regression signal only, not an iPhone performance claim.

## Scope audit

Immediately before Evidence creation, compare from AW52 status `bac37222dde10404e4b7a5f91e54fccbcdd9b1c6` to Worker branch was:

- ahead: 7
- behind: 0
- changed files: exactly four Library-owned files (Runtime, BoundedMutation, AW53 test, AW53 self-check)
- no Shared/App/PARITY/other Lane change

## Residual gaps

- Validation and subsequent Foundation reads/writes remain separate syscalls; same-path replacement TOCTOU is not eliminated. Descriptor-relative/no-follow or an Apple-equivalent primitive would be required for stronger closure.
- Foundation `.atomic` publication and directory metadata durability are not proven under physical iPhone/APFS force termination, protection-class transitions, File Provider behavior, or ENOSPC.
- Old segmented generations remain subject to the independent AW52 bounded cleanup substrate; AW53 does not create descriptor-level transactional garbage collection.
- `ManagedArtifactSegmentedStreamingTraversal`, `ManagedArtifactInventoryMarker`, `ManagedArtifactInventoryFreshActivation`, `ManagedArtifactInventorySegmentedBridge`, and top-level `ManagedArtifactInventory` still require independent path-authority audit. The top-level inventory still owns orphan-candidate deletion and authoritative-marker transitions.
- Remaining deletion/recovery metadata needs continued audit after the inventory surface.
- Physical iPhone/APFS/File Provider/protection-class/force-termination behavior and performance remain unmeasured.
- A production WMA compatibility decoder is not selected/licensed; real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixtures remain pending.
- Apple Core Data/WAL/force-termination/APFS/ENOSPC evidence remains pending.
- Real import/export/share, File Provider, AVFoundation validity/synchronization/naming/shareability and Differential Moises evidence remain pending.
- MOI-P001/P002/P017/P018/P019/P020/P024 remain MISSING until HQ real-device/reference/differential gates are satisfied.

## HQ integration requests

1. Run full Lane2/package compile and regression suite on integration, including existing `ManagedArtifactSegmentedRuntimeTests.swift`, bounded-mutation contracts, and new `ManagedArtifactSegmentedSteadyStatePathAuthorityTests.swift`.
2. Preserve the rule that dangling/symlinked manifest authority is corruption, never a compatibility-style missing node.
3. Preserve ancestor-aware managed-artifact snapshot semantics and zero-entry committed segmented authority after final removal.
4. Preserve segment publication as absent-only for new generation leaves and manifest replacement as regular-or-genuinely-missing authority with post-write validation.
5. Do not interpret AW53 as eliminating syscall-level TOCTOU or proving APFS crash durability.
6. Do not promote Lane-2 PARITY rows from portable AW53 evidence.
7. No Shared/App/PARITY contract or Core Data schema change was required by AW53.
