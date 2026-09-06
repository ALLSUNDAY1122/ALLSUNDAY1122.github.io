# L3-AW35｜Selected Reconstruction + Interactive Continuity Evidence Hardening

Result: `COMPLETE_NON_PARITY`

## Purpose

AW33 introduced one-way selected-stack reconstruction and AW34 removed resettable-debounce starvation with a fixed first-intent window. Physical-iPhone validation still lacked one bounded, machine-checkable Lane-3 contract that can correlate seek/loop interaction across those two mechanisms.

AW35 adds a bounded evidence buffer and validator for physical-device runs. It does not claim Apple runtime behavior, audible click/pop elimination, current-Moises equivalence, or PARITY.

## Recorded contract

Each retained seek/loop observation can carry:

- selected reconstruction slot generation at first intent and completion
- transport ticket and Playback generation
- first-intent uptime timestamp
- token-issued uptime timestamp
- audible-result uptime timestamp
- requested and applied seek/loop target
- cancellation-after-dispatch flag
- execution, pre-token supersession/cancellation/rejection/failure, or stale-generation rejection outcome

The analyzer rejects:

- token/audible timestamps that precede the intent
- audible-result timestamps that precede token issuance
- an executed operation that crosses a reconstruction slot generation
- a stale-generation rejection without an actual generation change
- executed observations without transport ticket / Playback generation / applied target
- seek-vs-loop target shape mismatch
- applied target error above the configured tolerance
- incomplete or invalid device metadata

Percentiles use nearest-rank p50/p95/p99 and retain maximum latency.

## Bounded-memory behavior

`Lane3InteractiveContinuityEvidenceBuffer` is a fixed-capacity ring. Default capacity is 4,096; accepted capacity is clamped to 16...65,536. When full, the oldest observation is replaced and `capacityDrops` is incremented with saturating overflow behavior.

This prevents long scrub/drag evidence sessions from turning the measurement layer itself into unbounded memory growth. A device run with capacity drops remains observable as such; the drop count is never silently discarded.

## Portable validation executed

Environment: Swift 6.2.1, Linux x86_64.

- strict concurrency complete
- warnings as errors
- self-test: PASS
- negative validation: PASS for slot-generation contamination, reversed timestamps, target-shape mismatch
- 100-observation ring test: retained 16, capacity drops 84, retained IDs 84...99
- 1,000,000-observation stress: retained 4,096, capacity drops 995,904, stale-generation rejections retained 4, analyzer issues 0
- stress latency accounting: token p99 2,000,000ns; audible-result p99 8,000,000ns

## Portable bookkeeping benchmark

20 rounds × 1,000,000 observation appends, optimized build:

- median: 46.832 ms
- p95: 57.979 ms
- max: 72.568 ms
- checksum: 59,918,060

This measures portable ring-buffer bookkeeping only. It does not measure actor scheduling, AVFAudio, iPhone latency, audio rendering, or audible response.

## Physical-device runbook

HQ / selected iOS instrumentation should populate this contract from a physical iPhone without changing its semantics:

1. Record first-intent time before the seek/loop request enters the selected Lane-3 authority.
2. Record the exact token-issued time at the selected transport discontinuity point; do not substitute UI completion time if token time is unavailable. Missing token time must remain missing.
3. Record the audible-result time from the chosen device/audio measurement method and retain its method in the external evidence bundle.
4. Record requested and actually applied seek/loop targets.
5. Capture `Lane3SelectedTransportReconstructionSlot` generation at intent and completion. Executed work crossing a replacement generation is a validation failure; a retired generation may only appear as explicitly rejected stale work.
6. Run continuous dragging long enough to measure first-intent-to-token and first-intent-to-audible-result p50/p95/p99 under AW34 fixed-window semantics.
7. Run at least one AW33 reconstruction during an interactive sequence and verify no executed result crosses the reconstruction generation.
8. Populate real hardware identifier, iOS version, build identifier, actual sample rate, rights-cleared real-audio flag, current-Moises differential flag, and human-listening flag.
9. Do not tune the provisional 16ms seek/loop quiet period from portable results. Tune only from physical-device UX/latency evidence.
10. Do not promote P006/P007/P008/P010/P012/P014/P015 from this evidence alone.

## Deferred automatic repeated-loop seam envelope

AW35 deliberately does not add future AudioUnit gain events. The AW34 gap remains: Swift-side generation rejection cannot revoke already-scheduled future AudioUnit parameter events. A timer-only workaround would weaken AW31 exact-host scheduling. Automatic repeated-loop seam automation therefore still requires cancelable future parameter events or generation-isolated gain-stage/graph replacement that itself does not introduce an audible discontinuity.
