# L4-W08 Validation — Chord Vocabulary / Inversion Hardening

Date: 2026-08-23 JST

## Scope

Lane 4 only. No Shared/App/PARITY/other-Lane code changed.

Goal: harden chord classification so unsupported complex harmony is not flattened into an incorrect major/minor result, while preparing an internal extended diagnostic vocabulary for current-iPhone reference verification.

## Production changes

- Added `Analysis/ChordVocabularyClassifier.swift`.
- Product `ChordTimelineAnalyzer` now delegates frame classification to the new classifier in `conservativeMajorMinor` mode.
- Product mode continues to emit only verified-safe labels: major (`C`), minor (`C:min`), `N`, `X`.
- Strong 7th/maj7/min7/sus/dim/aug evidence fails closed to `X` in product mode instead of being mislabeled as a simple triad.
- Internal `extendedDiagnostic` mode distinguishes dominant7, major7, minor7, sus2, sus4, diminished and augmented families for future reference validation.
- Added low-register pitch-class evidence so an inversion does not replace the harmonic root. Example: C/E remains root C; diagnostic representation can expose `C/E`.
- Augmented roots are treated as pitch-class symmetric: no arbitrary root is emitted without a sufficiently strong low-register anchor.
- Added canonical label parser/formatter with flat/sharp alias normalization and invalid-label rejection.

## Portable validation

Environment: Swift 6.2.1, x86_64 Linux.

Production classifier + timeline compiled against frozen-contract-shaped stubs: PASS.

Ten-case executable classifier harness: 10/10 PASS.

- C major -> `C`
- A minor -> `A:min`
- C7 product -> `X`
- C7 diagnostic -> `C:7`
- Cmaj7 diagnostic -> `C:maj7`
- Amin7 diagnostic -> `A:min7`
- Csus4 diagnostic -> `C:sus4`
- Bdim diagnostic -> `B:dim`
- Caug diagnostic with low-register C anchor -> `C:aug`
- C/E diagnostic -> `C/E`

Ten-case harness wall times across five runs: 0.33, 0.33, 0.34, 0.37, 0.32 seconds; median 0.33 seconds. This is portable Linux evidence, not an iPhone performance claim.

Timeline regression harness: PASS.

- 0–2 C major
- 2–4 A minor
- 4–5 silence `N`
- 5–7 G major
- labels exactly `[C, A:min, N, G]`
- source-time timeline remains gap-free and ends at 7.0 s
- standalone C7 product timeline emits `[X]`

Label normalization sanity: PASS.

- `Bb:maj7/D` -> `A#:maj7/D`
- `A:m7/C` -> `A:min7/C`
- `Db:sus` -> `C#:sus4`

Committed XCTest source adds 8 deterministic test methods and parses successfully with Swift 6.2.1. Full canonical `swift test` remains an HQ/integrated-checkout gate because the Worker runtime does not have the canonical repository checkout/dependency state.

## Evidence classification

NON_PARITY.

All W08 audio fixtures are project-generated synthetic adversarial material. They cannot satisfy MOI-P013. Current-iPhone Moises complex-chord/slash-label vocabulary has not been reference-verified, so product vocabulary expansion remains intentionally disabled.

Machine-readable evidence: `Analysis/benchmarks/L4-W08_CHORD_VOCABULARY_ADVERSARIAL.json`.

## Remaining P013 gates

- rights-cleared multi-genre real-audio chord ground truth
- current-iPhone Moises exact vocabulary and unknown behavior
- real inversions/voicings/noisy mixes/short transitions
- differential timestamp sequence comparison
- integrated iPhone timing/UX synchronization
- HQ PARITY judgment
