# L3-AW34｜Fixed-Window Continuous Coalescing / Seek-Loop Starvation Hardening

Result: `COMPLETE_NON_PARITY`

## Goal

Bound continuous seek/loop/tempo coalescing eligibility to the already-configured quiet-period window so a continuous scrub/drag stream cannot postpone Playback token dispatch indefinitely.

## Correctness gap found

The AW17 selected unified transport authority implemented latest-wins coalescing as a resettable debounce. Every replacement seek/loop/tempo cancelled the current wake task and started a fresh quiet-period sleep. If UI intents arrived more frequently than that quiet period, the pending command could remain non-ready for the entire gesture and no Playback generation would be consumed until the user stopped moving.

This is a responsiveness/correctness problem for `MOI-P007` seek/timeline and interactive `MOI-P008` loop editing. It is distinct from device-level tuning of the numerical quiet-period value.

## Product hardening

`Lane3UnifiedProductionTransportAuthority` now uses a fixed first-intent coalescing window per continuous family:

- the first pending seek/loop/tempo opens one deadline using the existing configured quiet period;
- replacements inside that open window remain latest-wins and resume predecessors as `supersededBeforeToken`;
- replacements do **not** cancel or extend the already-open deadline;
- at the deadline, whichever command is current/latest becomes ready;
- once that winner leaves the pending slot, a later intent opens a fresh window;
- actual token creation and coordinator mutation remain serialized by the existing single drain.

No new timing threshold was invented. The selected AW31 composition still uses the existing 16ms seek/loop quiet periods and zero inner tempo quiet period.

## Barrier / cancellation / recovery preservation

Existing discrete semantics are retained:

- `play` / `pause` still flush older continuous controls in ticket order and cancel the open wake task;
- media load/replacement, interruption and recovery still supersede older pending continuous controls before token creation;
- cancelling the current pending continuous winner closes its wake task;
- the next intent can open a fresh window;
- `recoveryBlocked` still rejects normal controls and does not allow a pending window to bypass fail-closed recovery.

Historical AW17 tests were updated from the obsolete assertion “a large burst always yields exactly one token” to the stronger fixed-window invariants: every input is either a window winner or pre-token supersession, backend seek count equals seek winners, and token generation equals actual executions.

## Portable validation actually executed

Environment: Swift 6.2.1, Linux x86_64.

The AW34 virtual-time stress/benchmark semantics were compiled with:

`-swift-version 6 -strict-concurrency=complete -warnings-as-errors -O`

### Starvation differential

For a one-second 1kHz input stream with a 16ms quiet period:

- fixed-window model: `63` executed window winners;
- historical resettable debounce model: `1` execution, only after the stream ended.

This demonstrates the exact starvation mode AW34 removes without depending on wall-clock scheduler jitter.

### 1,000,000-event stress

Input spacing: 125 microseconds (8kHz virtual stream).

- total inputs: `1,000,000`
- executed fixed-window winners: `7,813`
- pre-token supersessions: `992,187`
- accounting loss: `0`
- maximum first-intent-to-eligibility window: `16,000,000 ns`
- final ticket preserved as final winner: yes
- play/pause-style flush model: PASS
- lifecycle/media-style supersede model: PASS

### Portable CPU bookkeeping benchmark

20 rounds x 1,000,000 virtual submissions with runtime-varying monotonic spacing and no-inline state mutation:

- median: `2.718 ms`
- p95: `3.093 ms`
- max: `3.187 ms`
- checksum: `7633173834630080814`

This benchmark measures only the deterministic fixed-window state-bookkeeping model. It does **not** measure Swift actor scheduling, AVAudioEngine, file scheduling, seek latency, user-visible response time or iPhone performance.

## Repository regression authored

- `Playback/Tests/L3_AW34_FixedWindowCoalescingSelfTest.swift`
  - drives the actual `Lane3UnifiedProductionTransportAuthority` with protocol-compatible Playback/DSP dependencies;
  - uses a paced seek stream that remains active longer than several quiet periods and requires backend seek execution while the stream is still active;
  - verifies complete winner/supersession accounting;
  - verifies play flush ordering and no delayed duplicate token;
  - verifies pending cancellation closes a window and a fresh loop window reopens.
- `Playback/Tests/L3_AW34_FixedWindowCoalescingStress.swift`
  - deterministic starvation differential, one-million-event accounting and barrier semantics.
- `Playback/Tests/L3_AW34_FixedWindowCoalescingBenchmark.swift`
  - optimizer-resistant fixed-window bookkeeping benchmark.
- Updated AW17 self-test/benchmark keep historical barrier/recovery coverage valid under the new bounded-window semantics.

The complete repository actor test was authored but not executed against the full selected SwiftPM/Xcode source graph in this Worker environment. The deterministic stress and benchmark were executed locally as described above.

## Repeated-loop seam decision

AW33's first next-wave candidate was an exact-host repeated-loop seam envelope. Source audit found that current Apple AudioUnit gain ramps scheduled for future sample times cannot be safely revoked solely by the existing Swift generation fence after a seek/tempo/lifecycle mutation. Adding future loop fade events now could therefore leave stale gain automation in the live graph. Timer-only arming would also weaken AW31 exact-host scheduling.

AW34 deliberately did not add that unsafe mechanism. A future loop-seam wave needs a cancelable/generation-isolated exact-host gain strategy or graph/gain-stage generation replacement before it can be selected.

## Explicit non-PARITY boundary

Not established here:

- complete selected Xcode/iOS compile;
- physical-iPhone first-intent-to-token p50/p95/p99;
- actual 16ms seek/loop tuning quality;
- real AVAudioPlayerNode restart/seek latency;
- audible seek/loop click-pop or silence-gap quality;
- automatic repeated-loop seam envelope;
- rights-cleared real-audio listening;
- current-Moises differential.

Therefore `MOI-P006/P007/P008/P010/P012/P014/P015` remain `MISSING`. AW34 removes a Lane-local starvation defect but does not claim product PARITY.
