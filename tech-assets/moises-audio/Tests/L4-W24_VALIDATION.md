# L4-W24 Validation

Wave: `L4-W24｜Physical-iPhone Analysis performance repeatability / worst-case acceptance gate hardening`

Evidence class: **NON_PARITY_PORTABLE_SYNTHETIC**.

## What changed

Added `AnalysisDevicePerformanceAcceptance.swift` as the post-W23 acceptance layer for MOI-P021 physical-device evidence.

The W24 profile is HQ-owned and binds the exact:

- batch ID
- iPhone model
- iOS version
- app bundle/version/build
- Analysis manifest ID/SHA-256
- required fixture IDs and expected durations
- complete/cancellation repetition requirements
- exact predeclared run IDs
- approved performance limits

No Worker-4 production limit values are supplied.

## Anti-cherry-picking behavior

The run-ID set in the submitted batch must exactly match the HQ-predeclared run plan.

A missing planned run is `MISSING_PLANNED_RUN`; an unplanned replacement is `UNEXPECTED_RUN`; duplicate IDs are rejected. Therefore an unfavorable planned run cannot be dropped while preserving only the favorable minimum-count subset.

The profile itself requires at least two complete-analysis runs and two cancellation probes per fixture.

## Worst-case behavior

For each required fixture W24 retains the worst value and exact run ID for:

1. complete-analysis wall seconds
2. peak resident bytes
3. peak physical-footprint bytes
4. worst thermal-state rank
5. battery drain fraction
6. memory-pressure event count
7. cancellation latency seconds

No favorable mean is used for acceptance. Equal worst values resolve deterministically to the lexicographically smaller run ID.

## Fail-closed behavior exercised

Portable adversarial coverage exercised:

- approved repeated physical-run happy path
- worst wall-time run retained instead of a mean
- missing planned run
- unexpected run
- duplicate run ID
- mixed app build
- simulator/nonphysical runtime
- W23 telemetry-incomplete record
- failed complete-analysis run
- charging battery precondition
- excessive starting thermal state
- fixture-duration mismatch
- insufficient predeclared repetitions
- resident-memory limit breach
- physical-footprint limit breach
- thermal limit breach
- battery-drain limit breach
- memory-pressure limit breach
- cancellation-latency limit breach
- deterministic profile codec
- deterministic worst-run tie break

## Portable validation

Environment: Swift 6.2.1, x86_64 Linux.

- W24 production source-shaped typecheck against the W23 public surface: PASS.
- Durable `AnalysisDevicePerformanceAcceptanceTests.swift` Swift parse: PASS.
- Optimized portable adversarial harness: `18/18` assertions PASS in each of five clean runs.

### 50,000-run stress

Each stress run contained:

- 12,500 fixture IDs
- two planned complete-analysis runs per fixture
- two planned cancellation probes per fixture
- 50,000 total run records

Results after indexing optimization:

| Run | Internal seconds | Process wall seconds | Max RSS kB |
| --- | ---: | ---: | ---: |
| 1 | 0.321060 | 0.36 | 128040 |
| 2 | 0.335137 | 0.37 | 128072 |
| 3 | 0.323139 | 0.36 | 128068 |
| 4 | 0.309577 | 0.34 | 128052 |
| 5 | 0.316576 | 0.35 | 128092 |

Every stress run produced `WITHIN_HQ_APPROVED_LIMITS_PENDING_HQ` under the synthetic supplied limits.

The stress timings above measure W24 evaluator overhead only. They are **not** physical-iPhone Analysis performance evidence.

## Canonical Apple/device gate still pending

W24 did not execute an iPhone. The following remain HQ Late Integration work:

- canonical SwiftPM/Xcode XCTest execution
- active UIKit/Darwin W23 collector compilation
- actual representative long-track physical-iPhone runs
- production threshold approval
- build/device evidence corroboration
- thermal/battery test-environment control
- final MOI-P021 judgment

`WITHIN_HQ_APPROVED_LIMITS_PENDING_HQ` is explicitly not PARITY.
