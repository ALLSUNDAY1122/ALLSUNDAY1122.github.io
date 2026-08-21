# MOI-SEP-001｜Model / Weight / Dataset License Matrix

This ledger separates **code license**, **pretrained-weight rights**, and **training-data rights**. They are not interchangeable.

Status vocabulary:
- `CLEAR_FOR_BASELINE`: evidence is sufficiently explicit for a technical commercial-feasibility decision; release-time legal/notices review still required.
- `RESEARCH_ONLY`: do not ship the referenced weights/assets in the commercial product.
- `REVIEW_REQUIRED`: evidence is incomplete or ambiguous; commercial shipping is blocked until clarified.

| Asset | Code | Pretrained weights | Training/eval data | Project status | Reason |
|---|---|---|---|---|---|
| Deezer Spleeter | MIT | Authors' JOSS paper states source code and pretrained models are MIT | Original internal training corpus is not our reusable dataset | `CLEAR_FOR_BASELINE` | Explicit published statement covers pretrained models; 4/5-stem ready path |
| facebookresearch Demucs | MIT code | Commercial status not explicit enough; official issue #327 remains unresolved in archived repo | Depends on model/training provenance | `REVIEW_REQUIRED` | Do not equate MIT code with model-weight rights |
| Demucs-class architecture + internally trained weights | MIT architecture subject to notices | Project-owned if training chain is cleared | Must use commercially licensed/owned corpus | `CLEAR_CONDITIONALLY` | Preferred long-term quality route if the data chain is clean |
| Open-Unmix code | MIT | Varies by model | Varies | `RESEARCH_ONLY` for official pretrained product use until individually cleared | Code license does not settle each model/data chain |
| Open-Unmix `umxl` | MIT code | CC BY-NC-SA 4.0, non-commercial | private stems data | `RESEARCH_ONLY` | Documentation explicitly limits weights to non-commercial use |
| Open-Unmix `umxhq` / `umx` | MIT code | No explicit commercial grant captured by this task | MUSDB18-HQ / MUSDB18 are commercially restricted datasets | `REVIEW_REQUIRED` | Keep as benchmark, not default shipping dependency |
| MUSDB18 | n/a | n/a | Educational; commercial use requires express permission | `RESEARCH_ONLY` | Cannot be default commercial training corpus |
| MUSDB18-HQ | n/a | n/a | Educational; commercial use requires express permission | `RESEARCH_ONLY` | Same restriction; includes NC-licensed source material |
| Slakh2100 | support code separate | n/a | CC BY 4.0 | `CLEAR_CONDITIONALLY` | Commercially usable with attribution, but synthetic and insufficient alone for real-recording parity |
| ONNX Runtime Mobile | open-source runtime; release dependency review required | n/a | n/a | `RUNTIME_CANDIDATE` | iOS Objective-C package, Swift bridge, CoreML/XNNPACK support |

## Source evidence

### Spleeter
- Repository and code license: https://github.com/deezer/spleeter
- Pretrained model inventory: https://github.com/deezer/spleeter/wiki/3.-Models
- JOSS paper: https://joss.theoj.org/papers/10.21105/joss.02154

Important distinction: the repository README explicitly describes the **code** as MIT, while the authors' JOSS publication explicitly describes both the source code and pretrained models as MIT-distributed. This stronger model-specific evidence is why Spleeter is selected as the first shipping-feasibility baseline rather than assuming every MIT ML repository also licenses its weights.

### Demucs
- Repository: https://github.com/facebookresearch/demucs
- Pretrained-weight license question: https://github.com/facebookresearch/demucs/issues/327

The repository was archived in 2025. The open issue demonstrates unresolved ambiguity around distributing the provided pretrained models commercially. Until an authoritative grant is captured, official weights stay blocked for product shipping.

### Open-Unmix
- Product/docs: https://sigsep.github.io/open-unmix/
- Repository: https://github.com/sigsep/open-unmix-pytorch

The documentation explicitly marks `umxl` weights as non-commercial CC BY-NC-SA 4.0. For `umxhq` and `umx`, this task does not infer commercial model rights from the MIT source-code license or from availability of downloads.

### MUSDB
- MUSDB18: https://zenodo.org/records/1117372
- MUSDB18-HQ: https://zenodo.org/records/3338373

Both records restrict the supplied music material to educational use unless the copyright holders grant permission. This makes them unsuitable as the default corpus for training a commercially deployed model.

### Slakh2100
- Dataset site and attribution: https://www.slakh.com/

Slakh2100/Flakh2100 are CC BY 4.0. They can support commercially compatible experimentation/training with attribution, but their synthesized nature means a model trained only on Slakh cannot establish real-world vocal/instrument separation parity.

### iOS runtime
- Objective-C / Swift bridge: https://onnxruntime.ai/docs/get-started/with-obj-c.html
- CoreML Execution Provider: https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- Mobile deployment guidance: https://onnxruntime.ai/docs/tutorials/mobile/

## Release gate

Before any separator model or runtime is embedded in a production build or production service, record:
1. exact repository/tag/package version;
2. exact model-weight artifact hash and its license/provenance;
3. notices/attribution obligations;
4. training-data provenance if the project owns or fine-tunes the weights;
5. any model-use restrictions separate from source-code license;
6. server dependency/container licenses if inference is remote.

Absence of one of these items means `REVIEW_REQUIRED`, not implicit approval.
