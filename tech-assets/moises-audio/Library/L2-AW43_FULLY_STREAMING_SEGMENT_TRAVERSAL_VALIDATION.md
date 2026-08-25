# L2-AW43｜Fully Streaming Segmented Orphan Traversal Validation

## Goal
Eliminate the remaining AW40/AW42 pathological RSS gap where committed segmented orphan traversal decoded each <=512-entry segment separately but accumulated all entries for the current shard before candidate filtering.

## Implementation
- Added `ManagedArtifactSegmentedStreamingTraversal.swift`.
- Canonical `Lane2ManagedArtifactInventorySegmentedBridge.prepareOrphanCandidateSlice` now uses the streaming traversal reader.
- A committed generation is scanned segment-by-segment in manifest order.
- At most one decoded segment (<=512 entries) plus the bounded candidate result is retained by traversal.
- Candidate-limit early stop returns immediately without opening later segments.
- `afterRelativePath` remains the durable resume key; `prepare -> apply -> persistTraversal` semantics are unchanged.
- Segment entries are validated for canonical managed paths, deterministic shard membership, strict global lexical order, generation/index identity, regular-file/non-symlink status, and per-segment count ceiling.
- Full-shard completion checks decoded entry count against the committed manifest.
- Pre-segmented legacy fallback remains available only under AW38's 8 MiB encoded-size ceiling.

## Negative / interruption coverage
1. Later segment corruption is not touched when an earlier segment satisfies the candidate limit; this demonstrates no eager shard-wide materialization.
2. A scan that must reach the corrupt later segment fails closed.
3. Cursor remains on the last scanned relative path on a partial slice, preserving restart/resume behavior.
4. Malformed manifest/segment identity, symlink/non-regular segment, invalid path, duplicate/non-monotonic path and count mismatch fail closed.

## Portable verification
Swift toolchain: 6.2.1.

Strict concurrency / warnings-as-errors typecheck:

`L2_AW43_STREAMING_TYPECHECK_PASS`

Portable self-check using a 600-entry committed shard split across two segments, with segment 1 intentionally corrupted:

`L2_AW43_SELF_TEST_PASS early_stop=true later_corruption=true segment_bound=512 cursor_resume=true`

The `candidateLimit=1` scan returned after the first entry from segment 0 without reading the corrupt segment 1. A larger scan reached segment 1 and rejected it.

## Scope / parity
Owned changes only: `Library/**` plus Worker 2 status. No `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Core Data schema, or other-Lane source changes.

This is portable scalability/correctness evidence only. It does not satisfy physical-iPhone RSS/latency, APFS, force-termination, real import/export/share, codec, or Differential Moises gates and does not promote PARITY.
