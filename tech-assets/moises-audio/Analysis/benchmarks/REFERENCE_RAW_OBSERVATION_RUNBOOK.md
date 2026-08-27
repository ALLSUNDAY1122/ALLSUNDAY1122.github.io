# Current-iPhone Moises Raw Analysis Observation Runbook

Purpose: remove trust in manually calculated or transcribed current-iPhone Moises quality metrics. W20 requires the Reference side to preserve raw Moises observations and deterministically re-score them against the same Golden annotations used by the Project benchmark.

W20 does not perform the HQ-owned Moises capture, does not invent missing observations, does not select quality tolerances, and does not declare PARITY.

## W21 prerequisite for future human-transcribed Reference evidence

W20 predates the W21 independent-review layer. For future HQ current-iPhone evidence, a human-transcribed raw set must not be admitted directly to W20.

Use `AnalysisReferenceReviewConsensusEngine.validateAndCompileReference(...)` as the admission facade. W21 binds every raw claim to artifact-local anchors, requires independent reviewers and resolves only externally toleranced/exact agreement. Only its deterministic consensus raw set is passed into W20.

Direct W20 APIs remain valid for unit, compatibility and non-human/instrumented paths, but bypassing W21 is not acceptable for future human-transcribed current-iPhone Moises Reference evidence. See `REFERENCE_REVIEW_CONSENSUS_RUNBOOK.md`.

## Required inputs

1. The exact rights-cleared `AnalysisRealAudioBenchmarkManifest` used for Project scoring.
2. SHA-256 of the exact manifest bytes, already bound by the W19 HQ capture policy.
3. The W19 capture set containing run/build/device/artifact provenance and declared metric rows.
4. `AnalysisReferenceRawObservationSet`, bound to the same capture-set ID and exact manifest ID/SHA. For human transcription this must be the W21 consensus output.
5. The W19 HQ capture policy.

Start raw capture JSON from `REFERENCE_RAW_OBSERVATION_SET_TEMPLATE.json`. The empty template is intentionally invalid until real observations are added.

## Raw observation identity

Every raw observation is identified by:

`run_id + fixture_id + domain`

The set must match the W19 declared row set exactly. Missing rows, extra rows and duplicates fail closed.

Each observation must reference evidence artifact IDs already bound to the same W19 row. Raw data cannot be detached from its screen recording/export/instrumented artifact and later reused under another run.

## Observation status

`OBSERVED`
: the domain output was actually visible/measurable and the typed raw payload is present.

`NO_DECISION`
: Moises genuinely emitted no decision/detection. This is a scoreable product behavior, not a capture failure. Tempo/key become `decision_emitted=0`; beat/chord/structure are scored as empty estimates.

`UNSUPPORTED`
: the current Reference build does not expose a scoreable representation for this observation. This remains an explicit limitation and fails this differential input closed.

`UNSCORABLE`
: the evidence exists but cannot be converted to the canonical metric semantics with adequate certainty. It also fails closed.

Never convert `UNSUPPORTED` or `UNSCORABLE` to zero-quality metrics. That would fabricate a numeric Reference result.

## Domain payloads

Tempo:
- raw displayed BPM only.
- canonical metrics are recomputed: decision rate, relative error, exact-within-4%, octave-aware-within-4%.

Beat:
- raw beat timestamps.
- W16 cardinality policy is enforced before scoring.
- `beat_f_70ms` and median absolute timing error are recomputed with the canonical timeline matcher.

Key:
- raw tonic pitch class and mode.
- exact tonic/mode and weighted-key score are recomputed.

Chord:
- raw timestamped normalized chord labels.
- invalid/overlapping/out-of-range events are rejected before evaluator normalization can hide them.
- root, maj/min, no-chord, coverage and boundary timing metrics are recomputed by `AnalysisBenchmarkRunner.chordMetrics` and filtered through the W17 quality registry.
- vocabulary limitations remain explicit in the raw observation `limitations` field; do not silently map an unverified Reference label to a different chord class.

Structure:
- raw timestamped structural labels plus functional label when observable.
- invalid/overlapping/out-of-range sections are rejected.
- section boundary, pairwise, ARI, entropy, structural coverage and functional metrics are recomputed by `SectionBenchmarkEvaluator` using the same configuration as Project evidence.

## Declared metric integrity gate

W19 capture rows may contain operator-entered `qualityMetrics`, but W20 no longer treats those values as authoritative.

For every row W20 computes the canonical metric dictionary from raw data and requires:

- exact metric-key-set equality; and
- numeric identity within a fixed `1e-9` relative calculation tolerance.

This tolerance only absorbs deterministic floating-point serialization noise. It is not a product-quality or non-inferiority margin.

A missing `decision_emitted`, an added favorable metric, or any changed value produces `DERIVED_METRIC_SET_MISMATCH` / `DERIVED_METRIC_VALUE_MISMATCH`.

## W19 handoff

For direct non-human/instrumented use, call:

```swift
let derivation = AnalysisReferenceRawObservationDeriver.derive(
    rawSet: rawSet,
    captureSet: captureSet,
    policy: approvedCapturePolicy,
    manifest: goldenManifest,
    manifestSHA256: exactManifestSHA256
)
```

Only `DERIVED_REFERENCE_PENDING_W19` produces a `derivedCaptureSet`.

The derived capture set keeps W19 run/environment/artifact/row metadata but replaces operator-entered quality metrics with deterministic raw-derived values.

For human-reviewed current-iPhone evidence, the complete chain is:

1. W21 independent artifact-anchored review consensus.
2. W20 raw/declared derivation integrity gate.
3. W19 repeated-capture provenance/repeatability gate on the **derived** metrics.
4. W19 audited current-iPhone Moises Reference compilation.
5. W18 paired Project-vs-Reference comparison.
6. HQ final PARITY judgment.

Archive the W21 review set/report, consensus raw set, original W19 capture set, W20 derivation report, W19 derived validation report, audited Reference report, exact Golden manifest bytes/hash, HQ policies, and all evidence artifacts together.

## NON-PARITY notice

W20 templates/unit/portable tests contain no real current-iPhone Moises observations. Passing W20 proves only that raw Reference observations can be deterministically and audibly traceably converted into canonical metrics without trusting operator math. Passing W21 adds transcription-consensus integrity, but neither establishes MOI-P009/P011/P013/P016 or final PARITY without actual rights-cleared current-iPhone evidence and HQ judgment.
