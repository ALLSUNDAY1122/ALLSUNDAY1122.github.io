# L3-AW24｜Device Evidence / Listening Runbook

Result: `COMPLETE_NON_PARITY`

This Wave does not claim device, audible, current-Moises, or PARITY success. It makes the later HQ physical-iPhone evidence gate reproducible and machine-checkable.

## Why AW24 exists

AW13 binds the exact offline/reference PCM pair, control signature, production generation, recovery lineage, alignment and analyzer output into one SHA-256 run binding. AW15-AW23 then harden production authority, interruption behavior, click lifecycle and telemetry. Before AW24, HQ could still accidentally combine:

- a device capture from a different app build,
- a current-Moises capture from another fixture/control state,
- a listening note written against an older capture,
- Bluetooth timing with uncontrolled route latency,
- a telemetry window containing unscoped backend/click calls,
- or a short run presented as long-track evidence.

AW24 adds a device-evidence bundle validator and an AW13 adapter so those mixtures fail closed before HQ considers PARITY.

## Production files

- `Playback/Sources/Lane3DeviceEvidenceBundle.swift`
- `Playback/Sources/Lane3DeviceEvidenceAW13Adapter.swift`

Repository validation:

- `Playback/Tests/L3_AW24_DeviceEvidenceBundleSelfTest.swift`
- `Playback/Tests/L3_AW24_DeviceEvidenceBundleBenchmark.swift`

## Required physical-iPhone scenarios

Exactly one validated case is required for each scenario in one review bundle:

1. `mixerGainRamp`
   - Exercise solo/mute/volume transitions on real separated stems.
   - Minimum 10 successful repetitions.
   - No click/pop, desync, underrun or non-finite event.

2. `seekLoop`
   - Repeated seek and loop-boundary operations on a real track.
   - Minimum 10 successful repetitions.
   - Include tempo interaction in the selected product flow where applicable.

3. `tempo`
   - Positive/negative speed changes covering representative product range.
   - Minimum 10 successful repetitions.
   - Measure AW22 submission-to-DSP-entry/backend execution and compare current Moises audibly.

4. `pitch`
   - Representative negative/positive semitone changes plus rapid gesture.
   - Minimum 10 successful repetitions.
   - Use AW23 selected authority; direct `PracticeDSPProductionController.setPitchSemitones` is not valid product evidence.

5. `metronome`
   - Beat-aligned click on real studio/live material.
   - Minimum 10 successful repetitions.
   - Capture drift/phase behavior and click schedule timing.

6. `countIn`
   - Verify count-in start behavior and final-click-to-music-start timing.
   - Minimum 10 successful repetitions.
   - Pre-interruption count-in must not auto-restore.

7. `interruptionRecovery`
   - Phone/Siri/audio-route interruption cases.
   - Minimum 5 successful episodes.
   - Verify no stale/doubled click, stale pitch, accidental auto-resume or generation reuse.

8. `longTrackStability`
   - Continuous representative real-track run for at least 1,800 seconds.
   - No underrun, desync, click/pop or non-finite event.

## Build / device identity rules

The evidence bundle must identify:

- exact 40-character Git commit used for the selected app build,
- device model identifier,
- iOS version,
- physical-device = true,
- selected-Xcode-build = true,
- current-Moises reference snapshot ID and app version.

Do not store UDID, serial number, advertising identifier, ProjectID or user identity.

## Audio-route rule

Timing evidence is valid only for:

- built-in speaker,
- wired headphones,
- USB audio.

`bluetoothA2DP` is deliberately rejected for timing evidence because route buffering adds uncontrolled latency. Bluetooth can be tested separately as product compatibility evidence but must not be substituted for this timing bundle.

## AW13 chain-of-custody rule

Create every `Lane3DeviceEvidenceCaseReceipt` using the AW13 adapter when the full Lane-3 source set is available:

`Lane3DeviceEvidenceCaseReceipt(aw13:scenario:...)`

The adapter copies these fields from the exact `Lane3UnifiedEvidenceReportV2`:

- fixture ID,
- control signature FNV-1a64,
- AW13 run-binding SHA-256.

It rejects an AW13 report unless it is marked ready for real-audio review and still carries all NON_PARITY claim guards.

Do not manually re-key these fields in the selected integration route.

## Capture identity

For every scenario record SHA-256 digests for:

- candidate device capture,
- current-Moises comparison capture.

The manifest stores only digests, not raw audio/PCM or file paths. Raw rights-cleared artifacts may live in the HQ-approved evidence store, but the durable manifest must stay content-free.

The AW24 case binding SHA-256 includes:

- scenario,
- fixture/control/AW13 binding,
- candidate/reference capture digests,
- repetition counts,
- observed duration,
- real-audio/rights/current-Moises flags,
- timing summary,
- AW22 health counters.

Changing any bound field after capture changes the recomputed binding and invalidates the case.

## Telemetry health rule

A selected device window is rejected when any of the following is nonzero/true:

- AW22 `unscopedBackendApplyCalls`,
- AW22 `unscopedClickInvalidationCalls`,
- telemetry counter overflow,
- detected click/pop events,
- desync events,
- underrun events,
- non-finite sample events.

This is intentional. A partially instrumented product route must not produce performance evidence.

## Timing summary

Each scenario must provide a finite nonnegative timing distribution:

- samples > 0,
- p50 >= 0,
- p95 >= p50,
- max >= p95.

AW24 intentionally does not hard-code a Moises parity threshold. HQ compares candidate/reference behavior and user-perceived response on the same evidence case. The validator verifies completeness and chain-of-custody, not the final product-quality judgment.

## Listening review

Every scenario must have exactly one `Lane3DeviceListeningReview` bound to that scenario's `caseBindingSHA256`.

Minimum:

- 3 listening passes,
- no obvious candidate inferiority versus current Moises,
- no click/pop,
- no obvious warble inferiority,
- no obvious phasiness inferiority,
- no obvious formant-damage inferiority.

Listening review is intentionally stored without reviewer name or other personal identifier. HQ may use its own separate reviewer audit process, but the Lane-3 manifest only needs the bound verdict.

If the evidence case is altered after listening, `listeningBindingMismatch` is raised and listening must be repeated against the new case.

## Privacy boundary

The AW24 manifest must never contain:

- raw audio,
- raw PCM,
- local file path,
- ProjectID,
- device UDID/serial/other unique identifier,
- individual Playback/click generation or ticket values.

This preserves the AW19/AW22 aggregate privacy contract.

## Machine acceptance

Run:

`Lane3DeviceEvidenceValidator.validate(bundle)`

A bundle is only prepared for HQ quality judgment when:

- `readyForHQParityReview == true`,
- `issues.isEmpty`,
- `parityPromotionAllowed == false`.

`readyForHQParityReview` is not PARITY. HQ still owns:

- selected integrated Xcode build,
- physical-iPhone execution,
- actual rights-cleared captures,
- current-Moises reference freshness,
- human listening judgment,
- cross-lane chord transpose consistency for P012,
- final `PARITY_MATRIX.json` update.

## Portable AW24 validation

Environment:

- Swift 6.2.1
- Linux x86_64
- `-strict-concurrency=complete`
- `-warnings-as-errors`

PASS checks:

- valid 8-scenario bundle becomes `readyForHQParityReview=true` while parity promotion remains disabled,
- Bluetooth timing rejected,
- missing scenario rejected,
- duplicate scenario rejected,
- AW22 unscoped backend call rejected,
- <1800-second long-track case rejected,
- device identifier privacy violation rejected,
- listening review bound to another capture rejected,
- JSON-tampered repetition count invalidates case binding,
- Codable round-trip preserves a valid bundle,
- AW13 adapter compiles against the exact expected `Lane3UnifiedEvidenceReportV2` interface contract.

Portable benchmark, 20 rounds × 1,000 full 8-scenario validations:

- median: 304.620 ms / round
- p95: 313.603 ms / round
- max: 326.969 ms / round
- checksum: 160000

This benchmark measures manifest validation and SHA-256 rebinding only. It excludes Xcode, AVFAudio, AVAudioUnitTimePitch, click scheduling, audio IO, device capture, listening and current-Moises execution.
