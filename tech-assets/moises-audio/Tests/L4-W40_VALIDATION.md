# L4-W40 Validation｜Physical evidence multi-run batch assembly

Status: **COMPLETE as Worker-4 NON_PARITY engineering wave**  
PARITY impact: **none**. MOI-P009/P011/P013/P016/P021 remain MISSING.

## Latest-state audit at wave start

Canonical state was re-fetched before implementation.

- Notion still defines v4 / Four Autonomous Independent Lanes / Late Integration.
- Worker 4 current bundle was W40.
- Frozen base remained `be1c84314db182d6eee5097de34e017af1a4a7de`.
- Worker branch was ahead 405 / behind 0 from the frozen base at W40 start.
- HQ had advanced to Epoch 25 and made Lane 4 W37-W38 canonical.
- Epoch 25 Lane 4 frozen implementation head: `708ee3bd756a00f7405710337bc6d7b2f6eaf42c`.
- HQ Integration Run #190 / `32862540423`: SUCCESS 310/310 after an HQ test-fixture-only correction.
- Lane 4 W39+ remained post-Epoch25; no rebase was performed.
- PARITY_MATRIX still had zero promoted current-iPhone rows.

## Problem closed by W40

W39 eliminated manual single-run evidence encoding, but HQ still needed a safe way to assemble all physical runs into the W27 parent archive and W38 extension chain.

A naive batch assembler could fail in several ways:

- enumerate transaction-control or unrelated files as evidence;
- miss or duplicate W24 runs;
- accept an unexpected run;
- reuse one W36 workload execution across multiple planned runs;
- mix W39 bundle roots or policies;
- compute W38 before fixing the exact W27 root;
- publish batch metadata while a referenced W39 run changed;
- silently overwrite a prior batch;
- delete an ambiguous interrupted stage.

W40 implements a fail-closed batch layer for those risks.

## Implementation

Added production sources:

- `AnalysisPhysicalEvidenceW39BatchLoader.swift`
- `AnalysisPhysicalEvidenceBatchModels.swift`
- `AnalysisPhysicalEvidenceBatchAssembler.swift`
- `AnalysisPhysicalEvidenceBatchValidation.swift`
- `AnalysisPhysicalEvidenceBatchStaging.swift`

Registered all sources in `Package.swift`.

### W39 publication loader

The loader never enumerates a run directory to discover evidence.

It opens only `runs/<runID>/W39_BUNDLE_MANIFEST.json`, verifies that it is a READY schema-v1 control manifest with exactly nine unique W39 roles/paths, then reads only those declared files.

Every declared artifact must preserve its path, byte length and SHA-256. The reconstructed W39 bundle root is independently validated.

Extra files in the run directory are deliberately ignored.

### Exact W24 run inventory

`performanceProfile.plannedRuns` is authoritative.

Before archive synthesis W40 requires:

- nonempty unique safe W24 run IDs;
- W27 required IDs exactly equal W24;
- W38 template required IDs exactly equal W24;
- every W39 run is present and root-valid;
- every run has a unique W36 workload execution ID.

### W27 synthesis

W40 requires exactly the eleven W27 singleton roles and stores their exact bytes under:

`batches/<publicationID>/singletons/`

It then combines them with the exact four W39-derived W27 entries for every planned run.

The full existing W27 validator is executed against the supplied W22 coverage policy, W26 selection policy, W24 performance profile and W25 workload policy. W38 construction is prohibited unless W27 returns `rootConsistentPendingHQ` with zero issues and a matching recomputed root.

### W38 synthesis

The W38 policy template intentionally has no W27 root field supplied by the caller. W40 creates the real W38 policy only after W27 passes, inserting the exact computed W27 root.

For every run it projects exactly five W35/W36/W37 roles from the already validated W39 bytes.

The canonical `validateStrict` entrypoint is then executed. W38 must be root-consistent with zero issues before the batch can exist.

### W40 batch root

The deterministic W40 root binds:

- publication ID;
- sorted run ID / W36 execution ID / W39 root tuples;
- sorted singleton role/path/SHA/length metadata;
- exact W27 root;
- exact W38 root.

### Public API hardening

During W40 review, a semantic-bypass risk was identified: if `AnalysisPhysicalEvidenceBatchAssembly` exposed a public initializer, external code could construct a superficially root-consistent value without proving that the full semantic W27/W38 validators produced it.

The assembly initializer is therefore module-internal. Production callers can obtain an assembly only through `AnalysisPhysicalEvidenceBatchAssembler.assemble`, which runs the full W27 validator and W38 strict validator before construction.

The public stager also independently checks structural inventory, manifest/policy/report relationships, entry paths, SHA formats, nonzero lengths, exact W27 11+4N and W38 5N role counts and roots.

### Publication and recovery

W40 writes only the eleven singleton bytes and W27/W38 policy/manifest/report documents into the batch directory. Referenced W39 run bytes remain in their original `runs/<runID>` directories.

Publication sequence:

1. validate prepared assembly;
2. reopen and revalidate every W39 run;
3. create deterministic hidden W40 stage;
4. write staging marker;
5. write singleton bytes and six archive documents;
6. read them back;
7. write READY marker and `W40_BATCH_MANIFEST.json`;
8. move hidden stage to `batches/<publicationID>`;
9. read batch data back;
10. reopen and revalidate every W39 run again.

Recovery rules:

- existing final batch: fail closed, never overwrite;
- exact interrupted marker: remove incomplete stage and restage;
- corrupt/missing/mismatched marker: fail ambiguous and preserve the stage;
- failure after final move: preserve the final directory for HQ inspection.

### TOCTOU limitation

The W39 directories and W40 batch directory cannot be committed as one cross-directory filesystem transaction. W40 revalidates W39 immediately before and after publication, which closes normal stale-input windows, but cannot prevent a mutation after its final check.

HQ must treat selected W39 directories as immutable and later independently reopen/recompute roots. W40 does not claim signed immutable storage.

## Durable XCTest source added

### `AnalysisPhysicalEvidenceW39BatchLoaderTests.swift`

Covers:

- loader reads only the nine declared W39 paths and ignores an extra file;
- declared artifact tamper rejection;
- stale W39 bundle-root rejection;
- traversal path rejection;
- unsafe/missing run IDs;
- repeated deterministic reads.

### `AnalysisPhysicalEvidenceBatchStagingTests.swift`

Covers:

- structurally complete W27/W38 inventory accepted by the prepared boundary;
- a forged internally root-consistent W38 manifest with one required role removed is still rejected;
- successful batch publication;
- second publication collision/no overwrite;
- exact interrupted-stage recovery;
- corrupt-marker preservation and ambiguous failure;
- W39 artifact mutation after assembly and before publication causes fail-closed rejection and no batch final directory.

## Portable validation actually observed

Worker environment:

- Swift 6.2.1
- target `x86_64-unknown-linux-gnu`

### Fresh canonical SwiftPM/XCTest

`git ls-remote` failed with:

`Could not resolve host: github.com`

Therefore a fresh full Worker-branch SwiftPM/XCTest run was **NOT_OBSERVED** and is not claimed.

### Swift source-shaped W40 transaction mirror

Compiled with `swiftc -warnings-as-errors`.

Observed PASS:

- 20,000 valid inventory/tamper iterations;
- reused execution IDs rejected;
- missing role inventory rejected;
- 120 real temporary-filesystem publication/recovery transactions;
- alternating normal publication and exact-marker recovery;
- second publication attempts rejected as collisions;
- corrupt marker rejected as ambiguous and preserved.

Observed execution:

- compile elapsed approximately 0.61 s;
- runtime elapsed approximately 7.06 s;
- runtime maximum RSS approximately 20,748 kB.

### SHA-256 W40 root mirror

A 50,000-case root mirror completed successfully.

For every case:

- run order and singleton order did not affect the canonical root;
- W36 execution-ID mutation changed the root;
- W39 bundle-root mutation changed the root;
- W27 root mutation changed the root;
- W38 root mutation changed the root.

Observed execution:

- elapsed approximately 12.113 s;
- maximum RSS approximately 110,084 kB.

An initial 200,000-case configuration exceeded the 45-second execution limit and is explicitly recorded as `TIMEOUT_NOT_COUNTED_AS_PASS`.

## Acceptance mapping

W40 goal | Result
--- | ---
Read only validated W39 declared paths | Implemented
Ignore directory-wide extra files | Implemented
Exact unique W24 inventory | Implemented
Missing/unexpected run rejection | Implemented
Reused W36 execution rejection | Implemented
W27 11 singleton + 4/run synthesis | Implemented
Full W27 semantic validation | Implemented
W38 exact W27-root anchoring | Implemented
W38 5/run strict validation | Implemented
Deterministic W40 root | Implemented
Prepared-batch structural bypass hardening | Implemented
Batch atomic staging/recovery | Implemented
Pre/post W39 revalidation | Implemented
Existing final no-overwrite | Implemented
Durable negative/recovery XCTest source | Added
Portable stress evidence | Observed, NON_PARITY
Fresh full Worker SwiftPM/XCTest | NOT_OBSERVED
Physical iPhone/APFS evidence | NOT_OBSERVED

## Remaining P021 gate

W40 is evidence plumbing, not physical-device proof.

HQ must still:

1. wire a genuine bounded Lane-2 decoder;
2. compile the selected Xcode/Apple ARM stack;
3. execute W37/W39/W40 with exact HQ inputs on physical iPhone hardware;
4. observe real RSS, physical footprint, thermal, battery, memory-pressure and cancellation behavior;
5. keep W39 inputs immutable and independently audit W27/W38/W40 roots after transfer;
6. perform repeated W24 worst-case acceptance;
7. make the final P021 PARITY judgment.

P009/P011/P013/P016 also remain MISSING until their rights-cleared/current-iPhone differential gates are satisfied.
