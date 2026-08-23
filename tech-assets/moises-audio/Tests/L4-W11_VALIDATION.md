# L4-W11 Validation — Analysis Long-Audio Bounded-Memory / Performance Hardening

Date: 2026-08-23 JST

## Scope

Lane 4 only. No `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Global Queue, work-package/lane-plan/resource-lock, or other Worker Lane code was changed.

Goal: reduce Analysis memory amplification and long-duration runtime risk without weakening the complete-equivalence contract or claiming device performance from portable evidence.

## Production changes

- Added `AnalysisWorkingSetPolicy`.
  - High-rate mono PCM is normalized once to an Analysis working signal capped at 8 kHz.
  - Block-average resampling sanitizes NaN / infinity and bounds pathological finite amplitudes during the same pass.
  - Clean <=8 kHz input is reused without a second PCM allocation.
  - Working-set diagnostics report source/prepared byte counts and legacy whole-track Double-copy bytes avoided.
- Added `BoundedTempoBeatAnalyzer`.
  - Builds onset flux directly from Float PCM instead of first allocating a whole-track `[Double]` copy.
  - Autocorrelation sampling is capped per lag for long tracks.
  - Beat tracking remains source-time based and fails closed below confidence threshold.
- Added `BoundedMusicalKeyAnalyzer`.
  - Uses at most the configured uniformly distributed key windows.
  - Converts only the current analysis window to Double/Hann storage; no whole-track Double copy.
  - Preserves major/minor confidence, relative-key ambiguity, modal fail-closed, and temporal modulation safeguards.
- Added `BoundedChordTimelineAnalyzer`.
  - Converts only the active chord window to Double for the existing W08 `ChordFrameClassifier`.
  - Keeps no-chord handling, flicker bridging, short-segment absorption, ordering, and gap-free duration normalization.
- `ProjectOwnedMusicAnalyzer` now executes the bounded preparation + Tempo/Key/Chord path before W09 section hardening and W10 final snapshot robustness.
- Added `AnalysisLongAudioPerformanceBenchmark` with deterministic working-set budget modeling and a preparation wall-time row that can never self-declare PARITY.

The older Tempo/Key/Chord analyzers remain in the package as regression/reference implementations; the product-owned analyzer path is the bounded path.

## Portable validation

Environment: Swift 6.2.1, x86_64 Linux.

Production-source-shaped executable harness: **13/13 PASS**.

Validated:

1. 44.1 kHz -> 8 kHz preparation.
2. duration preservation.
3. NaN recovery.
4. infinity recovery.
5. pathological finite amplitude bounding.
6. sample-count reduction.
7. one-hour working-set budget.
8. 120 BPM decision emitted.
9. 120 BPM estimate within 4 BPM.
10. C-major key decision emitted.
11. C tonic recovered.
12. bounded chord timeline emitted and reaches exact duration.
13. budget serialization.

Five complete portable harness runs: all **13/13 PASS**.

- elapsed: 0.02, 0.02, 0.02, 0.02, 0.02 s
- max RSS: 20596, 20628, 20696, 20600, 20584 kB

Committed `AnalysisLongAudioHardeningTests.swift` typechecks against an `-enable-testing` MoisesAudioCore-shaped Swift module: **PASS**.

## 120-second preparation stress

Fixture: project-generated mono 220 Hz sine, 44.1 kHz, 120 seconds.

- source samples: 5,292,000
- prepared samples: 960,000
- prepared sample rate: 8,000 Hz
- duration after preparation: 120.000000 s
- preparation wall seconds across 3 runs: 0.014450, 0.010794, 0.011514
- process max RSS across runs: 39,920 / 39,996 / 40,024 kB

This RSS includes the synthetic source fixture and Swift process runtime. It is not an iPhone RSS claim.

## One-hour 44.1 kHz deterministic budget

For 3,600 s mono Float PCM:

- source PCM: 635,040,000 bytes
- prepared 8 kHz Float PCM: 115,200,000 bytes
- legacy whole-track source-rate Double region avoided: 1,270,080,000 bytes
- estimated bounded-path peak additional working set: 118,080,000 bytes
- estimated reduction ratio versus the legacy whole-track Double region: 10.756x

The 118 MB figure is an implementation-model estimate from explicit array/window sizes, not a physical-device measurement. Real iPhone allocator behavior, AVFoundation loader memory, thermal state, and integrated cross-Lane memory remain HQ gates.

## Evidence classification

**NON_PARITY**.

Machine-readable evidence:

- `Analysis/benchmarks/L4-W11_LONG_AUDIO_BOUNDED_MEMORY.json`

Portable synthetic compile/harness/performance evidence cannot promote:

- MOI-P009 BPM
- MOI-P011 Key
- MOI-P013 Chord
- MOI-P016 Song Section
- MOI-P021 Long-audio memory/thermal/battery stability

## Remaining gates

- canonical integrated SwiftPM/Xcode build after HQ semantic integration
- real rights-cleared multi-genre Analysis accuracy
- current-iPhone Moises differential for BPM/key/chord/sections
- physical-iPhone long-duration peak RSS and memory-pressure behavior
- thermal and battery evidence
- cancellation/interruption responsiveness during long Analysis
- final HQ PARITY judgment
