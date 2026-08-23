# L4-W14 Validation — Song Section end-to-end boundary over-segmentation hardening

## Scope

Worker 4 only. This wave changes Lane-4 Analysis, Package.swift and tests. Shared/App/PARITY/Queue/Lane Plan/Resource Locks remain untouched.

## Problem found after W13

W13 solved two important issues:

- the section stage became cooperatively cancellable,
- candidate/prototype/descriptor work became explicitly bounded.

However, full synthetic varied-structure inspection still exposed a correctness problem: the detector could preserve chord-subphrase candidates at roughly four-second spacing. A chord progression such as `C -> A:min -> F -> G` could therefore become multiple structural sections even when it belonged to one verse or chorus family. This also weakened downstream functional-label inference because repeated families were fragmented before clustering.

W14 does not hide that defect behind the prior W09 seeded-hardener result. It adds a new product boundary gate specifically for this end-to-end failure mode.

## Production changes

Added `SongSectionBoundaryHardener` after the W13 detector and before final snapshot publication.

The product path is now:

`CancellableSongSectionPipeline.analyze`
→ `SongSectionBoundaryHardener.harden`
→ existing W13 `hardenCancellable`
→ `AnalysisSnapshotRobustness.harden`

The W13 detector and W13 internal hardener are not rewritten. This preserves the already-validated cancellation and complexity behavior while adding a separate correctness layer.

### Boundary evidence

Every detected internal boundary is re-evaluated with evidence that is independent of one instantaneous chord transition:

- local RMS / energy discontinuity,
- broad harmonic-distribution distance,
- decided-vs-unknown chord coverage change.

A short section is allowed only when both adjacent boundaries have corroborating short-section evidence. With the product baseline:

- configured minimum section duration: 4 seconds,
- preferred normal structural spacing: 8 seconds,
- short 4-second structures remain possible when both boundaries are corroborated.

This preserves legitimate short parts such as pre-choruses while preventing an uncorroborated chord change from automatically creating another four-second structural fragment.

### Fail-closed behavior

- non-corroborated near-edge candidates are removed rather than creating short edge fragments,
- unknown/undecided chord evidence is not converted into a named family,
- after boundary selection, neutral seeds are sent back through the existing W13 cancellable family/functional-label hardener instead of duplicating or weakening that logic.

### Cancellation / bounded work

W14 adds cancellation checks while:

- evaluating candidate boundaries,
- scanning overlapping chords for broad harmonic evidence,
- probing local PCM RMS windows,
- rebuilding seeds.

Local RMS evidence is capped at 2,048 PCM probes per side. W13 limits remain unchanged:

- maximum boundary candidates: 16,384,
- maximum structural prototypes: 64,
- descriptor sample cap: 8,000.

## Portable executable validation

Swift 6.2.1 / x86_64-unknown-linux-gnu boundary-policy harness:

- 5 complete runs,
- 7/7 assertions PASS on every run,
- elapsed seconds: 0.01 / 0.01 / 0.04 / 0.01 / 0.01,
- max RSS kB: 38,484 / 38,404 / 38,380 / 38,332 / 38,320.

Observed pre-cancelled task completion latency:

- 0.511 ms,
- 0.415 ms,
- 0.497 ms,
- 0.407 ms,
- 0.394 ms.

Worst observed: ~0.511 ms.

These timings are portable Linux scheduler evidence only and are not physical-iPhone latency claims.

## Varied-structure fragmentation result

Deterministic W13-shaped over-segmented input:

- duration: 62 seconds,
- input section count: 15,
- input internal boundaries: `4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 50, 54, 58` seconds.

W14 output:

- output section count: 10,
- output internal boundaries: `4, 12, 16, 24, 32, 36, 44, 50, 58` seconds,
- removed chord-subphrase boundaries: `8, 20, 28, 40, 54` seconds,
- boundary density: ~13.55/min -> ~8.71/min,
- median section duration: 4 s -> 7 s.

The retained ten-section plan matches the prior W09 varied-structure semantic fixture used to establish:

`intro -> verse -> pre-chorus -> chorus -> verse -> pre-chorus -> chorus -> bridge -> chorus -> outro`

The portable W14 boundary harness validates the boundary plan itself. The already-existing W13 seeded-hardener evidence validates the functional-label hardener. The new committed canonical XCTest composes both surfaces and asserts the family/functional labels when the full MoisesAudioCore test target is executed.

## Stable progression negative case

A 16-second constant-energy repeated progression intentionally supplied as four 4-second fragments is reduced to at most two sections, with no output section shorter than 8 seconds. This directly checks that repeated chord movement alone no longer creates a boundary at every subphrase.

## XCTest source validation

Added `SongSectionBoundaryOversegmentationTests.swift` covering:

- deterministic removal of the five known chord-subphrase boundaries,
- preservation of short pre-chorus/edge structures and repeated structural families,
- full detector -> W14 fragmentation reduction,
- stable repeated-progression negative case,
- unknown chord evidence fail-closed behavior,
- diagnostics JSON keys,
- pre-cancelled `CancellationError`,
- unchanged W13 complexity caps.

The committed XCTest source typechecks against an `-enable-testing` portable `MoisesAudioCore`-shaped module exposing the exact W14 API surface: PASS.

The local environment cannot replace the canonical Xcode/SwiftPM integrated-checkout execution gate.

## PARITY status

**NON_PARITY.** W14 is correctness hardening and synthetic/portable evidence only.

MOI-P016 remains MISSING until HQ Late Integration completes:

- rights-cleared varied-structure real-audio section benchmarks,
- current-iPhone Moises differential boundary/label comparison,
- section navigation and loop integration,
- physical-iPhone evidence.

MOI-P021 also remains MISSING. W11-W14 improve modeled memory, cancellation and bounded Analysis work, but physical-iPhone peak RSS, memory pressure, cancellation responsiveness, thermal and battery evidence are still required.

Synthetic fixtures, portable harnesses, compile/typecheck results and model-based metrics must not promote PARITY.
