# L2-AW40｜Segmented Managed-Artifact Runtime Router Validation

Result: `COMPLETED_NON_PARITY`

## Goal

Convert the AW39 segmented migration substrate into a steady-state runtime surface that can be wired into AW29 canonical registration/removal/orphan traversal without reintroducing unbounded legacy-shard writes.

## Implementation

Added `Lane2ManagedArtifactSegmentedRuntime`.

Authority rule:

1. A valid committed segmented manifest wins over retained legacy v1 bytes.
2. Without a committed manifest, legacy v1 remains the compatibility authority.
3. The first successful `upsertManaged` / `removeManaged` mutation publishes a verified segmented generation.
4. Legacy bytes are intentionally preserved as pre-commit rollback evidence.
5. Empty post-delete shards publish a zero-entry committed manifest so stale legacy bytes cannot become authoritative again.

Write protocol:

- normalize and validate managed paths;
- load current committed/legacy authority;
- write max-512-entry segment files;
- read every new segment back;
- atomically write/replace the small committed manifest only after full verification;
- read committed generation back after publication.

Corrupt manifests/segments, symlinks, invalid paths and oversized legacy JSON fail closed.

`prepareOrphanCandidateSlice` exposes the existing AW29 slice/traversal contract and reads committed data in max-512-entry segment decodes. Legacy fallback is capped at AW38's 8 MiB ceiling.

## Portable verification

Swift 6.2.1, `-warnings-as-errors -strict-concurrency=complete`:

`L2_AW40_RUNTIME_TYPECHECK_PASS`

Executable mutation/recovery self-check:

`L2_AW40_SELF_TEST_PASS legacy_to_segmented=true legacy_preserved=true zero_manifest=true corrupt_manifest=true`

Regression coverage added for:

- legacy mutation -> segmented authority activation;
- retained legacy rollback bytes;
- segmented read-back;
- deleting the final entry without stale legacy reactivation;
- corrupt committed manifest fail-closed behavior.

## Scope / non-claims

This Wave adds the steady-state runtime router but deliberately does **not** yet replace every canonical `Lane2ManagedArtifactInventory` call site. Directly changing all AW29 call sites in the same Wave would increase migration blast radius before the router had independent recovery evidence.

Therefore this Wave does not claim:

- full canonical AW29 runtime activation;
- physical-iPhone RSS/latency evidence;
- APFS/ENOSPC/force-termination validation;
- MOI-P017/P024 or any other PARITY promotion.

Next priority is to wire canonical `registerIfManaged/registerManaged/remove/prepareOrphanCandidateSlice` paths to this router while preserving legacy fallback and existing cursor semantics, then run compatibility regression.
