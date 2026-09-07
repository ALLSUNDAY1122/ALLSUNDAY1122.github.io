# L3-AW13 | Unified Playback/DSP Evidence Receipt v2

Result: `COMPLETE_NON_PARITY`

## Goal

Close the Lane-3 evidence-chain gap left after AW09-AW12. AW09 generated time-domain and spectral evidence from one PCM pair, but AW10 envelope evidence and AW11/AW12 generation/recovery evidence were only retained beside it. That allowed accidental mixing of a stale production generation or a different PCM pair with an otherwise valid-looking report.

## Implementation

New source:

- `Playback/Sources/Lane3UnifiedEvidenceV2.swift`

The v2 pipeline does not wrap an arbitrary pre-existing AW09 report. It accepts the raw reference/observed PCM once and, in the same call:

1. validates a current AW12 production-generation receipt against a fresh `PracticeDSPGenerationCoordinator.snapshot()`;
2. rejects any receipt superseded by a later coordinator operation;
3. rejects metronome/count-in click-only receipts as render/replacement authority;
4. requires the AW11/AW05 lineage receipt to match AW12 playback generation, click generation and reason exactly;
5. runs AW07 PCM time/alignment analysis on the supplied PCM pair;
6. runs AW08 spectral analysis with the AW07 global lag;
7. runs AW10 cepstral-envelope/formant proxy on the exact same PCM pair and same global lag;
8. rebuilds the AW09 core evidence inside the same call;
9. hashes the canonical raw PCM representation with portable SHA-256;
10. creates one SHA-256 run binding over fixture/control identity, production generations, reason, operation serial, both PCM digests, alignment lag, envelope-window count and event count.

The legacy AW09 `Lane3TransportEvidenceReceipt.transactionSerial` field is populated from the AW12 coordinator operation serial only as a compatibility projection inside `coreEvidence`. The authoritative v2 transport source is the embedded, snapshot-validated `Lane3ProductionGenerationEvidenceReceipt`.

## PCM identity format

Algorithm: `SHA256_FLOAT32_LE_V1`

Canonical byte order includes:

- domain separator `LANE3_PCM_IDENTITY_V1`;
- channel count;
- exact `Double.sampleRate.bitPattern`;
- frame count;
- interleaved sample count;
- every `Float.bitPattern` in little-endian order.

The SHA-256 implementation is self-contained Swift so the receipt does not depend on CryptoKit availability in the portable harness.

Independent cross-check:

- Swift reference PCM digest: `1ae0e19a911d747fffa5c39cc8be7e7d51e583e235c32406faf8c2612eec8c67`
- Python `hashlib.sha256` over the independently reconstructed canonical bytes: exact match.

A one-sample mutation changed the observed PCM digest to:

`b0c189f9b8731d9950f742995979e5eeb8efa0efbe4131b51dfe83e16592f49c`

and changed the unified run binding.

## Portable validation

Swift 6.2.1 / Linux x86_64, exact AW13 source compiled and executed against interface-compatible AW05/AW07-AW12 types.

PASS:

- current AW12 transport binding accepted;
- stale AW12 receipt after a later operation rejected;
- click-only AW12 receipt rejected as render authority;
- AW11/AW12 playback-generation mismatch rejected;
- AW11/AW12 click-generation mismatch rejected;
- AW11/AW12 reason mismatch rejected;
- AW07/AW08/AW10 share one raw PCM input pair;
- AW10 lag mismatch rejected;
- AW10 non-finite evidence rejected;
- exact raw-PCM SHA-256 identity generated;
- one-sample mutation changes PCM digest and run binding;
- Codable v2 report round-trip PASS;
- all component perceptual/formant/PARITY claim flags remain false.

Portable deterministic sample output:

- run binding SHA-256: `47caf79fec1d422118a33e6e0ee973640f118fdec09f79397680f77c370c1c44`
- reference PCM SHA-256: `1ae0e19a911d747fffa5c39cc8be7e7d51e583e235c32406faf8c2612eec8c67`

A repository-level self-test and full-analysis benchmark source were also added. They instantiate the real portable `PracticeDSPProductionController`/`PracticeDSPGenerationCoordinator` and are intended to execute with the full Lane-3 source set during HQ build/integration.

## Portable receipt/hash benchmark

Interface-compatible analyzer stubs isolate AW13 receipt assembly plus canonical SHA-256 PCM hashing overhead.

- 20 rounds
- 20 unified assemblies per round
- 16,384 stereo frames per reference/observed buffer
- median: `27.258 ms / round`
- p95: `31.126 ms / round`
- max: `31.126 ms / round`
- checksum: `1331579990000`

This benchmark deliberately excludes the actual AW07/AW08/AW10 analysis cost, AVAudioEngine, AudioUnit, file IO and device capture. `Playback/Tests/L3_AW13_UnifiedEvidenceV2Benchmark.swift` measures the complete v2 pipeline when run with the full Lane-3 source set.

## Evidence scope and limits

Evidence scope: `LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY`

This wave improves chain-of-custody and integration safety only. It does not establish:

- selected-Xcode compile success;
- physical-iPhone timing;
- real rights-cleared track quality;
- current-Moises differential quality;
- human audible click/pop/warble/formant acceptance;
- P006/P007/P008/P010/P012/P014/P015 PARITY.

`humanAudibilityClaimed=false`, `standardizedPerceptualMetricClaimed=false`, `formantPreservationClaimed=false`, `parityPromotionAllowed=false` remain mandatory.
