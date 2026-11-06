# L1-M04 — Real separator differential gate runbook

Bundle: `L1-M04`  
Lane: `LANE-1-SEPARATION-PROCESSING`  
Assignment epoch: `2`  
Frozen Shared/App contract: `17d129c9f0faaf7f24a96439cf3aa3cd0e7c02e8`  
Evidence state: **NON_PARITY_EVIDENCE_ONLY**

This runbook is intentionally executable only after the external legal, credential, real-audio and reference inputs exist. It does not substitute synthetic fixtures or pre-generated samples for real separation quality evidence.

## Required external inputs

Before running a `PARITY_CANDIDATE` batch, all of the following must exist:

1. Approved production separator commercial terms record ID.
2. Approved privacy / user-audio retention and deletion record ID.
3. Reference-comparison rights record ID.
4. Provider stable-idempotency contract/evidence record ID.
5. Production credential environment variables named by the batch plan. Credential values must never be committed.
6. Rights-cleared G1/G2 real-audio fixture manifests and local audio files accepted by the L1-M01 rights gate.
7. A live provider driver command that writes the project run manifest at `{project_run}` and accepts the stable `{idempotency_key}`.
8. Current-iPhone Moises reference run manifests and local reference stem artifacts for each case. Reference assets are captured externally; this executor does not copy or scrape Moises assets.
9. Completed blind-review scores after the executor generates the worksheet/reveal mapping.

## Canonical batch template

Copy and edit:

`Separation/Evaluation/examples/differential-batch-plan.template.json`

The template currently contains eight representative cases across multiple genres, short/medium/long durations, 4-stem and 2-stem targets. For `PARITY_CANDIDATE`, code-enforced floors cannot be weakened by editing the plan:

- at least 6 real cases;
- at least 3 genres;
- short + medium + long coverage;
- at least one `vocals/drums/bass/other` core 4-stem case;
- stable provider idempotency with `{idempotency_key}` passed to the driver;
- production credential variables present;
- current-iPhone Moises identity for the reference system.

These are minimum floors, not evidence that six tracks alone are sufficient for final product PARITY. HQ may require broader coverage.

## One canonical command

From `tech-assets/moises-audio` or any working directory, provide an absolute/appropriate root and run:

```bash
python3 Separation/Evaluation/differential_gate.py run \
  --plan Separation/Evaluation/examples/differential-batch-plan.live.json \
  --root /ABSOLUTE/PATH/TO/RIGHTS_CLEARED_GATE_ROOT \
  --output-dir /ABSOLUTE/PATH/TO/RIGHTS_CLEARED_GATE_ROOT/evidence/l1-m04 \
  --evaluator Separation/Evaluation/cli.py
```

Use the **same command** throughout the gate. It is restartable/idempotent at the orchestration level: existing valid project run manifests are reused, and retry attempts use the same case-scoped stable idempotency key.

## Phase A — Preflight and project batch

The command first validates the batch plan and every fixture through the L1-M01 rights-aware evaluator. It fails before provider execution when required legal identifiers, production credentials, real-audio rights, target coverage, stable idempotency, safe paths or evaluator inputs are missing.

For each case the live provider driver receives:

- fixture path;
- project run-manifest destination;
- target roles;
- deterministic case-scoped stable idempotency key;
- gate root as configured by the driver template.

The executor captures only safe orchestration facts in `batch-execution.json`: attempt number, wall time, exit code, stable error code and idempotency key. It does **not** persist provider stdout/stderr, avoiding accidental credential or user-content leakage through logs.

Each successful project run is validated using the existing L1-M01 evaluator. A run that identifies itself as the reference system is rejected.

## Phase B — Reference comparison input

After project execution, the executor writes:

`comparison-input-manifest.json`

This records fixture/project/reference manifest paths plus SHA-256 bindings. `reference_assets_copied_by_executor` is always false.

If any current-iPhone reference manifest is absent, the command exits with external-input-required status. Capture the equivalent reference result on the current iPhone under the approved rights procedure, place the reference manifest and local comparison artifacts at the paths declared by the plan, then rerun the **same command**.

Reference manifests must identify exactly:

- `provider_id = MOISES_CURRENT_IPHONE`
- `provider_kind = REFERENCE_APP_CURRENT_IPHONE`

Project and reference identities are never interchangeable.

## Phase C — Objective and blind differential evidence

Once both systems have valid manifests, the executor runs the L1-M01 objective evaluator for PROJECT and REFERENCE runs. G1 fixtures with project-owned reference stems produce SI-SDR/reconstruction metrics; G2 fixtures contribute rights-cleared real-audio listening evidence without pretending objective ground truth exists.

The executor then creates:

- `reviewer-worksheet.template.json` — blind A/B score slots;
- `reviewer-reveal-map.private.json` — coordinator-only A/B-to-system mapping and local artifact locators;
- `reviewer-scores.json` — initially empty if no completed reviews exist.

Blind comparison requires **existing local artifacts inside the gate root** for both PROJECT and REFERENCE. Remote-only or missing URLs/files cannot become listening evidence.

Reviewers score the fixed dimensions 0..4 without reading the private reveal map:

- target preservation;
- bleed;
- musical noise;
- transient integrity;
- timbre/formant integrity;
- stereo/phase integrity;
- low-frequency integrity;
- reverb/ambience;
- overall practice usability.

Populate `reviewer-scores.json` according to `reviewer-scores.schema.json`, then rerun the same command.

## Phase D — Acceptance calculation

`acceptance.json` combines:

- project case failure rate;
- retry fraction;
- project/reference mean wall-time ratio;
- objective SI-SDR delta where real reference stems exist;
- objective-case coverage;
- mean blind-listening delta;
- worst per-role overall-practice-usability delta;
- project cost per audio minute when a cost ceiling is configured;
- reviewer coverage.

A successful lane result is named `LANE_GATE_CANDIDATE_PASS`, never `PARITY`. The file always carries `parity_state = NON_PARITY_EVIDENCE_ONLY` because final integrated iPhone/product differential and PARITY_MATRIX judgment remain HQ-owned.

## Expected evidence files

Under the output directory:

- `preflight.json`
- `batch-execution.json`
- `comparison-input-manifest.json`
- `evaluations/<case>.project.json`
- `evaluations/<case>.reference.json`
- `reviewer-worksheet.template.json`
- `reviewer-reveal-map.private.json`
- `reviewer-scores.json`
- `acceptance.json`

The project and reference run manifests/artifacts remain at the paths declared by the batch plan.

## Fail-closed conditions

The command must not be bypassed when it reports any of the following classes of failure:

- missing/invalid commercial, privacy, reference-rights or idempotency approval identifiers;
- missing production credentials;
- synthetic/non-real fixture for a PARITY candidate;
- unverified rights or missing reference-service-submission permission;
- inadequate case/genre/duration/target coverage;
- provider retry without stable idempotency;
- provider command that does not receive `{idempotency_key}`;
- project run failure or invalid run manifest;
- missing current-iPhone reference capture;
- incorrect project/reference system identity;
- remote-only or absent comparison artifacts;
- missing/invalid blind reviewer scores or inadequate reviewer coverage;
- acceptance threshold failure.

Do not convert an external-input-required exit or candidate failure into PASS manually.

## Security / copyright boundary

- Never commit API keys or provider secrets.
- Do not persist provider stdout/stderr as durable evidence unless a separately reviewed redaction mechanism is added.
- Do not copy Moises application assets, binaries, UI, model data or protected reference media into this repository.
- Reference audio remains externally captured under approved rights and is referenced by manifest path/hash only.
- Do not label generated/synthetic mechanics fixtures as quality evidence.

## Handoff to HQ

When a real batch reaches `LANE_GATE_CANDIDATE_PASS`, give HQ the complete evidence directory plus exact batch-plan SHA and branch/checkpoint SHA. HQ still owns:

1. four-lane semantic integration;
2. integrated iOS compile;
3. physical-device and long-track verification;
4. broader cross-feature regression;
5. current-iPhone product differential review;
6. final PARITY_MATRIX state changes.
