# L4 Autonomous Wave 05 Validation — Rights-safe Real-Audio MIR Benchmark

Date: 2026-08-23 JST

## Goal

Create the reusable real-audio benchmark gate for MOI-P009 BPM, MOI-P011 key, MOI-P013 chords and MOI-P016 song sections, while preventing synthetic or legally/technically unverified inputs from becoming PARITY evidence.

## Implementation

- `Analysis/RealAudioBenchmarkSuite.swift`
  - rights evidence + permitted-use model
  - REAL_AUDIO vs SYNTHETIC_TEST source classification
  - multi-domain ground-truth annotation
  - manifest validation
  - source checksum verification seam
  - duration/non-finite PCM guards
  - batch execution across tempo/beat/key/chord/structure
  - per-domain aggregate reporting
  - synthetic evidence remains non-PARITY
- `Analysis/RealAudioBenchmarkCodec.swift`
  - deterministic pretty/sorted JSON
  - ISO-8601 dates
- `Analysis/benchmarks/GOLDEN_MIR_MANIFEST_TEMPLATE.json`
  - intentionally fail-closed placeholder template
- `Analysis/benchmarks/REAL_AUDIO_BENCHMARK_RUNBOOK.md`
  - operator and HQ integration instructions
- `Tests/MoisesAudioCoreTests/RealAudioBenchmarkSuiteTests.swift`
  - 6 focused cases
- `Tests/MoisesAudioCoreTests/RealAudioBenchmarkCodecTests.swift`
  - ISO-8601 manifest round-trip

## Negative / recovery gates covered

The validator rejects unsupported schema, empty/duplicate fixture IDs, unsafe relative paths, invalid duration, missing rights grant, missing benchmark permission, expired rights, invalid SHA-256, absent reference domains, invalid BPM, beat bounds/order defects, chord bounds/overlap, section bounds/gaps/overlap/incomplete coverage.

The runner aborts on source checksum mismatch, decoded-duration mismatch, and non-finite PCM.

## Validation executed in Worker environment

Environment: Swift 6.2.1, x86_64 Linux.

1. `swiftc -parse RealAudioBenchmarkSuite.swift` — PASS.
2. `swiftc -typecheck` against frozen-contract-shaped stubs for DomainContracts / Analysis / evaluators — PASS.
3. Executable validation harness covering valid real eligibility, synthetic non-eligibility, rights/path/hash failures, five-domain batch report, JSON Codable round-trip, and checksum mismatch — PASS.
4. ISO-8601 codec typecheck and executable round-trip — PASS.
5. Attempted public GitHub `git ls-remote` from the Worker container — blocked because `github.com` DNS cannot resolve in this runtime. Therefore a fresh canonical `swift test` checkout is not claimed here; committed XCTest must be run by an environment with repository/network access or HQ integration.

## Commits

- `00a8734a11c060eb95198b92279fbe7747fa9875` — benchmark suite
- `17aa3e3bf67a2ace1c9f1f9bbdbe929bd802b142` — package source registration
- `d4c4b2dedec0360ba95e905e470d185d38339554` — benchmark suite XCTest
- `6eebd6237b77ed76405083a52ed3408845106ccc` — ISO-8601 JSON codec
- `dd5a50a21a33a987863dc34de757fa48c4ee257f` — package codec registration
- `0233419d1e837856f1ec19a9249dc0b78bcd8123` — Golden MIR template
- `f2352c95055b908fbf7465769ef4aaa374b466ea` — runbook
- `747a4bc9f933e470ed42ccfb98aa988feaaf23e1` — codec XCTest

## Remaining gates

This Wave does not promote PARITY. Actual rights-cleared multi-genre audio, trustworthy ground truth, physical-iPhone latency/RSS/thermal/battery, current-Moises differential, and HQ PARITY judgment remain outstanding.

The benchmark loader adapter must bind the final app-owned decode path to `AnalysisBenchmarkSignalLoading` and return the SHA-256 of the exact source file used for decoding. That adapter is a Late Integration concern because the production file/decode implementation is Lane 2 / HQ-composed.
