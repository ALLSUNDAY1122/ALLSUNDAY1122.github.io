# Analysis Differential Corpus Coverage / Sufficiency Runbook

Purpose: prevent an otherwise clean W21 -> W20 -> W19 -> W18 evidence chain from using a trivial, cherry-picked, synthetic-padded, rights-ineligible, or semantically narrow Analysis corpus.

W22 does not choose the production corpus, production minimum counts/durations, current-iPhone Moises observations, or PARITY. Those remain HQ Late Integration responsibilities.

## 1. Freeze the exact benchmark manifest first

Use the same rights-cleared `AnalysisRealAudioBenchmarkManifest` that will be used for Project scoring and current-iPhone Reference capture.

Archive the exact manifest bytes and compute SHA-256 over those exact bytes. The W22 policy must bind both:

- `expectedManifestID`; and
- `expectedManifestSHA256`.

If the manifest changes, W22 must be rerun against a newly approved policy or an explicitly re-approved binding. Do not substitute an equivalent-looking reserialization without updating the hash.

## 2. HQ approves the coverage policy

Start from `ANALYSIS_CORPUS_COVERAGE_POLICY_TEMPLATE.json`.

The template is intentionally invalid. HQ must replace the placeholders and supply all numerical requirements. Worker 4 ships no production fixture-count, duration, tempo-band, genre-count, key-mode, chord-vocabulary, inversion, no-chord, or structure thresholds.

A valid policy requires:

- `authority == HQ_LATE_INTEGRATION`;
- non-empty approval reference;
- exact manifest identity/hash;
- positive global minimum unique-fixture count and total duration;
- one positive domain minimum for every Analysis domain: `tempo`, `beat`, `key`, `chord`, `structure`;
- at least one semantic stratum;
- positive fixture-count and duration requirements for every stratum.

`minimumUniqueFixtureCount >= 1` and positive durations are structural fail-closed requirements only. They are not Worker-selected production sufficiency thresholds.

## 3. Define semantic strata from Golden annotations, not manual pass labels

Each `AnalysisCorpusCoverageStratum` contains a `domain`, HQ minimum fixture count/duration, and a predicate derived from the Golden manifest annotations.

Supported predicate dimensions:

- exact genre;
- BPM lower/upper range;
- exact key mode;
- canonical chord qualities: `major`, `minor`, `dominant7`, `major7`, `minor7`, `sus2`, `sus4`, `diminished`, `augmented`;
- chord inversion present/absent;
- no-chord (`N`) present/absent;
- minimum distinct chord-label count;
- minimum section count;
- minimum distinct structural-label count;
- required functional labels such as `verse`, `chorus`, `bridge` when the Golden annotation supplies them;
- repeated structural-label presence/absence.

Predicates may combine dimensions. This allows HQ to require, for example, a key benchmark stratum containing minor-mode tracks at a particular tempo band, or a chord stratum containing inversions and no-chord regions.

Do not encode a fixture as satisfying a stratum by hand. W22 derives membership from the manifest annotations, which prevents a favorable manual tag from silently padding coverage.

## 4. Rights and real-audio eligibility are mandatory

A fixture counts toward W22 only when:

1. it passes `AnalysisRealAudioManifestValidator.isParityEligible(...)`;
2. `sourceKind == REAL_AUDIO`; and
3. its rights grant includes `DIFFERENTIAL_REFERENCE` in addition to the canonical Analysis benchmark permission.

Synthetic fixtures and fixtures without differential-reference rights do not count. W22 currently treats their presence in the approved differential manifest as an issue rather than silently excluding them, so a mixed real/synthetic manifest cannot look comparison-ready by ignoring the unwanted rows.

## 5. Run coverage validation before expensive Reference capture

```swift
let coverage = AnalysisCorpusCoverageValidator.validate(
    manifest: goldenManifest,
    manifestSHA256: exactManifestSHA256,
    policy: hqApprovedCoveragePolicy
)
```

Proceed to current-iPhone Moises capture/review only when:

- `coverage.comparisonCorpusReady == true`; and
- `coverage.status == SUFFICIENT_CORPUS_PENDING_HQ`.

This status means only that the exact corpus meets the externally supplied coverage policy. It is not PARITY and does not assert that HQ chose strong enough production thresholds.

## 6. Diagnostics must be archived

Archive the W22 report with:

- exact manifest bytes/hash;
- HQ coverage policy;
- eligible fixture IDs;
- global eligible fixture count and duration;
- per-domain fixture count/duration and required minimums;
- per-stratum matched fixture IDs, fixture count, duration and required minimums;
- every coverage issue.

The matched fixture-ID lists make undercoverage and accidental concentration reviewable instead of reducing sufficiency to one boolean.

## 7. Required pipeline order

Recommended HQ sequence:

1. freeze rights-cleared Golden manifest bytes/hash;
2. W22 corpus coverage/sufficiency gate;
3. Project W17 audited benchmark on that exact manifest;
4. W19 current-iPhone capture provenance on that exact manifest;
5. W21 independent artifact-anchored review consensus;
6. W20 deterministic raw observation re-scoring;
7. W19 repeatability validation / audited current-iPhone Reference compile;
8. W18 paired Project-vs-Reference non-inferiority comparison;
9. HQ physical-iPhone, product-flow and final PARITY review.

W22 should also be rerun immediately before W18 if any corpus artifact or manifest binding changed after capture began.

## Fail-closed examples

W22 rejects or withholds comparison readiness for:

- wrong manifest ID or SHA;
- malformed/invalid canonical manifest;
- missing one of the five Analysis-domain minimum definitions;
- duplicate domain minimums;
- duplicate stratum IDs;
- zero/negative/NaN/Infinity requirements;
- empty semantic stratum predicates;
- impossible tempo bands;
- unknown/duplicate chord-quality names;
- synthetic fixtures;
- missing differential-reference rights;
- global fixture or duration deficit;
- domain fixture or duration deficit;
- semantic-stratum fixture or duration deficit.

## NON-PARITY notice

W22 portable/unit fixtures are synthetic source-shaped validation data and establish only coverage-gate correctness and scalability. They do not establish that any real corpus is sufficiently representative, do not contain current-iPhone Moises observations, and do not change MOI-P009/P011/P013/P016/P021. Final corpus selection, approval thresholds, current-Moises capture, physical-iPhone evidence and PARITY_MATRIX judgment remain HQ-owned.
