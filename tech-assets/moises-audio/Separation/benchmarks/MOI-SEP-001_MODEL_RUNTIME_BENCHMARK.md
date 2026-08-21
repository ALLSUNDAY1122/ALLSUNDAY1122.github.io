# MOI-SEP-001｜Source Separation Model / Runtime Benchmark

- Task: `MOI-SEP-001`
- Worker: `Moises-Worker-2`
- Attempt: `task/MOI-SEP-001/attempt-1`
- Integration epoch: `1`
- Baseline: `0b161104c9d905c85e65983b5d20ec98b5163b1e`
- Scope: research / architecture decision only
- PARITY rows touched by evidence: `MOI-P003`, `MOI-P004`, `MOI-P005`
- PARITY state change: **none**. All remain `MISSING` until real project fixtures and device/server measurements pass the gates.

## 1. Decision summary

The selected first path to **real multi-stem inference** is:

> **Server-side Spleeter 4-stem as the legally clearest baseline implementation, with 5-stem retained as an optional capability.**

The long-term quality path is:

> **A Demucs/HTDemucs-class server model using weights whose commercial rights are independently cleared (preferably internally trained/fine-tuned on a commercially licensed multitrack corpus).**

The iPhone on-device path remains an experiment, not the default production path:

> **ONNX Runtime Mobile + CoreML/XNNPACK should be tested first with a smaller Spleeter-class model. Do not assume a desktop PyTorch graph will map efficiently to ANE/CoreML.**

This decision minimizes the risk of claiming model quality while having no commercial right to ship the weights, and minimizes early iPhone memory/thermal risk.

## 2. What is measured vs. what is prior evidence

No project-owned Golden QA fixture has yet been run by this task. Therefore this document does **not** claim measured Moises parity.

The scores below are engineering-selection scores based on documented architecture, licensing, published/reference results and expected deployment topology. Device RSS, thermal state, battery impact, project RTF and listening quality remain `UNKNOWN` until `MOI-QA-001` and the later implementation task provide actual evidence.

Scale: 5 = favorable / low risk, 1 = unfavorable / high risk. `Legal` means suitability for a commercial shipping path based on the evidence currently available; it is not legal advice.

| Candidate | Topology | Legal | Expected quality | Latency | iPhone memory | iPhone thermal | Infra cost | Integration effort | Decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| Spleeter 4/5-stem pretrained | Server GPU/CPU | 5 | 3 | 4 | 5 | 5 | 3 | 5 | **Primary baseline** |
| Spleeter 4-stem converted | On-device ORT/CoreML | 5 | 3 | 2 | 2 | 2 | 5 | 2 | Experimental |
| HTDemucs/Demucs official pretrained | Server | 2 | 5 | 3 | 5 | 5 | 2 | 3 | Benchmark only until weight rights are resolved |
| Demucs-class, self-owned weights | Server | 4* | 5 potential | 3 | 5 | 5 | 2 | 1 | **Long-term quality candidate** |
| Open-Unmix `umxl` pretrained | Server | 1 | 3 | 3 | 5 | 5 | 3 | 4 | Exclude from commercial product |
| Open-Unmix `umxhq`/`umx` pretrained | Server | 2 | 3 | 3 | 5 | 5 | 3 | 4 | Rights review required; do not ship by default |
| HTDemucs-class converted to mobile | On-device | 1-2 | 5 potential | 1 | 1 | 1 | 5 | 1 | Not MVP |
| Spleeter server + thin iOS client | Hybrid | 5 | 3 | 3-4 | 5 | 5 | 3 | 4 | **Recommended product topology for first real slice** |

`*` Self-owned weights are only commercially clean if every training/fine-tuning asset and dependency is cleared for that use. The architecture license alone is not enough.

## 3. Candidate evidence

### 3.1 Spleeter

Spleeter provides pretrained 2-, 4- and 5-stem models. The 4-stem configuration is vocals / drums / bass / other; the 5-stem configuration adds piano. The implementation is TensorFlow-based.

The authors' JOSS paper states that the source code **and pretrained models** are distributed under MIT. The repository README separately identifies the code as MIT. Because the JOSS wording is explicit about the pretrained models, Spleeter currently has the clearest evidence among the compared ready-to-run multi-stem options for an initial commercial-feasible baseline. A release-time notices/legal review is still required.

Published reference results in the 2020 JOSS paper are useful only as historical baseline evidence, not as our product measurement. The reported 4-stem Spleeter MWF SDR values were approximately 6.86 vocals, 5.51 bass, 6.71 drums and 4.55 other on the referenced benchmark. The same paper reports GPU throughput far above real time on then-current desktop hardware. These values must not be converted into an iPhone or production SLA.

Sources:
- https://github.com/deezer/spleeter
- https://github.com/deezer/spleeter/wiki/3.-Models
- https://joss.theoj.org/papers/10.21105/joss.02154

### 3.2 Demucs / HTDemucs family

The archived `facebookresearch/demucs` repository is MIT-licensed at code level and is a strong quality reference family. However, an official repository issue specifically asks whether the provided pretrained weights inherit that license; the issue remains open in the archived repository. Therefore **code license must not be treated as proof of pretrained-weight commercial rights**.

Decision:
- Architecture/code may be used subject to the MIT terms.
- Official pretrained weights are **not an approved shipping dependency** in this project until provenance/license is explicitly cleared.
- A Demucs-class model with internally owned/cleared weights is the preferred long-term quality investigation because it avoids the weight-rights ambiguity while retaining a modern high-quality architecture family.

Sources:
- https://github.com/facebookresearch/demucs
- https://github.com/facebookresearch/demucs/issues/327

### 3.3 Open-Unmix

The Open-Unmix code is MIT. Its documentation explicitly states that the `umxl` weights are licensed only for non-commercial use under CC BY-NC-SA 4.0, so `umxl` is excluded from the commercial product path.

The `umxhq` and `umx` pretrained models are trained on MUSDB18-HQ/MUSDB18 respectively. The Open-Unmix documentation does not, in the evidence captured here, give us a sufficiently explicit independent commercial shipping grant for those weights. In addition, the MUSDB datasets themselves are restricted to educational/non-commercial use without permission from rights holders. We therefore keep `umxhq`/`umx` as research baselines only until their model-weight distribution terms are separately cleared; we do not infer a commercial right from the MIT code license.

Sources:
- https://sigsep.github.io/open-unmix/
- https://github.com/sigsep/open-unmix-pytorch
- https://zenodo.org/records/1117372
- https://zenodo.org/records/3338373

## 4. Training-data constraint

### MUSDB18 / MUSDB18-HQ

MUSDB18 and MUSDB18-HQ are valuable evaluation/reference corpora but the published license says their material is for educational purposes and cannot be used commercially without express permission from copyright holders. They therefore cannot be the default corpus for training a commercially distributed project model.

### Slakh2100

Slakh2100 is published under CC BY 4.0 and is commercially usable with attribution. It is synthesized/rendered multitrack material, so it is useful for pretraining, regression tests, augmentation and instrument-separation coverage. It is **not enough by itself to prove production-grade separation on real commercial recordings**, and it should not be treated as a substitute for a rights-cleared real-world vocal/multitrack corpus.

Sources:
- https://zenodo.org/records/1117372
- https://zenodo.org/records/3338373
- https://www.slakh.com/

## 5. Runtime topology comparison

### A. Server inference

Advantages:
- Keeps model memory and sustained compute off the iPhone.
- Makes larger/future models practical without App Store binary-size constraints.
- GPU fleet can be upgraded independently from the client.
- Simplifies first implementation of TensorFlow/PyTorch reference models.

Costs/risks:
- User audio must cross the network unless a privacy-preserving local mode is added.
- Upload/download time can dominate short inference time.
- GPU/CPU inference has recurring cost.
- Processing must support upload cancellation, idempotent retry, deletion and expiration policies.

**Selected for the first actual multi-stem vertical slice.**

### B. On-device inference

ONNX Runtime publishes an Objective-C iOS package that can be called from Swift. Its iOS runtime can use CoreML or XNNPACK. The CoreML Execution Provider requires iOS 13+; MLProgram mode requires iOS 15+. ONNX Runtime explicitly notes that performance is model/device specific and that partitioning caused by unsupported operators can degrade performance. Static shapes may improve CoreML execution.

Therefore the presence of a CoreML/ONNX conversion path is not evidence that a separator is suitable for on-device production. The following must be measured on target devices before promotion:
- conversion/operator coverage
- model load time
- peak RSS
- RTF for 1, 5 and 10 minute inputs
- sustained thermal state
- battery delta
- audio I/O scratch-space requirements
- cancellation/recovery behavior

Sources:
- https://onnxruntime.ai/docs/get-started/with-obj-c.html
- https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- https://onnxruntime.ai/docs/tutorials/mobile/

### C. Hybrid

The selected initial product topology is hybrid at the app level: native iOS import/status/playback UX with server-side separation. This gives the first implementation a realistic path to stable multi-stem output while leaving an explicit migration seam for future on-device models.

Hybrid does **not** remove privacy obligations. Upload encryption, retention, deletion, failed-job cleanup, retry and user-facing network state must be part of later product tasks.

## 6. First real-inference implementation contract

The next implementation task should use the following contract without redefining shared app contracts:

1. Input: decoded/normalized audio file from the product import pipeline.
2. First engine: Spleeter 4-stem, pinned model/runtime versions.
3. Outputs: `vocals`, `drums`, `bass`, `other`, with sample rate/channel metadata.
4. Optional evidence mode: 5-stem including `piano`.
5. Job lifecycle: queued → running → succeeded / cancelled / failed; deterministic retry identity.
6. Artifacts: original input is not silently retained; stems have an explicit expiry/deletion rule.
7. Metrics captured per job:
   - input duration
   - wall-clock processing duration
   - real-time factor
   - upload/download time separately
   - model/runtime version
   - backend device class
   - failure/cancellation result
8. Listening/quality is judged only against Golden QA fixtures and human listening rubric; no synthetic-only PASS.

## 7. Gates before a candidate can replace the baseline

A replacement separator may be promoted only if all are true:
- pretrained/self-trained weight rights are documented for commercial distribution/use;
- dependencies have compatible commercial licenses;
- real multi-genre fixtures beat or materially improve the baseline on the agreed objective/listening rubric;
- latency and infrastructure cost are measured;
- failure/cancel/retry semantics stay deterministic;
- output stem names/semantics remain compatible with the product contract;
- no current PARITY row is raised merely because inference runs.

## 8. Known unknowns / explicit risks

- `UNKNOWN`: current Moises iPhone separation quality/latency on identical fixtures; reference-capture task owns that evidence.
- `UNKNOWN`: Spleeter server RTF on the infrastructure we will actually use.
- `UNKNOWN`: Spleeter-on-iPhone peak RSS, thermal and battery cost.
- `UNKNOWN`: whether a production-quality Demucs-class weight set can be obtained under rights acceptable for this product without training our own.
- `UNKNOWN`: cost of a rights-cleared, real-recording multitrack training corpus.
- Risk: server topology adds privacy/retention and network-failure requirements.
- Risk: Spleeter is an older quality baseline; it is selected for legal/runtime clarity, **not because parity quality has been proven**.

## 9. Acceptance mapping

- Commercial-license-feasible candidates compared: **satisfied by this benchmark + license matrix**.
- On-device/server/hybrid scored for quality, latency, memory, thermal, cost: **satisfied as an engineering-selection matrix; unmeasured fields explicitly remain UNKNOWN**.
- At least one path to real multi-stem inference selected with risks: **satisfied — server-side Spleeter 4-stem first, Demucs-class rights-cleared server model as quality-upgrade path**.

This task provides a decision and evidence only. `MOI-P003`, `MOI-P004`, and `MOI-P005` remain `MISSING` until implementation and differential QA evidence exist.
