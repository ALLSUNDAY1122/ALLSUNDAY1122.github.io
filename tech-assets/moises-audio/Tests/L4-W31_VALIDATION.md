# L4-W31 Validation — Extreme-duration Analysis Retention

## Result

W31 is complete as Worker-4 engineering hardening. It does not establish MOI-P021 PARITY.

W31 bounds retained Tempo, Chord, and Section feature vectors while preserving the W29/W30 cadence for normal songs. The resource caps are not quality or PARITY thresholds.

## Production changes

- Added `AnalysisExtremeDurationRetentionPolicy`.
- Added `AnalysisExtremeDurationRetentionBudgetEstimator`.
- The shared `AnalysisSequentialPreparedFeatureAccumulator` now applies the same W31 plan to whole-signal and W30 pull-based input.
- `AnalysisSinglePassPreparedFeatureDiagnostics` records compression strides and structural-safety flags.
- `AnalysisChunkedInputBudget` now reports the current W31 retained-feature estimate.
- Package registration and durable XCTest were added.

## Normal-track behavior

At 10 minutes / 8 kHz:

- Tempo stride = 1.
- Chord stride = 1.
- Section energy = natural 100-Hz representation.
- Compression = false.

The durable test compares a normal musical fixture through the compatibility path and W31 path and requires equal Tempo, Key, Chord, and Section-energy outputs.

## Tempo

For extreme cardinality, W31 does not simply inspect every Nth Tempo frame. It still computes the natural-cadence onset stream, then max-pools contiguous groups before retention. This avoids losing a transient merely because it falls between sparse retained positions.

Pooling validation: 1117 assertions PASS in each of five runs. Stride 1 is exact identity and grouped output equals the maximum of every contiguous group.

If the effective retained-envelope rate is below Nyquist for the configured maximum BPM, Tempo fails closed to unknown.

## Chord

An initial 131,072-decision cap was rejected because it would make the 24-hour default hop 0.75 seconds. The production cap is 524,288, preserving the existing 0.25-second Chord cadence through 24 hours at 8 kHz.

If an ultra-long adaptive hop exceeds the bounded Chord analysis window, W31 emits one full-duration `X` marker rather than classify overwritten ring samples.

## Section energy

Section energy spans the full duration using at most 262,144 RMS frames. If that retained rate cannot represent the configured minimum section duration, the Section-energy signal becomes empty rather than fabricate structure.

## 24-hour plan

At 8 kHz:

- natural Tempo frames: 8,639,996
- Tempo stride: 9
- retained Tempo bins: 960,000
- effective Tempo hop: 0.09 s
- natural / retained Chord decisions: 345,600 / 345,600
- Chord stride: 1; hop remains 0.25 s
- natural Section frames: 8,640,000
- retained Section frames: 262,144
- no domain structurally suppressed

## Analytical memory

44.1-kHz mono Float source:

- 1-hour W31 major Worker-4 working set: 10,375,552 bytes.
- 24-hour historical W29/W30 estimate: 197,563,776 bytes.
- 24-hour W31 estimate: 41,172,416 bytes.
- reduction: approximately 4.798x.
- 24-hour Tempo onset + median scratch: 15,360,000 bytes.
- 24-hour Chord decisions: 22,118,400 bytes.
- 24-hour Section energy: 1,048,576 bytes.

Allocator/VM overhead and hidden decoder buffers are not modeled. W23/W24 physical-iPhone telemetry remains authoritative.

## Fail-closed examples

- 48 hours: Tempo retained rate is insufficient for configured maximum-BPM Nyquist -> Tempo unknown.
- 96 hours: adaptive Chord hop is wider than the bounded Chord window -> full-duration `X`.
- 30 days: retained Section rate cannot resolve minimum section duration -> empty Section-energy signal.

These are structural safeguards, not advertised duration limits.

## Portable validation

Swift 6.2.1 x86_64 Linux:

- final policy: 34/34 assertions PASS under strict concurrency / warnings-as-errors;
- diagnostics initializer/codec source-shape: 4/4 PASS;
- shared accumulator source-shape: PASS;
- Tempo pooling: 1117 assertions PASS x5;
- 500,000 deterministic retention plans per process x5: 0 failures;
- plan-stress internal seconds: 0.015103, 0.014655, 0.014172, 0.014176, 0.014616;
- plan-stress max RSS: 17,800 kB.

Portable timings are evaluator evidence only, not iPhone Analysis performance evidence.

## Durable XCTest

`AnalysisExtremeDurationRetentionTests.swift` covers normal-track invariance, exact 24-hour planning, Tempo/Chord/Section fail-closed cases, budget reduction, cardinality properties, diagnostic JSON round-trip, and cancellation.

`AnalysisChunkedInputPipelineTests.swift` was updated to the current W31 1-hour / 24-hour budgets.

Full canonical SwiftPM/Xcode XCTest remains an HQ Late Integration gate.

## Remaining risk

W31 targets retained memory, not all CPU work. Tempo still computes natural-cadence frame energy before pooling. The 24-hour Chord cadence is intentionally preserved, so overlapping Chord spectral work remains the largest obvious CPU/thermal risk in Worker-4 Analysis.

## PARITY boundary

MOI-P021 remains MISSING. A genuine Lane-2 bounded decoder, physical-iPhone W23/W24 evidence, and HQ-approved acceptance are still required. Compressed long-duration quality also remains subject to W22 rights-cleared differential evidence. W31 does not update PARITY_MATRIX and does not claim P009/P011/P013/P016/P021 PARITY.
