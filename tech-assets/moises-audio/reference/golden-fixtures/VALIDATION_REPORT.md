# MOI-QA-001｜Validation Report

Validated: 2026-08-22 11:59 JST  
Attempt: `task/MOI-QA-001/attempt-1`

## Acceptance checks

### 1. Copyright-safe differential-test fixture strategy
PASS.

Evidence:
- `GOLDEN_FIXTURE_STRATEGY.md`
- `LICENSE_AUDIT.md`

The strategy separates project-owned real multitracks, rights-cleared real reference tracks, non-commercial public research datasets, licensed synthetic material, and generated unit-test signals.

Synthetic-only and non-commercial-public-dataset-only PARITY are explicitly forbidden.

### 2. Multi-genre and hard-case matrix
PASS.

Evidence:
- `HARD_CASE_MATRIX.json`

Coverage includes 10 style/production buckets, 24 named hard cases, and mandatory 5/15/30/60 minute performance scenarios.

### 3. Objective metrics + listening / UX rubric
PASS.

Evidence:
- `LISTENING_UX_RUBRIC.md`
- `QA_GATE_SPEC.json`

The gate requires per-stem objective metrics where clean sources exist, blind A/B listening for real reference-comparable material, operation/time-to-state UX comparison, long-track performance, and failure/recovery scenarios.

### 4. Synthetic-only PASS impossible
PASS by contract.

`QA_GATE_SPEC.json` requires `PROJECT_OWNED_REAL_MULTITRACK` and `RIGHTS_CLEARED_REAL_REFERENCE` classes and sets both `synthetic_only_pass_forbidden` and `noncommercial_public_dataset_only_pass_forbidden` true.

### 5. Rights review
PASS for task scope.

Captured evidence:
- MUSDB18-HQ: educational-only / commercial permission required.
- MedleyDB audio: non-commercial research / CC BY-NC-SA terms.
- Slakh2100/Flakh2100: CC BY 4.0 but synthetic.
- mir_eval: MIT evaluation tooling; provides no audio rights.

No public dataset is promoted into a commercial-final-gate role without explicit rights.

## Machine / repository verification

GitHub compare from claim commit `77c843c0b202cfa909b7572a708f391535f1b252` to the attempt branch before this report showed:

- status: `ahead`
- ahead by: `5`
- behind by: `0`
- changed files: exactly 5
- every changed file under declared write scope `tech-assets/moises-audio/reference/golden-fixtures/**`
- no Shared/App/PARITY file modified

Remote read-back of `HARD_CASE_MATRIX.json` and `QA_GATE_SPEC.json` succeeded after creation. The JSON gate documents retain `parity_state_change=false` / `parity_state_change_from_this_task=false`.

## Self-review findings and corrections

Initial design risk: prose-only QA rules could allow later interpretation drift. Correction: added machine-readable `QA_GATE_SPEC.json` with explicit fixture classes, minimum counts, required metrics, rejection guards, long-track durations, and recovery scenarios.

Initial licensing risk: code license could be confused with dataset/audio rights. Correction: `LICENSE_AUDIT.md` explicitly separates MedleyDB software licensing from MedleyDB audio terms and treats public dataset audio as its own rights boundary.

## Known remaining work

This Task designs QA; it does not create the actual rights-cleared G1/G2 audio corpus and does not execute reference-vs-project A/B tests.

Required later work:
- obtain/record at least 12 G1 project-owned real full songs;
- obtain at least 12 G2 rights-cleared tracks permitted for submission to both systems;
- create immutable provenance/hashes;
- run real separation/analysis/performance/recovery benchmarks;
- perform blinded human listening Human Gate;
- let HQ make PARITY decisions from the resulting evidence.

## PARITY effect

None from this Task alone.

Rows informed: `MOI-P003`, `MOI-P009`, `MOI-P011`, `MOI-P013`, `MOI-P014`, `MOI-P021`, `MOI-P022`.

All remain `MISSING` until actual implementation and real-fixture evidence are produced and HQ evaluates them.
