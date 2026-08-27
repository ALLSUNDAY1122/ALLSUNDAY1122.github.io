# Analysis Chunked Input Runbook — W30

## Purpose

W30 adds a Worker-4-owned optional input seam that lets Analysis consume decoded mono `Float` PCM sequentially without requiring a whole-track `[Float]` allocation in Worker 4. It is an engineering prerequisite for MOI-P021 and is not PARITY evidence by itself.

The existing `AnalysisSignalLoading` whole-signal path remains a compatibility fallback.

## Late Integration ownership

Concrete file decoding remains Lane 2 / HQ-owned. Worker 4 does not edit `IO/**`, frozen `Shared/**`, or root `App/**`.

At Late Integration, prefer one of these integrations:

1. make the concrete Analysis decoder implement `AnalysisChunkedSignalLoading`; or
2. inject a separate `AnalysisChunkedSignalLoading` into `ProjectOwnedMusicAnalyzer` while preserving the existing `AnalysisSignalLoading` fallback.

Do not use `AnalysisWholeSignalChunkedCompatibilityAdapter` as MOI-P021 source-memory evidence. That adapter first materializes the whole source and exists only for migration/testing compatibility.

## Pull/backpressure contract

`AnalysisPCMChunkPulling.nextChunk()` is deliberately pull-based. Analysis requests another chunk only after consuming the prior chunk. This avoids the unbounded producer-queue risk of a push stream.

A conforming decoder must:

- provide a finite positive `sampleRate` and exact nonnegative source `sampleCount` before the first chunk;
- emit mono `Float` PCM;
- return nonempty chunks until the declared sample count is exhausted;
- set `startSampleIndex` to the exact absolute source sample index;
- emit chunks contiguously and in increasing order, with no gap or overlap;
- terminate only after exactly the declared source sample count has been emitted;
- honor task cancellation while decoding / waiting for the next chunk;
- avoid retaining the complete decoded source solely for Analysis.

W30 rejects empty chunks, gaps, overlaps, out-of-order chunks, overruns and truncated sources.

## Chunk size

`32,768` source samples is the default compatibility/example chunk size. It is an engineering collection choice, not a product/PARITY acceptance threshold. A real decoder may use another bounded chunk size.

For a 32,768-sample mono Float chunk, the PCM payload is 131,072 bytes.

## Resampling continuity

The chunked path preserves the W11/W29 prepared-signal definition using global absolute source indices:

- Analysis rate is `min(sourceRate, 8 kHz)`;
- resampling is used under the same W11 `sourceRate > targetRate * 1.05` rule;
- prepared output sample `i` averages the same source interval derived from `floor(i * ratio)` / `floor((i + 1) * ratio)`;
- NaN/infinity/out-of-range samples are sanitized with `AnalysisWorkingSetPolicy.boundedFinite` before averaging;
- the only resampler carry is the current averaging interval, so a chunk boundary does not reset resampling state.

Chunk size therefore must not change the W29 prepared features or downstream Tempo/Key/Chord/Section result.

## Shared W29 feature accumulator

Both input modes use `AnalysisSequentialPreparedFeatureAccumulator`:

- whole-signal fallback: `AnalysisPreparedSampleReader` supplies prepared samples;
- W30 chunked path: chunked resampler supplies prepared samples.

The accumulator produces the same W29 Tempo onset representation, bounded Key windows/global RMS probe, Chord frame decisions, and 100 Hz Section energy signal. Section detection/hardening and W15 final snapshot publication remain unchanged.

## Cancellation and failure behavior

Cancellation is checked while waiting for/pulling chunks, scanning source samples, emitting prepared samples and in all downstream analyzers. A cancelled or malformed input must not publish a partial final `AnalysisSnapshot`.

Decoder errors propagate; Worker 4 does not reinterpret them as successful empty analysis.

## Analytical memory expectation

Assuming the upstream decoder itself does not retain the entire decoded source:

### One hour, 44.1 kHz mono Float

- hypothetical whole decoded source: 635,040,000 bytes
- one 32,768-sample source chunk: 131,072 bytes
- Worker-4 retained feature/structural estimate plus one chunk: 10,766,976 bytes
- source/chunk payload ratio: about 4,844.97x

### Twenty-four hours, 44.1 kHz mono Float

- hypothetical whole decoded source: 15,240,960,000 bytes
- one 32,768-sample source chunk: 131,072 bytes
- Worker-4 retained feature/structural estimate plus one chunk: 197,563,776 bytes
- source/chunk payload ratio: about 116,279.30x

These figures are analytical. They do not include the concrete decoder's internal buffers, filesystem/cache effects, Swift allocator overhead, VM accounting, thermal state or battery behavior.

## Required HQ evidence

MOI-P021 remains MISSING until HQ Late Integration:

1. wires a genuine bounded Lane-2 decoder to the pull seam (not the whole-signal compatibility adapter);
2. runs the integrated app on the approved physical iPhone;
3. captures W23 memory/physical-footprint/thermal/battery/warning/cancellation evidence;
4. evaluates repeated runs through W24 HQ-approved worst-case thresholds;
5. preserves W25/W26/W27 workload/corpus/archive integrity.

A portable compile, synthetic fixture, analytical memory budget, or low Linux RSS must never be promoted to physical-device PARITY evidence.
