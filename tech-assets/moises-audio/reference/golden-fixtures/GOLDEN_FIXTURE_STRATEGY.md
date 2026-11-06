# MOI-QA-001｜Golden QA Fixture Strategy

Task: `MOI-QA-001`  
Attempt: `task/MOI-QA-001/attempt-1`  
Worker: `Moises-Worker-2`  
Integration epoch: `1`

## Purpose

This fixture system exists to prevent false parity. A model that compiles, separates synthetic tones, or scores well on one public benchmark does **not** pass Moises-equivalence QA.

Final quality decisions require all of the following:

1. rights-cleared **real recorded music**;
2. multiple genres and production styles;
3. hard cases that expose bleed, transient loss, reverb and low-frequency confusion;
4. objective metrics where true stems/annotations exist;
5. blinded listening against the reference product on comparable input;
6. performance/recovery evidence for long tracks and failure states;
7. explicit provenance for every fixture.

## Fixture classes

### G1 — PROJECT_OWNED_REAL_MULTITRACK — mandatory final separation gate

Real musicians / real instruments / real vocals recorded for this project, or recordings for which the project has explicit written rights for repeated commercial engineering evaluation.

Required properties:
- isolated source tracks are available;
- mixture is reproducibly rendered from those sources;
- consent/license permits long-term internal QA and commercial product development;
- no Moises-owned audio, model output or training data is redistributed;
- stems and mixture hashes are recorded;
- recording, mix, sample rate, bit depth and mastering notes are preserved.

This class is the canonical source for objective separation metrics because the clean references are known.

Minimum before any separation PARITY proposal: **12 full songs**, with at least 8 distinct style/production buckets and at least 6 vocal tracks. A single performer/producer must not dominate more than one third of the set.

### G2 — RIGHTS_CLEARED_REAL_REFERENCE — mandatory differential listening gate

Commercially usable or explicitly licensed real recordings where the project may legally submit the same source audio to the reference application and its own implementation for A/B comparison.

True stems are not required. These fixtures are used for:
- blinded Moises-vs-project listening;
- processing latency comparison;
- UX/state comparison;
- reference-output artifact observation.

Minimum before any central-flow PARITY proposal: **12 tracks**, with at least 8 style/production buckets. These can overlap with G1 where rights allow the same full mix to be submitted to the reference service.

### G3 — PUBLIC_RESEARCH_NONCOMMERCIAL — research only, never final product gate

Examples include MUSDB18-HQ and MedleyDB. They are valuable for reproducible research but published terms restrict commercial use. They may be used only when the team's use is permitted by their terms and must never be copied into a release bundle, customer telemetry sample, marketing asset, or commercial training corpus without separate rights.

Current evidence:
- MUSDB18-HQ: educational purposes only; commercial use requires permission of copyright holders.
- MedleyDB: non-commercial research / CC BY-NC-SA terms for dataset audio.

These datasets can reveal regressions and provide historical comparability, but **cannot cause a PARITY pass**.

### G4 — LICENSED_SYNTHETIC — regression only

Slakh2100/Flakh2100 are CC BY 4.0 and useful because clean rendered sources are available. They are synthetic/rendered music and therefore useful for:
- deterministic CI regression;
- exact stem reconstruction checks;
- long-duration concatenation/stress generation;
- instrument-isolation corner cases.

They cannot satisfy the real-audio requirement on their own.

### G5 — GENERATED_SIGNAL — unit tests only

Sines, impulses, chirps, silence, pink noise, clicks, deterministic mixes.

Use for:
- numerical correctness;
- channel/sample-rate edge cases;
- seek/loop boundaries;
- cancellation and corruption tests.

Never use this class for subjective quality or PARITY.

## Provenance record

Every audio fixture must have a sidecar record containing at minimum:

```json
{
  "fixture_id": "G1-POP-001",
  "class": "PROJECT_OWNED_REAL_MULTITRACK",
  "title_alias": "qa-pop-001",
  "rights_basis": "written project release / explicit license",
  "redistribution_allowed": false,
  "commercial_engineering_use_allowed": true,
  "reference_service_submission_allowed": true,
  "source_hashes": {},
  "mixture_hash": "sha256:...",
  "duration_seconds": 0,
  "sample_rate_hz": 44100,
  "channels": 2,
  "genre_bucket": "pop",
  "hard_cases": [],
  "annotation_version": 1,
  "notes": ""
}
```

If `commercial_engineering_use_allowed` or `reference_service_submission_allowed` is not established, the fixture cannot be used for the relevant gate.

## Real-multitrack acquisition protocol

To make G1 durable and legally clean:

1. Commission or record original performances specifically for QA, or obtain explicit licenses from rights holders.
2. Store the signed rights record outside the public repository; GitHub receives only a non-sensitive fixture identifier and rights status.
3. Record isolated tracks dry enough to produce trustworthy references, plus realistic production effects when desired.
4. Render a fixed reference mixture and record the exact mixing recipe/version.
5. Freeze immutable hashes for the mixture and all source stems.
6. Never replace an existing fixture silently. Create a new fixture version.
7. Keep at least one unmastered and one mastered/dense case in each major style family where feasible.

## Required style / production coverage

The final G1+G2 set must collectively include at least:

- modern pop with lead + backing vocals;
- rock with distorted guitars and acoustic drums;
- acoustic singer-songwriter;
- electronic/dance with synthesized bass and side-chain pumping;
- hip-hop / rap with dense low end;
- piano/keyboard-led arrangement;
- funk/soul/groove with syncopation;
- live/rehearsal-style performance with timing drift;
- sparse ballad;
- dense wall-of-sound or heavily limited master;
- at least one mono/near-mono legacy-style mix;
- at least one 48 kHz source in addition to 44.1 kHz.

## Required hard-case coverage

Across G1+G2, the suite must contain explicit fixtures for:

- lead vocal + backing vocal overlap;
- breathy/falsetto vocal;
- heavy vocal reverb/delay;
- kick vs bass fundamental overlap;
- bass guitar vs low guitar/synth overlap;
- cymbal wash over vocal consonants;
- distorted guitar masking vocal midrange;
- piano attacks and long sustain;
- dense stereo widening / phase effects;
- live tempo drift;
- tempo change or rubato;
- key modulation;
- sparse intro followed by dense chorus;
- long silence / near-silence region;
- clipping/limiting;
- low-bitrate lossy source;
- abrupt edit / hard transient;
- very quiet material followed by loud material.

## Long-track fixtures

Long-track performance may use rights-cleared real material concatenated with controlled transitions, provided the source provenance remains valid.

Required durations for performance/recovery testing:
- 5 minutes — normal song baseline;
- 15 minutes — long mix / rehearsal;
- 30 minutes — stress;
- 60 minutes — endurance.

Long-track fixtures must test:
- peak RSS;
- wall time and real-time factor;
- device thermal state where on-device processing exists;
- upload/retry behavior where server processing exists;
- storage growth and cleanup;
- seek/loop response at early/middle/late positions;
- cancellation at 10%, 50% and near completion;
- interruption/relaunch recovery.

## Separation objective metrics

On G1/G4 where clean references exist, record per stem and aggregate:

- SI-SDR (dB);
- SDR or equivalent BSS score with tool/version pinned;
- mixture reconstruction error;
- stem energy leakage matrix where feasible;
- silent-source false-positive energy;
- channel count/sample-rate preservation;
- duration/sample alignment error;
- clipping/NaN/Inf checks.

Never aggregate away the worst stem. Report vocals/drums/bass/other separately.

Promotion evidence must include median, P10 and worst-case fixture results so a small set of strong tracks cannot hide catastrophic failures.

## Analysis objective metrics

When BPM/key/chord/song-part annotations exist on rights-cleared fixtures:

- BPM: exact ±4%, octave-aware score, explicit half/double-tempo error rate;
- Beat: F-measure plus continuity metrics;
- Key: exact, tonic, mode, weighted relation score;
- Chords: duration-weighted root/maj-min/triad accuracy, no-chord precision/recall, coverage;
- Sections: 0.5 s and 3 s boundary F, structural grouping metric, functional-label macro-F1 where labels exist.

Public annotation sets can be used as secondary reference, but their source-audio rights must be checked separately.

## Reference-product differential protocol

For G2 tracks:

1. Use the exact same source file for reference and project run where permitted.
2. Record timestamp, reference app version/build if visible, tier, selected separation mode and network conditions.
3. Export comparable stems/mix only where the reference product permits it.
4. Normalize playback level for blind listening without altering the underlying artifacts.
5. Randomize A/B identity; listener must not know which system produced which file.
6. Score using `LISTENING_UX_RUBRIC.md`.
7. Keep raw scores and comments; never overwrite losing runs.
8. Re-run after any material model/runtime change.

## Synthetic-only guardrail

A quality candidate is **automatically ineligible for PARITY** if any of these is true:

- no G1 or G2 real-audio fixture has been run;
- only G4/G5 fixtures pass;
- public benchmark results are cited but project-owned/rights-cleared real audio is absent;
- objective metrics exist without blinded listening for separation quality;
- listening exists without objective/reference metrics where clean stems are available;
- latency/memory/failure behavior is unmeasured for the intended runtime.

## Dataset licensing notes captured for this task

- MedleyDB audio: non-commercial research / CC BY-NC-SA 4.0 terms; do not use as final commercial gate asset.
- MUSDB18-HQ: educational-only; commercial use requires permission of copyright holders.
- Slakh2100/Flakh2100: CC BY 4.0; permitted as attributed synthetic regression material, but not sufficient for real-audio parity.

License state must be rechecked before any asset is actually downloaded into project infrastructure.

## Exit condition for the fixture system

This strategy is complete when:
- rights classes and mandatory real-audio rule are fixed;
- genre/hard-case coverage is explicit;
- provenance sidecar is defined;
- objective, listening, performance and failure evidence expectations are explicit;
- synthetic-only and non-commercial-dataset-only PASS is structurally impossible.

No PARITY row changes as a result of this document alone.