# L3-AW04 | Sample-time metronome / count-in execution

## Goal

Move Lane 3 from planner-only click timing toward a production-executable Apple path while preserving the core ownership rule: Playback owns the engine/transport clock; DSP owns click planning and click-node scheduling semantics.

## Implementation

- `DSP/Sources/ClickExecution.swift`
  - preflights the entire click batch before any Apple buffer can be queued;
  - rejects stale generation, negative/non-increasing time, count-in clicks at/after music start, and events before the supplied render origin;
  - converts absolute project-render sample time to click-player-relative sample time;
  - tracks generation, render origin, sample rate, schedule kind and queued-through sample for rolling windows;
  - append is rejected if anchor/rate/kind changes or the new window overlaps an already queued window.
- `DSP/Sources/PracticeDSPClickExecutionPlanning.swift`
  - derives metronome and count-in plans directly from `PracticeDSPState`;
  - carries `scheduleGeneration` into every event;
  - tempo therefore changes rendered click spacing, while generation changes make prior plans stale.
- `DSP/Sources/AppleSampleAccurateClickExecutor.swift`
  - uses one dedicated `AVAudioPlayerNode` supplied to the DSP executor;
  - validates the complete batch and both click buffers before queue mutation;
  - replacement/invalidation calls `playerNode.stop()` to purge the old dedicated click queue without stopping music/stem nodes;
  - Playback supplies the common host-time anchor. Relative sample time 0 is intended to align with that anchor;
  - rolling append is allowed only against the exact same generation/origin/rate/kind.

The older `AppleSampleTimeClickScheduler` is preserved for history but must not be treated as stale-generation-safe production evidence because it validates generation inside the enqueue loop and does not own queue invalidation.

## Portable validation

Swift 6.2.1 Linux source-equivalent isolated compile/run: PASS.

Coverage:

- normal 48 kHz metronome absolute -> relative sample mapping;
- rolling append and overlap rejection;
- generation invalidation clears queue anchor/state;
- old-generation event rejection before enqueue;
- generation-regression rejection;
- four-click count-in strictly before music start;
- event-before-render-origin rejection;
- non-increasing sample rejection;
- append render-origin mismatch rejection;
- append sample-rate mismatch rejection;
- append schedule-kind mismatch rejection;
- PracticeDSP metronome-disabled and missing-count-in rejection;
- tempo-ratio-aware metronome/count-in planning;
- 100,000 sequential rolling-window append regression.

## Planner benchmark

Environment: Swift 6.2.1 Linux, optimized build.

Each of 20 rounds:

- 50,000 rolling batches;
- 8 events per batch;
- 400,000 click events per round;
- fixed 48 kHz anchor/generation with state append validation.

Observed:

- median: 4.712 ms
- p95: 7.540 ms
- p99: 11.517 ms
- max: 11.517 ms
- checksum: 51,297,024,000,000

This measures portable planning/state bookkeeping only. It does not measure `AVAudioPlayerNode`, Audio Unit render load, hardware output latency or audible click alignment.

## Required Apple / PARITY gates

Still required before P014/P015 can move from MISSING:

1. selected Xcode/iOS SDK compile for `AppleSampleAccurateClickExecutor`;
2. integrated Playback host supplies one authoritative render-origin sample and common host-time anchor;
3. seek, loop, tempo change and interruption increment generation and immediately call click-queue invalidation before replacement scheduling;
4. target-device confirmation that `AVAudioPlayerNode.stop()` purges queued click buffers as assumed by this Lane-local design;
5. physical-iPhone captured onset measurements through the L3-M01 device harness;
6. studio and live/variable-tempo rights-cleared tracks;
7. count-in final-click -> music-start measurement;
8. long-running drift and repeated seek/loop/tempo-change tests;
9. human listening for double-clicks, stale clicks, gaps and accent anomalies;
10. current Moises differential comparison.

No PARITY promotion is authorized by this Wave.
