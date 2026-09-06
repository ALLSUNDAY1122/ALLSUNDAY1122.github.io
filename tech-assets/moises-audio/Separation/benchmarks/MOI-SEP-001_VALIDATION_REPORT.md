# MOI-SEP-001｜Validation report

Captured: 2026-08-22 JST
Attempt: `task/MOI-SEP-001/attempt-2`

## Acceptance review

### 1. Only licence-permitted model/runtime candidates compared — PASS

The production comparison is fenced by VERIFIED `MOI-SEP-LIC-001`.

Allowed production lineage:
- MIT Demucs/HTDemucs-class code;
- project-owned weights trained from scratch on rights-cleared real multitracks;
- optional separately contracted commercial model only if the exact topology/weight/use grant is written.

Explicitly not selected:
- official Demucs pretrained weights;
- Spleeter pretrained weights under the unresolved current commercial/conversion/redistribution ambiguity;
- Open-Unmix model weights/data combinations not independently cleared for this commercial product.

### 2. On-device / server / hybrid scored — PASS

Compared:
- direct PyTorch/CUDA server;
- ONNX Runtime/CUDA server challenger;
- direct Core ML on-device;
- ONNX Runtime + CoreML EP on-device;
- server inference + iPhone durable project/job/stem cache hybrid product topology.

Scores are explicitly labelled pre-benchmark engineering scores, not measured quality claims.

### 3. One viable real multi-stem path selected with risks — PASS

Selected path:

`rights-cleared real multitracks -> project-owned HTDemucs-class checkpoint -> PyTorch/CUDA asynchronous server inference -> deterministic stem manifest -> iPhone verified download/durable cache -> mixer/practice`

Why this is the viable first path:
- it keeps the lawful trained checkpoint in the same framework for first quality validation;
- it does not require shipping or converting restricted third-party pretrained weights;
- it avoids assuming a large separator fits current iPhone memory/thermal limits;
- it supports the already observed nonblocking processing/player lifecycle;
- it leaves ONNX/Core ML as measurable optimizations instead of prerequisites.

Explicit risks:
- **HIGH** real-data acquisition/licensing cost and schedule;
- **HIGH** quality-convergence risk from training from scratch;
- **MEDIUM-HIGH** GPU training burden;
- **UNKNOWN until benchmarked** inference RTF, GPU memory, concurrency and cost;
- network/upload privacy and retention obligations for server inference;
- Core ML/ONNX export feasibility remains unverified for the eventual trained graph;
- target-iPhone memory/thermal/battery remain unmeasured.

## Authoritative feasibility evidence reviewed

Current authoritative documentation confirms only feasibility primitives, not this model's final performance:
- PyTorch maintains current CUDA execution and GPU performance guidance.
- Demucs configuration permits `use_musdb: false` and custom WAV training data, supporting the rights-cleared custom-training path.
- Core ML Tools supports PyTorch graph capture/conversion and modern ML Program deployment; exact separator graph support must still be tested.
- ONNX Runtime documents CUDA/mobile/CoreML execution paths and reduced-operator builds; exact exported graph coverage must still be tested.

No documentation source is treated as evidence that the project model already meets Moises quality.

## Guardrails

This task does NOT establish:
- trained project-owned weights;
- actual stem output;
- separation SI-SDR;
- listening parity;
- server cost viability;
- iPhone on-device feasibility;
- MOI-P003/P004/P005 PARITY.

All three parity rows remain `MISSING`.

## Downstream handoff

`MOI-SEP-002` should consume these decisions only after its other dependencies are VERIFIED:
1. load the HQ fixed contracts rather than redefining Shared/App;
2. use a rights-cleared model artifact lineage;
3. implement job progress/cancel/retry/failure deterministically;
4. capture actual output with Golden real-audio evidence;
5. retain Reference comparison as the final product-quality gate.

## Files added by attempt-2

- `Separation/benchmarks/MOI-SEP-001_RUNTIME_TOPOLOGY.md`
- `Separation/benchmarks/MOI-SEP-001_DECISION.json`
- `Separation/benchmarks/MOI-SEP-001_BENCHMARK_PROTOCOL.md`
- `Separation/benchmarks/MOI-SEP-001_VALIDATION_REPORT.md`

No Shared/App/PARITY file is modified by this attempt.