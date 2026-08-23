# L4-W15 Validation — Final AnalysisSnapshot cardinality / cancellation hardening

## Scope

Worker 4 only. This wave changes Lane-4 Analysis, Package registration, product Analysis routing and Worker-4 tests/evidence. Shared/App/PARITY/Queue/Work Package/Lane Plan/Resource Locks remain untouched.

## Problem addressed

Before W15, the final `AnalysisSnapshotRobustness.harden` publication guard was synchronous internally. Even though the product actor checked cancellation immediately before and after the guard, the guard could still:

- scan complete beat/chord/section collections,
- sort complete beat/chord/section collections,
- build normalized timelines,
- compute section evidence coverage,

without observing task cancellation until all work completed.

Malformed or abnormally high-cardinality upstream output could therefore delay cancellation at the final publication stage.

## Production implementation

Added `AnalysisSnapshotRobustness.hardenCancellable(...) throws` in `AnalysisSnapshotCancellable.swift`.

The existing non-throwing `harden(...)` remains unchanged for compatibility, benchmark tooling and regression comparison.

`ProjectOwnedMusicAnalyzer` now uses the throwing cancellable guard before returning the product-facing snapshot.

Cancellation checks are present during:

- beat filtering,
- beat sorting,
- beat deduplication,
- beat-interval generation and median sorting,
- chord candidate normalization,
- chord stable merge sorting,
- chord gap/overlap normalization,
- decided-chord coverage accumulation,
- section candidate normalization,
- section stable merge sorting,
- section gap/overlap normalization.

The custom bottom-up stable merge sort is used because a monolithic standard-library `sorted()` call cannot observe `Task` cancellation while the sort is executing.

No partial `AnalysisSnapshot` is returned after cancellation; `CancellationError` propagates through the frozen `MusicAnalyzing async throws` contract.

## Duration-aware cardinality policy

Added `AnalysisSnapshotCardinalityPolicy` and machine-readable diagnostics.

The guard does not truncate an otherwise accepted timeline. Instead, cardinality is checked before large normalization work. If an upstream feature exceeds its duration-aware bound, only that feature fails closed:

- beat overflow -> tempo decision becomes `nil`,
- chord overflow -> one full-duration `X` chord,
- section overflow -> one full-duration `X` section.

Chord overflow also naturally suppresses section semantics because decided chord coverage becomes insufficient.

### 10-second input bounds

- beats: 2,048
- chords: 4,096
- sections: 512

These large floors prevent short normal songs from being rejected because of dense but plausible analyzer output.

### 1-hour input bounds

Using product baseline configuration:

- beats: 25,264
- chords: 28,864
- sections: 3,664

For comparison, one hour contains at most about:

- 12,600 beats at the configured 210 BPM upper bound,
- 14,400 chord frames at a 0.25-second chord hop,
- 900 minimum-duration sections at 4 seconds each.

Therefore normal baseline analyzer scale remains below the W15 limits with approximately 2x beat/chord and 4x section headroom plus fixed slack.

Section cardinality is also capped at 16,385, matching the W13 candidate budget plus the terminal section.

## Portable executable validation

Swift 6.2.1 / x86_64-unknown-linux-gnu source-shaped harness:

- five complete runs,
- 9/9 assertions PASS on every run,
- wall time: 0.06 seconds on each run,
- max RSS: 33,580 / 33,776 / 33,524 / 33,528 / 33,492 kB.

Validated:

1. normal unsorted beat normalization,
2. normal chord coverage normalization,
3. unsupported product chord vocabulary fails closed while supported minor chords remain,
4. functional-label vocabulary/confidence semantics remain,
5. beat overflow fails closed to nil tempo,
6. chord overflow fails closed to one full-duration `X`,
7. section overflow fails closed to one full-duration `X`,
8. one-hour duration-aware limits match policy values,
9. mid-flight cancellation during accepted high-cardinality chord sorting propagates `CancellationError`.

## Cancellation stress

A 24-hour-duration synthetic snapshot containing 300,000 reverse-ordered chord events was used so the input remains below its duration-aware W15 chord limit of 691,264 while still forcing substantial normalization/sorting work.

Cancellation was requested after 1 ms.

Observed request-to-`CancellationError` latency:

- run 1: 0.084 ms
- run 2: 0.079 ms
- run 3: 0.769 ms
- run 4: 0.182 ms
- run 5: 0.389 ms

Worst observed portable value: approximately 0.769 ms, below the 250 ms harness threshold.

These values are Linux scheduler evidence only and are not physical-iPhone latency or power claims.

## Canonical regression source

Added `AnalysisSnapshotPublicationHardeningTests.swift`.

The canonical test suite requires:

- cancellable guard output equals the legacy guard for a normal mixed snapshot,
- canonical JSON bytes are identical between legacy and cancellable normal outputs,
- duration-aware limits are exact,
- feature-specific overflow fails closed without corrupting unaffected features,
- pre-cancelled publication throws `CancellationError`,
- 300,000-event mid-flight normalization cancellation completes within 250 ms.

Full SwiftPM/Xcode execution remains an HQ integrated-checkout gate; portable source-shaped execution does not replace it.

## PARITY status

**NON_PARITY.** No PARITY row is promoted by W15.

MOI-P009 / P011 / P013 / P016 remain blocked on rights-cleared real-audio and current-iPhone differential evidence.

MOI-P021 remains MISSING because W15 does not provide physical-iPhone peak RSS, memory pressure, cancellation responsiveness, thermal or battery evidence.

W15 only closes the Lane-4 final publication-stage cancellation/cardinality defect and improves readiness for HQ Late Integration.
