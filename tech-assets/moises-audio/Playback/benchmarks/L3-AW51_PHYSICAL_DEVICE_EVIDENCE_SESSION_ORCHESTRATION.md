# L3-AW51 | Physical Device Evidence Session Orchestration

Result: `COMPLETE_NON_PARITY`

## Purpose

AW51 does not synthesize physical evidence. It prepares one fail-closed physical-iPhone session that can collect the already-required Lane3 evidence for `MOI-P006`, `P007`, `P008`, `P010`, `P012`, `P014`, `P015`, and `P021` without changing PARITY state until real artifacts exist and HQ reviews them.

The implementation reuses the existing AW24 device-evidence bundle/validator and AW40 seek-loop physical-session analyzer. It adds only session preflight, ordered orchestration, long-track resource receipts, and an authoritative strict completion gate.

## Preflight contract

A session cannot start unless all of the following are declared ready:

- physical iPhone and selected Xcode build with build commit SHA;
- built-in/wired/USB timing route (`bluetoothA2DP` remains rejected for timing evidence);
- safe privacy snapshot with no raw audio/PCM/path/project/device/generation identifiers in the manifest;
- named rights-cleared real-audio fixture of at least 1,800 seconds;
- current-iPhone Moises snapshot ID and version;
- all eight AW24 scenario harnesses;
- timing instrumentation and external audible marker;
- candidate and current-Moises capture paths;
- human listening review path;
- interruption trigger;
- RSS, thermal, battery, unpowered battery-drain, and current-Moises resource sampling readiness.

`makePlan` emits 27 ordered steps: three steps for each of seven normal scenarios, five for long-track stability (candidate resource trace + candidate execution + reference resource trace + reference execution + listening), then final bundle publication.

## PARITY row mapping

- mixer gain ramp -> `MOI-P006`
- seek/loop -> `MOI-P007`, `MOI-P008`
- tempo -> `MOI-P008`, `MOI-P010`
- pitch -> `MOI-P012`
- metronome -> `MOI-P014`
- count-in -> `MOI-P015`
- interruption recovery -> supporting resilience evidence, no direct row promotion
- long-track stability -> `MOI-P007`, `MOI-P021`

The plan always carries `parityPromotionAllowed=false`.

## P021 resource trace

Candidate and current-Moises long-track traces are session-bound and non-parity. The low-level completion evaluator requires:

- `longTrackStability` scenario;
- at least 1,800 seconds observed;
- at least 60 samples;
- maximum sample interval <= 30 seconds;
- non-zero peak RSS;
- thermal observations;
- finite battery levels in `0...1`;
- no external power during the battery window;
- lowercase SHA-256 digest of the trace artifact.

The strict completion gate additionally requires exactly one candidate trace and exactly one current-Moises trace for the session, non-negative thermal counters, and exactly one thermal state per resource sample.

## Strict completion binding

`Lane3PhysicalEvidenceSessionCompletionGate` is the HQ-facing completion authority for AW51. It wraps the lower-level AW24/AW51 completion primitive and rejects:

- an AW24 bundle that is not itself ready for HQ review;
- any AW24 case using a fixture different from the preflight fixture;
- duplicate candidate resource traces;
- duplicate current-Moises resource traces;
- negative thermal counters;
- thermal sample coverage that does not equal the resource-trace sample count.

The strict report still sets `parityPromotionAllowed=false`. Passing it means only `readyForHQReview`, never PARITY.

## Portable/focused verification

Worker environment: Swift 6.2.1, Linux x86_64, language mode 6, strict concurrency complete, warnings as errors, optimized build.

A self-contained logic reproduction passed:

- 27 ordered steps;
- eight targeted PARITY rows;
- 1,310 primary fail-closed preflight cells (missing scenarios, capability toggles, Bluetooth route, short long-track fixture);
- strict completion negative cases for fixture mismatch, duplicate traces, negative thermal counters, and missing thermal coverage;
- focused plan construction approximately 2.41 microseconds/plan on one Linux run.

This timing is only a portable orchestration-cost reference. It is not iPhone, AVFAudio, RSS, thermal, battery, audio, or Moises performance evidence.

Repository-native files authored:

- `Playback/Tests/L3_AW51_PhysicalEvidenceSessionOrchestrationSelfTest.swift`
- `Playback/Tests/L3_AW51_PhysicalEvidenceSessionOrchestrationStress.swift`
- `Playback/Tests/L3_AW51_PhysicalEvidenceSessionOrchestrationBenchmark.swift`

The stress defines 1,000 ready cells plus 1,312 rejected cells. The benchmark defines 20,000 plan constructions. These repository-native executables were authored but not run from a full Worker-branch checkout because the Worker environment cannot resolve GitHub for cloning.

## What AW51 does not prove

AW51 does not prove any of the following:

- selected Xcode/AVFAudio execution;
- physical-iPhone playback correctness or latency;
- click/pop/desync absence on real hardware;
- real RSS/thermal/battery behavior;
- current-Moises differential equivalence;
- blind/human listening non-inferiority;
- P012 chord-display transpose consistency across lanes;
- any PARITY promotion.

Those remain physical/HQ gates. The point of AW51 is to ensure the next physical session cannot begin with missing instrumentation or end with mixed/incomplete evidence while appearing complete.
