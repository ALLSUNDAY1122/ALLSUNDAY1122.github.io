# MOI-QA-001｜Golden Fixture License Audit

Captured: 2026-08-22  
Purpose: establish which public datasets may be used as final commercial-product QA evidence versus research/regression only.

This file is an engineering rights screen, not legal advice. Exact terms must be re-read before downloading, redistributing, training on, or shipping any dataset-derived asset.

## MedleyDB

Official dataset site:
- https://medleydb.weebly.com/downloads.html
- https://medleydb.weebly.com/description.html

Observed terms:
- dataset audio is offered for non-commercial research use;
- site states CC BY-NC-SA 4.0 terms for the dataset/audio;
- the separate MedleyDB software repository is MIT, but that software license does **not** grant commercial rights to the audio.

Project classification: `G3_PUBLIC_RESEARCH_NONCOMMERCIAL`.

Allowed project role:
- optional research/reference benchmark where use complies with terms.

Not allowed as the only final commercial QA gate:
- do not treat strong MedleyDB scores as product PARITY;
- do not bundle audio in app/repository/release;
- do not use as default commercial training corpus without separate rights.

## MUSDB18-HQ

Official Zenodo record:
- https://zenodo.org/records/3338373

Observed terms:
- provided for educational purposes only;
- material should not be used commercially without express permission from copyright holders;
- package contains mixture plus drums/bass/other/vocals stems.

Project classification: `G3_PUBLIC_RESEARCH_NONCOMMERCIAL`.

Allowed project role:
- reproducible research comparison if use complies with terms.

Not allowed as the only final commercial QA gate:
- no PARITY based solely on MUSDB18-HQ;
- no assumption that downloaded stems are commercially reusable assets.

## Slakh2100 / Flakh2100

Official site:
- https://www.slakh.com/

Observed terms:
- Slakh2100 and Flakh2100 are licensed under Creative Commons Attribution 4.0 International.
- dataset is synthesized/rendered multitrack music rather than a substitute for diverse real commercial recordings.

Project classification: `G4_LICENSED_SYNTHETIC`.

Allowed project role:
- deterministic source-separation regression;
- exact stem-reference numerical checks;
- stress/long-track construction subject to attribution and license terms;
- CI fixtures where storage size is practical.

Restriction in this project:
- synthetic-only PASS is forbidden;
- Slakh success cannot replace G1/G2 real-audio evidence.

## mir_eval

Repository:
- https://github.com/mir-evaluation/mir_eval

Observed state:
- MIT-licensed evaluation library;
- suitable for offline metric computation for beat, key, chord and segmentation benchmarks.

Project classification: evaluation tooling candidate; it does not provide audio rights.

## Project-owned real multitrack material

Preferred final-gate rights route:
- original recordings commissioned/recorded for this project; or
- explicit written license from all necessary rights holders permitting repeated commercial engineering evaluation and, when required, submission to the reference service.

The rights record itself should be kept out of the public repository if it contains personal/signature details. GitHub records only fixture id, rights status, hashes, allowed uses and version.

## Decision

Final source-separation and product-flow PARITY proposals require G1/G2 real audio. Public non-commercial datasets are supplementary research evidence. Licensed synthetic data is regression evidence. None of these categories may be silently promoted across rights boundaries.
