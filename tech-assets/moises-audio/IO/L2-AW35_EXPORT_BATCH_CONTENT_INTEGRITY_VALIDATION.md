# L2-AW35 Export Batch Content Integrity Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW07/AW17/AW19 made export publication/registration crash-safe, but the published bytes themselves had no durable post-publication fingerprint. A regular non-empty file could therefore be replaced or modified between encoding/publication and Library registration without the lifecycle handoff detecting content drift.

AW35 adds a durable batch integrity manifest to canonical `IOExportBatchTransaction`, verifies it after atomic publication, and makes `Lane2ExportRegistrationJournal.prepare(...)` verify any AW35+ manifest before it persists a Library registration intent or clears the pre-registration marker.

## Fresh canonical state

At finalization/re-read:

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`; v4 autonomous lanes unchanged.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `08b53b6a36b8e36b547f09ad02d45bdbdc5dfdc4`, integration epoch 23, assignment epoch 2.
- Prior Worker status blob: `e4fba1e9c01bde9177bb6cda89c8e060be4e2d70` from AW34 status commit `67849000294db33ed976abeea2edd6d372548d99`.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`; Lane-2 rows remain MISSING.

## Production behavior

### Durable manifest before publication

`IOExportBatchTransaction.commit(...)` now fingerprints every staged output before the atomic directory rename and writes:

`.lane2-batch-integrity-v1.json`

inside the staging batch. Each manifest entry binds:

- exact leaf filename;
- byte count;
- deterministic streamed content digest.

The manifest is atomically written and synchronized before the pre-registration marker and batch-directory move. The existing marker remains synchronized before publication.

### Publication read-back

Immediately after the same-volume directory move, `verifyPublishedBatch(batchID:)` reloads the manifest from the published directory and verifies:

- manifest schema and batch identity;
- non-empty manifest;
- safe unique leaf filenames;
- regular non-symlink output files;
- current byte count and content digest;
- no unexpected extra files other than the two known hidden metadata files.

If post-rename verification fails during `commit`, the newly published directory is removed and the commit fails instead of returning artifacts that were not read-back verified.

### Library registration gate

`Lane2ExportRegistrationJournal.prepare(...)` validates an AW35+ published batch before persisting the durable Library intent and before clearing `.lane2-registration-pending`.

If a published output was changed after IO publication, Library registration intent creation fails with `publicationIntegrityFailed`, and the pre-registration marker remains available for recovery/quarantine.

Pre-AW35 batches without an integrity manifest retain the historical compatibility registration path. AW35 does not strand already-published legacy user exports during upgrade.

## Negative / recovery coverage

Prepared regressions cover:

1. normal two-file publication writes a manifest and verifies;
2. byte-count-changing mutation is rejected;
3. same namespace with an unexpected extra file is rejected;
4. symlink replacement is rejected;
5. Library registration validates integrity before marker clear;
6. a tampered AW35 batch neither clears the marker nor persists a registration intent;
7. a pre-AW35 batch without a manifest retains compatibility registration.

## Portable validation

Swift environment: Swift 6.2.1 Linux.

Exact committed self-check source blob:

`0c8a69a4bee597d29db5aaa605c1eaf4d7fb1e3d`

Compiled with:

`swiftc -parse-as-library -warnings-as-errors -strict-concurrency=complete`

Result:

`L2_AW35_SELF_TEST_PASS scenarios=4 size_change_rejected=true same_size_mutation_rejected=true symlink_rejected=true chunk_bytes=1048576`

The self-check reproduces the production streamed digest constants/chunking and confirms unchanged round-trip, appended-byte drift, same-size byte replacement drift, and symlink rejection. It is portable algorithm/filesystem evidence, not an Apple/iPhone export-quality or performance result.

Production/source static audit:

`L2_AW35_STATIC_AUDIT_PASS checks=18/18`

Checks covered manifest-before-marker ordering, atomic manifest write, manifest synchronization, marker synchronization, rename-after-manifest, post-rename read-back, published-directory removal on commit verification failure, schema/batch identity, duplicate/safe filenames, byte count, streamed digest, non-symlink regular files, unexpected-file rejection, registration verification before intent persistence, marker retention on integrity failure, and explicit pre-AW35 compatibility.

## Exact production/test blobs

- `IOExportBatchTransaction.swift`: `dcd98d66f36a0076711b33e0d72b231375a7880b`
- `Lane2ExportRegistrationJournal.swift`: `5dea18088eb42725a26130dc71fc0d7c1377fead`
- `IOExportBatchIntegrityTests.swift`: `29c8b27b6df5b67d268973a01e9e861e8cdacc10`
- `ExportBatchIntegrityRegistrationTests.swift`: `edf4dea9bc71934aa5d91632e3320c78406e38db`
- `L2AW35ExportBatchIntegritySelfCheck.swift`: `0c8a69a4bee597d29db5aaa605c1eaf4d7fb1e3d`

## Commit ledger before Evidence

Base AW34 status: `67849000294db33ed976abeea2edd6d372548d99`

1. `d467d420d962557353f9d61ef77d59c1d66468b1` — durable export batch integrity manifest
2. `1cb6c5cbb0213b715003152f3b05a19aa8063149` — verify export batch before Library registration
3. `ed5cf8e759e5166e09b90041f78716a03b06fe93` — IO integrity regressions
4. `b6a66337d094308fa042167231a3c3790925541d` — registration integrity regressions
5. `c16a7f56f48e58b6fa38fd518c5a381e47229043` — registration test correction
6. `3f5d5ed9a9561a5a6c56ed4564b1fad95f09a84f` — exact-algorithm portable self-check

AW34-status -> pre-Evidence compare: six commits, five changed files, all within `tech-assets/moises-audio/IO/**` or `tech-assets/moises-audio/Library/**`; no Shared/App/PARITY/other-lane implementation path changed.

## Important limitations / next correctness gap

AW35 closes integrity drift from staged encoding through publication read-back and the initial Library-intent handoff. It does **not** claim a cryptographic adversarial integrity boundary: the current deterministic digest is intended for corruption/mutation detection in app-owned storage, not authenticity against an attacker who can rewrite both media and manifest.

There is also a remaining narrow lifecycle TOCTOU after `Lane2ExportRegistrationJournal.prepare(...)` returns: bytes could change after the pre-registration verification and before `metadata.recordExports(...)`, or after metadata commit but before intent retirement. Existing relaunch `alreadyRegistered` recovery currently checks `requireReady` (regular/non-empty) rather than the AW35 manifest again. The next Lane-2 wave should revalidate AW35 integrity at metadata commit/intent-retirement and relaunch already-registered recovery boundaries, preserving the intent and failing closed rather than silently retiring it when bytes drift.

Real AVFoundation exports, actual iPhone filesystem/APFS force termination, storage pressure, share destination behavior, codec fixtures and integrated end-to-end export remain HQ/Apple gated.

## PARITY

No PARITY row is promoted from AW35. MOI-P019 and the other Lane-2 rows remain MISSING until actual Apple export/share, synchronization/validity, real-device interruption and differential gates are completed.
