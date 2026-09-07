# L3-AW45 | Single-Pass Codec / Long-Track Identity Verification

## Result

`COMPLETE_NON_PARITY`

AW44 bound the AW43 clean codec execution report to the exact AW30 long-track PCM identity, but its verification path reread the same long clean PCM multiple times: once to reproduce AW43 FNV/counters, then twice through the self-identity `reference == observed` SHA-256 receipt. AW45 removes those redundant evidence-only passes without weakening the content binding.

## Fresh canonical state

- Operating model: `FOUR_AUTONOMOUS_INDEPENDENT_LANES_LATE_INTEGRATION`
- assignment epoch: 2
- planning revision: 4
- canonical integration HEAD observed at Wave start: `d25c6af17bf5165704acaaa94afaa6a4ed3599b5` (HQ Epoch32)
- Worker 3 branch Wave-start HEAD: `4b8f9f71e5a3cfea2b06a6fe04e41810f1044c34` (AW44)
- ownership remains `Playback/**` + `DSP/**`
- no Shared/App/PARITY file is edited by this Wave
- final PARITY authority remains HQ

## Implementation

`Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor` is a synchronous bounded traversal primitive using the existing incremental `SHA256_FLOAT32_LE_V1` implementation. Each exact PCM chunk is exposed to a caller-supplied visitor and then hashed from the same sample buffer.

`Lane3CodecLongTrackEvidenceBinder` now uses one clean-source traversal to simultaneously:

1. preserve the AW43 clean report's original `maximumChunkFrames` boundary;
2. reproduce AW43 `readCalls` and `framesRead`;
3. reproduce the AW43 rolling PCM FNV-1a checksum;
4. reject non-finite or failed/short clean reads fail-closed;
5. compute the canonical `SHA256_FLOAT32_LE_V1` clean PCM digest;
6. construct the same reference==observed self-identity semantics in memory without rereading the source;
7. continue matching that digest to the explicitly selected AW30 reference or observed role;
8. preserve AW30 run-binding recomputation, completion validation and the existing AW44 combined binding format.

The existing `identityChunkFrames` parameter remains validated (`> 0`) for source/API compatibility, but AW45 deliberately uses `cleanReport.maximumChunkFrames` for the actual combined traversal. SHA identity is independent of chunk segmentation; AW43 report counters are not. Using the stored AW43 chunk boundary is therefore required to reproduce the report exactly.

## Read-amplification reduction

For a successful clean source with `N` bounded chunk reads:

- AW44 verification path: `N` AW43 sweep + `N` SHA reference + `N` SHA observed = `3N` reads.
- AW45 verification path: one combined FNV + SHA traversal = `N` reads.

This is a 3x reduction in clean-source read calls for this evidence-binding stage. It does not claim a 3x wall-clock production speedup because decoder cost, filesystem cache state, SHA/FNV CPU work and the surrounding AW30/AW43 workflows differ.

## Focused portable verification executed in Worker environment

Environment:

- Swift 6.2.1
- Linux x86_64
- Swift language mode 6
- strict concurrency `complete`
- warnings as errors

A focused exact-algorithm harness used 180,000 frames, 2 channels, 100 Hz synthetic deterministic Float32 PCM and the repository SHA/FNV field encoding.

Observed:

`L3_AW45_FOCUS_PASS digest=fed6505b0fcb3b01 fnv=7262699423100747709 onePassReads=44 oldAW44EquivalentReads=132`

Validated:

- SHA-256 equals an independent Python `hashlib.sha256` calculation of `SHA256_FLOAT32_LE_V1` bytes;
- FNV-1a equals the independent expected value;
- 4,096-frame and 1,000-frame traversal chunks produce the same SHA-256;
- one combined traversal requires 44 reads where the prior AW44-equivalent path requires 132 reads.

## Focused performance comparison

An optimized Swift focused harness compared, over five iterations and 360,000 frames:

- old-equivalent work: one FNV sweep plus two SHA passes;
- new work: one traversal computing FNV and SHA together.

Observed:

`L3_AW45_BENCH_PASS oldSeconds=0.20767319202423096 singlePassSeconds=0.10029256343841553 ratio=2.070673885524447 checksum=10216074435157666133`

This ~2.07x focused synthetic CPU result is structural evidence only. It is not a physical-iPhone, AVFAudio decoder, APFS, battery, thermal or production long-track performance claim.

## Repository-native durable coverage authored

- `Playback/Tests/L3_AW45_SinglePassCodecIdentitySelfTest.swift`
  - verifies old-equivalent 3N reads versus N single-pass reads with an instrumented source;
  - verifies SHA identity equality;
  - verifies FNV/read/frame counters match the AW43 sweep;
  - verifies chunk-boundary digest invariance;
  - rejects short reads and zero chunk size.
- `Playback/Tests/L3_AW45_SinglePassCodecIdentityStress.swift`
  - 20 rounds across 8 chunk sizes from 1 to 65,536 frames;
  - checks digest invariance and total-frame traversal on every run.
- `Playback/Tests/L3_AW45_SinglePassCodecIdentityBenchmark.swift`
  - compares old-equivalent three-pass work with the new combined traversal using production repository primitives.

The repository-native files were authored but not executed in this Worker environment because the container cannot resolve `github.com` to clone the branch. HQ's permanent full Lane3 Swift 6 strict typecheck gate must compile and run them during semantic integration.

## Security / evidence semantics preserved

- SHA-256 remains content addressing, not an authenticity signature.
- No raw PCM is retained in durable evidence.
- No compressed bytes or source paths are added to the binding receipt.
- AW43 truncated/corrupted compressed-file derivative parentage remains unproven; AW45 does not change that boundary.
- The AW44 binding receipt schema and evidence scope remain unchanged.
- Physical-iPhone evidence is not inferred from portable execution.
- No PARITY row is promoted by this Wave.

## Remaining external / HQ gates

- full Worker-branch typecheck and repository-native AW44/AW45 execution;
- selected Xcode/AVFAudio compile and runtime;
- rights-cleared >=30-minute real clean/truncated/corrupted codec families;
- physical-iPhone RSS/thermal/battery evidence;
- physical timing/click-pop/audibility evidence;
- current-Moises differential and human listening;
- AW42 repeated-loop seam automation remains fail-closed until a selected Apple mechanism provides stale-event revocation or generation-isolated future rendering.

`MOI-P006/P007/P008/P010/P012/P014/P015/P021` therefore remain `MISSING` pending HQ real-device / real-audio evidence and final judgment.