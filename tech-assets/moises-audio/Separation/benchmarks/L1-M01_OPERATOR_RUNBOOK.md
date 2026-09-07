# L1-M01 — Rights-aware real-audio separation evaluation operator runbook

Status: executable evaluation package complete; **NON-PARITY until real external inputs exist**.

## Purpose

This package makes false quality promotion structurally difficult. It validates fixture rights before reading audio, validates provider/model/cost/timing/result evidence, computes streaming objective metrics for G1 clean references, validates blinded listening records, and always emits a single-run result as `NON_PARITY_EVIDENCE_ONLY`.

It does not provide a model, credentials, music rights, or Moises output. Those remain separate external/HQ gates.

## Required inputs

For G1 objective evaluation:
- project-owned or explicitly licensed real recorded multitrack;
- opaque `rights_record_id` linked to a signed private rights record outside the public repository;
- commercial engineering use permission;
- mixture and every requested reference stem with immutable SHA-256;
- live project separator result for every requested role;
- exact provider/model/version/topology/commercial approval basis;
- measured upload/queue/inference/download/total timing and cost basis.

For G2 differential listening:
- rights-cleared real source that may legally be submitted to both systems;
- `reference_service_submission_allowed=true`;
- blind A/B score records for PROJECT and REFERENCE on every evaluated stem.

G3/G4/G5 may be regression fixtures but are rejected for `PARITY_CANDIDATE`.

## Repository files

- `Evaluation/evaluation_core.py` — fail-closed validators and streaming PCM metrics.
- `Evaluation/cli.py` — executable CLI.
- `Evaluation/schemas/*.schema.json` — machine-readable data contracts.
- `Evaluation/examples/*.json` — templates and an explicit NON-PARITY example.
- `Tests/test_evaluation_package.py` — unit/negative suite.

## Commands

Run from `tech-assets/moises-audio/Separation/Evaluation`.

```bash
python3 cli.py validate-fixture \
  --fixture /secure/eval/G1-POP-001.json \
  --root /secure/eval \
  --purpose PARITY_CANDIDATE
```

```bash
python3 cli.py validate-run \
  --fixture /secure/eval/G1-POP-001.json \
  --run /secure/eval/RUN-G1-POP-001.json \
  --root /secure/eval
```

```bash
python3 cli.py evaluate \
  --fixture /secure/eval/G1-POP-001.json \
  --run /secure/eval/RUN-G1-POP-001.json \
  --root /secure/eval \
  --output /secure/eval/evidence/RUN-G1-POP-001.evidence.json \
  --purpose REGRESSION
```

For a fixture that is also legally allowed for reference-service submission, add `--listening /secure/eval/LISTEN-G1-POP-001.json` and use `--purpose PARITY_CANDIDATE`. A G2 fixture follows the same listening format but normally has no clean reference stems, so objective SI-SDR is not fabricated.

## Fail-closed rules

The CLI exits non-zero when any required rights field is absent/unverified, a PARITY candidate is G3/G4/G5, a G1 reference role is missing, a run result is missing/duplicated/extra, a local hash differs, an output is only a remote URL and already expired, a provider/model/version/commercial-basis field is absent, timing/cost is malformed, PCM formats are incompatible, duration alignment exceeds 20 ms, or blind score records are incomplete/invalid.

Absolute paths and `..` traversal in manifests are rejected. Signed rights documents and API credentials must not be copied into this repository.

## Objective metric behavior

The runner reads PCM WAV in chunks rather than loading a full song into RAM. It supports 8/16/24/32-bit uncompressed PCM, requires matching sample rate/channel/sample width for reference-vs-estimate metrics, computes per-stem SI-SDR and RMSE, and computes mixture reconstruction normalized RMSE from the complete requested result set. Metrics are recorded per stem; there is no aggregate that can hide the worst stem.

The evaluator does not invent a quality threshold here. Final thresholds require real G1/G2 distributions and HQ differential review. An effectively identical stream is capped at finite +120 dB so emitted JSON cannot contain Infinity/NaN.

## Blind listening capture

Use the dimensions and rejection logic in the canonical `LISTENING_UX_RUBRIC.md`. Score while identities are blind, then populate `revealed_system`. `PARITY_CANDIDATE` format validation requires both PROJECT and REFERENCE records for every requested role when differential listening is applicable.

## Evidence interpretation

Every output created by this bundle states:

`"parity_state": "NON_PARITY_EVIDENCE_ONLY"`

That is deliberate. A single rights-cleared run is evidence, not product parity. Before any separation PARITY proposal, the canonical QA strategy still requires at minimum 12 G1 full songs / 8 style buckets / 6 vocal tracks plus the G2 differential set, blind listening, performance/recovery evidence, and HQ review. Real credentials/model supply and current-iPhone integration remain separate gates.
