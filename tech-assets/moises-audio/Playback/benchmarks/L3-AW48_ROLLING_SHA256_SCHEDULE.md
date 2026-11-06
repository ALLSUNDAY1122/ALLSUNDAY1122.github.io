# L3-AW48｜Rolling SHA-256 Message Schedule

Result: **COMPLETE_NON_PARITY**

## Goal

Reduce the per-SHA-block message-schedule working storage used by `SHA256_FLOAT32_LE_V1` without changing any durable PCM identity, AW44-AW47 receipt/binding semantics, or the AW46 metadata-stability fence.

## Change

AW47's `Lane3IncrementalSHA256.compressRaw` constructed a 64-element `UInt32` Array for each 64-byte SHA block. AW48 derives each SHA word from the last 16 words and overwrites the `W[t-16]` slot after it is no longer needed.

- Previous explicit schedule: 64 x UInt32 = 256 bytes of source-level schedule storage per SHA block.
- AW48 explicit schedule: 16 x UInt32 = 64 bytes in `withUnsafeTemporaryAllocation`.
- Reduction in explicit schedule working storage: 75%.
- SHA round count remains 64.
- SHA domain/header and `SHA256_FLOAT32_LE_V1` byte format are unchanged.
- AW47 direct Float32 raw-buffer feeding remains unchanged.
- AW46 metadata freeze/checks remain unchanged.

The temporary-allocation API is intentionally described as bounded temporary storage; this evidence does not claim a particular compiler stack/heap placement on every target.

## Focused verification

Environment: Swift 6.2.1, Linux x86_64, Swift language mode 6, strict concurrency complete, warnings as errors, optimized build.

A side-by-side legacy 64-word implementation and the selected 16-word implementation were compared over 98 arbitrary message/chunk cells. The SHA-256 NIST `abc` vector remained:

`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`

Existing Lane3 PCM identity fixtures also remained exact:

- AW47 special Float32 bit-pattern corpus: `a44c84af8d97712aa378026410127ed758b73d0024b0aa8d053f3156291745cb`
- 180,000-frame deterministic long-track corpus: `fed6505b0fcb3b01a65fccc8e3b913772cb50e90e2835f9a0e51e74f6719bab2`

The initial `SIMD16<UInt32>` ring prototype was rejected because focused optimized execution regressed by about 17%. The selected `withUnsafeTemporaryAllocation` 16-word implementation showed a legacy/new focused ratio of about 1.11x in the final run, with five repeated ratios ranging approximately 0.99x to 1.14x. This is too noisy to claim deterministic CPU speedup; the durable AW48 performance result is the 75% reduction in explicit message-schedule storage with no observed large regression in the focused proxy.

## Repository-native coverage authored

- `Playback/Tests/L3_AW48_RollingSHA256ScheduleSelfTest.swift`
- `Playback/Tests/L3_AW48_RollingSHA256ScheduleStress.swift`
- `Playback/Tests/L3_AW48_RollingSHA256ScheduleBenchmark.swift`

The stress suite covers 40 deterministic PCM cases x 5 chunk sizes = 200 cells. Its expected aggregate `18370574486077463754` was calculated independently with Python `hashlib`, so the stress test is not merely self-consistency between two calls to the new implementation.

## Boundaries

This Wave does not prove:

- Xcode/AVFAudio runtime behavior,
- physical-iPhone RSS/CPU/thermal/battery improvement,
- rights-cleared real-codec long-track performance,
- current Moises differential parity,
- authenticity signatures or compressed-derivative provenance,
- any Lane3 PARITY row.

HQ should run the permanent Lane3 Swift 6 strict typecheck and the AW48 repository-native self-test/stress/benchmark, then rerun AW46 metadata-mutation and AW44-AW47 receipt regressions at semantic integration.
