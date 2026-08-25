# L2-AW44｜Bounded Segmented Mutation Validation

## Goal
Close the remaining managed-artifact scalability gap after AW43: committed segmented upsert/remove must not materialize a pathologically concentrated shard as one in-memory array before publishing a new generation.

## Fresh canonical read
- Notion canonical: v4 autonomous independent lanes / late integration.
- Resource lock: integration epoch 30, assignment epoch 2, planning revision 4.
- HQ canonical includes Lane 2 through AW42; PARITY promotion remains 0.
- Wave start Worker branch HEAD: `a22dde0f28bc89802040126429ac57e93d7ea44f`.

## Implementation
Added `ManagedArtifactSegmentedBoundedMutation.swift` and routed canonical bridge registration/removal through it.

For an already-committed segmented shard:
- mutation input is processed in batches of at most 256 paths;
- the prior generation is decoded one segment at a time, maximum 512 entries;
- sorted updates/removals are merged while streaming;
- output is buffered only until 512 entries, then atomically written as one new segment;
- every new segment is read back before manifest publication;
- the manifest is atomically replaced only after the complete generation verifies;
- a corrupt source manifest/segment therefore leaves the previous manifest authority intact.

Legacy v1 fallback remains compatible and is still constrained by AW38's 8 MiB legacy shard ceiling before the first segmented generation exists.

During strict verification, the Worker branch was also found to retain the pre-HQ-fix Swift 6 parse boundary `guard lhs == try rhs()`. The bridge now uses `guard lhs == (try rhs())`, matching the semantic fix already recorded by HQ integration without changing runtime behavior.

## Portable executable self-check
Swift 6.2.1, strict concurrency, warnings-as-errors.

Pathological fixture:
- 1,300 inventory entries intentionally concentrated into one shard;
- 300 existing paths updated;
- 300 paths removed;
- committed generation uses three source segments;
- post-removal fixture has 1,000 entries;
- later committed segment is corrupted before a final mutation to verify fail-closed authority retention.

Result:

`L2_AW44_SELF_TEST_PASS entries=1300 upsert=300 remove=300 segment_bound=512 batch_bound=256 manifest_fail_closed=true`

Observed assertions:
- `maximumDecodedSegmentEntries <= 512` for upsert and remove;
- `maximumMutationBatchEntries <= 256`;
- 300 same-shard mutations produce two bounded generations rather than one unbounded mutation set;
- upsert preserves 1,300 entries;
- removing 300 leaves 1,000 entries;
- corrupt committed source segment causes mutation failure;
- manifest bytes before/after that failure are identical.

Bridge-specific strict typecheck after parse-boundary repair:

`L2_AW44_BRIDGE_TYPECHECK_PASS`

## Failure / interruption semantics
A new generation is never authoritative merely because some segment files were written. Authority changes only at final atomic manifest replacement after complete segment read-back. Therefore interruption or corruption before manifest replacement leaves the previous committed generation authoritative. Unreferenced provisional generation files may remain and can be reclaimed separately; they do not become authoritative.

## Scope audit
Owned changes only:
- `tech-assets/moises-audio/Library/Sources/**`
- `tech-assets/moises-audio/Library/Tests/**`
- this Evidence file
- `automation/chatgpt-dispatcher/moises-equivalence/worker-status/worker-2.json`

No Shared/App/PARITY/Core Data schema or other-Lane source changes.

## Non-PARITY statement
This is portable correctness/scalability evidence only. It does not satisfy physical-iPhone/APFS/RSS/latency, Core Data/WAL, real import/export/share, real codec, AVFoundation validity, or Differential Moises gates. No Lane-2 PARITY row is promoted by AW44.
