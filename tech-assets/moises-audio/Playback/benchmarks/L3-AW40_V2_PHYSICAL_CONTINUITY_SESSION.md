# L3-AW40｜AW38/AW39 v2 Physical Continuity Session

Result: `COMPLETE_NON_PARITY`

## Purpose

AW38/AW39 can now produce exact seek/loop instrumentation with reconstruction-slot generation stamping, but AW35's legacy target schema cannot represent `setLoop(nil)`. AW40 adds a bounded, machine-checkable physical-session layer that remains entirely on the v2 path and aggregates seek, enabled-loop and loop-disable observations without fabricating an AW35 numeric loop range.

## Implementation

- `Lane3InteractiveContinuityV2PhysicalSessionContext`
  - requires session/device/build/sample-rate metadata
  - requires an explicit uptime clock-domain label
  - uses an audio fixture identifier rather than a raw user file path
  - records physical-iPhone, rights-cleared-real-audio, current-Moises and listening gates separately
- `Lane3InteractiveContinuityV2PhysicalSessionBuffer`
  - default capacity 4096, clamped to 16...65536
  - ring overwrites oldest retained sample and saturating-counts capacity drops
  - separately counts non-executed outcomes and unusable AW38 instrumentation results
- `Lane3InteractiveContinuityV2PhysicalSessionAnalyzer`
  - preserves three v2 shapes: seek / enabled loop / loop disabled
  - reports p50/p95/p99/max for intent→token, token→backend, intent→backend, intent→audible and token→audible
  - reports both aggregate and per-shape latency summaries
  - bounds issue-detail retention to 16...4096 while counting dropped issue details
  - requires zero capacity drops for a complete physical session because a truncated session is not full evidence
  - does not fail physical measurement merely because coalesced/cancelled operations were non-executed; those are excluded from executed latency statistics and counted separately
  - requires at least one valid sample of each of the three v2 shapes
  - keeps physical-session completeness distinct from current-Moises/human-listening differential completeness
  - always sets `parityPromotionAllowed=false`
- AW38/AW39 adapter
  - accepts `legacyAW35CannotRepresentLoopDisabled` as a v2-nonblocking warning only
  - every other AW38 instrumentation issue remains fail-closed
  - AW39 non-executed outcomes never enter executed percentile/coverage data

## Portable validation

Environment: Swift 6.2.1, Linux x86_64, Swift language mode 6, `-strict-concurrency=complete -warnings-as-errors`.

Self-test PASS:
- seek + enabled loop + loop disabled all retained
- p50/p95 calculation checked
- non-executed outcome counted separately without invalidating otherwise valid physical measurements
- missing audible marker fails physical completeness
- current-Moises/listening gates affect only the differential bundle, not raw physical timing completeness
- duplicate sample IDs fail closed
- unusable instrumentation result fails closed
- capacity clamp and drop accounting checked
- issue-detail retention capped at 16 with explicit drop accounting

Optimized stress PASS, 1,000,000 samples:
- retained: 4096
- capacity drops: 995904
- duplicate sample IDs in retained window: 0
- fully valid retained samples: 4096
- physical session complete: false by design because capacity drops prove the session was truncated

Optimized benchmark PASS, 20 × 1,000,000 ring appends:
- median: 30.607613 ms
- p95: 34.793808 ms
- max: 57.969762 ms
- checksum: 20000190

The benchmark measures only portable recorder bookkeeping. It is not seek latency, AVFAudio latency, audible latency, iPhone performance or product latency.

## Selected-runtime gate

The AW38 adapter regression is authored but complete selected SwiftPM/Xcode/AVFAudio execution is not claimed. Physical completion still requires actual iPhone metadata, independently observed audible timestamps in the declared uptime clock domain, rights-cleared real audio, and complete v2 shape coverage. Current-Moises differential and human listening remain separate additional gates.

No PARITY row is promoted by this wave.
