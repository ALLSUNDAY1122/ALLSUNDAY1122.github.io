# L4-W37 Validation

Bundle: `L4-W37｜Physical-iPhone Analysis capture orchestration / periodic telemetry + cancellation timing hardening`

Result: **WORKER COMPLETE / NON_PARITY**. This record proves orchestration hardening and durable tests only. It does not substitute for selected-Xcode or physical-iPhone evidence.

## Latest-state audit

- Notion v4 `4 Autonomous Independent Lanes / Late Integration` re-read before continuation.
- Worker branch was exactly at W37 commit `2abda0641f4f506401eff87493c1eb0d61d5f042` before continuation.
- Frozen-base compare: ahead 367 / behind 0 before continuation; returned file set was Worker-4 owned scope plus `worker-4.json` only.
- Integration PR #4431 is Epoch 23. Lane 4 is canonical through W36 source head `22d85e8bf0e25c110104cc2aa5d09bfcc87e444e`; W37 remains post-checkpoint Worker work.
- PARITY rows MOI-P009/P011/P013/P016/P021 remain MISSING and were not edited.

## Defect found during W37 continuation

The existing W23 session recorded `TELEMETRY_SAMPLE_CAP_REACHED` only as a limitation. The W37 coordinator did not interpret that limitation as a capture-integrity failure, so a run could otherwise remain structurally complete after periodic telemetry stopped at the cap.

Hardening added:

- W23 sampling now reports `CAPTURED`, `THROTTLED`, `CAP_REACHED`, or `FINISHED` explicitly.
- W37 records periodic sampling attempts/captures and fail-closes on cap reach.
- A capture lasting at least one requested interval must contain a periodic sample beyond start/final snapshots.
- Telemetry sampler is cancelled and joined before finalization.
- Pending cancellation helper is cancelled and joined immediately after W36 returns so it cannot survive the workload and create a telemetry-free tail.
- `cancellationObserved` remains recordable only after a real post-source-work cancellation request and a W36 `CANCELLED` result.
- Portable W37 execution-integrity evidence binds W23/W25/W35/W36 run IDs and W35/W36 execution ID.
- Batch validation rejects duplicate W37 run IDs and one W36 execution ID reused across distinct runs.

## Durable XCTest added

`AnalysisDeviceCapturePlanTests.swift` covers:

- valid HQ-bound complete and cancellation plans;
- malformed authority/sampling/cancellation plan;
- run-kind mismatch;
- fixture/source metadata mismatch;
- manifest mismatch;
- W23/W25/W35/W36 identity binding;
- non-bounded source rejection;
- telemetry cap, missing periodic sample and sampler cleanup failures;
- planned cancellation completing normally;
- cancellation before source work;
- reversed request/observed timing;
- cancellation-helper cleanup;
- duplicate run ID and reused execution ID;
- deterministic codec round trip;
- 2,000-iteration deterministic integrity stress.

`AnalysisIOSPhysicalCaptureCoordinatorTests.swift` is Apple-conditional and covers:

- explicit W23 telemetry-cap result;
- cap limitation persistence into evidence;
- forced final telemetry remaining inside the existing `maximumSampleCount + 1` bound;
- post-finish sampling rejection;
- battery-monitoring state restoration on finish.

## Validation executed in Worker environment

Environment: Swift 6.2.1, `x86_64-unknown-linux-gnu`.

1. Portable execution-integrity mirror stress: **PASS**.
   - 100,000 complete-run validations + 100,000 cancellation-run validations.
   - Adversarial cap, sampler leak, missing periodic sample, source-work-zero cancellation and reversed timing cases rejected.
   - Elapsed: approximately 0.02 s.
   - Maximum RSS: approximately 16,076 kB.
2. Apple-conditional source-shaped orchestration syntax parse with Swift frontend: **PASS**.
3. Full repository SwiftPM/XCTest: **NOT OBSERVED** in Worker environment. Direct GitHub checkout is unavailable because the environment cannot DNS-resolve `github.com`.
4. UIKit/Darwin typecheck and selected Xcode/Apple ARM build: **NOT OBSERVED**; HQ integrated Apple environment gate remains required.
5. Physical iPhone execution/telemetry: **NOT OBSERVED** and intentionally not fabricated.

## Acceptance mapping

- runKind mismatch: fail-closed by capture-plan/profile binding tests.
- fixture mismatch: fail-closed by capture-plan/profile/workload binding.
- manifest mismatch: fail-closed by capture-plan/profile/workload binding.
- source metadata mismatch: fail-closed by W25 policy/source equality.
- non-bounded source: fail-closed by preflight and execution-integrity validation.
- telemetry sampling unavailable: W23 remains incomplete/invalid rather than PARITY; periodicity/cap are additionally W37 fail-closed.
- planned cancellation normal completion: fail-closed.
- source-work-before-cancel requirement: fail-closed.
- request-before-observed timing: fail-closed.
- observed cancellation requires W36 CANCELLED: fail-closed.
- W23/W25/W35/W36 run identity: fail-closed.
- duplicate/reused execution: fail-closed by W37 batch gate and retained W25 batch validation.
- helper task cleanup: sampler and cancellation helper are joined before finish.
- sampling-cap silent success: eliminated.

## Remaining external gates

W37 does not close MOI-P021. Required later: genuine Lane-2 bounded decoder, selected Xcode/Apple ARM compile, physical iPhone W23/W36/W37 capture, real RSS/physical footprint/thermal/battery, HQ-supplied cancellation timing, repeated W24 worst-case acceptance, HQ thresholds, final evidence archive integrity, and HQ PARITY judgment.

Next Worker-4 candidate: `L4-W38｜Physical evidence archive role extension / W35-W37 capture-chain integrity hardening`.
