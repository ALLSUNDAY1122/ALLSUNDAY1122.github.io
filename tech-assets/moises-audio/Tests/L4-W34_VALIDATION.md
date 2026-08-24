# L4-W34 Validation — Chord Backend Runtime Equivalence Guard

## Result

W34 is complete as Worker-4 engineering hardening. It does not establish MOI-P013 or MOI-P021 PARITY.

The W33 interleaved Chord backend is no longer trusted solely because portable fixtures were bit-identical. Every Analysis run now begins with a bounded reference-vs-vectorized verification sequence on actual non-no-chord frames. Unverified optimized decisions are never published.

## Production behavior

- New run state starts as `verifying`.
- No-Chord frames bypass spectral work and do not consume verification frames.
- First 8 non-no-chord classification frames compute reference and interleaved evidence.
- Spectral evidence comparison is Double-bit-exact for all 12 chroma values and bass dominance, with exact bass pitch class.
- Final label and confidence are also compared exactly through the shared W33 scorer.
- Verification frames publish the reference decision only.
- The 8th matching frame remains reference-published; optimized publication begins with the next eligible frame.
- Any mismatch publishes the reference result for the current frame and permanently changes that Analysis run to `scalarFallback`.
- Fewer than 8 eligible frames means the run stays reference-published for its entire duration.
- Workspace shape/sample-rate mismatch continues to use the legacy reference classifier.

## Diagnostics

`AnalysisSinglePassPreparedFeatureDiagnostics` now records guard state, verification count/matches, fallback status/index and reference/vectorized publication counts. Custom Codable defaults allow older W29-W33 diagnostics to decode without falsely claiming backend verification.

The accumulator retained-byte estimate was also corrected to include W33 `recurrenceS1` and `recurrenceS2` scratch arrays.

## Portable validation

Swift 6.2.1 source-shaped validation:

- guard strict concurrency + warnings-as-errors: PASS
- classifier strict concurrency + warnings-as-errors: PASS
- diagnostics Codable compile: PASS
- budget estimator compile: PASS

Actual classifier integration on a harmonic Chord fixture:

- classifier calls: 10
- verification comparisons: 8
- verification matches: 8
- reference publications: 8
- vectorized publications: 2
- final guard state: `vectorizedVerified`
- final label/confidence mismatches versus legacy classifier: 0

Forced mismatch validation:

- first comparison matched
- second comparison contained an intentional spectral bit mismatch
- second/current frame published reference result
- state became `scalarFallback`
- fallback comparison index: 2
- all subsequent publications remained reference
- no vectorized publication occurred after fallback

No-Chord validation confirms 20 quiet calls consume zero verification comparisons and leave the guard in `verifying`.

## State-transition stress

100,000 guard runs per process, five independent processes. Every tenth run forced a mismatch at comparison 4.

- checksum: `860000` in all five processes
- internal elapsed range: `0.003995881–0.004308556 s`
- maximum RSS range: `16708–16900 kB`

These values measure the small guard state machine only; they are not Analysis or iPhone performance results.

## One-hour bounded overhead

Default 8 kHz / 0.70 s Chord window / 0.25 s hop:

- Chord frames: `14,400`
- verification frames upper bound: `8`
- window samples: `5,600`
- spectral bins: `48`
- W33 vectorized window element visits: `80,640,000`
- W34 maximum extra reference window element visits: `2,150,400`
- total Chord Goertzel recurrence updates: `3,870,720,000`
- W34 maximum extra verification recurrence updates: `2,150,400`
- recurrence overhead fraction: `0.0005555555555555556` (~0.05556%)

Chord cadence, window size, vocabulary, thresholds and decision scoring remain unchanged.

## Safety boundary

Bit-exact comparison is intentionally conservative. A harmless Apple ARM/compiler floating-point difference may force scalar fallback. W34 prefers slower verified reference computation over silently publishing an optimized result whose active-build equivalence is unknown.

Portable validation cannot establish selected Apple ARM equivalence, physical-iPhone speed, thermal behavior, battery drain, or current-Moises quality. Those remain HQ Late Integration gates. MOI-P013 and MOI-P021 remain MISSING.

## Durable artifacts

- `Analysis/AnalysisChordBackendEquivalenceGuard.swift`
- `Analysis/AnalysisReusableChordFrameClassifier.swift`
- `Analysis/AnalysisChordBackendGuardBudget.swift`
- `Analysis/AnalysisSinglePassPreparedFeatures.swift`
- `Analysis/AnalysisSequentialPreparedFeatureAccumulator.swift`
- `Tests/MoisesAudioCoreTests/AnalysisChordBackendEquivalenceGuardTests.swift`
- `Tests/MoisesAudioCoreTests/AnalysisChordBackendGuardBudgetTests.swift`
- `Analysis/benchmarks/ANALYSIS_CHORD_BACKEND_GUARD_RUNBOOK.md`
- `Analysis/benchmarks/L4-W34_CHORD_BACKEND_EQUIVALENCE_GUARD.json`
- `Package.swift`
