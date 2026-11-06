# L3-AW39 Selected Lease Generation Stamping

Result: `COMPLETE_NON_PARITY`

## Problem

AW38 can correlate exact Playback token timing by `playbackGeneration`, but its initial integration contract accepted `slotGenerationAtIntent` and `slotGenerationAtCompletion` from snapshots taken outside `Lane3SelectedTransportReconstructionSlot`. A successful operation can release its shared lease, then an already-waiting reconstruction can advance the slot generation before the caller obtains the completion snapshot. The old evidence path could therefore conservatively classify an operation that actually ran entirely on one selected stack as `executedAcrossSlotGeneration`.

## AW39 change

`Lane3SelectedTransportReconstructionSlot` now captures the current `slotGeneration` in the same private `SharedLease` that increments `inFlightOperations`. Replacement already waits until `inFlightOperations == 0`, so the captured generation cannot change during that operation.

New APIs:

- `submitSeekStamped(to:resume:loop:)`
- `submitLoopStamped(_:)`

They return `Lane3SelectedTransportGenerationStampedOutcome`. Existing `submitSeek` and `submitLoop` delegate to the stamped path and discard only the evidence metadata, so product transport semantics are not forked.

`Lane3LeaseStampedInteractiveContinuityAdapter.swift` feeds an executed stamped outcome into AW38 using the same exact lease generation for intent and completion. Non-executed guarded outcomes remain non-executed and are never fabricated into continuity observations.

## Negative/reconstruction regression authored

`L3_AW39_SelectedLeaseGenerationSelfTest.swift`:

1. executes seek on slot generation 1 and retains its stamped outcome;
2. triggers a later tempo commit failure;
3. reconstructs the selected facade to generation 2;
4. correlates the already-completed generation-1 seek only after reconstruction;
5. requires AW38 observation intent/completion generations to remain 1 even though current slot generation is 2;
6. executes `setLoop(nil)` on generation 2 and retains AW38 v2 `loopDisabled` semantics;
7. verifies a rejected guarded outcome remains `nonExecuted` rather than being converted to executed evidence.

The selected repository/Xcode test is authored but is not claimed executed in this environment.

## Portable strict-concurrency evidence

A distilled actor model matching AW39's `SharedLease` capture / `inFlightOperations` drain / replacement ordering was compiled with Swift 6.2.1 Linux using:

`-swift-version 6 -strict-concurrency=complete -warnings-as-errors`

The first harness compile exposed test-only issues (`@main` compiler mode and `await` inside `precondition` autoclosure); both were corrected. Post-fix race run:

`L3-AW39 structural race PASS stamped=1 current=2`

A separate strict compile confirmed the legacy delegation syntax `try await asyncCall().member` is valid under Swift 6.

This portable run proves only the ordering shape and Swift concurrency surface used by AW39. It does not prove complete selected repository/Xcode/AVFAudio execution.

## Preserved invariants

- reconstruction still waits for every in-flight shared lease;
- slot generation advances only during exclusive reconstruction;
- stale recovery tickets remain rejected;
- old facade remains one-way poisoned after AW33 recovery latch;
- AW34 fixed-window seek/loop behavior is unchanged;
- AW36 cancellation admission behavior is unchanged;
- AW38 exact playback-generation timing and external-audible-marker requirements are unchanged;
- no Shared/App/PARITY scope was modified.

## Remaining gates

HQ should run AW33 + AW37 + AW38 + AW39 selected tests in the complete SwiftPM/Xcode/iOS graph, then use the stamped seek/loop APIs for physical-iPhone continuity evidence. Physical audible timing still requires an independently validated marker in the same uptime clock domain. Rights-cleared real audio, current-Moises differential, listening, long-track device evidence and final PARITY remain HQ/device gates.
