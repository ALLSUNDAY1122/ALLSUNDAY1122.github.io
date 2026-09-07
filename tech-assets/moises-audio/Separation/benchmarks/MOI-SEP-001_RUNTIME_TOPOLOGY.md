# MOI-SEP-001｜Lawful model/runtime topology

Captured: 2026-08-22 JST
Attempt: `task/MOI-SEP-001/attempt-2`
Integration epoch: 1
Scope: runtime/topology research only. No PARITY state change.

## Non-negotiable licensing input

This attempt consumes `MOI-SEP-LIC-001` as a hard constraint.

Production candidates MUST use:
- permissively licensed Demucs/HTDemucs-class code only;
- project-owned weights trained from scratch;
- rights-cleared project-owned/commissioned real multitracks;
- optional CC BY 4.0 Slakh2100 only as supplementary synthetic data.

Production candidates MUST NOT load or convert:
- official Demucs pretrained weights;
- current Spleeter pretrained weights unless a later authoritative written commercial grant resolves the verified ambiguity;
- Open-Unmix weights whose model/data rights are noncommercial or otherwise not independently cleared;
- MUSDB/MUSDB-HQ as commercial training data without separate express rights.

The architecture/runtime decision below therefore does not re-open model-rights questions.

## Candidate topology comparison

Scores are pre-benchmark engineering scores from 1 (weak) to 5 (strong). They are NOT measured quality or PARITY evidence. Unknowns are deliberately penalized.

| Candidate | Exact model artifact | Quality preservation | First-result latency | iPhone memory/thermal | Infra cost | Conversion/operator risk | Offline/privacy | Engineering confidence | Decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| A. PyTorch CUDA server | project-owned training checkpoint loaded by the same PyTorch model code used for validation | 5 | 3 | 5 | 2 | 5 | 2 | 5 | **SELECTED BASELINE** |
| B. ONNX Runtime CUDA server | export of the same project-owned checkpoint | 4 | 4 | 5 | 3 | 3 | 2 | 3 | challenger after numerical/audio equivalence |
| C. Direct Core ML ML Program on-device | direct PyTorch -> Core ML conversion of project-owned weights | 3 | 3 | 2 | 5 | 2 | 5 | 2 | R&D only until full export + device gate passes |
| D. ONNX Runtime + CoreML EP on-device | ONNX export partitioned to Core ML execution provider where supported | 3 | 3 | 2 | 5 | 2 | 5 | 2 | secondary R&D path, not first production path |
| E. Hybrid product flow: server inference + iPhone durable cache/state | A or later B performs inference; iPhone owns upload state, project state and downloaded stems | 5 | 4 after upload/job orchestration; first inference still network-bound | 5 | 2 | 4 | 3 | 5 | **SELECTED PRODUCT TOPOLOGY** |

### Why A is the inference baseline

Training is already planned in PyTorch/Demucs-class code. Serving that same project-owned checkpoint through PyTorch/CUDA removes a model-format conversion step from the first quality loop. This is the lowest-risk way to determine whether the lawful project-owned model itself can reach the Golden QA quality bar before optimizing deployment.

PyTorch's current CUDA stack remains a direct production-capable GPU execution path; the project still must pin framework/CUDA versions and measure actual VRAM, RTF and throughput.

### Why E is the initial product topology

The current iPhone Reference evidence shows upload progress followed by a playable project/player state while stems are still being prepared. A server inference job with local durable project state naturally supports the same nonblocking lifecycle without assuming that large separation inference must run on-device.

The iPhone side owns:
- input normalization and upload lifecycle;
- project/job identifiers and durable processing snapshot;
- playable source/local media state where available;
- download verification and durable stem caching;
- cancellation/retry/reconnect presentation;
- mixer/practice behavior once stem artifacts are available.

The server side owns:
- selected project-owned separator model version;
- inference execution;
- deterministic stem manifest and hashes;
- progress/job state;
- output retention/deletion policy required by Privacy/P024 work.

## Why ONNX is a challenger, not baseline

ONNX Runtime provides CUDA and mobile execution-provider paths and reduced-operator builds for constrained environments. It is attractive for lower runtime footprint and provider portability, but every exported separator graph must first prove:
- successful export without silent graph changes;
- output waveform equivalence against PyTorch on the same weights/input;
- no stem reorder/time-origin drift;
- no material SI-SDR/listening regression;
- lower or equal RTF/cost that justifies the extra format and runtime surface.

No such project-owned weight/export artifact exists yet, so ONNX cannot outrank the direct PyTorch baseline today.

## Why Core ML is R&D only today

Core ML Tools supports direct PyTorch conversion and recommends ML Program for modern iOS targets. ML Program supports float16 conversion and Apple provides quantization/palettization tooling. Those capabilities make an eventual on-device separator plausible, but they do not prove that a Demucs-class graph will convert completely or fit target iPhone RAM/thermal limits.

Before Core ML promotion the exact trained project model must pass:
1. graph capture and full conversion with no unsupported fallback/custom op dependency;
2. fixed and long-audio chunk shape strategy;
3. numerical/audio equivalence against PyTorch;
4. model package size and peak working-set measurement;
5. 5/15/30/60-minute device stress with thermal/battery evidence;
6. Golden real-track listening comparison;
7. no regression in cancellation/recovery or output synchronization.

Core ML conversion evidence used for feasibility only:
- PyTorch models can be captured by TorchScript or `torch.export` and converted through Core ML Tools.
- ML Program is the modern target for iOS 15+ and receives current performance features.
- float16 and weight compression tools exist, but compression must be quality-gated rather than assumed safe.

## Benchmark dimensions for all candidates

Every executable candidate uses the SAME project-owned model version and Golden fixture IDs where the format permits.

Measure separately:
- model load/cold start;
- upload time and bytes (server/hybrid only);
- queue wait;
- inference wall time;
- download time and bytes;
- total time to first usable stems;
- real-time factor (RTF = inference seconds / audio seconds);
- peak GPU VRAM or iPhone peak RSS;
- CPU/GPU/ANE utilization where observable;
- 5/15/30/60-minute thermal and battery effects on-device;
- server cost per processed audio minute and concurrency;
- cancellation at ~10%, ~50% and near-completion;
- retry/idempotency and duplicate-job behavior;
- output duration, sample rate, channel layout, alignment and stem manifest hashes;
- Golden SI-SDR/reconstruction/listening rubric.

## Selection gates

`A -> E` is the implementation direction for the next product slice, but it is not PARITY.

A different runtime may replace PyTorch server only if it shows all of:
- exact same cleared project-owned weights or a formally versioned derivative;
- output quality no worse under Golden objective + blind listening gates;
- no synchronization or duration regression;
- materially better latency/cost/device characteristics;
- explicit distribution/runtime license clearance;
- reproducible benchmark evidence.

## Authoritative runtime references

- PyTorch CUDA semantics/docs: https://docs.pytorch.org/docs/main/notes/cuda.html
- PyTorch performance tuning: https://docs.pytorch.org/tutorials/recipes/recipes/tuning_guide
- Demucs custom training configuration (`use_musdb: false`, custom WAV dataset): https://github.com/facebookresearch/demucs/blob/main/conf/config.yaml
- Core ML Tools PyTorch conversion workflow: https://apple.github.io/coremltools/docs-guides/source/convert-pytorch-workflow.html
- Core ML ML Program conversion: https://apple.github.io/coremltools/docs-guides/source/convert-to-ml-program.html
- ONNX Runtime CoreML Execution Provider: https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
- ONNX Runtime reduced operator configuration: https://onnxruntime.ai/docs/reference/operators/reduced-operator-config-file.html

## Known UNKNOWNs

- Actual project-owned training checkpoint does not exist yet.
- Real separator quality is therefore unmeasured.
- Server GPU model/region/concurrency/cost are not selected.
- Exact Core ML conversion/operator coverage for the eventual trained architecture is untested.
- Target-iPhone RSS/thermal/battery for separation is unmeasured.
- Reference separation quality and end-to-end processing latency remain unmeasured.

These remain UNKNOWN and cannot be promoted by this research task.