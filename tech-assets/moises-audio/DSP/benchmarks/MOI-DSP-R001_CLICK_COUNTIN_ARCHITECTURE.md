# MOI-DSP-R001｜Smart Click / Count-in Synchronization Architecture

## Scope rule

This is a DSP research artifact. It does **not** redefine shared Playback or Analysis contracts.

Inputs assumed from owners of those logical resources:
- Playback: current render/sample timeline, play/pause/seek/loop events.
- Analysis: beat/downbeat positions and confidence, plus tempo map if variable-tempo support is implemented.
- DSP: renders click/count-in against those positions and applies time/pitch processing.

## Selected architecture

Use a **single render-clock domain**. Music and click must be scheduled against the same `AVAudioEngine` sample timeline rather than using UI timers (`Timer`, `DispatchQueue.asyncAfter`, display refresh) to trigger audible clicks.

Apple documents that `AVAudioPlayerNode` schedules buffers/file segments at an `AVAudioTime`, and exposes conversion between node/player timelines. That gives the required primitive for sample-timeline scheduling.

Authoritative sources:
- https://developer.apple.com/documentation/avfaudio/avaudioplayernode
- https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulebuffer(_:at:options:completionhandler:)
- https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulesegment(_:startingframe:framecount:at:completioncallbacktype:completionhandler:)

## Clock model

Define three concepts without changing shared types:

1. `sourceTime`: position in original decoded track.
2. `renderTime`: position in output audio frames after tempo/time scaling.
3. `musicalBeat`: beat/downbeat position supplied by Analysis.

For a constant tempo ratio `r = output_playback_speed / source_speed`:

`renderDuration = sourceDuration / r`

A source beat at source seconds `t` maps to render seconds `t / r`, plus the transport's current render origin. For a variable tempo map, use piecewise integration; do not multiply the full timeline by one global ratio.

The click scheduler receives the mapped output sample frame and schedules the click buffer to that frame on the common engine timeline.

## Smart metronome

### Required states
- `unavailable`: no trustworthy beat grid.
- `ready`: beat grid exists, click disabled.
- `playing`: scheduled against transport.
- `lowConfidence`: grid exists but Analysis confidence is below future threshold; UI may warn rather than pretend certainty.
- `resyncRequired`: seek/loop/tempo-map mutation invalidated future scheduled clicks.

### Scheduling rules

- Never trigger audio from a UI timer.
- Keep a rolling schedule-ahead window; exact size is implementation/measurement dependent.
- After seek, loop jump or material tempo change, cancel/replace only future click events and reschedule from the new authoritative render origin.
- Downbeat accents use the same timeline and differ only in click sample/gain.
- Click audio must be short, normalized and project-owned or rights-cleared. No third-party sample asset is required.
- If the beat grid cannot cover a region reliably, fail visibly or mute click for that region rather than free-running a guessed metronome.

## Count-in

Count-in is transport preparation, not a separate wall-clock countdown.

Selected behavior for implementation evaluation:
1. User requests play with count-in enabled.
2. Determine target source start position and nearest valid musical beat/downbeat context.
3. Create N pre-roll beats in musical time using the active tempo map.
4. Schedule count-in clicks on the render clock.
5. Schedule music start at the calculated sample time on the same clock.
6. If seek/tempo configuration changes before music starts, invalidate and reschedule the whole pre-roll atomically.

This prevents accumulated `Timer` jitter and removes a separate clock domain.

## Tempo/pitch interaction

- Tempo/speed change remaps beat timestamps into render time.
- Pitch/key shift must not move click timing.
- Click sample itself should normally bypass musical pitch shift; it may share master output gain but not the song's key-transposition DSP.
- If music time-stretch processing has algorithmic latency, compensate by measuring/rendering the effective music-path delay and aligning click scheduling to the audible music output, not merely the unprocessed input timeline.

## Seek/loop rules

For any seek or loop boundary:
- obtain new authoritative source position;
- discard future scheduled clicks from the old segment;
- map upcoming beats through the current tempo transformation;
- schedule new clicks with a new generation/token so stale completions cannot rearm the old schedule.

Loop stress must include at least 100 repeats of short and long loops with tempo change enabled. A successful loop cannot slowly accumulate click phase error.

## Measurement hooks required later

Capture from an offline/manual-render or audio tap where possible:
- expected beat sample frame;
- actual click onset sample frame;
- expected musical transient/beat reference where ground truth exists;
- DSP algorithm reported/measured latency;
- callback/render underrun count;
- reschedule generation id after seek/loop;
- output sample rate.

Apple documents offline manual rendering for `AVAudioEngine`; use it for deterministic regression before real-device output tests.

Source:
- https://developer.apple.com/documentation/AVFAudio/performing-offline-audio-processing

## Later real-track gates

The later implementation/QA task must meet all of these before proposing parity:

- 10-minute constant-tempo test: click onset absolute error median <= 1 ms and P99 <= 3 ms relative to the expected mapped beat grid.
- 100-loop stress: no monotonic phase drift; final-loop click error remains within the same 3 ms P99 envelope.
- seek stress at early/middle/late positions: no stale click from the previous schedule after the new audible position is established.
- tempo-change stress: mapped click grid follows the new rate with no accumulated phase drift.
- count-in: music first-frame/start marker error relative to intended beat <= 3 ms in deterministic rendered tests.
- render underruns/dropouts attributable to click scheduling: 0 in 30-minute stress.
- live-recording/tempo-drift cases: click follows the supplied beat grid; if beat-grid quality is bad, failure is attributed to Analysis rather than hidden by a free-running DSP clock.

These thresholds are engineering gates for the project and are not observations of the Reference app.

## Known unknowns

- Exact current Reference metronome/count-in settings and free entitlement remain dependent on `MOI-REF-001`/later Reference capture.
- Actual Apple TimePitch algorithmic latency on target iPhones is UNKNOWN until device measurement.
- Whether Reference intentionally smooths tempo-control changes is UNKNOWN.
- Whether count-in begins on nearest downbeat vs. another rule is UNKNOWN.

Do not guess these behaviors in implementation; keep the architecture capable of adopting the later verified behavior.
