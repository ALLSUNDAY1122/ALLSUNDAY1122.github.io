# L1-A20 Validation — Differential Gate Resume / Reproducibility Hardening

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Make the existing L1-M04 real-separator differential gate safe to run as a long 12+12-scale live campaign that can stop and resume without silently changing the experiment.

A20 preserves the identity of the batch, each case, provider attempt history, project/reference/evaluation artifacts, reviewer assignments, acceptance thresholds and the final evidence chain. It does not provide the still-missing real Golden/provider/current-iPhone evidence itself.

## Implementation

### Durable resume ledger

`Separation/Evaluation/differential_resume.py` adds a versioned, atomic, fsync-backed resume ledger.

A batch semantic identity includes:

- batch ID and purpose;
- canonical case set, target roles and fixture manifest SHA-256;
- project/reference output locations;
- provider command template, timeout and maximum attempt policy;
- credential **environment variable names only**, never credential values;
- legal/commercial/privacy/idempotency approval IDs;
- complete acceptance policy object and SHA-256;
- A19 Golden corpus lock when supplied;
- differential gate/evaluator toolchain file SHA-256 values.

Case ordering does not change the batch identity. A semantic change to thresholds, fixture bytes, provider command, legal approval IDs, Golden lock, timeout or toolchain does change it and the old resume ledger fails closed with `L1A20_BATCH_IDENTITY_MISMATCH`.

Each case also has a deterministic `case_identity_sha256`. The raw provider idempotency key is not stored in the resume ledger; only a domain-separated SHA-256 identity is retained.

## Provider attempt crash semantics

Before a provider subprocess is invoked, the attempt is durably written as `STARTED`.

On relaunch:

- if a valid project run was produced before termination, the unfinished attempt becomes `RECOVERED_OUTPUT` and the provider is **not called again**;
- if no valid output exists, the unfinished attempt becomes `INTERRUPTED` and remains consumed in the maximum-attempt budget;
- a subsequent attempt uses the same stable M04 idempotency identity;
- attempt numbering/history never resets merely because the coordinator process restarted.

This prevents a process crash from silently creating a fresh attempt budget or losing ambiguity evidence.

## Evolving vs immutable evidence

A20 distinguishes legitimate in-progress evolution from evidence mutation.

### May evolve while the batch is incomplete

- attempt history while retrying;
- `batch-execution.json` until all project cases have succeeded;
- missing reference artifacts becoming available;
- review scores as assigned reviewers complete work;
- explicit reviewer replacement chain before final acceptance.

### Immutable once bound

- fixture manifest SHA;
- successful project run manifest;
- reference run manifest after capture;
- project/reference evaluation output;
- final successful `batch-execution.json`;
- comparison input manifest after every reference exists;
- preflight identity;
- reviewer worksheet/reveal mapping;
- base reviewer roster/base assignment semantic identity;
- finalized reviewer control files;
- acceptance evidence;
- completed evidence chain.

If an already bound artifact is deleted or its bytes change, resume fails closed rather than silently regenerating it and pretending it belongs to the original experiment.

## Reference resume

If all project separation cases finish but one or more current-iPhone reference run manifests are absent:

- state becomes `WAITING_REFERENCE`;
- successful project results and attempt history remain intact;
- the comparison manifest is not immutable-bound while it still contains expected missing-reference entries;
- when reference manifests arrive, they are validated as `MOISES_CURRENT_IPHONE / REFERENCE_APP_CURRENT_IPHONE`, bound by SHA and the gate continues.

No Moises assets are copied by the executor.

## Golden lock binding

For `PARITY_CANDIDATE`, the batch now requires `golden_corpus_lock_sha256` from the A19 intake gate.

Both runtime and `differential-batch-plan.schema.json` enforce this. The checked-in live template contains a deliberately invalid placeholder string, not a fake all-zero SHA, so it cannot accidentally be interpreted as an approved Golden corpus lock.

`REGRESSION` batches may omit the Golden lock.

No real A19 Golden lock exists yet, so no live PARITY candidate was run in A20.

## Reviewer assignment stability

A20 adds deterministic blind reviewer assignments from an opaque reviewer roster.

For each case / stem / blind system A-or-B slot:

- assignment IDs are derived from batch identity and opaque reviewer ID;
- roster ordering does not change the assignment set;
- assignments contain no revealed PROJECT/REFERENCE identity;
- an unassigned reviewer score is rejected;
- missing assigned reviews are explicitly listed.

If there are zero completed reviews, the gate still persists the full missing-assignment set and moves to `WAITING_REVIEW`; it does not exit before durable assignment evidence exists.

### Replacement reviews

Reviewer replacement is explicit, never a silent reshuffle.

`reviewer-replacements.json` identifies:

- the assignment being superseded;
- the replacement reviewer;
- a fixed reason code: `UNAVAILABLE`, `CONFLICT_OF_INTEREST`, `INVALID_REVIEW`, or `COORDINATOR_CORRECTION`.

The old assignment remains in replacement history. A review submitted against a superseded assignment is retained for audit but excluded from active acceptance calculation. A replacement reviewer who is already assigned to the same case/stem/blind slot is rejected.

The base roster and base assignment identity freeze after first binding; replacements and scores may evolve only while the batch is incomplete.

## Acceptance threshold audit trail

The full acceptance policy, not only `policy_id`, is part of `batch_identity_sha256` and is separately recorded as `acceptance_policy_sha256`.

Therefore changing any threshold mid-campaign requires a new semantic batch rather than rewriting the historical experiment.

`acceptance.json` additionally includes A20 reproducibility references, and `reproducibility-audit.json` records:

- batch identity;
- exact acceptance policy and policy hash;
- Golden lock;
- toolchain file hashes;
- reviewer evidence hashes;
- acceptance checks/result;
- final evidence-chain hash.

The reproducibility audit itself is outside the evidence chain so the chain has no circular self-hash dependency.

## Evidence schema versioning

A20 keeps the legacy M04 plan schema at `schema_version = 1` for compatibility and introduces separately versioned A20 evidence contracts:

- `Separation/Evaluation/schemas/differential-resume-ledger.schema.json`
- `Separation/Evaluation/schemas/differential-reproducibility-audit.schema.json`

The live batch-plan schema was extended with the conditional A19 Golden-lock requirement while keeping the existing plan version.

## Machine verification

Executed against the final A20 implementation after the evolving-execution and zero-review fixes:

- resume / immutable-evidence / reviewer semantics: **52 assertions PASS**;
- execution/relaunch integration: **17 assertions PASS**;
- 24-case scale and semantic-mutation faults: **23 assertions PASS**;
- gate / Golden-lock / zero-review behavior: **8 assertions PASS**;
- total: **100 / 100 assertions PASS**;
- `py_compile` for final A20 implementation and tests: **PASS**.

The 24-case stress model represents the required 12+12-scale campaign size. It verifies 24 unique case identities and reviewer-assignment determinism independent of case and roster ordering.

Checked-in tests:

- `Separation/Tests/test_differential_resume.py`
- `Separation/Tests/test_differential_execute_resume.py`
- `Separation/Tests/test_differential_resume_faults.py`
- `Separation/Tests/test_differential_gate_a20_import.py`

Machine-readable matrix:

`Processing/Tests/L1-A20_DIFFERENTIAL_RESUME_MATRIX.json`

## Remaining live inputs

A20 finishes the autonomous engineering preparation for the Lane 1 differential campaign, but the following remain external/HQ live gates:

- production separator credential and written commercial/privacy route approval;
- real rights-cleared A19 G1/G2 corpus and approved Golden coverage policy/lock;
- real project separator outputs;
- current-iPhone Moises reference outputs;
- blind human reviewers and completed listening evidence;
- actual provider cost/retention/cancel/rate-limit evidence;
- integrated iPhone long-track/background/relaunch/storage/thermal evidence.

Absence of these inputs is not a Worker `BLOCKED_HUMAN` condition after non-Golden engineering acceptance. The lane should be handed to HQ as a coherent checkpoint with live gates pending.

## Lane Engineering Gate A status

A05 through A20 are now complete. The Lane 1 autonomous engineering roadmap has implemented the provider route, profiles/capabilities, lifecycle/idempotency/cancel semantics, artifact validation/atomicity, retention/privacy/cost guards, long-track streaming/storage preflight, reconnect registry, fault normalization, observability, Golden intake and reproducible resumable differential gate.

The appropriate post-A20 state is therefore `CHECKPOINT_READY`, not PARITY and not human-blocked.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

`MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021` and `MOI-P024` remain `MISSING` until the external/live/integrated evidence is actually collected and HQ changes `PARITY_MATRIX.json`.
