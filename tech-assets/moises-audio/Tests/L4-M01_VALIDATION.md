# L4-M01 validation — standalone iOS host

Date: 2026-08-22 JST
Lane: `LANE-4-IOS-ANALYSIS`
Frozen epoch contract SHA: `be1c84314db182d6eee5097de34e017af1a4a7de`

## Scope implemented

- reproducible XcodeGen `iOS/project.yml` with application + unit-test targets and shared scheme;
- standalone SwiftUI diagnostic host;
- fail-closed `HostModuleSlots` injection boundary around frozen HQ protocols;
- explicit DSP Late Integration slot even though DSP is not in the frozen coordinator constructor;
- conditional AVFoundation/AVFAudio compile/link smoke;
- host composition negative/smoke tests;
- portable HostCore added to SwiftPM regression target;
- reproducible simulator build/test instructions and physical-device gap ledger.

No IO, Library, Playback, DSP, Separation implementation was copied into the Lane-4 host. `Shared/**`, `App/**`, Queue and `PARITY_MATRIX.json` were not edited.

## Machine checks

Environment available to Worker 4:

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
xcodebuild: UNAVAILABLE
xcodegen: UNAVAILABLE
```

### Swift build

A temporary local SwiftPM harness was reconstructed from the frozen canonical Shared/App/Core source text plus the exact Lane-4 HostCore changes because direct repository clone from the execution container cannot resolve github.com.

Result:

```text
swift build --disable-sandbox
Build complete! (5.45s)
```

This confirms the portable frozen Shared/App + Lane-4 HostCore contract surface compiles under Swift 6.2.1/Linux. It is not Apple/Xcode evidence.

### Regression + negative cases

The reconstructed harness ran the canonical existing regression behaviors plus the four new host-composition checks:

```text
swift test --disable-sandbox
DomainContractCoordinatorTests: 5/5 PASS
SeparationQualityTests: 8/8 PASS
LibraryContractTests: 4/4 PASS
IOSHostCompositionTests: 4/4 PASS
TOTAL: 21 tests, 0 failures, 0 unexpected
```

The first attempt to assemble the temporary harness compressed an existing async XCTest and incorrectly placed `await` inside an XCTest autoclosure. That temporary transcription error was corrected to the canonical pattern of awaiting actor values before assertions; the product branch test source was not defective.

New negative/smoke coverage verifies:

1. an empty host fails closed and reports all coordinator-required module slots in deterministic order;
2. the frozen `VerticalSliceCoordinator` can be constructed solely through protocol injections without importing other Lane implementations;
3. DSP remains explicit in the Late Integration surface;
4. Apple framework smoke fails closed on a non-Apple platform and is structured to link AVFoundation/AVFAudio on Apple.

### XcodeGen/static configuration check

`project.yml` was parsed with PyYAML 6.0.3 and mechanically inspected.

```text
YAML_PARSE_PASS
TARGETS MoisesLane4Host,MoisesLane4HostTests
APP_SOURCES ../Shared,../App,../Analysis,HostCore,App
FORBIDDEN_OTHER_LANE_SOURCES_PASS
```

The app source list contains no `../IO`, `../Library`, `../Playback`, `../DSP`, or `../Separation` path.

## Apple/Xcode evidence boundary

The current Worker execution host is Linux and has neither `xcodebuild` nor `xcodegen`. Therefore an actual iOS Simulator build cannot be truthfully claimed in this Macro Bundle. `iOS/README.md` provides the exact XcodeGen and `xcodebuild` commands for an Apple runner.

Per v3 Late Integration, HQ still owns:

- actual Xcode generation and simulator compile/test;
- four-Lane integrated compile;
- concrete IO/DSP Apple backend validation;
- physical-iPhone install/run;
- real audio, synchronization, latency, interruption, thermal/memory and quality evidence;
- Moises differential comparison and PARITY judgment.

## PARITY statement

L4-M01 is platform/build infrastructure. No PARITY row is promoted. All product PARITY claims remain dependent on later integrated real-device/real-audio evidence.
