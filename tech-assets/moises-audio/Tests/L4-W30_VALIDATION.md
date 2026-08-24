# L4-W30 Validation — Chunked Analysis Input / Whole-source PCM Elimination Seam

## Result

W30 is complete as Worker-4 engineering hardening. It does **not** establish MOI-P021 PARITY.

The product Analysis surface now supports an optional pull-based chunked PCM source. When HQ/Lane 2 supplies a genuine bounded decoder, Worker 4 no longer requires the complete decoded mono `[Float]` to exist before W29 feature extraction starts. The existing whole-signal loader remains a compatibility fallback.

## Production changes

- `AnalysisChunkedSignalLoading` is an optional Analysis-owned integration seam.
- `AnalysisPCMChunkPulling.nextChunk()` provides explicit pull/backpressure semantics.
- every chunk carries an absolute `startSampleIndex`.
- descriptor declares exact source sample rate and total source sample count before consumption.
- chunked resampling preserves W11 global-index block-average and finite/clamp semantics across chunk boundaries.
- `AnalysisSequentialPreparedFeatureAccumulator` is shared by W29 whole-signal fallback and W30 chunked input, preventing algorithm drift between the two paths.
- `ProjectOwnedMusicAnalyzer` prefers a supplied/conforming chunked loader and falls back to the existing `AnalysisSignalLoading` route otherwise.
- Section analysis and W15 final snapshot publication remain common after the prepared Analysis result.

## Backpressure correction

The first W30 draft used an `AsyncThrowingStream` of chunks. That was rejected during the same wave because a producer could enqueue the complete track before the consumer processed it, recreating whole-track retention outside the Analysis code.

The final contract is pull-based: Analysis asks for exactly one next chunk only after the previous chunk has been consumed. This materially strengthens the bounded-memory integration contract.

It still cannot prove that a future decoder does not retain its own internal whole-track buffer. That is why physical W23/W24 process telemetry remains required.

## Chunk integrity / failure behavior

The final extractor rejects:

- invalid/nonfinite/zero sample-rate descriptors;
- negative or nonrepresentable sample counts;
- empty chunks;
- gaps;
- overlaps;
- out-of-order chunks;
- chunks extending past the declared source count;
- sources ending before the declared count;
- prepared sample-count mismatch;
- nonsequential prepared-sample feed into the shared accumulator.

Chunk-end arithmetic is checked before addition so malformed very-large indices cannot silently wrap.

## Chunk-size and resampling invariance

Private algorithm validation covered source rates:

`44.1 kHz, 48 kHz, 96 kHz, 8.2 kHz, 8 kHz, 4 kHz`

and source lengths including 1, 2, 17, 1,000 and 10,001 samples, with randomized chunk boundaries and pathological `NaN` / infinity / out-of-range samples.

Chunked prepared samples matched the W11/W29 whole-signal prepared definition exactly.

Durable XCTest additionally covers:

1. W30 chunk sizes 3 / 127 / 4,096 / 16,384 versus the W29 whole-signal feature output;
2. one-sample chunks across every resampling boundary;
3. NaN/infinity/±16 bound sanitization;
4. gap/overlap/out-of-order rejection;
5. truncated/overrun/empty-source-chunk rejection;
6. exact one-hour and 24-hour analytical budgets;
7. cancellation while waiting for the next pull chunk.

## Swift validation

Source-shaped Swift 6.2.1 x86_64 Linux:

- `-swift-version 6`
- `-strict-concurrency=complete`
- `-warnings-as-errors`

Result: **PASS** for the pull contract, sequential feature accumulator, chunked resampler/pipeline, optional product-loader route and durable test source shape.

Full canonical SwiftPM/Xcode execution remains an HQ integrated-checkout gate.

## Portable adversarial/stress harness

Five independent process runs were executed.

Each process: **145 assertions PASS**.

Coverage included six source sample rates, chunk sizes 1 / 3 / 127 / 4,096, pathological source values, and malformed source cases.

Stress source:

- 20,000,000 source samples generated on demand;
- maximum pull chunk: 32,768 samples;
- no 20,000,000-sample source array created by the stress provider;
- prepared output samples: 3,628,118;
- checksum: 41,309.841472 in every process.

Final inner stress seconds by process:

`0.245021, 0.250311, 0.268892, 0.252891, 0.248935`

Whole process wall seconds:

`1.35, 1.38, 1.38, 1.42, 1.35`

Max RSS kB:

`18,492, 18,448, 18,356, 18,452, 18,376`

Maximum observed RSS: **18,492 kB**.

These figures are **NON_PARITY portable engineering evidence**. They are not iPhone memory/thermal/battery/wall-time evidence and do not include a real Lane-2 decoder.

## Analytical long-audio budget

Assuming the upstream decoder honors the pull contract and itself does not retain the whole decoded track:

### One hour / 44.1 kHz mono Float

- hypothetical whole decoded source PCM: **635,040,000 bytes**
- 32,768-sample chunk: **131,072 bytes**
- estimated chunk + Worker-4 retained feature/structural working set: **10,766,976 bytes**
- source/chunk payload ratio: **4,844.970703x**

### Twenty-four hours / 44.1 kHz mono Float

- hypothetical whole decoded source PCM: **15,240,960,000 bytes**
- 32,768-sample chunk: **131,072 bytes**
- estimated chunk + Worker-4 retained feature/structural working set: **197,563,776 bytes**
- source/chunk payload ratio: **116,279.296875x**

The 24-hour feature working set is still substantial because Tempo onset, Chord decision and Section energy feature cardinalities scale with duration. W30 solves the dominant whole-source buffer seam but does not solve every extreme-duration retained feature.

## HQ handoff

At Late Integration, HQ/Lane 2 must wire a **genuine pull-based decoder**. Using `AnalysisWholeSignalChunkedCompatibilityAdapter` is not acceptable evidence for source-memory elimination because that adapter first obtains a complete `AnalysisSignal`.

The integrated decoder's real process memory, physical footprint, thermal state, battery behavior, memory warnings and cancellation latency must be captured with W23 and accepted through W24 repeated worst-case gates. W25/W26/W27 integrity gates remain applicable.

## PARITY boundary

MOI-P021 remains **MISSING**.

MOI-P009 / P011 / P013 / P016 also remain MISSING until HQ completes rights-cleared real-audio/current-iPhone Moises differential evidence.

## Next highest-value Worker-4 gap

After whole-source retention is removed at the seam, the remaining Worker-4 extreme-duration memory growth is retained feature cardinality. The next wave should bound the long-duration Tempo onset / Chord predecision / Section-energy working set without changing normal-song output semantics or weakening W22/W23/W24 evidence requirements.
