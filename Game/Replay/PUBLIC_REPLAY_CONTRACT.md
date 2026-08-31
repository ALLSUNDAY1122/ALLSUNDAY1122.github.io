# Session A Replay / Clone Public Contract

Status: Replay format V1, integration-ready 2026-09-01.

## Commands

`ReplaySystem` conforms to `ReplayControlling`:

```swift
func startRecording(context: ReplayContext)
func stopRecording() -> ReplayRecording?
func clearRecording(for courseID: String?)
func spawnClone(recording: ReplayRecording, options: CloneSpawnOptions) -> CloneID
func removeClone(_ id: CloneID)
func removeAllClones()
```

Additional fixed-tick integration methods:

```swift
func captureTick(tick: UInt64, state: any ReplayStateSource, input: ReplayInputSample) -> Bool
func recordMarker(tick: UInt64, kind: ReplayMarkerKind) -> Bool
func stepClones() -> [CloneSnapshot]
func cloneSnapshot(_ id: CloneID) -> CloneSnapshot?
func bestRecording(for courseID: String) -> ReplayRecording?
```

## Replay V1 state

Every captured frame contains:

- fixed simulation tick;
- authoritative position and velocity;
- normalized movement/action input metadata;
- locomotion state;
- air-jump and air-dash resource state;
- facing direction;
- alive/dead state.

Checkpoint, death, and lap-completion semantics are stored as markers.

## Fixed-tick completeness

V1 requires captured ticks to be strictly increasing **and contiguous**. If a live recording skips a tick, that recording becomes invalid and `stopRecording()` returns `nil`; it must not become the course best or emit `recordingCompleted`.

This rule prevents a dropped capture from silently shortening time during Clone playback.

## Validation

Constructing `ReplayRecording` rejects:

- unsupported format versions;
- empty recordings;
- duplicate/reversed ticks;
- missing ticks;
- marker frame indices outside the frame array;
- marker tick values that do not equal the referenced frame tick.

Unknown/future formats therefore fail safely instead of producing plausible-but-wrong playback.

## Marker ordering

`recordMarker(tick:kind:)` may be called immediately before or after same-tick state capture. Marker tick is buffered first and resolved to a frame only when recording finalizes. A future marker for which no frame is ever captured is discarded.

## Clone playback

`CloneSpawnOptions` supports:

- loop/non-loop playback;
- start-frame selection;
- phase offset in fixed ticks.

Multiple Clone instances have independent cursors. V1 playback advances exactly one recorded frame per Clone tick and applies the recorded authoritative state directly. It does not integrate input, so position/velocity error cannot accumulate over long loops.

Recorded dead frames are visual/state data for the Clone; they do not destroy the Clone playback object. A looping Clone can therefore replay death and later return to the recording's initial live state.

## Best recording

`ReplaySystem` keeps one in-memory best recording per `courseID`, preferring the shortest valid `durationTicks`. `clearRecording(for:)` clears one course or all courses when passed `nil`.

Persistence is deliberately outside Session A. Session C may serialize Replay data, but must persist `version` and revalidate through `ReplayRecording` when loading.

## Signal

Successful non-empty `stopRecording()` emits:

```swift
.recordingCompleted(RecordingEvent(frameCount: recording.frameCount))
```

Invalid/empty recordings emit no completion signal.

## Session C fixed-tick order

On each `FixedStepClock` tick:

1. apply normalized input to Player;
2. step Player;
3. record semantic markers for the same tick if triggered;
4. capture the resolved Player state;
5. advance Clones;
6. render `CloneSnapshot` values without mutating Clone cursors directly.

Calling marker before or after step 4 on the same tick is supported.
