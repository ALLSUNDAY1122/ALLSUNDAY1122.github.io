# L4-W07 Validation｜Musical Key Hardening

Date: 2026-08-23 JST
Branch: `moises/wp4-analysis-platform`
Scope: Worker 4 owned `Analysis/**` / `Tests/**`
PARITY claim: **NO**. All W07 accuracy evidence is deterministic synthetic/adversarial evidence only.

## Goal

Reduce false single-key decisions for relative major/minor ambiguity, rooted modal material and strong modulation while preserving clear major/minor decisions and dominant-body-key behavior.

## Production changes

- `MusicalKeyAnalyzer` now ranks major/minor candidates using profile similarity plus tonic-triad support.
- Relative major/minor counterparts are compared explicitly. Near-ties without meaningful tonic separation fail closed to `nil`.
- Rooted Dorian / Phrygian / Lydian / Mixolydian / Locrian signatures are diagnosed using the mode-characteristic altered pitch versus the conventional major/minor pitch. Until current-iPhone reference vocabulary is verified, clear modal signatures fail closed rather than being mislabeled major/minor.
- Temporal chroma is compared across track halves. Two sufficiently decisive, pitch-rich halves that disagree on key fail closed as a single-key modulation case.
- A short foreign-key intro is allowed when the dominant body remains globally and temporally coherent.
- Key confidence is calibrated from candidate margin, tonic-triad support and temporal agreement.
- `MusicAnalysisConfiguration` exposes `keyRelativeAmbiguityMargin` and `keyModulationMargin` with validated defaults.

## Portable execution

Environment: Swift 6.2.1, x86_64 Linux.

The production `MusicalKeyAnalyzer.swift` was compiled against frozen-contract-shaped stubs and executed against the W07 deterministic fixtures.

Results:

| Fixture | Result | Confidence | Outcome |
| --- | --- | ---: | --- |
| clear C major | C major | 0.999996 | PASS |
| clear A minor | A minor | 0.999996 | PASS |
| transposed D major | D major | 0.999995 | PASS |
| equal C-major/A-minor pitch collection, no tonic evidence | nil | — | PASS fail-closed |
| rooted D Dorian signature | nil | — | PASS fail-closed |
| rooted G Mixolydian signature | nil | — | PASS fail-closed |
| C major -> E major strong modulation | nil | — | PASS fail-closed |
| 2 s G intro -> 10 s C major body | C major | 0.782104 | PASS |

Measured portable RTF was approximately 0.0050–0.0068 for these 12–16 second deterministic fixtures. This is not an iPhone performance claim.

## XCTest coverage

`MusicalKeyHardeningTests.swift` adds six XCTest methods covering:

1. clear major/minor and transposition retention,
2. relative major/minor ambiguity fail-closed,
3. rooted Dorian and Mixolydian fail-closed,
4. strong mid-track modulation fail-closed,
5. short foreign-key intro not overriding the body key,
6. product confidence threshold forcing a weaker decision to unknown.

The XCTest source parses successfully. A fresh full canonical `swift test` remains an HQ/integrated-checkout gate because the Worker environment has previously been unable to resolve github.com for a fresh canonical checkout.

## Machine-readable evidence

`Analysis/benchmarks/L4-W07_KEY_ADVERSARIAL.json`

- `synthetic_only=true`
- `parity_eligible=false`
- includes all deterministic W07 cases, portable timing and explicit limitations.

## Remaining gates

- No rights-cleared multi-genre Golden MIR real-audio corpus has been run.
- Current-iPhone Moises modal vocabulary, relative-key behavior and modulation behavior remain unverified.
- No physical-iPhone latency/RSS/thermal/battery evidence exists.
- MOI-P011 must remain `MISSING` until HQ evaluates real-audio and current-Moises differential evidence.
