# L4-W47 Validation｜Physical iPhone real-audio corpus execution provenance

Date: 2026-08-26 JST

## Result

`IMPLEMENTED / NON_PARITY / REAL PHYSICAL EXECUTION NOT OBSERVED`

W47 adds the Project-side provenance layer required before W46 can treat a Project audited Analysis report as coming from an exact physical-iPhone real-audio corpus execution.

No P009/P011/P013/P016/P021 PARITY state was changed.

## Production behavior added

W47 now has four portable Analysis files plus one iOS coordinator:

- `AnalysisPhysicalRealAudioCorpusModels.swift`
- `AnalysisPhysicalRealAudioCorpusValidation.swift`
- `AnalysisPhysicalRealAudioCorpusReport.swift`
- `AnalysisPhysicalRealAudioCorpusHelpers.swift`
- `iOS/HostCore/AnalysisIOSPhysicalRealAudioCorpusCoordinator.swift`

The iOS coordinator:

1. accepts canonical manifest bytes only;
2. re-encodes and requires exact byte identity;
3. hashes those exact bytes;
4. runs only on physical `iphoneos/arm64` (not Simulator/Catalyst);
5. requires `GENUINE_LANE2_BOUNDED_DECODER`;
6. iterates every manifest fixture with no selection parameter;
7. requires `.boundedPull` source contract and exact source SHA;
8. executes existing `AnalysisCurrentDeviceWorkloadRunner` / W30-W36 current chunked Analysis runtime;
9. records unique decoder execution ID, workload run ID and workload execution ID;
10. retains canonical snapshot bytes/hash and source population observations;
11. aborts on any fixture failure/cancellation, with no ready partial-success package;
12. assembles and immediately reopens the final package before returning READY-pending-HQ.

The portable assembler independently revalidates canonical manifest SHA, exact inventory, runtime binding, source bindings, W36 stage order, execution binding, canonical snapshots and unique IDs. It rebuilds the entire audited Project report from retained fixture snapshots and rejects a package whose stored report cannot be rebuilt exactly.

## Self-audit corrections before publication

Two robustness gaps were identified before final branch publication and corrected:

1. The first draft used `Dictionary(uniqueKeysWithValues:)` after manifest validation. A malformed duplicate fixture manifest could therefore have trapped before a clean fail-close result. W47 now builds lookup maps without duplicate-key trapping; duplicate fixture IDs remain a canonical manifest validation failure.
2. The first draft accepted a SHA-shaped `manifestSHA256` next to a manifest struct. W47 now canonical-encodes the manifest inside portable validation, hashes those canonical bytes and requires exact equality with the supplied manifest root.

The package codec test was also corrected to use the actual `AnalysisPhysicalRealAudioCorpusCodec.encode/decode` API names before publication.

## Negative-first XCTest source

`AnalysisPhysicalRealAudioCorpusExecutionTests.swift` covers:

- valid complete package reopen;
- W47 Project report root equality with the W46 canonical report-root function;
- selective fixture subset rejection;
- simulator runtime rejection;
- compatibility decoder rejection;
- source SHA drift rejection;
- observed source sample population drift rejection;
- reused workload execution ID rejection;
- reused decoder execution ID rejection;
- reused run ID rejection;
- missing Analysis stage rejection;
- snapshot mutation with recomputed workload binding cannot reuse an older Project report;
- package-root tamper rejection;
- deterministic package codec round-trip and reopen;
- synthetic fixture rejection;
- canonical manifest SHA drift rejection.

The durable XCTest source is committed, but a full current Worker-branch XCTest run was not observed in this environment.

## Fresh Worker branch attempt

Command:

`git ls-remote https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git refs/heads/moises/wp4-analysis-platform`

Observed:

- exit: 128
- error: `Could not resolve host: github.com`
- elapsed: ~0.11 s
- max RSS: ~3,804 kB

Therefore:

**Fresh full Worker-branch SwiftPM/XCTest = NOT_OBSERVED.**

Do not infer a full branch PASS from the portable checks below.

## Swift 6 strict-concurrency source checks

Environment:

- Swift 6.2.1
- x86_64 Linux

### Split W47 portable production core

The four exact local production source files matching the remote production blobs were typechecked with dependency stubs using:

`-swift-version 6 -strict-concurrency=complete -warnings-as-errors -typecheck`

Observed:

- PASS
- elapsed ~2.49 s
- max RSS ~135,400 kB

Remote blob readback matched the locally validated production blobs for the W47 portable production files inspected.

### W47 XCTest source-shaped typecheck

The committed test body was typechecked in a local single-module mirror with only `@testable import MoisesAudioCore` removed.

Observed:

- PASS
- elapsed ~2.97 s
- max RSS ~136,260 kB

This is a compile-surface check, not XCTest execution.

### iOS coordinator source-shaped typecheck

Linux cannot typecheck the UIKit/Darwin-gated source directly. A source-shaped copy removed only the outer UIKit/Darwin guard/imports and replaced the device-model helper with a constant; the corpus execution logic was retained.

Observed:

- PASS with Swift 6 strict concurrency and warnings-as-errors
- elapsed ~2.15 s
- max RSS ~141,644 kB

This is not selected-Xcode/iphoneos compilation.

## Swift fail-close mirror

A Swift 6 executable mirror exercised 12 rotating adversarial classes:

1. manifest root invalid;
2. synthetic fixture;
3. simulator platform;
4. compatibility decoder;
5. fixture subset;
6. source SHA drift;
7. observed sample drift;
8. duplicate run ID;
9. duplicate workload execution ID;
10. duplicate decoder execution ID;
11. incomplete stage set;
12. invalid snapshot evidence.

Observed:

- PASS 180,000 / 180,000 rejected as required
- exactly 15,000 checks per class
- compile ~1.43 s / 147,252 kB RSS
- run ~1.02 s / 18,060 kB RSS

This mirror validates gate logic only; it is not product execution evidence.

## Canonical package-root mirror

A canonical-JSON SHA-256 mirror generated 25,000 package shapes and mutated 12 provenance fields per package, including manifest root, runtime root, device/session, decoder kind, fixture inventory, source SHA, workload execution ID, snapshot SHA, Project report root and status.

Observed:

- PASS 25,000 packages
- PASS 300,000 mutations changed the package root
- elapsed ~19.93 s
- max RSS ~110,556 kB

This is deterministic tamper-evidence validation only.

## Real external gates still missing

No real W47 READY package was produced in this wave because the session did not have:

- an HQ-approved exact rights-cleared real-audio corpus;
- a genuine integrated Lane-2 bounded decoder implementation;
- a selected physical iPhone execution of the full corpus;
- an actual current-iPhone W19-W21 Moises reference package.

Accordingly:

- MOI-P009 remains `MISSING`;
- MOI-P011 remains `MISSING`;
- MOI-P013 remains `MISSING`;
- MOI-P016 remains `MISSING`;
- MOI-P021 remains `MISSING` for the independent W45 device/performance reasons.

## Trust boundary

W47 runtime/device/decoder/build/session SHA commitments are not Apple attestation, signatures, Secure Enclave proof or trusted timestamps. HQ must independently retain/verify the selected source files, legal grants, W47 package root and device/build provenance before using the W47 Project report in W46.

The correct final authority remains HQ Late Integration. Worker 4 does not edit `PARITY_MATRIX.json`.
