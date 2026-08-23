# L4-W06 Validation — Tempo / Beat real-world hardening

Date: 2026-08-23 JST
Branch: `moises/wp4-analysis-platform`
Frozen Shared/App base: `be1c84314db182d6eee5097de34e017af1a4a7de`
Evidence class: **SYNTHETIC / ADVERSARIAL / NON-PARITY**

## Goal

Reduce the Lane 4 MOI-P009 correctness gap without waiting for the external Golden MIR corpus or an Apple device. Harden `TempoBeatAnalyzer` against common octave/meter errors, gradual tempo drift, weak percussion and syncopated onset energy, while preserving fail-closed unknown behavior.

## Production changes

`Analysis/TempoBeatAnalyzer.swift` now uses:

- joint autocorrelation + metrical-grid candidate scoring;
- onset-mass coverage so a slower candidate cannot win only because it samples the strongest alternating accents;
- explicit subharmonic suppression when the faster grid is strongly periodic and explains materially more onset mass;
- common-ratio ambiguity detection for 1:2, 2:1, 2:3, 3:2, 1:3 and 3:1 meter/octave conflicts; near-ties reduce confidence until the normal product threshold fails closed;
- adaptive beat tracking with bounded local onset search and period smoothing instead of a single immutable beat period;
- robust BPM reporting from median tracked inter-beat intervals, bounded around the original global candidate;
- a transient-contrast guard to reject sustained tonal material after relaxing the old weak-percussion transientness threshold.

## Failure-driven correction

The first W06 executable harness exposed a regression: after lowering the transientness gate, a sustained C4 sine wave produced a false ~139.5 BPM result because tiny frame-RMS modulation was highly periodic.

The implementation was corrected before commit by comparing maximum onset flux with whole-signal log-RMS (`transientContrast`). The same sustained tone then returned `nil`, while the 96 BPM weak-percussion fixture continued to pass.

## Adversarial executable results

Swift 6.2.1 / x86_64 Linux optimized targeted harness:

| Case | Result |
|---|---|
| 75 BPM + weak eighth subdivisions | 75.0 BPM, confidence 0.9650, Beat F@70ms 1.000 |
| 150 BPM alternating 0.90/0.55 accents | 150.0 BPM, confidence 0.8423, Beat F@70ms 1.000 |
| linear 100→130 BPM over 30s | 115.3846 BPM median tracked rate, confidence 0.3720, Beat F@70ms 0.9828 |
| 96 BPM weak percussion + tonal bed/noise | 96.7742 BPM, confidence 0.6938, Beat F@70ms 0.9744 |
| 90 BPM + equal half-beat subdivision | `nil` — metrical ambiguity fails closed |
| 120 BPM + stronger 0.65-beat syncopated ghost notes | 120.0 BPM, confidence 0.8818 |
| sustained C4 tone | `nil` — no invented tempo |

Aggregate optimized harness: wall ~0.10s, peak RSS ~20,772 KiB for all seven synthetic cases in one process. This is not an iPhone performance result.

Machine-readable evidence: `Analysis/benchmarks/L4-W06_TEMPO_BEAT_ADVERSARIAL.json`.

## Committed XCTest coverage

`Tests/MoisesAudioCoreTests/TempoBeatHardeningTests.swift` adds seven deterministic cases matching the scenarios above, including beat-F assertions for half/double, drift and weak-percussion paths.

The production analyzer also typechecked in a targeted Swift 6.2.1 harness against frozen-contract-shaped stubs. A fresh full canonical `swift test` is still not claimed from this Worker environment; HQ must execute the complete suite from an integrated checkout.

## What this does not prove

- No rights-cleared real-audio corpus was used.
- Live drummer, rubato, swing, genre diversity and exact meter interpretation remain unverified.
- The syncopation fixture verifies tempo-rate robustness, not authoritative musical beat phase on real recordings.
- No Xcode / Simulator / physical-iPhone latency, RSS, thermal or battery measurement was run.
- No current-Moises differential was run.
- MOI-P009 therefore remains `MISSING` until HQ executes and judges real evidence.

## Done-when result

W06 is complete as a **NON-PARITY hardening wave**: meaningful production algorithm changes, negative/failure behavior, seven deterministic regression cases, executable evidence and durable documentation are committed entirely inside Lane 4 ownership.
