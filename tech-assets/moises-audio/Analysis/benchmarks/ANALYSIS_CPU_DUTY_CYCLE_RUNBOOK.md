# Analysis CPU Duty-Cycle Runbook

## Purpose

W32 reduces Worker-4 Analysis CPU work that scales with long audio while preserving ordinary-song behavior and Chord cadence. This runbook is engineering evidence only. It cannot establish MOI-P021 PARITY without physical-iPhone W23/W24 evidence.

## Tempo path

- Audio shorter than 1800 seconds keeps the historical per-frame Tempo window rescan and therefore the historical floating-point summation order.
- At 1800 seconds or longer, Tempo frame energy uses a rolling sum-of-squares over the same 368-sample default window and same 80-sample natural hop at 8 kHz.
- The rolling sum is rebuilt from the exact current ring window every 2048 natural Tempo frames to bound floating-point drift.
- W31 max-pooling still occurs only after every natural-cadence onset has been computed.
- The 1800-second boundary is a resource implementation switch, not a product quality or PARITY threshold.

## Chord path

W32 does not reduce the default 0.25-second Chord cadence. It does not skip Chord windows.

For one Analysis run it precomputes and reuses:

- Hann weights for the fixed Chord window;
- MIDI 36...83 frequencies and accepted bins;
- Goertzel coefficients;
- pitch-class and low-register bass metadata;
- one windowed-sample scratch buffer.

The per-frame Goertzel recurrence, Chord candidate scoring, confidence logic, vocabulary and post-processing are unchanged. A kernel/sample-count/sample-rate mismatch falls back to the legacy classifier rather than use an invalid optimized kernel.

## Required regression checks

1. Compare rolling Tempo frame energies with reference rescans on deterministic tonal/transient fixtures.
2. Reject if maximum absolute energy delta exceeds the recorded engineering tolerance or if frame cardinality differs.
3. Compare reusable Chord classifier labels and confidence against `ChordFrameClassifier` across multiple harmonic windows.
4. Compare legacy and reusable raw chroma/bass spectral values. Bit-pattern equality is preferred because W32 reuses the same Hann and Goertzel formulas.
5. Check short/ordinary audio remains on reference Tempo mode.
6. Check one-hour analytical operation counts.
7. Stress duration/sample-rate budget calculations for overflow/non-negative behavior.
8. Preserve cancellation tests in the full Analysis pipeline.

## Current portable evidence

See `L4-W32_LONG_AUDIO_CPU_DUTY_CYCLE.json`.

At one hour / 8 kHz prepared input:

- Tempo reference window terms: 132,478,528.
- Tempo rolling updates: at most 57,599,632 plus 64,768 periodic rebase terms.
- Chord frame count remains 14,400 at 0.25 seconds.
- Repeated Hann/frequency/coefficient setup is reduced from 14,400 setups to one.
- 3,870,720,000 Goertzel sample iterations remain unchanged and are the largest obvious remaining Chord CPU cost.

## Physical-device gate

HQ must run the integrated application with the genuine Lane-2 bounded decoder and capture W23 telemetry, then apply the predeclared W24 acceptance profile. At minimum compare:

- complete Analysis wall time;
- resident and physical footprint;
- starting/worst thermal state;
- battery drain while unplugged;
- memory-pressure events;
- cancellation latency.

Do not translate portable Linux timing ratios directly into iPhone thermal or battery claims.

## PARITY boundary

W32 is NON_PARITY engineering evidence. MOI-P021, P009, P011, P013 and P016 remain HQ-owned final gates. Rights-cleared W22 differential evidence is still required wherever a long-duration implementation path can affect output.
