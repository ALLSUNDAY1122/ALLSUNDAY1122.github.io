# MOI-SEP-LIC-001｜Separator License / Weight / Data Audit

Captured: 2026-08-22 JST
Task: `MOI-SEP-LIC-001`
Attempt: `task/MOI-SEP-LIC-001/attempt-1`
Scope: research/licensing only. No PARITY state change.

## Decision

None of the previously shortlisted ready-to-run pretrained separators is treated as commercially cleared for this product today.

The selected lawful product path is:

1. Use a permissively licensed separator architecture/runtime as code only.
2. Train **project-owned weights from scratch** without MUSDB/MUSDB-HQ and without any restricted pretrained initializer.
3. Use rights-cleared project-owned/commissioned real multitracks as the production-quality corpus.
4. Slakh2100 (CC BY 4.0) may be used as supplementary synthetic instrument data with attribution, but it cannot substitute for real vocal/multitrack evidence.
5. First deployment topology remains **server-side inference**, because it avoids premature iPhone memory/thermal constraints while model quality is still being established.

Preferred architecture family for that path: **Demucs/HTDemucs-class code**, because the code is MIT and the repository documents training/exporting custom models. Official pretrained weights are explicitly excluded.

## Candidate matrix

| Candidate | Code | Exact pretrained-weight status | Training-data provenance | Commercial shipping verdict |
|---|---|---|---|---|
| Spleeter 2/4/5-stem | MIT code | **AMBIGUOUS / NOT CLEARED by project policy.** A 2020 JOSS paper states code and pretrained models were distributed under MIT, but the current repository README says only the code is MIT. GitHub issue #957 (2026-07-20) asks specifically about commercial use, conversion and redistribution; it remains open and the two comments through 2026-08-17 contain no Deezer maintainer answer. | Deezer internal datasets, including Bean; JOSS says training data cannot be released for copyright reasons. | Do not ship weights or converted weights until Deezer gives an authoritative current grant/contract resolving commercial use and intended distribution topology. Server-only use is also held pending the same grant. |
| Demucs / HTDemucs official pretrained | MIT code | **NOT COMMERCIAL.** In issue #327, contributor/author Alexandre Defossez states the model weights are not covered by MIT and are provided only for scientific purposes. | Current HTDemucs README says MUSDB-HQ plus an extra 800-song dataset; MDX variants also use MUSDB-HQ. MUSDB-HQ itself is educational/non-commercial without permission. | Exclude all official pretrained weights from commercial builds/services unless Meta/rights holders issue a superseding written grant. |
| Demucs-class project-owned weights | MIT code | **CLEARABLE BY PROJECT** if trained from scratch and owned by the project; no official pretrained initializer. | Only datasets with commercial training rights. Proposed: project-owned/commissioned real multitracks + Slakh2100 CC BY 4.0 supplementary data. Explicitly disable MUSDB in training config. | **Selected product path.** Weight ownership and dataset provenance must be recorded in a model card and training manifest. |
| Open-Unmix `umxl` | MIT code | Explicitly CC BY-NC-SA 4.0 / non-commercial in official Open-Unmix docs. | Private stems dataset. | Exclude from commercial shipping. |
| Open-Unmix `umxhq` / `umx` | MIT code | No independent commercial pretrained-weight grant was found in the official docs captured here. | `umxhq` is trained on MUSDB18-HQ; `umx` on MUSDB18. Both datasets state educational-only / no commercial use without express permission. | Research baseline only unless exact weight and training-data rights are separately cleared. |

## Authoritative evidence

### Spleeter

- Current repository license file: MIT for the software/code.
  - https://github.com/deezer/spleeter/blob/master/LICENSE
- Current README says: `The code of Spleeter is MIT-licensed.` It also advertises a commercial Spleeter Pro route.
  - https://github.com/deezer/spleeter
- 2020 JOSS paper states that Spleeter source code and pretrained models were distributed under MIT. It also says the models were trained on Deezer internal datasets and that the training data cannot be released for copyright reasons.
  - https://joss.theoj.org/papers/10.21105/joss.02154
- Current commercial-use/format-conversion question is still unresolved:
  - https://github.com/deezer/spleeter/issues/957
  - As of 2026-08-17, comments show other commercial users asking the same question and no maintainer answer.

Project rule: because `MOI-SEP-LIC-001` explicitly forbids treating Spleeter pretrained weights as commercially cleared while current weight-use/conversion/redistribution ambiguity remains unresolved, the historical paper statement is not enough for production approval.

### Demucs / HTDemucs

- Code license: MIT.
  - https://github.com/facebookresearch/demucs/blob/main/LICENSE
- Official pretrained-weight issue:
  - https://github.com/facebookresearch/demucs/issues/327
  - Author/contributor statement: weights are outside the MIT grant and intended only for scientific use.
- Current README training provenance:
  - https://github.com/facebookresearch/demucs
  - HTDemucs is described as trained on MUSDB-HQ plus an extra 800-song dataset.
- Training documentation supports custom datasets and exporting locally trained models:
  - https://github.com/facebookresearch/demucs/blob/main/docs/training.md
  - `conf/config.yaml` permits `use_musdb: false` and custom WAV datasets.

### Open-Unmix

- Code license: MIT.
  - https://github.com/sigsep/open-unmix-pytorch/blob/master/LICENSE
- Official pretrained model docs:
  - https://sigsep.github.io/open-unmix/
  - `umxl` weights are explicitly non-commercial (CC BY-NC-SA 4.0).
  - `umxhq` is trained on MUSDB18-HQ; `umx` on MUSDB18.

### Training datasets

- MUSDB18:
  - https://zenodo.org/records/1117372
  - License text limits the corpus to educational purposes and requires express rights-holder permission for commercial use.
- MUSDB18-HQ:
  - https://zenodo.org/records/3338373
  - Same commercial restriction; provenance includes multiple non-commercial sources.
- Slakh2100:
  - https://www.slakh.com/
  - Official site states Slakh2100/Flakh2100 are CC BY 4.0.
  - It is synthesized MIDI/rendered multitrack data, so it is supplementary evidence/data, not a real-vocal quality substitute.

## Selected lawful training path

### Weight ownership

- Initialize model weights randomly/project-controlled; do not load official Demucs/Spleeter/Open-Unmix pretrained weights.
- Training job outputs are project-owned artifacts under the project's chosen commercial terms.
- Preserve a reproducibility manifest containing architecture commit, dependency versions, dataset item IDs, rights record IDs, training config, seed, weight hash and evaluator versions.

### Data contract

Each real multitrack training item must have:

- explicit permission for ML training and commercial exploitation of resulting weights;
- permission covering isolated stems, mixtures and transformations used in augmentation;
- provenance/rights-holder identity and signed release/contract reference;
- permitted retention/deletion rules;
- instrument/stem mapping to vocals/drums/bass/other and any advanced stems.

Prohibited for commercial training unless separately licensed: MUSDB18, MUSDB18-HQ and any other dataset whose terms are educational/non-commercial.

Slakh2100 may be included with CC BY 4.0 attribution, but because it is synthetic it must not be the sole training or validation basis for real-recording PARITY.

## Cost / runtime / schedule risks

| Area | Risk | Mitigation |
|---|---|---|
| Real multitrack data acquisition | **High / likely dominant cost.** Rights-cleared vocals and full-band stems must be recorded, commissioned or licensed. | Start rights ledger before ingestion; reject any item without explicit commercial ML-training rights. |
| GPU training | **Medium-high.** Spleeter's published training took roughly one week on a single GPU; HTDemucs training is heavier and uses long multi-epoch schedules. Exact project cost remains UNKNOWN until corpus/model size is fixed. | Begin with a smaller 4-stem training configuration and instrument training telemetry; scale only after quality trend is proven. |
| Quality | **High.** Training from scratch avoids license ambiguity but may trail modern pretrained models until enough real data exists. | Use Golden QA gates, real multi-genre fixtures, listening rubric and objective metrics; no synthetic-only promotion. |
| Deployment runtime | **Medium.** Large Demucs-class models are not assumed suitable on-device. | First commercial topology: server inference; measure RTF/GPU memory/cost before any iPhone conversion attempt. |
| Schedule | **High / multi-week risk.** Corpus contracting, cleaning, training and iterative listening cannot be treated as a one-week implementation task. | Parallelize rights acquisition, dataset tooling and benchmark harness; keep pretrained licensing procurement as a separate optional fast-track. |

## Optional procurement fast-track

Spleeter's current README advertises a commercial Spleeter Pro offering. If a written commercial agreement can grant the exact intended use (server inference and, if needed, conversion/redistribution), it may be faster than self-training. No public price or exact weight grant was found in this audit, so cost and schedule remain `UNKNOWN/TBD quote`. This route cannot unblock shipping until the contract explicitly covers the selected topology.

## Acceptance check

- Code license, exact pretrained-weight rights and training-data provenance separated for every prior shortlist candidate: **PASS**.
- At least one lawful multi-stem path: **PASS — project-owned Demucs-class weights trained from scratch on rights-cleared data, server topology**.
- Spleeter not classified commercially cleared while #957 remains unresolved: **PASS**.
- Official Demucs pretrained weights excluded: **PASS**.
- Shortest lawful procurement/training path selected with cost/data/runtime/schedule risks: **PASS**.

No `PARITY_MATRIX` entry is modified by this task. `MOI-P003`, `MOI-P004`, `MOI-P005` remain `MISSING` pending real inference, quality and product evidence.
