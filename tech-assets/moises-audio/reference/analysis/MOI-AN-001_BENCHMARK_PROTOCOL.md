# MOI-AN-001｜Music Analysis Benchmark Protocol

This protocol defines how BPM/beat, key, chord and song-structure candidates are to be compared. It is an evaluation contract, not a PARITY pass.

## 1. Non-negotiable fixture rule

A public MIR annotation set alone cannot prove product parity. Final promotion requires a **project-owned or explicitly rights-cleared real-audio fixture set** that can legally be processed, retained for engineering use, and used for repeated differential testing.

Synthetic audio may be used for deterministic unit tests, but a candidate cannot PASS the product gate using synthetic-only evidence.

Every benchmark fixture must record:
- audio rights/provenance category;
- genre/style;
- duration;
- sample rate/channels;
- presence of vocals;
- tempo stability / tempo changes;
- meter where known;
- key/modulation notes where known;
- chord-density category;
- structural complexity;
- ground-truth source and annotator confidence where applicable.

## 2. Public/reference datasets

### 2.1 Harmonix Set — beats/downbeats/BPM/functional sections

The Harmonix Set contains human annotations for 912 Western pop tracks, including beats, downbeats, BPM metadata and functional structural labels. The repository is MIT-licensed, but the project separately describes audio/spectrogram access and associated license terms. Therefore annotation/code availability must not be interpreted as a blanket right to redistribute source audio.

Use:
- beat/downbeat and BPM evaluation;
- functional section boundary/label reference;
- genre-stratified regression where lawful matching audio is available.

Do not:
- bundle copyrighted source audio into this repository;
- infer audio rights from the annotation repository license.

Source:
- https://github.com/urinieto/harmonixset

### 2.2 GiantSteps Tempo / Key — EDM tempo and key

GiantSteps provides curated tempo and key annotations for electronic dance music based on Beatport previews. The annotation repositories include download scripts for source previews; those source-audio rights are separate from annotation availability.

Use:
- tempo octave-error stress test;
- key classification in EDM/electronic material;
- reference annotations only with lawfully obtained audio.

A later crowdsourced GiantSteps tempo annotation release is listed under CC BY 4.0; `mirdata` documents GiantSteps key license information as CC BY-SA 4.0. Exact dataset/version and rights must be pinned when a benchmark is materialized.

Sources:
- https://github.com/GiantSteps/giantsteps-tempo-dataset
- https://github.com/GiantSteps/giantsteps-key-dataset
- https://www.cp.jku.at/datasets/giantsteps/

### 2.3 McGill Billboard — chord annotations

McGill Billboard v2 annotations are made available under CC0. The project explicitly does not distribute original copyrighted audio. This makes it appropriate as a chord/structure annotation reference when paired with independently lawful audio access.

Use:
- chord root/major-minor vocabulary;
- richer chord-vocabulary scoring;
- phrase/structure cross-checks.

Source:
- https://ddmal.ca/research/The_McGill_Billboard_Project_%28Chord_Analysis_Dataset%29/

### 2.4 Project Golden MIR set — mandatory final gate

Create a small but durable rights-cleared set containing at minimum:
- steady 4/4 pop with vocals;
- live drums with timing drift;
- electronic/dance track;
- acoustic singer-songwriter;
- dense rock/metal mix;
- piano/keyboard-heavy track;
- syncopated/funk or groove-heavy track;
- slow ballad;
- meter/tempo ambiguity case;
- modulation/key-change case;
- weak/no-percussion case;
- long intro/outro and unusual section order case.

At least one third of final fixtures should include real vocals, and the set must include both highly produced and sparse recordings.

## 3. BPM / tempo metrics

Record all of the following; do not collapse them into one score:

1. `tempo_rel_error = abs(predicted_bpm - reference_bpm) / reference_bpm`.
2. median and P90 relative error across tracks.
3. exact-tempo accuracy within ±4%.
4. octave-aware accuracy where half/double-tempo equivalents are counted separately as an alternate success metric.
5. half/double-tempo error rate as its own failure category.
6. analysis wall time and real-time factor.

Why both exact and octave-aware: an algorithm that consistently returns 70 BPM for a 140 BPM track can appear musically related but produces wrong UX for click/count-in unless the product explicitly resolves the metrical level.

## 4. Beat / downbeat metrics

Use `mir_eval`-compatible beat metrics with the configuration pinned in the result artifact:

- Beat F-measure with the conventional 70 ms matching tolerance.
- Cemgil score.
- Continuity metrics: `CMLc`, `CMLt`, `AMLc`, `AMLt`.
- Downbeat F-measure using a separately declared tolerance.
- median signed/absolute beat timing error.
- first-valid-beat acquisition delay for interactive/streaming variants.

A high aggregate F-score does not override severe continuity failures; long stretches of phase-shifted beats must remain visible in the result.

Reference:
- https://github.com/mir-evaluation/mir_eval/blob/main/mir_eval/beat.py

## 5. Key metrics

Canonical score: `mir_eval.key.weighted_score` with the MIREX-compatible descending-fifth option enabled.

Relationship weights:
- exact tonic + mode: 1.0
- perfect fifth relation: 0.5
- relative major/minor: 0.3
- parallel major/minor: 0.2
- other: 0.0

Also record:
- exact key accuracy;
- tonic-only accuracy;
- mode accuracy;
- confidence calibration bucket;
- modulation-case failure notes, because a single whole-song key may be intrinsically ambiguous.

Reference:
- https://github.com/mir-evaluation/mir_eval/blob/main/mir_eval/key.py

## 6. Chord metrics

Normalize reference and estimate intervals to the same time extent, then compute duration-weighted scores.

Required:
- root weighted accuracy;
- major/minor weighted accuracy;
- triad weighted accuracy;
- seventh/tetrad vocabulary score when the engine claims those labels;
- no-chord (`N`) precision/recall;
- chord-change boundary median absolute error;
- coverage: fraction of track duration for which a non-unknown decision is emitted.

The product must not inflate score by outputting only high-confidence easy intervals. Coverage and accuracy are reported together.

Reference:
- https://github.com/mir-evaluation/mir_eval/blob/main/mir_eval/chord.py

## 7. Song-structure metrics

Boundary quality and label/cluster quality are scored independently.

Required boundary metrics:
- precision / recall / F at 0.5 s;
- precision / recall / F at 3.0 s;
- median reference-to-estimate and estimate-to-reference boundary deviation.

Required structural-label metrics:
- pairwise precision / recall / F for repeated-section grouping;
- Adjusted Rand Index;
- normalized conditional entropy or equivalent over/under-segmentation diagnostic.

Functional labels (`verse`, `chorus`, `bridge`, etc.) require a separate normalized label mapping and macro-F1. Arbitrary cluster labels (`A`, `B`, `C`) must not be scored as if they were semantic labels.

References:
- https://github.com/mir-evaluation/mir_eval/blob/main/mir_eval/segment.py
- https://mir-eval.readthedocs.io/latest/api/segment.html

## 8. Performance metrics

Every candidate benchmark must record alongside accuracy:
- runtime topology: iPhone / server CPU / server GPU;
- hardware identifier;
- software/model version;
- cold and warm initialization time;
- analysis wall time;
- real-time factor;
- peak RSS where measurable;
- on-device thermal state and battery delta where applicable;
- server compute cost estimate per audio minute where applicable;
- failure, retry and cancellation behavior.

No candidate is promoted based only on accuracy if latency, memory or rights are unknown.

## 9. Minimum comparison format

Each benchmark run emits one machine-readable row per fixture and task domain, including:

```json
{
  "fixture_id": "...",
  "rights_class": "PROJECT_OWNED|LICENSED_TEST|PUBLIC_REFERENCE",
  "engine": "...",
  "engine_version": "...",
  "domain": "tempo|beat|key|chord|structure",
  "metrics": {},
  "wall_seconds": 0,
  "rtf": 0,
  "peak_rss_mb": null,
  "thermal": null,
  "known_limitations": []
}
```

`null` means unmeasured. It must not be silently converted to zero or a favorable value.

## 10. Promotion gate

A candidate can move from research to implementation only when:
1. code/model/data licensing is explicitly acceptable for its intended topology;
2. project-owned real-audio fixtures have been run;
3. all required domain metrics are present;
4. failure cases are retained, not filtered out;
5. latency/memory/cost are measured for the intended runtime;
6. comparison against the current selected baseline is reproducible;
7. no PARITY row is raised solely from public-dataset or synthetic results.

This task defines the protocol only. Product parity remains `MISSING` until the later implementation/QA tasks provide the required evidence.
