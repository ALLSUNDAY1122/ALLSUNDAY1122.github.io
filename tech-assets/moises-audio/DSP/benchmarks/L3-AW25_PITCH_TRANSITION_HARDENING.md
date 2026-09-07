# L3-AW25｜Pitch Transition Click/Pop Hardening

Result: `COMPLETE_NON_PARITY`

AW23 made pitch/key mutation authoritative and serialized, but the selected Apple baseline still wrote `AVAudioUnitTimePitch.pitch` as one immediate value. AW25 adds a bounded transition contract so large interactive pitch changes can use the Audio Unit parameter scheduler instead of relying on UI/actor-timed micro-steps.

## Production changes

- `DSP/Sources/PracticeDSPPitchTransition.swift`
  - portable transition policy/planner/receipt
  - immediate, scheduled-ramp and explicit immediate-fallback modes
  - cancellation-insensitive short transition barrier
- `DSP/Sources/PracticeDSPTransactionalApplication.swift`
  - pitch-only transactions may remain open across a short asynchronous transition barrier
  - actor reentrancy during that barrier is fail-closed with `transactionInFlight`
  - logical state commits only after final backend readback matches the requested pitch
  - begin/finalize/readback mismatch rolls back to the exact pre-transition backend state
  - rollback failure poisons the gate for explicit recovery
  - production controller exposes the last pitch-transition receipt without advancing click generation
- `DSP/Sources/AppleTimePitchPitchTransition.swift`
  - intended Apple path uses `AUAudioUnit.scheduleParameterBlock`
  - ramp is used only when render resources are allocated and the pitch parameter advertises `flag_CanRamp`
  - unsupported/unready cases use the prior immediate setter and record the fallback reason
- `DSP/Sources/Lane3DSPRuntimeTelemetryAdapters.swift`
  - AW22 telemetry wrapper now preserves the pitch-transition protocol instead of erasing Apple ramp capability
  - non-transition backends explicitly report `backendTransitionUnsupported`

## Provisional interactive policy

The current policy is preparation for device tuning, not a final Moises-equivalent threshold:

- delta `<= 0.20` semitone: immediate
- minimum ramp: `8 ms`
- slope: `2 ms / semitone`
- maximum ramp: `32 ms`
- settle guard: `4 ms`
- maximum scheduled ramp: `4096 frames`

Examples at 48 kHz:

- 1 semitone -> 384 ramp frames, 12 ms total barrier
- 6 semitones -> 576 ramp frames, 16 ms total barrier
- 12 semitones -> 1152 ramp frames, 28 ms total barrier

At very high sample rates the 4096-frame cap prevents an unbounded barrier. Physical-iPhone AW24 evidence must tune this policy against responsiveness and audible artifacts.

## Why not Task.sleep micro-stepping

AW25 deliberately does not implement a loop that repeatedly sleeps and writes small pitch increments. Scheduler jitter from the app actor/task layer should not define the audio-domain transition. The Apple adapter instead prepares one sample-frame ramp event. The gate waits only so no later DSP/control mutation can interleave before the scheduled transition is considered complete.

## Transaction semantics

For a pitch-only mutation where the selected backend supports `PracticeDSPPitchTransitionBackendApplying`:

1. Read the physical backend and require it to match the last committed logical state.
2. Begin a transition and validate its NON_PARITY receipt.
3. If scheduled, hold `transactionInFlight` for the bounded ramp + settle duration.
4. Finalize the exact target value.
5. Read the backend again and require target alignment.
6. Commit the logical `PracticeDSPState` only after step 5.

While step 3 is suspended, `apply`, `commitControlOnly` and recovery fail closed with `transactionInFlight`. This prevents actor reentrancy from allowing tempo/metronome/count-in or another direct gate mutation to enter a backend that is still ramping. AW23 remains the selected product-level serializer above this gate.

Pitch-only success still preserves `scheduleGeneration`; pitch is not falsely converted into a transport/click discontinuity.

## Failure / recovery

Portable tests cover:

- transition-begin failure -> exact old state restored
- transition-finalize failure -> exact old state restored
- final readback mismatch -> exact old state restored
- rollback failure -> gate marked desynchronized
- reentrant control-only mutation during ramp -> `transactionInFlight`
- telemetry wrapper around a transition-capable backend -> scheduled-ramp capability preserved
- telemetry wrapper around a legacy backend -> explicit `backendTransitionUnsupported` immediate fallback

## Apple adapter evidence boundary

Apple documentation states that `AUScheduleParameterBlock` schedules parameter changes and a nonzero `rampDurationSampleFrames` requests a ramp; hosts should check parameter flags for ramp capability. `AUEventSampleTimeImmediate` requests execution as soon as possible in the render cycle. `kNewTimePitchParam_Pitch` identifies the NewTimePitch pitch parameter.

AW25 only authors this selected-device path. This environment cannot compile or execute AVFAudio/AudioToolbox on the target iPhone. Therefore:

- Apple adapter selected-Xcode compile: pending HQ
- runtime confirmation that NewTimePitch pitch exposes `flag_CanRamp` on target iOS: pending HQ
- actual scheduled-ramp execution: pending HQ
- audible click/pop/warble/phasiness/formant quality: pending HQ
- current-Moises differential/listening: pending HQ

An `immediateFallback` receipt is not evidence that the ramp path worked. For P012 device evidence, HQ should record the transition receipt and distinguish `.scheduledRamp` from every fallback reason.

## Portable validation

Environment:

- Swift 6.2.1
- Linux x86_64
- strict concurrency complete
- warnings as errors

Self-test PASS:

`L3-AW25 pitch transition self-test PASS ramps=5 reentrancy=blocked failures=rolledBack telemetryTransitionPreserved=true generationPreserved=true`

Validated:

- immediate threshold planning
- 1/6/12-semitone frame/barrier planning
- 4096-frame high-rate cap
- invalid sample-rate rejection
- scheduled transition final commit/readback
- reentrancy block
- begin/finalize/mismatch rollback
- rollback-failure desynchronization
- AW22 telemetry protocol preservation and explicit fallback
- production-controller pitch-only schedule-generation preservation

Portable benchmark:

- rounds: 20
- transitions per round: 5,000
- total transitions: 100,000
- median: 212.518 ms / round
- p95: 233.649 ms / round
- max: 269.458 ms / round
- checksum: 134315520

Benchmark uses a fake synchronous transition backend and no-op sleeper. It measures planner/transaction/receipt overhead only and excludes actual waiting, AVFAudio, Audio Unit rendering, audio IO, physical-device latency and listening.

## HQ device integration requirements

1. Build the selected graph with `AppleTimePitchBackend` underneath `Lane3DSPTelemetryTransactionalBackend`; AW25 requires the telemetry wrapper to preserve transition capability.
2. Route product pitch through AW23 `Lane3UnifiedPracticeControlAuthority`; direct controller calls remain invalid product evidence.
3. After each representative device pitch operation, read `PracticeDSPProductionController.pitchTransitionReceipt` before unrelated DSP mutation clears it.
4. Require a valid `LANE3_AW25_PITCH_TRANSITION_NON_PARITY` receipt and record mode/fallback for the AW24 pitch case.
5. On target iPhone verify whether the live NewTimePitch pitch parameter is rampable and whether render resources/sample rate are valid.
6. Tune the provisional 8–32 ms policy using AW22 latency plus AW24 current-Moises A/B and listening; do not tune from portable timing.
7. Test rapid positive/negative semitone gestures, tempo→pitch and pitch→tempo, interruption during pitch, and no click/pop/desync.
8. Keep P012 MISSING until physical-device audio, current-Moises differential, human listening and chord-display transposition all pass HQ judgment.
