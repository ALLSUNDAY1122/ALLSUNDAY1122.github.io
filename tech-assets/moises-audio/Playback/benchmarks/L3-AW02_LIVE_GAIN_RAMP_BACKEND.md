# L3-AW02 — Live gain-ramp backend integration

## Goal

Move Lane 3 from an isolated Apple ramp primitive to a complete PlaybackBackendDriving implementation that can route every loaded stem through an independent ramp-capable gain stage.

## Why this wave exists

MOI-P006 remains MISSING. The preserved legacy `AppleMultiTrackPlaybackBackend` still applies mixer changes through `AVAudioPlayerNode.volume`, so it cannot be treated as evidence that mute/solo/volume transitions are click/pop/zipper safe.

## Implementation

- `PlaybackBackendGainApplicationPlanner`
  - normalizes the complete loaded-stem gain map before graph mutation;
  - ignores stale committed gains belonging to a previous stem set;
  - rejects duplicate loaded stems, unknown requested stems and missing render sample rates;
  - selects `.ramped` while playing and `.immediate` while paused;
  - delegates deterministic frame-count derivation to the proven AW01 execution planner.
- `AppleTransactionalStemGainRampStage`
  - gives one dedicated mixer node to one stem;
  - uses the system mixer's global linear-gain parameter;
  - requires a ramp-capable Audio Unit parameter;
  - splits validation from scheduling so a whole multi-stem batch can be preflighted before the first event is scheduled.
- `AppleRampedMultiTrackPlaybackBackend`
  - preserves the established host-time multitrack scheduling, seek/loop and terminal-state behavior;
  - stages file validation plus ramp-capability validation before destroying the current playable graph;
  - connects `player -> dedicated mixer -> main mixer` per stem;
  - applies paused/setup gain changes immediately only after validating every loaded stem;
  - applies playing-state changes by validating all ramp steps first and then scheduling the complete batch;
  - leaves the legacy backend untouched as a rollback/reference implementation until HQ can compile and select the new backend in the integrated iOS target.

## Rapid retarget rule

The backend tracks the last committed target for deterministic planning, but the Audio Unit ramp is scheduled without forcing that old target as the new ramp start. A rapid user retarget is therefore intended to continue from the Audio Unit's current render value. This avoids an explicit jump to a stale target immediately before a new ramp.

## Portable validation

Swift 6.2.1 Linux self-test: PASS.

Covered:

- playing -> ramped path;
- paused -> immediate path;
- omitted requested gain -> unity normalization matching the historical backend contract;
- stale committed stem does not contaminate a replacement graph;
- deterministic StemID ordering;
- 44.1/48/96 kHz frame derivation;
- unchanged transition elision;
- duplicate/unknown/missing-rate fail-closed cases;
- 10,000 sequential rapid-retarget state transitions.

Benchmark: 20 rounds x 50,000 eight-stem application plans, 75% playing-state requests. Median 816.148 ms, p95/p99/max 847.456 ms, checksum 5618999424. This is CPU planner evidence only.

## Apple runtime gate still open

This wave does not claim Apple runtime or audible quality PASS. Required late-integration evidence remains:

1. compile both new Apple sources with the selected Xcode/iOS SDK;
2. select `AppleRampedMultiTrackPlaybackBackend` in the integrated host instead of the legacy backend;
3. confirm the target iPhone exposes the expected ramp-capable mixer gain parameter;
4. record physical-iPhone mute/solo/volume transitions and feed them into the L3-M01 click/pop/zipper measurement path;
5. run rights-cleared real-track listening;
6. compare current Moises under equivalent control transitions.

`PARITY_MATRIX.json` must remain unchanged until HQ completes those gates.
