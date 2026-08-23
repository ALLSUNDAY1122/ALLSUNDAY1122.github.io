# L4-W22 Validation — Analysis Differential Corpus Coverage / Sufficiency Gate

## Scope

W22 closes the evidence-quality gap identified after W21: a perfectly paired, provenance-valid, independently reviewed and deterministically re-scored Project-vs-current-iPhone comparison could still be misleading if HQ selected only a tiny or biased set of easy tracks.

This wave adds a machine-readable corpus sufficiency gate without selecting production sufficiency thresholds for HQ.

## Implementation

Added `Analysis/AnalysisBenchmarkCorpusCoverage.swift`.

The validator binds an HQ-approved `AnalysisCorpusCoveragePolicy` to the exact benchmark manifest ID and SHA-256, then derives fixture features once from Golden annotations and evaluates global, domain and semantic-stratum coverage.

Hard-coded scope requirements are limited to structural correctness:

- authority must be `HQ_LATE_INTEGRATION`;
- every Analysis domain must have an HQ minimum: `tempo`, `beat`, `key`, `chord`, `structure`;
- counts and durations must be positive;
- at least one semantic stratum is required;
- semantic predicates must be non-empty and internally valid.

Worker 4 does **not** ship production corpus-size, duration, genre, tempo-band, key-mode, chord or structure minimums.

## Semantic coverage

Stratum membership is derived from Golden manifest annotations rather than hand-entered fixture tags.

Supported dimensions:

- exact genre;
- BPM lower/upper bands;
- key mode;
- canonical chord quality;
- inversion presence;
- no-chord presence;
- distinct chord-label count;
- section count;
- structural-label diversity;
- required functional labels;
- repeated structural-label presence.

Predicates may be combined across dimensions.

## Rights / evidence eligibility

A fixture can count only if it is real audio, passes canonical `AnalysisRealAudioManifestValidator.isParityEligible`, and its rights grant includes `DIFFERENTIAL_REFERENCE`.

Synthetic or rights-ineligible fixtures produce explicit issues and do not silently pad coverage.

## Deterministic diagnostics

The report records:

- exact manifest ID/SHA;
- eligible unique fixture IDs;
- eligible total duration;
- per-domain counts/durations and HQ minimums;
- per-stratum matched fixture IDs/count/duration and HQ minimums;
- sorted issues;
- `INSUFFICIENT_CORPUS` or `SUFFICIENT_CORPUS_PENDING_HQ`.

`SUFFICIENT_CORPUS_PENDING_HQ` is not PARITY.

## Adversarial portable validation

Environment: Swift 6.2.1 x86_64 Linux, source-shaped production validation.

Five clean runs of the adversarial harness completed with `16/16 PASS` on every run.

Covered cases:

1. balanced corpus accepted under supplied policy;
2. all five domain diagnostics satisfied;
3. all semantic strata satisfied;
4. trivial one-track global deficit;
5. domain deficit;
6. stratum deficit;
7. exact manifest hash mismatch;
8. missing four required domain minimums;
9. duplicate domain minimum;
10. duplicate stratum ID;
11. synthetic padding rejection;
12. missing `DIFFERENTIAL_REFERENCE` rights rejection;
13. empty semantic predicate rejection;
14. unknown chord-quality rejection;
15. Golden-derived inversion/minor/repeated-section membership;
16. deterministic policy codec round-trip.

## Stress validation

Optimized source-shaped stress case:

- 50,000 real-audio-shaped fixture records;
- all five Analysis domains represented per fixture;
- 9 semantic strata;
- fixture features computed once then reused across stratum matching;
- all five runs produced `comparisonCorpusReady=true`, 50,000 eligible fixtures, 9 satisfied strata, 0 issues.

Internal elapsed seconds:

- 0.985302
- 1.021424
- 0.987189
- 0.991817
- 0.998183

Process wall seconds:

- 1.00
- 1.04
- 1.00
- 1.01
- 1.02

Maximum RSS kB:

- 98040
- 98040
- 98016
- 98016
- 98028

These are Linux validator stress measurements, not iPhone Analysis performance measurements.

## Durable files

- `Analysis/AnalysisBenchmarkCorpusCoverage.swift`
- `Tests/MoisesAudioCoreTests/AnalysisBenchmarkCorpusCoverageTests.swift`
- `Analysis/benchmarks/ANALYSIS_CORPUS_COVERAGE_POLICY_TEMPLATE.json`
- `Analysis/benchmarks/ANALYSIS_CORPUS_COVERAGE_RUNBOOK.md`
- `Analysis/benchmarks/L4-W22_ANALYSIS_CORPUS_COVERAGE.json`
- updated `Analysis/benchmarks/PAIRED_DIFFERENTIAL_RUNBOOK.md`

## Remaining gates

W22 does not provide actual production sufficiency evidence because no HQ-approved production coverage policy or rights-cleared production corpus was supplied in this wave.

MOI-P009 / P011 / P013 / P016 remain MISSING pending the actual rights-cleared corpus, W22 HQ policy, current-iPhone Moises observations, Project real-audio scoring and paired differential evidence.

MOI-P021 remains MISSING pending physical-iPhone peak memory/RSS, cancellation, thermal and battery measurements.

Full canonical SwiftPM/Xcode XCTest execution remains an HQ integrated-checkout gate. Portable source-shaped validation does not replace it.

## Next recommended Worker-4 wave

Prioritize P021 directly: add a physical-iPhone Analysis performance evidence harness under Worker-4-owned `iOS/**` / `Analysis/**` that can record resident/physical memory, thermal-state transitions, battery delta, wall time and cancellation latency for representative long-track Analysis runs, with machine-readable evidence and fail-closed device provenance. Actual physical-device execution remains HQ Late Integration owned.
