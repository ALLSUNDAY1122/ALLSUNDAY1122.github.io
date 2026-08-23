# L2-AW08 Library Metadata Sharding / Corruption Recovery Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Lane Plan/Resource Locks.

Goal: remove the monolithic lifecycle-sidecar rewrite bottleneck and make lifecycle metadata corruption isolatable/recoverable without deleting user audio/project content.

## Implementation

`Lane2LifecycleMetadataStore` keeps the existing public API but introduces storage revision 2:

- one ownership JSON shard per project under `.LibraryLifecycle/v2/projects/`;
- one export JSON shard per project under `.LibraryLifecycle/v2/exports/`, preserving atomic multi-artifact metadata updates for a project;
- one bounded failure-history document (`failures.json`, default maximum 64);
- one `schema.json` marker written **last** after migration completes.

Legacy `lane2-lifecycle-v1.json` migration is idempotent and crash-safe:

1. decode and validate the complete v1 document first;
2. discard only an unmarked partial v2 metadata tree;
3. atomically write deterministic project/export shards and failure history;
4. write the v2 marker last;
5. retain the original v1 source document after successful migration.

This means an interrupted migration never makes a partially written v2 tree authoritative.

## Corruption behavior

Normal reads remain fail-closed.

- malformed project/export/failure shards raise `corruptShard`;
- shard filename/record UUID mismatch is rejected;
- invalid relative paths inside a shard are treated as shard corruption;
- duplicate export IDs inside one project shard are rejected;
- malformed legacy v1 remains `corruptDocument`;
- unsupported future schema is not silently quarantined or downgraded.

Explicit recovery APIs are additive:

- `quarantineCorruptShards()` moves only malformed sidecar files to `.LibraryLifecycle/Quarantine/` and preserves their raw bytes;
- `quarantineCorruptLegacyDocument()` preserves a malformed legacy document before initializing an empty v2 sidecar so the canonical Library can later reconcile ownership metadata;
- neither recovery API removes user audio, stem, export, or Core Data store content.

Recovery is intentionally explicit rather than automatic because HQ/App owns the user-facing recovery decision.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Validation:

- strict-concurrency + warnings-as-errors typecheck for the production source: PASS;
- strict-concurrency + warnings-as-errors typecheck with committed XCTest coverage: PASS;
- executable self-check: PASS, 8 scenario groups;
- v1 -> v2 migration preserves ownership/export/failure data and legacy source: PASS;
- single-project mutation leaves unrelated project-shard bytes unchanged: PASS;
- corrupt shard fails closed, explicit quarantine preserves exact raw bytes, valid shards remain readable: PASS;
- corrupt legacy fails closed until explicit preservation, then empty v2 can be rebuilt: PASS;
- deleting export state survives reopen and cleanup converges: PASS;
- failure history remains bounded to 64 with durable ordering: PASS;
- path traversal remains rejected: PASS.

Self-check marker:

`L2_AW08_SELF_TEST_PASS scenarios=8 projects=2000 write_s=2.250490 single_update_s=0.001623 snapshot_s=0.110948`

Large-library filesystem metadata benchmark on this runner:

- create/update 2,000 project ownership shards: 2.250490 s total;
- update one project in the 2,000-project library: 0.001623 s;
- full 2,000-project snapshot read: 0.110948 s;
- unrelated shard byte-for-byte unchanged after the single-project update.

These timings are Linux filesystem metadata evidence only and are **not** iPhone performance claims.

## Why this is a product-quality improvement

The previous lifecycle sidecar rewrote one complete JSON snapshot for routine project/export changes. That makes write amplification grow with library size and turns one malformed byte into failure of the entire sidecar.

The v2 representation keeps ordinary ownership writes project-local, keeps export-batch metadata atomic at project granularity, isolates corruption, preserves raw recovery evidence, and keeps the public Lane-2 integration API stable for late integration.

## Gates intentionally still open

- Apple Core Data runtime migration/interruption suites;
- actual iPhone relaunch/interruption across Core Data + lifecycle-sidecar operations;
- APFS low-storage behavior and write-failure injection on device;
- actual Files/File Provider/share/codec execution;
- real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixture matrix;
- production WMA decoder dependency/license audit if native decode is unavailable;
- Differential Moises and final HQ PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW08. The wave materially improves MOI-P017 durability/scalability preparation and corruption recovery, but MOI-P017/MOI-P018/MOI-P019 and other Lane-2-relevant rows remain HQ-owned `MISSING` until integrated Apple/device/real-flow gates pass.
