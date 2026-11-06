# MOI-SEP-001｜Runtime / topology benchmark protocol

This protocol is the acceptance bridge from research to executable `MOI-SEP-002`. It does not itself prove separation quality.

## Fixture policy

Use the verified Golden QA fixture policy. Final product promotion requires rights-cleared real audio. Synthetic signals and Slakh-style synthetic stems are useful for deterministic regression but cannot be the sole PASS basis.

All runtime candidates must process the same input IDs with the same project-owned model lineage. A converted/compressed artifact gets a new immutable artifact ID and hash but remains linked to the source checkpoint.

## Test matrix

### Audio duration
- short functional clips: 30 s / 60 s
- product stress tracks: 5 / 15 / 30 / 60 min

### Content
Cover at minimum the Golden style/hard-case buckets already defined by `MOI-QA-001`, including:
- vocal + backing overlap;
- kick/bass overlap;
- cymbal wash;
- distorted guitar masking;
- piano transients/sustain;
- stereo/phase effects;
- sparse-to-dense transitions;
- live tempo drift;
- lossy input;
- mono and 48 kHz input cases.

## Server benchmark

For PyTorch CUDA baseline and any ONNX Runtime CUDA challenger record:

1. exact model artifact hash;
2. architecture/code commit;
3. framework/runtime/CUDA/cuDNN/provider versions;
4. GPU SKU and memory;
5. container/image digest;
6. cold model-load time;
7. warm inference time;
8. inference RTF;
9. peak GPU VRAM;
10. host RAM/CPU;
11. output storage bytes;
12. upload/download bytes;
13. cost per processed audio minute;
14. single-job throughput and safe concurrency;
15. failure class and cleanup behavior.

Do not hide queue time inside inference time. Product latency must report at least:
`upload + queue + inference + download + local-finalize`.

## On-device benchmark

For direct Core ML or ONNX Runtime/CoreML paths record on named target iPhone hardware:

- conversion log and unsupported-op result;
- model package/binary size;
- load latency;
- peak RSS;
- 5/15/30/60 min wall time and RTF;
- thermal state at start/end and transition times;
- battery delta;
- CPU/GPU/ANE execution evidence where available;
- background/interruption behavior;
- output identity/alignment against the server source checkpoint.

A conversion that runs only on desktop/macOS is not an iPhone PASS.

## Output integrity gates

For each stem:
- expected stem IDs exactly match the manifest;
- duration mismatch is reported, never silently padded without manifest annotation;
- channel count and sample rate are recorded;
- no NaN/Inf;
- no introduced clipping beyond explicit normalization policy;
- time origin is common across all stems;
- sum/reconstruction metric is recorded where applicable;
- SHA-256 or equivalent artifact hash stored for each output.

A runtime challenger is rejected if it causes stem swap, time drift, unexplained duration change, missing output, or deterministic waveform divergence that also degrades Golden metrics/listening.

## Quality gates

The runtime layer may not claim quality from runtime speed alone.

Use:
- per-stem SI-SDR;
- reconstruction error;
- leakage/silent-source false-positive metrics when source labels permit;
- Golden blind listening dimensions: target preservation, bleed, musical noise, transients, timbre/formant, stereo/phase, bass integrity, ambience/reverb, overall practice usability.

Promotion rule: a runtime optimization must be non-inferior to the direct PyTorch checkpoint under the Golden gate and must also not create a new genre/hard-case failure cluster.

## Latency decision rule

No fabricated millisecond threshold is used before a real checkpoint and target environment exist.

Record distributions rather than one run:
- cold and warm median;
- P90/P95 where sample size permits;
- worst observed run with cause;
- Reference end-to-end observation when comparable.

Product promotion requires no obvious processing-time inferiority against Reference without a documented reason. HQ owns the final threshold after actual Reference/device/server measurements.

## Memory / thermal decision rule

On-device promotion is automatically blocked if:
- the app is terminated under the mandatory long-track run;
- persistent serious/critical thermal behavior prevents the required core flow;
- memory pressure causes output corruption or unrecoverable processing state.

Server promotion is blocked if the selected GPU cannot safely meet concurrency without OOM or if cost/RTF makes the product flow nonviable. Exact cost ceiling is a later business/HQ gate, not guessed here.

## Cancellation and recovery

Test cancellation at approximately 10%, 50%, and near completion.

Required behavior:
- cancel request becomes durable;
- client does not show success after cancellation;
- server stops or marks result nonpublishable;
- incomplete large artifacts are cleaned or retained only under an explicit resumable policy;
- retry creates or reuses a job idempotently;
- reconnect cannot duplicate billing/inference unintentionally;
- stale output from an older model/job cannot overwrite the active project manifest.

## Selected executable order

1. Train or procure a rights-cleared project-owned checkpoint.
2. Run direct PyTorch/CUDA baseline with Golden fixtures.
3. Only after baseline quality is credible, test ONNX Runtime CUDA export as cost/latency challenger.
4. In parallel after model graph stabilizes, attempt direct Core ML ML Program conversion.
5. Promote an on-device route only after device memory/thermal/quality gates pass.

This ordering avoids spending time optimizing a model that has not yet demonstrated lawful real-audio quality.