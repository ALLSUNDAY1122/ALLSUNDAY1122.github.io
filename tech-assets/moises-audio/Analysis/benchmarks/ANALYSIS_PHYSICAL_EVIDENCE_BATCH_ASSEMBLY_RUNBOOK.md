# Analysis Physical Evidence Batch Assembly Runbook — L4-W40

Status: NON_PARITY engineering procedure. This runbook does not authorize a PARITY promotion.

## Purpose

W40 assembles an exact multi-run physical evidence batch from W39-published per-run directories without manually enumerating or copying their evidence files.

The batch has four integrity layers:

1. each W39 run has its own nine-artifact bundle root;
2. W27 binds eleven singleton artifacts plus exactly four W23/W25 artifacts for every W24 planned run;
3. W38 anchors the exact W27 root and adds exactly five W35/W36/W37 artifacts for every W24 planned run;
4. W40 binds all W39 run roots plus the W27 and W38 roots into one publication root.

None of these roots is a signature, trusted timestamp, Secure Enclave proof, Apple attestation, or proof of hardware origin.

## Required inputs

Use only HQ-approved inputs for one physical evidence campaign:

- W22 coverage policy and coverage report;
- W26 selection policy and selection report;
- exact golden manifest bytes;
- W24 performance profile, performance batch and acceptance report;
- W25 workload policy;
- build corroboration;
- physical-device corroboration;
- one successfully published W39 directory for every and only every W24 planned run;
- W27 HQ policy;
- W38 chain-policy template carrying all identifiers/binding fields except the W27 root, which W40 computes.

The exact eleven W27 singleton roles are:

- GOLDEN_MANIFEST
- W22_COVERAGE_POLICY
- W22_COVERAGE_REPORT
- W26_SELECTION_POLICY
- W26_SELECTION_REPORT
- W24_PERFORMANCE_PROFILE
- W24_PERFORMANCE_BATCH
- W24_ACCEPTANCE_REPORT
- W25_WORKLOAD_POLICY
- BUILD_CORROBORATION
- DEVICE_CORROBORATION

## W39 input rule

Do not enumerate `runs/<runID>/` and do not treat every file in it as evidence.

For every planned run, W40 opens only:

`runs/<runID>/W39_BUNDLE_MANIFEST.json`

It then reads only the nine paths declared by that control manifest. Extra files are ignored. Each declared file is checked for normalized relative path, role inventory, byte length and SHA-256, and the complete W39 bundle root is recomputed.

The W39 control manifest must remain `READY_TO_PUBLISH`, must bind the exact run ID and W36 workload execution ID, and must contain exactly one of every W39 role.

## Exact run inventory

The W24 `plannedRuns` array is authoritative for batch membership.

W40 fails closed if:

- W24 contains duplicate or empty run IDs;
- W27 required run IDs do not exactly equal W24;
- W38 template required run IDs do not exactly equal W24;
- any W39 run is missing;
- any unexpected run is substituted;
- two planned runs reuse the same W36 workload execution ID.

## W27 synthesis

W40 places the eleven singleton byte sequences under:

`batches/<publicationID>/singletons/`

The four W27 per-run entries are projected directly from the exact W39 bytes:

- W23 raw performance evidence
- W23 validation report
- W25 workload receipt
- W25 workload validation report

The full W27 validator is then executed with the canonical W22/W26/W24/W25 policy objects. Root-consistent status with zero issues is mandatory before W38 is built.

## W38 synthesis

Only after W27 passes does W40 create the W38 policy, inserting the exact computed W27 root.

The five W38 roles per run are projected from the same validated W39 bytes:

- W35 runtime algorithm evidence
- W36 current runtime evidence
- W37 capture plan
- W37 execution-integrity evidence
- W37 execution-integrity report

W40 calls `AnalysisPhysicalEvidenceArchiveChainValidator.validateStrict`. This rechecks the W24 inventory, W27 root, W35/W36/W37 run/execution binding, bounded-source semantics and W36 execution reuse.

## W40 root

The W40 root deterministically binds:

- publication ID;
- sorted `(runID, workloadExecutionID, W39 bundle root)` tuples;
- sorted singleton role/path/SHA/length metadata;
- W27 root;
- W38 root.

Any change to one of these inputs changes the W40 root.

## Publication transaction

Call `AnalysisPhysicalEvidenceBatchStager.publish` only after `assemble` succeeds.

The stager:

1. structurally revalidates the prepared W27/W38 inventories and roots;
2. reopens every referenced W39 run and checks run ID, execution ID and W39 root again;
3. creates a deterministic hidden stage under `batches/`;
4. writes `W40_STAGING_MANIFEST.json`;
5. writes the eleven singleton bytes and six W27/W38 policy/manifest/report documents;
6. reads them back;
7. writes `W40_BATCH_MANIFEST.json` in READY state;
8. moves the whole hidden directory to `batches/<publicationID>`;
9. reads the batch metadata back again;
10. reopens every referenced W39 run again before returning success.

The W39 evidence bytes are referenced in place and are not recopied into the W40 batch directory.

## Recovery policy

- Existing final `batches/<publicationID>`: fail closed; never overwrite.
- Existing hidden stage with the exact W40 marker identity: remove the incomplete stage and restage from authoritative inputs.
- Missing, corrupt or mismatched marker: return an ambiguous recovery failure and preserve the stage for HQ inspection.
- Failure after the final directory move: preserve the final directory. Do not auto-delete or overwrite it.

## TOCTOU limitation

W40 checks referenced W39 runs before and after the batch directory move, but it cannot make separate pre-existing W39 run directories and the W40 directory one filesystem transaction.

Therefore HQ must treat the W39 run directories as immutable once selected. A malicious or accidental mutation after W40's final check remains detectable by a later independent re-open/root audit, but W40 alone does not provide a cross-directory lock or signed immutable storage.

## Physical P021 procedure

For real P021 evidence HQ must still:

1. use a genuine bounded Lane-2 decoder;
2. compile the selected Apple/Xcode stack;
3. execute W37 and W39 on physical iPhone hardware for every exact W24 run;
4. preserve physical RSS, physical-footprint, thermal, battery, pressure and cancellation evidence;
5. assemble W40 from those immutable W39 runs and HQ singleton bytes;
6. independently record/anchor W27, W38 and W40 roots;
7. execute repeated W24 worst-case acceptance;
8. make the final PARITY decision.

Portable tests, synthetic fixtures, valid roots and a successful W40 publication remain NON_PARITY until these gates are satisfied.
