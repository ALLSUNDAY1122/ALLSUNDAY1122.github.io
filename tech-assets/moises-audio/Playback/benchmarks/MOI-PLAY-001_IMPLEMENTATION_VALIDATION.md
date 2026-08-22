# MOI-PLAY-001 implementation validation

Captured: 2026-08-22 JST
Worker: `Moises-Worker-3`
Work package: `MOI-WP3-PLAYBACK-DSP`
Branch: `moises/wp3-playback-dsp`

## Implemented

- `MultiTrackPlaybackController` implements the HQ `PlaybackPreparing` contract without editing `Shared/**`.
- Source playback state can exist before stems are ready. When stems arrive while playback is active, the controller asks the backend for the current source position and loads stems at the same project timeline position.
- Stem mixer state supports continuous `0...1` volume, mute and solo. Effective gains are derived centrally; any active solo suppresses non-solo tracks and mute still silences a soloed track.
- Seek and loop validate project duration and increment schedule generations instead of carrying cumulative per-loop offsets.
- `PlaybackTimelinePlanner` converts project time to each stem's own sample frame and handles non-zero `StemArtifact.startTimeSeconds` using delayed common-start scheduling.
- `normalizedProjectPosition` derives loop position from the absolute raw project clock, so repeated loop position math does not accumulate incremental rounding drift.
- `AppleMultiTrackPlaybackBackend` is an AVAudioEngine/AVAudioPlayerNode path behind the portable controller. Source and stem cycles use a common host-time anchor. Loop cycles are queued against absolute host times; normal terminal completion uses `.dataPlayedBack` while loop prequeue uses `.dataConsumed`.
- App-owned relative path containment is enforced before AVAudioFile opening.

## Commits in this PLAY wave

- `da48342f206a83f324dfd1b9daf0a4bb943cae38` — portable playback controller/timeline/mixer state.
- `0c80edc99c68c37b4e8d64b748c2d4c0e4bee95a` — initial Apple multitrack backend.
- `e24ba740274220221b4301dc6a5fa1f4aa5ed806` — portable regression self-test.
- `6f9def351ae61a77bbe46b07b7a4d75594e7c3f0` — 3-hour/4-stem interaction planner benchmark.
- `3892fea90f833b514f39141ae23ce21239e20b84` — source/stem loop completion and absolute host-time lifecycle hardening.
- `e135d05556fd23322e325e712b13b00bf028e560` — absolute loop position normalization.
- `69b623dc8c22de30325851f1507c899b63e0c0b9` — 100k-loop-position regression coverage.

## Executed validation in current worker environment

Environment: Swift 6.2.1, x86_64 Linux. `AVFAudio` is unavailable here.

A contract-compatible compile harness supplied only the current HQ `ProjectID`, `AssetID`, `StemID`, `StemRole`, `LocalAudioAsset`, `StemArtifact`, and `PlaybackPreparing` shapes. No Shared or Package file was modified.

Portable self-test result:

`MOI-PLAY-001 portable self-test: PASS`

Covered:
- non-zero stem start offset mapping;
- sample-frame seek mapping on a 3-hour track;
- solo/mute/volume effective-gain semantics;
- source -> stem transition preserves backend-reported playback position;
- seek and loop state transitions;
- absolute loop normalization across up to 100,000 repetitions without incremental position accumulation.

Latest optimized portable benchmark, 20,000 randomized seeks over four synthetic metadata stems representing a 3-hour 48 kHz project:

`median_ms=0.000311 p95_ms=0.000480 p99_ms=0.000481 max_ms=0.122321`

This benchmark measures only CPU planning for four stem frame positions plus mixer gain derivation. It is NOT AVAudioEngine seek latency, device output latency, audible gap length, or click/pop quality evidence.

## Acceptance gate status

Implemented/portable evidence:
- stable project/stem identity boundary behind canonical `StemArtifact`;
- source-to-stem position-preserving transition contract;
- solo/mute/volume state and gain derivation;
- seek/loop absolute timeline planning with long-track arithmetic regression;
- Apple AVAudioEngine scheduling implementation path exists.

Still mandatory before claiming `MOI-PLAY-001` Acceptance or any PARITY promotion:
1. Compile the Apple backend under the canonical iOS/macOS target once `MOI-BLD-IOS-001` exists.
2. Execute rights-cleared real source/stem fixtures through the actual AVAudioEngine graph.
3. Measure multi-stem onset skew, seek audible gap/latency, repeated-loop boundary drift, and source->stem transition discontinuity.
4. Exercise solo/mute/continuous volume changes and confirm no unacceptable click/pop/zipper artifacts; the current backend sets AVAudioPlayerNode volume directly and this must not be assumed click-free without target evidence.
5. Run representative long tracks on target iPhone and measure interaction latency, memory, interruptions and repeated seek/loop behavior.
6. Execute Reference differential validation later using actual separated stems. Current separation supply remains independently blocked and does not invalidate the playback implementation seam.

## Current blocker / PARITY

Canonical Queue deliberately allows PLAY implementation while separation supply is blocked, but the iOS host target is still missing. Therefore device/audio Acceptance cannot truthfully be closed in this worker environment.

`MOI-P006`, `MOI-P007`, and `MOI-P008` remain `MISSING`. Waveform is not treated as a mandatory gate unless current-iPhone Reference evidence later confirms it.

No `Shared/**`, `App/**`, `Package.swift`, Queue, resource-lock file, or `PARITY_MATRIX.json` was changed by Worker 3.
