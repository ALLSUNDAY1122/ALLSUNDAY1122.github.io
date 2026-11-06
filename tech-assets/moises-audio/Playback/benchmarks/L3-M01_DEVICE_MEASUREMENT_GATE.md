# L3-M01｜Playback / DSP device measurement gate

Captured: 2026-08-22 JST
Lane: `LANE-3-PLAYBACK-DSP`
Bundle: `L3-M01`

## Purpose

This package turns the remaining Playback/DSP device-quality questions into a reproducible measurement contract that HQ can wire into an Apple/iPhone host later without changing Lane 3 core semantics.

It does **not** claim product PARITY. Harness-only, simulator-only, synthetic-only, rights-unknown, missing-audio-capture, missing-listening-review, or missing-Reference-differential runs are deliberately marked ineligible by `parityEvidenceEligible=false`.

## Portable implementation

`Playback/Measurements/Lane3DeviceMeasurementHarness.swift` evaluates captured observations and emits sorted JSON evidence.

Required measurement families:

1. Playback synchronization
   - `playback.onset_skew`: max-min onset time across simultaneously scheduled stem markers.
   - `playback.seek_gap`: seek command to first valid post-seek audio.
   - `playback.loop_max_drift`: worst absolute loop-boundary timing error.
   - `playback.loop_end_to_end_drift`: signed timing-error change from first to last measured loop; this catches accumulating drift.
2. Mixer transition risk
   - `playback.gain_step_over_local_rms`: controlled-fixture sample discontinuity relative to local RMS.
   - `playback.gain_settling`: worst settling interval after volume / solo / mute transition.
   - Automated values never replace human click/pop/zipper review.
3. Metronome / count-in
   - `dsp.metronome_max_onset_error` against sample-derived expected beat times.
   - `dsp.metronome_end_to_end_drift` across the capture.
   - `dsp.count_in_max_onset_error` for preroll clicks.
4. Tempo / pitch / artifact / latency
   - `dsp.tempo_ratio_error` from requested versus measured output ratio.
   - `dsp.pitch_error` in cents from requested versus measured semitone shift.
   - `dsp.render_latency`: instrumented audio/control response latency, explicitly not planner CPU time.
   - `dsp.transient_peak_loss` and `dsp.noise_floor_increase` as objective guardrails.
   - Listening review remains mandatory for formant/timbre/transient/musical artifact acceptance.

## Provisional engineering thresholds

These values are Lane 3 engineering guardrails, **not measured Moises Reference guarantees**. HQ may tighten or supersede them after physical-device/reference evidence. A run must preserve the threshold profile identifier `LANE3_PROVISIONAL_ENGINEERING_NOT_REFERENCE` so provisional numbers cannot be misrepresented as observed competitor behavior.

| Metric | Provisional threshold |
| --- | ---: |
| stem onset skew | <= 2.0 ms |
| seek audible gap | <= 100 ms |
| maximum loop boundary drift | <= 2.0 ms |
| loop end-to-end drift | <= 2.0 ms |
| controlled gain step / local RMS | <= 12 dB |
| gain transition settling | <= 20 ms |
| metronome max onset error | <= 2.0 ms |
| metronome end-to-end drift | <= 1.0 ms |
| count-in max onset error | <= 2.0 ms |
| tempo ratio error | <= 0.10% |
| pitch error | <= 5 cents |
| instrumented render/control latency | <= 100 ms |
| transient peak loss | <= 3 dB |
| noise-floor increase | <= 6 dB |

The gain-step, transient and noise-floor thresholds are only objective alarms. Passing them cannot establish inaudibility; physical-device listening review is required.

## Capture contract for HQ late integration

The platform adapter should capture actual observations without changing Lane 3 core behavior:

1. Use an app-owned, rights-cleared real fixture and record its provenance in `Lane3FixtureManifest`.
2. For stem onset skew, place or identify a common transient/marker in each stem and record actual output onset timestamps from the same capture clock.
3. For seek, timestamp the control command and first valid post-seek output in the same monotonic clock domain.
4. For loop drift, record expected absolute loop boundary times and actual detected boundary times for a long repeated run. Never derive later boundaries by repeatedly adding the previous measured error.
5. For gain/solo/mute, use a controlled continuous fixture, record local RMS, maximum adjacent sample discontinuity around the transition, settling interval, and a human audible-artifact verdict.
6. For metronome/count-in, derive expected timestamps from the sample-time planner and compare actual click onsets from captured audio.
7. For tempo/pitch, record requested and independently measured output ratio/semitone shift plus latency, transient loss, noise-floor change and listening verdict.
8. Encode the report with `Lane3DeviceMeasurementHarness.encodeJSON` and validate it against `L3-M01_RESULT.schema.json`.

## Fail-closed rules

`parityEvidenceEligible` is false unless **all** of these are true:

- fixture rights are `rightsCleared`;
- fixture contains real audio;
- capture surface is `physicalIPhone`;
- actual output audio was captured;
- automated measurements pass;
- gain and practice-DSP human artifact reviews are complete and pass;
- Reference differential has been completed for the run.

Synthetic data remains useful for harness regression only. It cannot satisfy the real-audio gate. A schema-valid JSON document or green automated metric set is not a PARITY claim.

## Portable regression

Executed in the Worker 3 Linux environment with Swift 6.2.1:

```text
swiftc -O Lane3DeviceMeasurementHarness.swift L3_M01_MeasurementHarnessSelfTest.swift
L3-M01 measurement harness self-test: PASS
```

Coverage includes:

- harness-only values may pass engineering thresholds while PARITY eligibility remains false;
- a fully populated physical-device/rights/listening/reference record can become evidence-eligible;
- synthetic-only fixtures fail closed;
- timing count mismatch and non-monotonic capture fail with explicit errors;
- excessive onset skew/seek gap produce an automated gate failure instead of silent acceptance;
- JSON encoding is exercised.

## Deferred Apple/runtime work

This bundle intentionally does not edit `Package.swift`, `iOS/**`, `Shared/**` or `App/**`. HQ/Lane 4 owns platform wiring. Actual AVAudioEngine capture, physical-device audio loopback/recording, Apple SDK compilation and Moises differential execution remain late-integration evidence. Those deferred steps must use the same result contract rather than inventing a second pass criterion.
