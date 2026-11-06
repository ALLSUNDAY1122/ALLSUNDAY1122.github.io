# L3-M04 Offline / Reference Render Contract

Status: Lane 3 portable control-reference path complete. This document and all generated examples are **NON-PARITY evidence**. Audible quality, Apple runtime behavior, real-device latency, and Moises differential acceptance remain HQ Late Integration gates.

## Purpose

`Lane3OfflineReferenceRender.swift` converts an explicit stem/practice fixture into a deterministic frame-domain render plan without depending on the final app shell, iOS lifecycle, wall-clock timers, Shared/App mutation, or AVFAudio availability.

The plan is intended to be the common expected-timeline input for later Apple offline rendering, physical-iPhone capture, and Moises-vs-project differential measurement. It does not imitate Moises audio or use proprietary assets.

## Input contract

A fixture declares:

- a stable `fixtureID`;
- one or more stem descriptors: stable ID, project start time, source frame count, source sample rate, effective gain;
- explicit project render range;
- output sample rate;
- tempo ratio, pitch semitones, metronome state, optional count-in click count and downbeat stride;
- an ordered source beat grid and explicit count-in beat interval.

Fail-closed validation rejects empty stems, duplicate stem IDs, non-finite/invalid timing, unsupported engineering ranges, invalid gain, non-monotonic or duplicate beat times, same-output-frame metronome collisions, count-in without an interval, and timeline overflow.

The portable engineering ranges intentionally match the current Lane 3 Apple baseline capability envelope: tempo `0.03125...32`, pitch `-24...24` semitones, count-in `1...32` clicks. Product/tier limits remain a separate HQ/App policy concern.

## Deterministic render plan

The planner computes:

1. Count-in pre-roll frames from the explicit source beat interval and tempo ratio.
2. Music start frame after pre-roll.
3. Per-stem source intersection with the requested project range.
4. Source start/frame count for each intersecting stem.
5. Tempo-adjusted render start/frame count on one output sample clock.
6. Expected events for practice state, count-in, music start/end, stem start/end, and metronome clicks.
7. A stable `controlSignatureFNV1A64` over exact IEEE-754 bit patterns, integer frames, IDs and event metadata.

FNV-1a is used only as a deterministic control-manifest fingerprint. It is **not cryptographic**, is not an audio integrity hash, and must not be used to establish asset authenticity or PARITY.

No position is advanced by repeatedly adding floating-point loop durations. Long duration timing is always computed from an explicit source time to an integer output frame.

## Machine-readable evidence

- `L3-M04_REFERENCE_FIXTURE.schema.json`: fixture schema.
- `L3-M04_REFERENCE_FIXTURE.example.json`: non-parity example input.
- `L3-M04_PLAN.example.json`: deterministic expected control plan.
- `L3-M04_OBSERVATION_TEMPLATE.example.json`: expected observation skeleton for a future renderer/capture.
- `L3-M04_VALIDATION.json`: local portable validation record.

`Lane3ReferenceEvidenceEncoder` serializes plans with sorted JSON keys. `Lane3ReferenceComparator` checks fixture/signature identity, duration, ordered event identity/timing, and optional audio-summary deltas. It always returns `parityPromotionAllowed = false` because this comparator is not the final product gate.

## Audio comparison hook

`Lane3PCMAnalyzer` provides a portable summary for decoded interleaved Float PCM:

- frame count;
- peak absolute amplitude;
- RMS;
- DC offset;
- non-finite sample count.

The comparator can enforce duration/event tolerances and summary peak/RMS deltas when actual decoded audio is supplied. Summary equality is intentionally insufficient for audible equality; waveform-level artifact analysis, transient/noise metrics, human listening, and Reference differential remain required through the L3-M01 device-measurement gate.

## Long-track benchmark

Portable benchmark workload:

- 24-hour project range;
- 8 stems at 48 kHz with staggered starts;
- tempo ratio 0.75 and pitch -2 semitones;
- 4-click count-in;
- 172,801 source beats (120 BPM over 24 hours);
- 172,824 expected events per plan;
- 12 full plan generations.

Swift 6.2.1, x86_64 Linux, optimized build:

- median: 118.834 ms
- p95: 143.252 ms
- p99: 143.252 ms
- max: 143.252 ms
- deterministic signature: `bceee1be47217988`

This measures control-plan generation only. It does not measure PCM render throughput, iPhone CPU/thermal behavior, AVAudioEngine latency, or battery use.

## Exact HQ Late Integration checks

HQ must perform the following before any affected PARITY row can advance:

1. Compile all Lane 3 sources with the selected Xcode/iOS SDK, including `AppleTimePitchBackend`, the existing Apple offline renderer, Playback backend, and new portable reference-plan types.
2. Map actual integrated stem artifacts and effective solo/mute/volume state into the fixture descriptor without changing the deterministic frame contract.
3. Run the Apple offline renderer / integrated Apple graph using the same tempo/pitch settings and capture the actual output file plus actual event/sample-time observations.
4. Decode the resulting artifact and populate `Lane3ReferenceObservation` with actual frame count/events/audio summary; do not mark `actualAudioCaptured` true without an actual captured/rendered audio artifact.
5. Feed the same rights-cleared fixture into the L3-M01 physical-device measurement harness for onset skew, seek gap, loop drift, gain transitions, click timing, tempo/pitch accuracy, artifact and latency metrics.
6. Verify the live Apple mixer executes a real ramp or equivalent click-safe gain transition; the portable 12 ms gain plan alone is not audible proof.
7. Verify count-in and metronome are scheduled from the authoritative sample clock and reject stale generation tokens after seek/loop/tempo/interruption changes.
8. Run rights-cleared real multi-genre physical-iPhone captures and human listening review.
9. Run differential comparison against current iPhone Moises Reference under the HQ protocol.
10. Only HQ may update `PARITY_MATRIX.json`; this plan/comparator never promotes PARITY by itself.

## Scope boundary

No `Shared/**`, `App/**`, `Package.swift`, `iOS/**`, Queue, resource lock, or PARITY file is modified by L3-M04. Cross-lane adapter or package wiring is deliberately deferred to HQ Late Integration.
