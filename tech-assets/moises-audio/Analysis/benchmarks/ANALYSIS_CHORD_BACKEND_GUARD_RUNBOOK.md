# Analysis Chord Backend Equivalence Guard Runbook

## Scope

This runbook covers L4-W34 only. It is an engineering safety gate around the W33 interleaved multi-bin Chord spectral backend. It does not establish MOI-P013 or MOI-P021 PARITY.

## Runtime contract

For every new Analysis run, the Chord backend starts in `verifying`.

1. No-chord frames (`segmentRMS < noChordRMS`) return `N` before backend verification and do not consume the verification budget.
2. For the first 8 actual non-no-chord classification frames, compute both `referencePerBin` and `interleavedMultiBin` spectral evidence.
3. Compare all 12 chroma doubles, bass pitch class and bass-dominance using exact Double bit patterns.
4. Score both evidence objects through the same `AnalysisChordDecisionScorer` and compare label plus confidence bit-exactly.
5. During verification, publish only the reference decision. The 8th matching frame is still reference-published.
6. After 8 consecutive exact matches, state becomes `vectorizedVerified`; the next non-no-chord frame may publish the optimized backend result.
7. If any evidence or decision mismatch occurs, publish the reference result for that current frame, transition permanently to `scalarFallback`, and use reference computation for every remaining non-no-chord frame in that Analysis run.
8. A run with fewer than 8 non-no-chord classification frames remains `verifying` and therefore publishes reference decisions only.

This intentionally prefers correctness over speed. A harmless architecture/compiler rounding difference may force scalar fallback. That is acceptable until Apple-runtime evidence proves the optimized backend safe on the selected build.

## Required diagnostics

`AnalysisSinglePassPreparedFeatureDiagnostics` must preserve:

- `chordBackendGuardState`
- `chordBackendVerificationFrameLimit`
- `chordBackendVerificationComparisons`
- `chordBackendVerificationMatches`
- `chordBackendFallbackTriggered`
- `chordBackendFallbackComparisonIndex`
- `chordBackendReferencePublicationCount`
- `chordBackendVectorizedPublicationCount`

Older serialized diagnostics that predate W34 decode with fail-safe defaults (`verifying`, zero comparisons/publications, no claimed verification).

## Bounded overhead

Default one-hour Analysis at 8 kHz / 0.70 s Chord window / 0.25 s hop has 14,400 Chord frames. W34 verifies at most 8 non-no-chord frames. The additional reference recurrence work is therefore bounded to 2,150,400 recurrence updates, about 0.05556% of the 3,870,720,000 default one-hour Chord recurrence updates. Cadence and window length are unchanged.

## Negative cases

Reject optimized publication for the run by falling back when any of the following occurs during verification:

- one chroma Double differs at the bit level;
- bass pitch class differs;
- bass-dominance Double differs at the bit level;
- final Chord label differs;
- confidence differs, including nil-vs-value or Double bit pattern;
- active workspace shape/sample-rate mismatch uses the legacy scalar classifier directly.

No-Chord frames are not treated as proof that the spectral backends agree because spectral computation is intentionally skipped for them.

## Apple/HQ execution

At Late Integration, execute the canonical XCTest suite and selected Xcode/ARM build, then inspect the W34 diagnostics on W26-selected rights-cleared physical-device runs. If any run falls back, do not mix its timing/thermal results with vectorized-verified runs without explicitly retaining the backend state in evidence.

Linux/portable timings, synthetic harmonic fixtures, and this guard itself are NON_PARITY engineering evidence. Physical-iPhone wall time, RSS/phys-footprint, thermal trajectory, battery drain, current-iPhone Moises differential and final PARITY remain HQ-owned gates.
