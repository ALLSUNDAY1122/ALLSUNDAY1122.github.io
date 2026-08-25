# L3-AW36｜Cancellation Admission / Late-Delivery Retention Hardening

Result: `COMPLETE_NON_PARITY`

## Problem

`Lane3UnifiedProductionTransportAuthority` previously stored every cancellation that arrived after the ticket was no longer pending or executing in `cancellationBeforeEnqueue`. The cancellation handler itself is delivered by a separate `Task` back to the actor, so a cancellation can race behind normal completion or supersession. Such a retired ticket can never enqueue again, leaving an unconsumable marker and allowing long interactive cancel/complete workloads to grow retained state monotonically.

## Production change

AW36 introduces `Lane3UnifiedCancellationAdmissionFence` and wires it into continuous and discrete admission.

- A ticket is registered only while it is allowed to reach its enqueue closure.
- A cancellation observed during that admission window is retained only until the same ticket consumes admission.
- Already-cancelled callers abandon admission before returning.
- Pending and executing cancellation behavior remains unchanged.
- A cancellation delivered after admission/pending/execution retirement is counted as late telemetry and is not retained as a future marker.
- The snapshot exposes admission counts, late-retired cancellation count, overflow state and the invariant that every pre-enqueue cancellation marker is backed by a live admission ticket.

This does not change AW34 fixed-window deadlines, latest-wins semantics, play/pause flush ordering, lifecycle/recovery supersede ordering, or selected AW31 tempo quiet-period policy.

## Portable validation

Swift 6.2.1, Linux x86_64, strict concurrency complete, warnings as errors.

Self-test:
- true pre-enqueue cancellation is consumed as cancelled-before-dispatch
- normally consumed admission does not become a future cancellation marker
- abandoned admission leaves no retained state
- late retired cancellation increments telemetry only

1,000,000-event optimized stress:
- pre-enqueue cancellations: 200,000
- late retired cancellations: 400,000
- retained admission tickets after run: 0
- retained cancellation markers after run: 0
- invariant violations: 0

20 x 1,000,000 optimized bookkeeping benchmark:
- median: 44.723 ms
- p95: 50.038 ms
- max: 53.359 ms
- checksum: 5,000,192

The benchmark covers only admission-fence bookkeeping. It does not measure actor scheduling, AVFAudio, device latency, audible behavior, battery, thermal behavior, or current-Moises differential.

## Remaining gates

- complete selected SwiftPM/Xcode graph compile and execution
- actual actor cancellation/completion race regression on Apple runtime
- physical-iPhone continuous seek/loop latency and audible-result evidence
- rights-cleared real audio and current-Moises differential/listening
- automatic repeated-loop seam envelope remains intentionally deferred until safe exact-host gain automation isolation exists

No PARITY row is promoted by AW36.
