# L2-AW38｜Managed Artifact Inventory Shard Preflight Validation

## Fresh-read baseline
- Notion canonical: Moises技術同等化｜AI音源分離アプリ 正本, v4 autonomous independent lanes.
- Worker contract: c9e8ec5d191108db6eb20fbd40db0dab3c46b725.
- Work package: aad7983bdaf315a996dce1496ed245008085c712.
- Lane plan: 10b595b47e5a71278bde32e8656bd284e14e62eb.
- Resource lock: da13653539143850b41925097a23b9e44f259576, integration epoch 25 / assignment epoch 2 / planning revision 4.
- Worker-status baseline blob: 755d00a0c2b520c30d79f7307732be8a8954e2d1.
- PARITY matrix: db98892a379180c25ffeb3586a7c3353620a2d5d, Lane-2 rows remain MISSING.
- Wave start branch HEAD: e05e5a4a3a5983772a2ec3c85da2efc7f5b18962.

## Gap
AW29 bounded orphan maintenance limits candidate count and visited shard count, but each v1 shard is still one JSON file. A pathological concentration can therefore force JSONDecoder to materialize an arbitrarily large shard before the candidate budget becomes effective.

## AW38 implementation
`ManagedArtifactInventoryMarker.swift` now performs a metadata-only authoritative-shard preflight before the inventory fast path is considered valid.

The preflight:
- uses an 8 MiB hard encoded-size ceiling per v1 shard,
- requires at most 256 shard files,
- requires canonical two-hex-digit `.json` shard names,
- requires every shard to be a regular non-symlink file,
- checks file size before any shard payload is decoded,
- fails closed on filesystem metadata/enumeration errors.

`hasValidAuthoritativeMarker` now requires both the exact authoritative marker bytes and a successful shard preflight. When preflight fails, `BoundedOrphanSweep` does not enter the authoritative inventory fast path and instead retains the existing filesystem compatibility route. Therefore a pathological v1 shard is rejected before `ManagedArtifactInventory.loadShard` can JSON-decode it during bounded orphan maintenance.

## Negative / recovery behavior
Covered cases:
- normal small shard remains eligible,
- an encoded shard above the supplied hard limit is rejected,
- malformed/unexpected shard filenames are rejected,
- symlink shard replacement is rejected,
- empty/no-shard authoritative inventory remains valid.

The fallback is non-destructive: AW38 does not invalidate or rewrite v1 inventory data merely because a shard exceeds the safety ceiling. It declines the risky fast path and leaves compatibility maintenance available.

## Portable verification
- Swift 6.2.1 warnings-as-errors / strict-concurrency standalone self-check: `L2_AW38_SELF_TEST_PASS normal=true oversized=true symlink=true`.
- Exact production preflight Foundation/API shape typecheck: `L2_AW38_MARKER_TYPECHECK_PASS`.

## Explicit limitations
AW38 is not a segmented-storage migration and does not prevent a v1 shard from growing past 8 MiB at write time. It bounds decode exposure for the authoritative orphan-maintenance path. A durable crash-safe v1 -> segmented inventory migration is still needed to remove write-time concentration/failover pressure rather than only refusing the fast path. Physical-iPhone RSS/latency and APFS behavior remain unmeasured.

## PARITY
COMPLETED_NON_PARITY. No Lane-2 PARITY row is promoted from this portable hardening evidence.
