# L3-AW47｜Streaming PCM Identity SHA Input

Result: `COMPLETE_NON_PARITY`

## Goal

Remove the AW46 per-chunk `Float32 -> [UInt8]` materialization from long-track `SHA256_FLOAT32_LE_V1` identity hashing without changing durable digest semantics, AW46 metadata-stability fencing, AW43 report reproduction, AW44/AW45 content binding, or any PARITY claim.

## Implementation

- `Lane3IncrementalSHA256.update(_:)` now feeds raw storage into a bounded SHA block path rather than materializing each 64-byte slice as a new array.
- `updateFloat32LittleEndian(_:)` consumes the existing `[Float]` storage directly on selected little-endian Apple/Linux targets.
- Big-endian fallback explicitly emits each Float bit pattern in little-endian order, preserving the algorithm contract.
- The PCM chunk conversion array formerly sized at `samples.count * 4` is removed.
- The existing overflow check remains before the raw Float storage is passed to SHA.
- AW46 metadata snapshots/checks before and after each source read and at completion remain unchanged.

## Memory boundary

For 4096-frame stereo chunks:

- former additional PCM conversion buffer: `4096 * 2 * 4 = 32768 bytes`
- AW47 additional PCM conversion buffer: `0 bytes`
- source `[Float]` chunk remains bounded and unchanged
- SHA internal partial block remains bounded to <=64 bytes
- full-track PCM is still not retained by the identity path

For the default 16384-frame stereo identity chunk, the removed conversion buffer is 131072 bytes per full chunk.

## Focused portable verification

Environment:

- Swift 6.2.1
- Linux x86_64
- Swift language mode 6
- strict concurrency complete
- warnings as errors
- optimized build

Results:

1. Legacy buffered and AW47 raw-streaming SHA paths matched across chunk sizes `1, 7, 64, 257, 4096, 16384, 65536`.
2. The existing 180000-frame synthetic identity remained:
   `fed6505b0fcb3b01a65fccc8e3b913772cb50e90e2835f9a0e51e74f6719bab2`.
3. A 16-sample bit-pattern corpus including positive/negative zero, subnormals, max finite, infinities and two NaN payloads matched independent Python `hashlib` evidence:
   `a44c84af8d97712aa378026410127ed758b73d0024b0aa8d053f3156291745cb`.
4. No deterministic CPU speedup is claimed. Repeated focused timings were close/noisy; the durable improvement is elimination of the chunk-sized conversion allocation/copy, not a portable timing guarantee.

## Repository-native coverage authored

- `L3_AW47_StreamingPCMIdentitySelfTest.swift`
- `L3_AW47_StreamingPCMIdentityStress.swift`
- `L3_AW47_StreamingPCMIdentityBenchmark.swift`

The stress program checks 20 repetitions across 10 chunk sizes (200 digest/FNV cells) so SHA block alignment is exercised independently from PCM chunk alignment.

## Required HQ integration checks

- Full Lane3 Swift 6 strict typecheck.
- Execute AW47 self-test/stress/benchmark.
- Rerun AW46 metadata mutation stress against the AW47 raw path.
- Rerun AW44/AW45 stable content-binding/receipt regression and verify combined binding remains unchanged.
- Selected Xcode/AVFAudio and physical-iPhone long-track RSS/thermal/battery evidence remain separate gates.

## Non-claims

AW47 is a bounded evidence-path allocation improvement only. It does not establish physical-device performance, audible quality, authenticity signatures, compressed derivative provenance, or any Moises PARITY row.
