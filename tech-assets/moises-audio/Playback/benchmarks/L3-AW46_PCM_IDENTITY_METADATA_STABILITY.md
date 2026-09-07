# L3-AW46 | PCM Identity Metadata Stability Fence

## Result

`COMPLETE_NON_PARITY`

AW45 reduced representative long clean verification to one bounded PCM traversal. AW46 closes a correctness gap in that optimized path: `Lane3PCMChunkReadable` is a generic `Sendable` boundary whose metadata properties are not structurally immutable. Without an explicit fence, a future adapter could expose one `channels/sampleRate/frameCount` header while returning PCM after a visible metadata change, or the codec binder could hash under one metadata snapshot and then reread changed getters when constructing its durable report/identity.

## Canonical audit

- operating model: FOUR_AUTONOMOUS_INDEPENDENT_LANES_LATE_INTEGRATION
- assignment epoch: 2
- planning revision: 4
- integration head observed at Wave start: `bd0d14f3a48ab64e3a5d10f165578bc24cf54968`
- HQ integration epoch observed: 33
- Epoch33 already semantically integrated Lane3 through AW45
- Worker branch start head: `165f89a1e96c2846daabf1c21fa9141f9eaa2147`
- ownership remains Playback/** + DSP/**
- Shared/App/PARITY_MATRIX were not edited

## Implementation

`Lane3LongTrackPCMIdentityHasher` now:

1. captures two consecutive metadata snapshots before traversal and rejects immediate instability;
2. uses one frozen channels/sample-rate/frame-count snapshot to construct the SHA256_FLOAT32_LE_V1 header;
3. validates that exact snapshot before every chunk read;
4. validates it again immediately after every chunk read;
5. validates it at traversal completion;
6. computes expected sample counts from frozen metadata rather than rereading mutable getters;
7. makes `makeReceipt` persist its captured metadata rather than post-hash getter values.

`Lane3StablePCMIdentityFingerprint.swift` adds a consumer bridge that carries the exact hashed digest plus frozen channels/sampleRate/frameCount out of the traversal. Its visitor independently checks the outer frozen snapshot around every chunk callback.

`Lane3CodecLongTrackEvidenceBinder` now uses this fingerprint for AW43 clean report reconstruction and AW44/AW45 identity construction. It no longer rereads `cleanSource.channels`, `cleanSource.sampleRate`, or `cleanSource.frameCount` after hashing to populate the durable clean report or identity receipt.

## Failure semantics

Visible metadata mutation throws `Lane3PCMIdentityStabilityError.sourceMetadataChanged` and produces no digest receipt. This is fail-closed evidence behavior. It is not intended to recover or reinterpret a source whose format changed mid-read.

The fence covers observable metadata changes before/after reads and around the fingerprint visitor. A malicious/buggy adapter that changes hidden decoder state without changing the protocol metadata and without failing its read remains outside what this generic interface can prove; selected Apple adapters still require their own source-mutation/runtime validation.

## Focused portable verification

Swift 6.2.1 Linux, Swift language mode 6, strict concurrency complete, warnings as errors:

- stable 180,000-frame stereo source: 44 reads at chunkFrames=4096, unchanged from AW45;
- stable FNV1A64: `7262699423100747709`, unchanged from AW45;
- independent Python hashlib SHA256_FLOAT32_LE_V1: `fed6505b0fcb3b01a65fccc8e3b913772cb50e90e2835f9a0e51e74f6719bab2`, unchanged from AW45;
- channels mutation rejected at every one of 44 read positions;
- sampleRate mutation rejected at every one of 44 read positions;
- frameCount mutation rejected at every one of 44 read positions;
- total dynamic-metadata negative cells: 132 / 132 rejected.

Focused timing proxy was intentionally not promoted to a performance claim. Repeated optimized Linux runs were noisy; the fence adds metadata getter checks but does not add PCM read passes. Repository-native benchmark therefore records stable read counts and getter-check volume alongside elapsed time rather than claiming a deterministic speed ratio.

## Durable coverage

- `Playback/Tests/L3_AW46_PCMIdentityMetadataStabilitySelfTest.swift`
- `Playback/Tests/L3_AW46_PCMIdentityMetadataStabilityStress.swift`
- `Playback/Tests/L3_AW46_PCMIdentityMetadataStabilityBenchmark.swift`
- `Playback/Tests/L3_AW46_FrozenFingerprintBridgeSelfTest.swift`

HQ semantic integration should also rerun AW44/AW45 binder self-tests to prove unchanged durable receipt semantics for stable fixtures.

## Non-claims / remaining gates

- no Xcode compile claimed in Worker environment;
- no selected AVFAudio runtime execution;
- no physical-iPhone execution;
- no rights-cleared real >=30-minute codec family execution;
- no physical RSS/thermal/battery evidence;
- no current-Moises differential or human listening evidence;
- no authenticity signature or compressed derivative-parentage proof;
- no PARITY row promotion.

`MOI-P006/P007/P008/P010/P012/P014/P015/P021` remain MISSING pending HQ/device/real-audio gates.
