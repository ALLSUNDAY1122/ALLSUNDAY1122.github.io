# L2-AW41｜Segmented Canonical Bridge Validation

## Goal
Preserve AW29's public two-phase cursor semantics while routing registration/removal/orphan preparation through the AW40 segmented runtime, so the eventual canonical call-site switch does not silently advance traversal before the caller has applied a slice.

## Fresh-read
- Notion canonical: v4 autonomous independent lanes.
- Integration epoch: 28.
- Assignment epoch: 2.
- Planning revision: 4.
- HQ canonical through Lane 2 AW39.
- Worker branch start HEAD: `84077342b436eae61ebf3012aabd8b1a9e0491e7`.
- PARITY promotion: 0.

## Implementation
`Lane2ManagedArtifactInventorySegmentedBridge` delegates managed registration/removal and candidate preparation to `Lane2ManagedArtifactSegmentedRuntime`, while retaining the existing `cursor.json` location and explicit `persistTraversal(after:)` boundary.

The bridge adds stale-slice protection: a slice may commit its next traversal only if its `priorTraversal` still equals the durable cursor. This prevents an older concurrent/retried slice from rolling the cursor backward or skipping work.

Corrupt/symlink cursor state fails closed. `resetTraversalForRecovery()` is explicit rather than silently discarding corruption.

## Regression coverage
`ManagedArtifactInventorySegmentedBridgeTests.swift` covers:
1. prepare is side-effect free until explicit traversal persistence;
2. committed traversal becomes the next prepare's prior cursor;
3. replaying a stale slice is rejected;
4. corrupt cursor fails closed;
5. explicit recovery reset returns traversal to shard 0.

## Scope
Only `Library/**` plus Worker 2 status are changed. Shared/App/PARITY and other lanes remain untouched.

## Non-claims
This Wave does not claim physical-device evidence or PARITY. It also does not claim the old `Lane2ManagedArtifactInventory` implementation has already been deleted; it creates the compatibility bridge needed for a low-risk final call-site cutover.
