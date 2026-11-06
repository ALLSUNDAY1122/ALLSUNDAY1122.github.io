# L3-AW52 | Candidate Physical Resource Trace

Result: `COMPLETE_NON_PARITY`

## Goal

Populate the **candidate-side** P021 resource evidence required by AW51 using public selected-iOS/Darwin surfaces without inventing metrics for the third-party current-Moises process.

## Implementation

- `Lane3CandidatePhysicalResourceTraceAccumulator`
  - portable sample/receipt core;
  - strictly increasing `ProcessInfo.systemUptime` domain;
  - RSS must be non-zero;
  - battery must be finite `0...1`;
  - canonical binary trace artifact with IEEE-754 bit patterns + little-endian integers;
  - AW51 candidate receipt is emitted only for >=1800 seconds, >=60 samples, max gap <=30 seconds, no externally powered sample, valid lowercase SHA-256.
- `Lane3AppleCandidatePhysicalResourceRecorder`
  - `@MainActor` selected-iOS recorder;
  - recommended host cadence: 15 seconds;
  - battery: `UIDevice.batteryLevel` + `batteryState`; battery monitoring is enabled for the recorder lifetime and restored on successful finish/cancel when AW52 enabled it;
  - thermal: `ProcessInfo.thermalState` mapped fail-closed to nominal/fair/serious/critical;
  - candidate process RSS: `task_info(mach_task_self_, MACH_TASK_BASIC_INFO, ...)` / `resident_size`;
  - artifact SHA-256: CryptoKit `SHA256` over the exact canonical artifact bytes;
  - charging/full samples are recorded as externally powered and therefore cannot produce an AW51-ready receipt.

## Evidence boundary

AW52 can measure the candidate app because it owns that process. It does **not** inspect, estimate, infer, or fabricate current-Moises process RSS. If a stock iPhone does not expose a defensible reference-side RSS surface, HQ must revise the comparison contract explicitly or use an allowed external measurement surface.

AW52 also does not claim:

- selected-Xcode compile PASS;
- physical-iPhone execution;
- real RSS/thermal/battery values;
- current-Moises resource values;
- battery-drain precision beyond the `UIDevice` battery-level surface;
- P021 or any other PARITY promotion.

## Portable focused verification

Swift 6.2.1 / Linux x86_64, language mode 6, strict concurrency complete, warnings-as-errors, optimized build:

- stable 121-sample / 15-second trace: PASS;
- duration: 1800 seconds;
- sample count: 121;
- max interval: 15 seconds;
- expected peak RSS fixture: `200491520` bytes;
- thermal coverage: 31 nominal + 30 fair + 30 serious + 30 critical = 121;
- canonical artifact size: 3214 bytes;
- canonical artifact FNV1A64: `14041105997891895343`;
- independent Python `hashlib.sha256` and Swift-produced artifact file `sha256sum` both produced:
  `1fab95e460f8f53a2130d2be6a082d36d172b6cd8b5e1eef68b084419ba75cca`.

Stress-equivalent focused execution:

- 300 valid traces across 10/12/15/20/25/30-second cadences: PASS;
- 482 rejection cells: 121 external-power positions + 120 non-monotonic positions + 120 >30-second gap positions + 121 invalid-battery positions: PASS.

Portable reference benchmark:

- 5000 complete 121-sample traces including artifact construction + receipt aggregation;
- one optimized Linux run: ~0.410 s total, ~82 microseconds/trace;
- this is orchestration cost only and is not an iPhone performance claim.

## Physical execution contract

1. Use a rights-cleared >=30-minute real-audio fixture and the same AW51 session identifier.
2. Run candidate long-track playback on a physical iPhone selected Xcode build.
3. Ensure battery monitoring has warmed enough to return a real level/state; unknown (`-1`) fails closed.
4. Keep the battery window unplugged; any charging/full sample prevents receipt finalization.
5. Invoke `sample()` every 15 seconds. A >30-second observed gap prevents receipt finalization.
6. After >=1800 seconds, call `finish()` and persist the returned canonical artifact bytes together with the AW51 receipt.
7. Feed that receipt into `Lane3PhysicalEvidenceSessionCompletionGate` together with the separately acquired current-Moises reference evidence.
8. HQ alone decides P021/PARITY.
