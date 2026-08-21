# MOI-AN-001｜Music Analysis Candidate Benchmark

- Task: `MOI-AN-001`
- Worker: `Moises-Worker-2`
- Attempt: `task/MOI-AN-001/attempt-1`
- Baseline: `0b161104c9d905c85e65983b5d20ec98b5163b1e`
- PARITY rows: `MOI-P009`, `MOI-P011`, `MOI-P013`, `MOI-P016`
- PARITY change: **none**. This task defines implementation candidates and benchmark gates only.

## 1. Decision summary

The commercially safest implementation sequence is not one monolithic MIR dependency. It is a split pipeline:

1. **BPM / beats**: project-owned onset-envelope + periodicity/tempogram pipeline, with `librosa` (ISC) used as a permissive server/reference baseline during development.
2. **Key**: project-owned chroma/HPCP-style feature extraction + major/minor profile scoring. `librosa` chroma/CQT is suitable for reference prototyping; do not embed GPL key-finder code.
3. **Chords**: start with project-owned chroma + chord-template + temporal smoothing/Viterbi baseline; measure against CC0 McGill Billboard annotations. Move to ML only when training-audio and model-weight rights are explicit.
4. **Song parts / functional sections**: use MSAF (MIT core) as a structure-boundary research baseline and All-In-One as an accuracy/reference candidate only. Do **not** ship All-In-One as-is until its full pretrained/dependency chain is commercially cleared, because its normal install/runtime pulls model/data dependencies with non-commercial terms.
5. **Evaluation**: use `mir_eval` (MIT) metrics as the canonical offline scoring vocabulary.

This keeps the first product path free from AGPL/GPL/NC model obligations while preserving higher-accuracy research comparators.

## 2. Candidate matrix

`Commercial-fit` is a technical licensing assessment, not legal advice. 5 = favorable, 1 = blocked/high risk.

| Candidate | Tasks | Code/license | Weight/data constraint | Commercial-fit | Runtime fit | Decision |
|---|---|---|---|---:|---|---|
| Project-owned DSP + Accelerate/vDSP | BPM, beat, key, chord baseline | project-owned / Apple platform APIs | no pretrained weights | 5 | native iPhone/server | **Primary product path** |
| librosa | BPM/beat, chroma/CQT/features | ISC | no bundled pretrained model required | 5 | Python server/reference | **Reference + server baseline** |
| MSAF core | song structure boundaries/labels | MIT | dataset/algorithm-specific rights still separate; optional GPL extension exists separately | 4 | Python server/research | **Structure research baseline** |
| All-In-One Music Structure Analyzer | BPM, beat/downbeat, functional sections | MIT package | default pipeline depends on madmom models and source separation; full model/dependency rights must be cleared | 2 | GPU/server | Research comparator only |
| madmom source | beat/downbeat/chord-related MIR building blocks | BSD code | supplied model/data files CC BY-NC-SA 4.0 | 2 | Python/server | Code concepts/reference only; bundled models blocked |
| Essentia open distribution | BPM, key, chords/features, broad MIR | AGPLv3 | pretrained models CC BY-NC-ND 4.0 for non-commercial; proprietary licenses offered | 1 without paid license | C++/Python | Do not embed under current project license state |
| Essentia proprietary license | broad MIR | commercial license available on request | model/dependency scope must be covered by purchased terms | 4 conditional | C++/server/mobile possible | Procurement option if accuracy/time benefit justifies cost |
| aubio | tempo/beat/onset | GPLv3 | no model needed for many functions | 1 for closed-source embedding | C/iOS/server | Exclude unless commercial rights obtained |
| libKeyFinder | key | GPLv3+ | no ML weight requirement | 1 for closed-source embedding | C++ | Exclude from proprietary product |
| mir_eval | evaluation only | MIT | no product inference model | 5 | offline CI/server | **Canonical evaluator** |

## 3. BPM / beat tracking

### 3.1 Product-owned baseline

The baseline algorithm should be implementable without copying third-party source:

1. mono or weighted stereo downmix for analysis;
2. STFT / spectral-flux or energy-change onset strength;
3. onset-envelope normalization;
4. autocorrelation/tempogram candidate periods;
5. tempo prior + half/double-tempo candidate handling;
6. beat-phase dynamic programming / local peak alignment;
7. confidence derived from periodicity peak separation and beat consistency.

This is deliberately model-free. It is suitable for native implementation using Accelerate/vDSP and keeps latency/memory predictable.

### 3.2 librosa reference

`librosa` is ISC-licensed and provides beat/tempo and chroma primitives. It is appropriate as:
- a reproducible development reference;
- a server-side fallback candidate;
- a source of feature-definition comparison.

It should not become the architectural contract. The contract is BPM + beat timestamps + confidence, allowing a later native engine to replace it.

Source:
- https://github.com/librosa/librosa
- https://github.com/librosa/librosa/blob/main/LICENSE.md

### 3.3 Excluded direct dependencies

`aubio` supports beat/tempo tracking and runs on iOS, but is GPLv3 and explicitly advises contacting the author for commercial-product use. It is therefore not selected for a closed commercial app without separate rights.

Source:
- https://github.com/aubio/aubio
- https://aubio.org/

## 4. Key detection

### 4.1 Product-owned baseline

Selected baseline architecture:
- tuning estimation;
- CQT/STFT-derived chroma or HPCP-like 12-bin pitch-class energy;
- harmonic/percussive weighting as needed;
- aggregate over stable musical regions rather than raw whole-file energy only;
- compare against major/minor key profiles;
- return tonic, mode and confidence/margin.

This avoids shipping a copyleft key-detection library and leaves the feature extractor replaceable.

### 4.2 libKeyFinder

`libKeyFinder` is GPLv3-or-later. It is useful as an offline comparator but not selected for direct embedding in a proprietary application.

Source:
- https://github.com/mixxxdj/libkeyfinder

### 4.3 Essentia

Essentia is attractive technically because it has mature tonal/MIR algorithms, but its open license is AGPLv3 and its supplied ML models are non-commercial CC BY-NC-ND 4.0; the authors offer proprietary licensing. Therefore:
- no unlicensed product embedding;
- it may be benchmarked separately for accuracy;
- proprietary procurement is a legitimate future option if it materially beats the project-owned implementation.

Source:
- https://essentia.upf.edu/licensing_information.html

## 5. Chord recognition

### 5.1 Product-owned non-ML baseline

Start with a deterministic baseline:
- beat-synchronous or short-window chroma;
- major/minor/no-chord templates first;
- cosine/correlation score per candidate chord;
- temporal smoothing with HMM/Viterbi or equivalent project-owned state transition logic;
- optional seventh-chord vocabulary only after major/minor accuracy is stable;
- explicit `N`/no-chord state and confidence.

This baseline is unlikely to be the final quality ceiling. Its purpose is to establish a legally clean measurable floor and the exact output contract.

### 5.2 ML upgrade rule

A neural chord model can replace the baseline only when:
- source code license is compatible;
- pretrained weight license is explicit;
- training/fine-tuning audio rights are documented;
- the chord vocabulary can map deterministically into the product schema;
- the model beats the baseline on project-owned real-audio fixtures, not only public annotations.

McGill Billboard annotations are especially useful because the annotations are released under CC0, while the project page explicitly notes that original audio cannot be distributed for copyright reasons. This makes the distinction between annotation rights and audio rights explicit.

Source:
- https://ddmal.ca/research/The_McGill_Billboard_Project_%28Chord_Analysis_Dataset%29/

## 6. Functional song-part / structure analysis

### 6.1 MSAF

MSAF core is MIT-licensed and is a useful modular framework for structure analysis research. A separate `msaf-gpl` repository exists for GPL algorithms; those algorithms must not be silently imported into a closed commercial product.

Use MSAF for:
- boundary algorithm comparison;
- feature/segmentation experiment harness;
- non-functional A/B/C structural grouping reference.

Do not assume an arbitrary structural label (`A`, `B`, `C`) equals semantic `verse`, `chorus`, `bridge`.

Sources:
- https://github.com/urinieto/msaf
- https://github.com/urinieto/msaf/blob/main/LICENSE.md
- https://github.com/urinieto/msaf-gpl

### 6.2 All-In-One

All-In-One predicts BPM, beats, downbeats, functional segment boundaries and labels such as intro/verse/chorus/bridge/outro. Its repository code is MIT and it is a strong research reference for the target product behavior.

However, its standard installation explicitly includes `madmom`, and its pipeline uses source separation. `madmom` source is BSD but its supplied model/data files are CC BY-NC-SA 4.0. The source-separation dependency also requires the separate weight-rights review documented by `MOI-SEP-001`. Therefore the All-In-One repository's MIT license alone does not make the complete pretrained pipeline commercially shippable.

Decision: use it for offline/reference comparison only until the exact model and dependency chain is cleared or re-trained with project-owned/cleared weights.

Sources:
- https://github.com/mir-aidj/all-in-one
- https://github.com/mir-aidj/all-in-one/blob/main/LICENSE
- https://github.com/CPJKU/madmom

## 7. Evaluation library

`mir_eval` is MIT-licensed and provides established metrics for beat, key, chord and segmentation evaluation. It should be pinned in the benchmark environment and its metric configuration stored with results.

Source:
- https://github.com/mir-evaluation/mir_eval

## 8. Architecture seam

The product contract should expose four independent result domains so engines can change separately:

- `TempoAnalysis`: BPM, confidence, beat timestamps, optional downbeats.
- `KeyAnalysis`: tonic pitch class, major/minor mode, confidence.
- `ChordTimeline`: timestamped chord intervals, normalized labels, confidence.
- `SongStructure`: timestamped boundaries, structural cluster labels and optional functional labels/confidence.

No selected research library should leak its proprietary/internal label types into shared application contracts.

## 9. Acceptance mapping

- BPM/key/chord/song-part candidates compared: **satisfied**.
- Benchmark datasets and error metrics defined: see `reference/analysis/MOI-AN-001_BENCHMARK_PROTOCOL.md`.
- Licensing and commercial-use constraints documented: **satisfied**, including code-vs-model-vs-audio distinctions.

`MOI-P009`, `MOI-P011`, `MOI-P013`, and `MOI-P016` remain `MISSING` until real-audio differential tests and product integration pass their gates.
