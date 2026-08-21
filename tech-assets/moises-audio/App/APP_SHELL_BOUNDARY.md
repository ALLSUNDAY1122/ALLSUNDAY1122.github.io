# App Shell Boundary — Integration Epoch 1

Owner: HQ (`app-shell`).

## App shell responsibility

App shell is the only composition root. It wires feature contracts and owns navigation/lifecycle presentation, but does not implement audio algorithms.

Required vertical flow:

`Import -> Project/Processing -> Mixer/Player -> Practice/Analysis -> Library/Export`

The exact screen hierarchy and reference-equivalent interaction details remain subject to MOI-REF-001 evidence. This file fixes ownership, not unverified Moises UI details.

## Composition rules

- IO supplies a normalized imported audio asset.
- Separation turns that asset into stem artifacts and processing state.
- Playback consumes stem artifacts and exposes transport/mixer state.
- Analysis produces BPM/key/chord/section facts.
- DSP consumes explicit timing/music facts plus playback clock to provide practice transforms/click/count-in.
- Library persists project/setlist/resume records and durable artifact references.
- IO exports/shareable artifacts from explicit project/mix inputs.
- App observes/co-ordinates those modules through Shared contracts.

## State ownership

App may own:
- current route/sheet/alert
- selected project identity
- app lifecycle coordination
- entitlement presentation state
- dependency container/composition

App must not become the source of truth for:
- audio transport position or mixer levels
- separation inference/progress internals
- BPM/key/chord/section algorithms/results caches
- DSP render internals
- project persistence records
- imported/exported file lifetime internals

## Failure and recovery rule

Each feature exposes deterministic domain failure to App. App chooses user-facing recovery actions (retry/cancel/back/open project), while feature modules own the underlying cleanup/retry semantics.

## Reference restraint

Until MOI-REF-001 is integrated, screen names, navigation depth, paywall placement, operation counts, and current iOS feature availability must not be invented as Moises-equivalent facts.
