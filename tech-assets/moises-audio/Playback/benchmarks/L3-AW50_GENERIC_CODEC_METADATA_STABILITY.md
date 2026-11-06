# L3-AW50 | Generic Representative Codec Metadata Stability

Result: `COMPLETE_NON_PARITY`

## Canonical audit

- Latest Notion canonical observed: HQ Epoch 44.
- HQ Epoch 44 integrates Lane3 through AW49 and records Lane3 Playback+DSP full portable source typecheck PASS.
- Integration head observed: `701698290b6e2076ce71a9208d2626af85f918b5`.
- Worker branch started AW50 at `3df91be785116917814773a777f0a15da5b81568`.
- PARITY promotions remain zero.

## Gap closed

AW49 hardened the selected Apple file-backed adapter, but the generic AW43 `Lane3RepresentativeCodecExecutionProbe.sweep` still reread `channels`, `sampleRate`, and `frameCount` live throughout a traversal. A future non-Apple `Lane3PCMChunkReadable` could therefore change metadata between chunks and cause loop bounds, sample-count validation, and final report fields to describe different source states.

AW50 freezes a bit-exact metadata snapshot before the first PCM read, confirms it with a second preflight snapshot, and verifies it before and after every bounded PCM read plus once before successful completion.

## Durable behavior

- `channels`, `sampleRate.bitPattern`, and `frameCount` are frozen at preflight.
- Loop termination uses frozen `frameCount`.
- Expected interleaved sample count uses frozen `channels`.
- Final `actualChannels`, `actualSampleRate`, and `actualFrameCount` use the frozen snapshot.
- Initial descriptor mismatch remains `sourceMetadataMismatch`.
- Runtime/preflight instability uses the existing `sourceMetadataChanged` failure code.
- Existing report schema and failure-code enum are unchanged.
- Selected Apple AW49 behavior remains compatible; Apple adapter errors already fold source identity mutation into `sourceMetadataChanged`.

## Focused verification actually executed

Swift 6.2.1 Linux, `-swift-version 6`, `-strict-concurrency=complete`, `-warnings-as-errors`, optimized build:

- stable 3,084-frame / 2-channel / 48 kHz / 257-frame chunks: 12 reads, 3,084 frames, FNV1A64 `8284563594282402565`.
- channels mutation after each of 12 read positions: rejected.
- sample-rate mutation after each of 12 read positions: rejected.
- frame-count mutation after each of 12 read positions: rejected.
- 36/36 focused mutation-position cells returned source-metadata-change behavior.
- preflight flapping metadata was rejected before PCM consumption.

A focused 5,000-sweep timing comparison produced legacy/fenced ratio `0.9869`. This is a synthetic Linux CPU observation only; no deterministic speedup or iPhone cost claim is made.

## Repository-native coverage authored

- `L3_AW50_RepresentativeCodecMetadataStabilitySelfTest.swift`
- `L3_AW50_RepresentativeCodecMetadataStabilityStress.swift`
  - 20 stable cells.
  - 3 metadata fields × 12 mutation positions × 20 rounds = 720 mutation cells.
  - verifies frozen report fields and exact accepted-read counters before the mutation.
- `L3_AW50_RepresentativeCodecMetadataStabilityBenchmark.swift`
  - 2,000 stable sweeps.
  - 4 PCM reads per sweep remain 4.
  - 11 getter reads per metadata field per sweep are explicitly audited.

These repository-native executables were authored but not run from a full Worker branch checkout in this environment. HQ Epoch44's full Lane3 typecheck predates AW50, so post-AW50 full typecheck remains required.

## Non-parity boundaries

AW50 does not prove codec support, real-file corruption behavior, AVFAudio runtime behavior, physical iPhone stability, RSS/thermal/battery, current-Moises differential quality, or audible parity. It does not make the file identity fence cryptographic provenance. `MOI-P006/P007/P008/P010/P012/P014/P015/P021` remain MISSING.
