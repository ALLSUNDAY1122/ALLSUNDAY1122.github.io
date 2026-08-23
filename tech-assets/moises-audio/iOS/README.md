# Lane 4 standalone iOS host

This directory is the epoch-2 standalone iOS platform host for `LANE-4-IOS-ANALYSIS`.

It compiles the frozen `Shared/**` and `App/**` contracts plus Lane-4-owned `Analysis/**` and `iOS/**`. It intentionally does **not** copy or compile the current implementations from the IO, Library, Playback, DSP, or Separation lanes. Those implementations are injected by HQ during Late Integration.

## Canonical configuration

- XcodeGen spec: `project.yml`
- project: `MoisesLane4Host`
- scheme: `MoisesLane4Host`
- deployment target: iOS 16.0
- Swift: 6.0 / complete strict concurrency
- application bundle id: `jp.allsunday1122.moiseslane4host`

The generated `.xcodeproj` is build output. `project.yml` is the reproducible source of truth for this Lane bundle.

## Generate and build on an Apple/Xcode-capable machine

From `tech-assets/moises-audio/iOS`:

```bash
xcodegen generate --spec project.yml

xcodebuild \
  -project MoisesLane4Host.xcodeproj \
  -scheme MoisesLane4Host \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

To run the iOS unit/smoke tests, select an available simulator first:

```bash
xcrun simctl list devices available

xcodebuild \
  -project MoisesLane4Host.xcodeproj \
  -scheme MoisesLane4Host \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

If the exact simulator name is unavailable, substitute any installed iPhone simulator. Do not turn a missing simulator runtime into a product failure; record the Xcode/runtime version and use an installed destination.

## Module injection boundary

`HostModuleSlots` is the only Lane-4 composition seam for implementations owned by the other lanes. It exposes frozen-contract slots for:

- `AudioImporting` — IO lane
- `SourceSeparationProviding` — Separation lane
- `PlaybackPreparing` — Playback lane
- `ProjectPersisting` — Library lane
- `AudioExporting` — IO/export lane
- `PracticeDSPConfiguring` — DSP lane
- `MusicAnalyzing` — Analysis; Lane 4 will provide this in later Macro Bundles

`makeCoordinator()` fails closed when a constructor-required slot is absent. DSP remains an explicit Late Integration slot even though the frozen `VerticalSliceCoordinator` constructor does not currently accept it.

The standalone app deliberately starts with `HostModuleSlots.empty` and presents the missing-slot diagnostic state. This is not a fake implementation of other lanes.

## Platform smoke boundary

`ApplePlatformSmoke` is a compile/link smoke only. On an Apple target it touches `AVAsset`, `AVAudioEngine`, and `AVAudioUnitTimePitch` so the host can prove the AVFoundation/AVFAudio link surface is available. On non-Apple platforms it fails closed and reports unavailable.

This smoke does **not** prove:

- physical-device audio routing/session behavior;
- real stem playback or DSP quality;
- AVAudioUnit render latency/artifact thresholds;
- interruption/background behavior;
- thermal/battery/memory behavior;
- IO picker/share behavior;
- four-Lane integrated compilation;
- any Moises PARITY row.

## Physical-device and Late Integration gaps

HQ Late Integration must still:

1. inject actual Lane 1/2/3 implementations without changing the frozen contract semantics silently;
2. generate the Xcode project and run simulator build/tests on an Apple runner;
3. compile the fully integrated target, including the actual IO and DSP Apple backends;
4. install/run on a physical target iPhone;
5. measure audio routing, synchronization, latency, interruptions, thermal/memory behavior and real-audio quality;
6. run differential Moises evidence before any PARITY promotion.

A successful host build is platform evidence only and must not promote `PARITY_MATRIX.json`.
