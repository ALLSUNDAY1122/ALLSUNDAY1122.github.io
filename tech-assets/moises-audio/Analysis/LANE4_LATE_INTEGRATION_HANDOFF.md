# Lane 4 Late Integration Handoff

Date: 2026-08-22 JST
Lane: `LANE-4-IOS-ANALYSIS`
Frozen Shared/App contract SHA: `be1c84314db182d6eee5097de34e017af1a4a7de`

This document is the handoff from Worker 4 to HQ Late Integration. It does not authorize PARITY promotion.

## Implemented Lane 4 surface

Lane 4 now owns a complete portable analysis path behind the frozen `MusicAnalyzing` contract:

- `TempoBeatAnalyzer`: BPM, confidence and source-time beat timestamps.
- `MusicalKeyAnalyzer`: tonic pitch class, major/minor mode and confidence/unknown handling.
- `ChordTimelineAnalyzer`: timestamped major/minor chord events plus explicit `N` no-chord and `X` unknown.
- `SongSectionAnalyzer`: source-time structural section intervals, conservative structural clustering, optional functional labels and unknown handling.
- `ProjectOwnedMusicAnalyzer`: one `AnalysisSnapshot` containing all four result domains.
- `AnalysisBenchmarkRunner` + `SectionBenchmarkEvaluator`: machine-readable AN-001-oriented metrics.
- standalone iOS host/DI slot from L4-M01.

No Lane 2 IO, Lane 3 Playback/DSP or Lane 1 Separation implementation is copied into Lane 4.

## Integration seam

`AnalysisSignalLoading` is the only required audio-loading seam for the current analysis engine:

```swift
public protocol AnalysisSignalLoading: Sendable {
    func loadSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSignal
}
```

HQ should provide an adapter from the final app-owned/decode path into mono PCM `AnalysisSignal` and then compose:

```swift
let analysis = ProjectOwnedMusicAnalyzer(loader: appOwnedSignalLoader)
let slots = HostModuleSlots(
    importer: importer,
    separator: separator,
    playback: playback,
    analysis: analysis,
    persistence: persistence,
    exporter: exporter,
    practiceDSP: practiceDSP
)
```

Do not move IO/decode ownership into `Analysis/**` to make this wiring convenient. If the final Lane 2 decoder already exposes PCM, adapt it centrally in HQ integration.

## Time-coordinate contract for App/Playback

All analysis timestamps use original source-time seconds.

- beat: `TempoAnalysis.beatTimesSeconds`
- chord: `startSeconds <= sourceTime < endSeconds`
- section: `startSeconds <= sourceTime < endSeconds`

Stored analysis timestamps should not be rewritten when playback speed changes. Playback/UI should map the current playback clock to source time before selecting a beat/chord/section. This avoids cumulative drift and keeps saved analysis stable.

Pitch/key shifting is also a presentation/practice transformation. Preserve base detected `MusicalKey` and `ChordEvent.normalizedLabel`; if current-reference UX requires transposed display, apply the semitone transform at the integrated presentation boundary rather than mutating the original analysis artifact.

## Unknown semantics are intentional

- tempo/key may be `nil` when confidence is insufficient.
- chord `N` means no chord/silence; chord `X` means unknown/insufficient confidence.
- section structural label `X` means structure could not be justified.
- `SongSection.functionalLabel == nil` is a valid result and must not be converted to a guessed `verse`, `chorus` or `bridge` label.

The product UI should present unknown states without treating them as processing failure.

## Persistence / serialization

`AnalysisSnapshot`, `TempoAnalysis`, `MusicalKey`, `ChordEvent` and `SongSection` are frozen-contract `Codable` values. Lane 4 tests preserve timestamp order through JSON round trips.

If HQ/Library chooses to persist analysis, keep persistence schema evolution in the owning integration/Library layer. Worker 4 intentionally did not modify `Shared/**` or `Library/**`.

## Required HQ checkpoint gates

Before any Analysis PARITY promotion, HQ must run all of the following:

1. merge Lane 4 semantically with the other lane checkpoints without discarding Lane-owned commits;
2. run a fresh canonical `swift test` from an actual checkout;
3. generate the Xcode project and run the iOS Simulator build/test gate;
4. inject the concrete app-owned audio/PCM loader through `AnalysisSignalLoading`;
5. compile the actual four-lane iOS composition;
6. run the rights-cleared Project Golden MIR real-audio set across multiple genres/structures;
7. collect full AN-001 tempo/beat/key/chord/section metrics, including failure and unknown cases;
8. measure physical-iPhone wall time, peak memory, thermal/battery behavior and long-audio stability;
9. verify chord/section visual synchronization against the integrated playback clock at normal and altered playback speeds;
10. perform current-Moises differential comparison for BPM, key, chord vocabulary/timestamps, section boundaries/labels and UX;
11. update `PARITY_MATRIX.json` only from HQ after the above evidence is reviewed.

## Reference questions HQ must resolve

- Confirm the exact chord vocabulary exposed by current iPhone Moises: major/minor only vs inversions, sevenths, extensions or slash chords.
- Confirm the exact functional section labels and unknown behavior exposed by current iPhone Moises.
- Confirm whether section labels transpose, relabel or otherwise interact with speed/pitch controls.

Do not expand or narrow the required product scope from assumptions; use current-reference evidence.

## Current PARITY state

`MOI-P009`, `MOI-P011`, `MOI-P013` and `MOI-P016` remain `MISSING`. Current Lane 4 benchmark artifacts are synthetic/test evidence and are explicitly non-PARITY.
