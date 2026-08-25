# L4-W46｜Real-audio Analysis parity adjudication runbook

## Purpose

W46 is the fail-closed HQ readiness gate for these four current-iPhone Analysis rows:

- `MOI-P009` — BPM detection
- `MOI-P011` — AI key detection
- `MOI-P013` — chord detection
- `MOI-P016` — song parts / section detection

W46 never edits `PARITY_MATRIX.json` and never returns `PARITY`.

The strongest positive W46 result is only:

`READY_FOR_HQ_ANALYSIS_PARITY_JUDGMENT`

HQ retains final row-by-row PARITY authority.

## Production entry point

Use `AnalysisRealAudioParityCanonicalAdjudicator.adjudicate(...)` with the exact retained manifest bytes.

The byte gate:

1. decodes the manifest;
2. re-encodes it using `AnalysisRealAudioBenchmarkCodec`;
3. requires byte-for-byte canonical equality;
4. computes SHA-256 from those exact bytes;
5. requires the digest to equal the independent HQ binding;
6. only then enters W46 semantic adjudication.

Do not derive the expected manifest digest from an untrusted decoded manifest at the destination.

## Independent HQ binding

`AnalysisAnalysisParityEvidenceBinding` pins the exact evidence package and selected environments:

- rights approval reference;
- manifest ID/SHA;
- W22 coverage-policy ID/root;
- W19 capture-set ID/root;
- W19 capture-policy ID/root;
- W21 review-set ID/root;
- W21 review-policy ID/root;
- W18 differential-tolerance-profile ID/root;
- Project audited-report root;
- Project engine/version;
- selected Project `iphoneos / arm64` source/build/device/session metadata;
- current-iPhone Reference engine;
- Moises product/app/build/device/OS/locale/tier;
- minimum current-reference epoch;
- minimum repeat captures;
- minimum independent reviewers.

The binding is metadata unless HQ externally signs, trusted-timestamps or attests it. W46 does not mislabel SHA commitments as device attestation.

## Rights gate

Every manifest case must be real audio and must have a nonexpired rights grant that explicitly permits all three uses:

- `ANALYSIS_BENCHMARK`
- `INTERNAL_QUALITY_REVIEW`
- `DIFFERENTIAL_REFERENCE`

Synthetic fixtures cannot satisfy W46 regardless of metric quality.

The manifest root pins the exact fixture/grant/source-SHA inventory. HQ must separately retain the underlying grant evidence.

## W22 coverage gate

W46 recomputes `AnalysisCorpusCoverageValidator.validate(...)`.

The complete manifest fixture set must equal the W22 eligible fixture set. No ineligible fixture may be silently dropped.

All HQ domain minimums and semantic strata must pass. This is where the corpus must prove, as applicable:

- multi-genre tempo coverage and octave-sensitive BPM ranges;
- major/minor/modal key coverage;
- chord qualities, inversions, no-chord regions and label diversity;
- varied section counts, repeated labels and structural/functional patterns.

A favorable subset is not accepted.

## W19-W21 current-iPhone Reference gate

W46 does not trust a saved Reference score table by itself. It reruns:

`AnalysisReferenceReviewConsensusEngine.validateAndCompileReference(...)`

This requires:

- the exact selected current Moises app/build/iPhone/OS/locale/tier;
- capture timestamps not older than the HQ reference epoch;
- repeated reference captures;
- artifact-backed observations;
- independent reviewer identities;
- reviewers distinct from the capture operator when policy requires it;
- field-local evidence anchors;
- consensus on BPM/key/chord/section values and boundaries;
- raw metric derivation from reviewed observations;
- stable repeated capture validation.

Unsupported or unscorable current-iPhone observations do not become quality scores.

## Project report gate

The Project audited report must:

- use the exact same manifest;
- use the HQ-bound Project engine/version;
- be parity-eligible;
- contain no validation issues;
- contain no evaluator-rejected rows;
- contain no non-parity rows.

The external HQ binding must identify a selected `iphoneos / arm64` Project source/build/device/session. This is provenance metadata, not cryptographic physical-device proof.

## W18 paired differential gate

W46 recomputes `AnalysisPairedDifferentialComparator.compare(...)` from the Project audited report and the W19-W21 reviewed Reference.

Required status:

`WITHIN_SUPPLIED_TOLERANCE_PENDING_HQ`

Additionally:

- comparison complete;
- same corpus complete;
- metric pairing complete;
- every pair parity-candidate evidence;
- every pair inside the HQ-supplied tolerance;
- zero differential issues.

W46 does not accept a good corpus mean that hides a bad fixture.

## Feature-row anti-masking gates

For every manifest fixture whose ground-truth annotation covers the feature domain, every listed metric below must appear exactly once.

### MOI-P009 — BPM

Required paired metrics:

- `decision_emitted`
- `exact_within_4pct`
- `octave_aware_within_4pct`
- `tempo_rel_error`

This preserves both exact BPM and octave-aware diagnostics while preventing no-decision cases from being hidden.

### MOI-P011 — AI key

Required paired metrics:

- `decision_emitted`
- `exact_key_accuracy`
- `tonic_accuracy`
- `mode_accuracy`
- `weighted_key_score`

Modal/major/minor breadth is supplied by the W22 corpus policy.

### MOI-P013 — chords

Required paired metrics:

- `root_weighted_accuracy`
- `majmin_weighted_accuracy`
- `no_chord_precision`
- `no_chord_recall`
- `coverage`

Inversion/complex-quality breadth is supplied by W22 strata and the current Reference annotation.

### MOI-P016 — song parts / sections

Required paired metrics:

- `boundary_f_0_5s`
- `boundary_f_3_0s`
- `pairwise_f`
- `adjusted_rand_index`
- `structural_coverage`

Varied structures and repeated labels are supplied by W22 strata.

## Per-row result

Each row independently emits either:

- `READY_FOR_HQ_ROW_JUDGMENT`
- `NOT_READY_FOR_HQ_ROW_JUDGMENT`

One missing metric, duplicated pair, outside-tolerance fixture or non-parity-candidate pair makes that row NOT_READY.

The final report records expected/observed pair counts and the worst regression fixture for each row.

## Persisted report verification

After storing or transferring W46 output, call:

`AnalysisAnalysisParityAdjudicationReportValidator.validate(...)`

The validator requires exactly P009/P011/P013/P016, consistent pair counts, deterministic roots and valid READY/NOT_READY semantics.

A global rights/root/reference/device-binding failure may legitimately make the overall report NOT_READY while the four feature metric rows individually remain READY. Global issues remain authoritative in that case.

A forged overall READY cannot omit current-reference/differential roots or feature-level pair evidence even if its report root is recomputed.

## Current project state

Until HQ supplies the rights-cleared real corpus, current-iPhone reviewed Reference evidence and selected physical Project differential package, W46 must remain:

`NOT_READY_FOR_HQ_ANALYSIS_PARITY_JUDGMENT`

Portable Swift mirrors and synthetic XCTest fixtures only validate the gate implementation. They cannot satisfy any PARITY row.
