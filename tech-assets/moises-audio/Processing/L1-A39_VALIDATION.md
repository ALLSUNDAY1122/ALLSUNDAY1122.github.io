# L1-A39 Validation｜Crash-Safe Cancel-During-Start Relaunch Recovery

State: `COMPLETED_NON_PARITY`

Target: `MOI-P020` progress / cancel / retry / resume

## Problem found

`ProcessingLifecycleCoordinator.requestCancel(...)` intentionally persists cancellation intent before provider cancellation. While provider `start()` is still in flight, that durable record can be:

- `state = cancellationRequested`
- `jobID = nil`
- `stableErrorCode = PROC_CANCEL_REQUESTED_DURING_START`

If the app terminates at that exact seam, the remote provider may already have accepted the start even though no job ID was durably bound locally.

The pre-A39 generic relaunch path grouped all `cancellationRequested` records with normal active jobs and eventually required a `jobID`. For the unbound form this falls into `PROC_JOB_BINDING_MISSING`. Blind retry is also unsafe because a first provider job may already exist.

This is a real P020 recovery gap rather than an evidence-only issue.

## Existing safe primitive

Lane 1 already had `ProcessingAmbiguousStartResolver` and `StableProcessingIdempotencyKey`.

For providers that expose stable idempotent start, the resolver:

- derives one stable key from the durable generation UUID;
- reuses that key after network loss/relaunch;
- recognizes `cancellationRequested + jobID=nil` as preserved cancellation intent;
- persists a recovered job binding before remote cancellation;
- then performs cancel/rollback and persists the cancelled terminal state.

A39 does not duplicate that logic. It connects the lifecycle relaunch entrypoint to it.

## Implementation

Added:

`Processing/Sources/ProcessingCrashSafeRelaunchRecovery.swift`

The new `ProcessingCrashSafeRelaunchRecovery` actor is a Lane-1-owned relaunch front door. It composes:

- canonical `ProcessingLifecycleCoordinator` recovery;
- durable `ProcessingLifecycleStateStoring` state;
- optional `ProcessingAmbiguousStartResolver` capability.

Two small lane-local protocols make the composition testable without modifying the frozen Shared provider contract:

- `ProcessingLifecycleRelaunchRecovering`
- `ProcessingAmbiguousStartResolving`

The existing coordinator and resolver conform by extension.

### Recovery rules

1. `starting + jobID=nil` → ambiguous-start resolution path.
2. `startAmbiguous + jobID=nil` → ambiguous-start resolution path.
3. `cancellationRequested + jobID=nil` → **same ambiguity path while preserving cancellation intent**.
4. If no stable resolver exists → return `.ambiguousStart`; never invent a binding and never auto-start a duplicate.
5. If resolver remains ambiguous → return `.ambiguousStart`; do not enter generic lifecycle recovery.
6. If resolver rebinds or completes cancellation → only then delegate to the canonical lifecycle, which decides reconnect/retry/completion from the now-durable state.
7. `cancellationRequested + jobID!=nil` bypasses the resolver and uses normal lifecycle behavior.
8. `recoveryAction(...)` is a non-mutating preview and surfaces the unbound cancellation as `.ambiguousStart` without remote resolution.

The cancellation intent is deliberately **not** rewritten to `startAmbiguous`; the existing resolver uses the `cancellationRequested` state to know that a recovered remote job must be cancelled rather than resumed.

## Regression

Added formal repository self-test candidate:

`Processing/Tests/L1_A39_SelfTest.swift`

It covers seven orchestration scenarios:

- unbound cancel-start without stable resolver fails closed;
- unresolved stable recovery stays ambiguous;
- successful rebind delegates only after durable resolution;
- recovered cancellation delegates its terminal state;
- already-bound cancellation bypasses ambiguous resolution;
- preview is non-mutating and prevents generic missing-binding UX;
- missing state is a no-op.

The pre-existing `L1_M02_SelfTest.swift` remains the lower-level regression for the actual stable-idempotent resolver, including cancellation-intent survival, remote cancel, rollback, durable binding-before-cleanup and same-key retry behavior.

## Machine validation observed in A39

Swift toolchain: `Swift 6.2.1`.

An isolated interface-compatible harness compiling the **A39 source candidate itself** executed:

- scenarios: **7 / 7 PASS**
- failures: **0**
- errors: **0**

The initial harness/test review also caught Swift 6 actor-isolation/autoclosure misuse in the first formal test draft. The committed self-test was corrected to await actor values before synchronous assertions.

The environment does not provide an executable exact Worker-branch checkout, so repository-native compilation of the committed formal self-test and the final-tip A26 full audit remain `NOT_OBSERVED` rather than being falsely reported as PASS.

Machine-readable evidence:

`Processing/Tests/L1-A39_CANCEL_START_RELAUNCH_MATRIX.json`

## Integration requirement

HQ/App should construct and invoke `ProcessingCrashSafeRelaunchRecovery` as the processing relaunch/startup recovery entrypoint when a stable-idempotent start capability is available.

For the project-controlled server route this means composing:

- `ProcessingLifecycleCoordinator`
- the same `ProcessingLifecycleStateStoring`
- `ProcessingAmbiguousStartResolver`
- `ServerStableStartCapability`

before offering retry/start actions after relaunch.

If the selected provider cannot prove stable-idempotent start semantics, A39 must remain fail-closed as `.ambiguousStart`; UI must not silently retry a potentially accepted start.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

A39 materially reduces the P020 implementation gap, but `MOI-P020` remains `MISSING` until HQ observes the integrated current-iPhone long-processing flow across cancel/retry/interruption/relaunch without project corruption or duplicate provider jobs.
