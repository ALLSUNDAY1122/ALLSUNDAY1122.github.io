# MOI-DSP-R001｜Validation Report

## Task result

Status proposed by Worker: `INTEGRATION_READY`

This task is research/benchmark design. It does not claim real-track DSP parity and does not change `PARITY_MATRIX.json`.

## Acceptance review

### 1. Commercially usable speed/tempo and pitch/key paths compared

PASS for research acceptance.

Compared:
- Apple AVAudioUnitTimePitch / Varispeed;
- Rubber Band 4.x commercial path;
- Superpowered public-app licensed path;
- SoundTouch commercial and LGPL paths.

For each, candidate matrix records independent tempo/pitch capability, iOS integration, distribution boundary, expected quality ceiling and the fact that project CPU/memory/thermal measurements remain UNKNOWN.

Selected first implementation baseline:
- Apple `AVAudioUnitTimePitch`.

Selected quality challenger:
- Rubber Band 4.x under purchased commercial licence, only if later measured quality justifies dependency/procurement.

### 2. Smart metronome/click and count-in architecture compared/defined without shared-contract changes

PASS.

Selected architecture:
- common `AVAudioEngine` sample-time domain;
- `AVAudioPlayerNode` sample-time scheduling;
- tempo mapping transforms Analysis beat positions into output/render sample positions;
- count-in and music start scheduled on the same render clock;
- no `Timer`/UI clock is permitted to trigger audible click events;
- seeks, loops and tempo mutations invalidate future click schedules using a generation/token pattern.

No Shared/App/Playback/Analysis source file was changed.

### 3. Code licence / assets / distribution obligations documented separately

PASS.

Captured current authoritative vendor boundaries:
- Apple: system-framework baseline; no third-party DSP binary/model.
- Rubber Band: GPL v2+ open-source path vs purchased proprietary commercial licence; vendor explicitly warns against GPL App Store route.
- Superpowered: evaluation is private/internal only; public app needs launch-capable licence.
- SoundTouch: LGPL 2.1 plus separate commercial non-LGPL licence; static iOS route is not treated as obligation-free.
- Click samples: project-owned/rights-cleared only.
- No pretrained ML model/training-data dependency in the selected DSP paths.

### 4. At least one implementation path selected with measurable gates

PASS.

`MOI-DSP-R001_VALIDATION_GATE.json` defines:
- tempo ratios 0.5–2.0 for baseline validation;
- pitch shifts ±1/3/7/12 semitones;
- duration ratio error <= 0.1%;
- monophonic/steady pitch median error <= 10 cents;
- blind listening dimensions and Reference-relative reject rule;
- click error median <=1 ms / P99 <=3 ms in deterministic 10-min test;
- 100-loop drift stress;
- count-in/music-start error <=3 ms in deterministic rendering;
- zero render underruns in 30-min click stress;
- 5/15/30/60-min target-iPhone CPU/RSS/thermal/battery measurements before promotion.

These are project engineering gates, not observed Reference values.

## Mechanical/repository verification

Claim commit: `96478f2732458d7c13d8ed02f7f69a5551315e49`

Commits before this report:
- `ee5411e0fe33dd0cce2df502bb671f519cae7e5b` — DSP candidate matrix and selected baseline/challenger.
- `24a1402aeefaca8750de52178be10f31119a4258` — sample-timeline click/count-in synchronization architecture.
- `51e89dd83618855235f245a75c09224386d39c8b` — licence/distribution/asset audit.
- `ce95f82b76ff30ba6b6f8dd722d06941e2533aa6` — machine-readable measurable validation gate.

GitHub compare from claim commit to attempt branch before this report:
- ahead by 4;
- behind by 0;
- exactly four changed files;
- all changed files are under `tech-assets/moises-audio/DSP/benchmarks/**`, matching declared write scope.

Remote read-back of `MOI-DSP-R001_VALIDATION_GATE.json` confirmed the committed gate content.

## Self-review findings

1. Avoided the false inference that a technically usable OSS DSP is automatically App-Store-safe.
2. Avoided using UI timers as the metronome audio clock.
3. Kept BPM/beat estimation out of DSP ownership; it consumes Analysis results only.
4. Kept transport state out of DSP ownership; it consumes Playback timing only.
5. Did not invent unresolved Reference speed/pitch ranges or count-in behavior.
6. Did not set CPU/memory/thermal PASS from desktop/vendor marketing; target-device measurements remain mandatory.
7. Did not promote any PARITY row based on research.

## Known remaining work

- Current Reference speed/pitch ranges and smoothing behavior: `UNKNOWN`, pending Reference task.
- Actual target-iPhone latency/CPU/RSS/thermal/battery for Apple TimePitch: not measured yet.
- Rubber Band / Superpowered / SoundTouch target-iPhone comparative benchmark: not run yet.
- Human blind listening on rights-cleared real tracks: not run yet.
- Exact commercial licence purchase terms must be rechecked if/when a challenger is selected for release.

## PARITY impact

No state change.

Rows informed but still `MISSING`:
- `MOI-P010` audio speed changer;
- `MOI-P012` pitch/key changer;
- `MOI-P014` smart metronome/click;
- `MOI-P015` count-in.

Implementation and real-device/real-track differential QA are required before any candidate parity status is proposed.

## Next dependency information

After HQ verifies this research task and `MOI-ARCH-001` establishes final shared vertical-slice contracts, `MOI-DSP-001` can implement the selected baseline without re-running this candidate-selection work. The implementation must retain a replaceable backend seam so Rubber Band or another commercially cleared challenger can be tested without changing shared contracts.
