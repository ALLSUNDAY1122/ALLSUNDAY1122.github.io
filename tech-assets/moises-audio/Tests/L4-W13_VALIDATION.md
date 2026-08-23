# L4-W13 Validation — Song Section cooperative cancellation / worst-case complexity hardening

## Scope

Worker 4 only. This wave changes Lane-4 Analysis and tests. Shared/App/PARITY/Queue/Lane Plan/Resource Locks remain untouched.

## Production changes

- Added `SectionChordTimelineIndex`:
  - sorted validated chord intervals,
  - prefix-max-end lower bound for overlap discovery,
  - binary-search nearest chord boundary.
- Added `SongSectionComplexityBudget`:
  - maximum 16,384 section boundary candidates,
  - maximum 64 structural prototypes,
  - maximum 8,000 signal probes per descriptor.
- Added `CancellableSongSectionPipeline` and routed `ProjectOwnedMusicAnalyzer` through it.
- Cancellation checks are performed during:
  - context scanning,
  - descriptor signal/chord loops,
  - candidate selection/filtering,
  - section descriptor creation,
  - false-boundary suppression,
  - structural clustering/scoring,
  - verse/chorus/pre-chorus/bridge functional labeling.
- Prototype overflow fails closed to structural `X`; it does not force a low-similarity section into an existing family.

## Complexity hardening

The previous section descriptor and boundary-snap paths repeatedly scanned the complete chord list. On long timelines, candidate-count × chord-count work could grow quadratically.

For a deterministic 1-hour planning case with 14,400 chord events and 1-second configured section hop:

- boundary candidates: 3,600
- legacy naive chord-visit upper bound: 311,054,400
- indexed nominal chord-visit upper bound: 129,600
- nominal visit reduction ratio: ~2,400.11x

The indexed value is a planning model for the hardened product chord timeline, not a physical-device CPU measurement.

For an extreme 24-hour duration, the effective scan hop is increased to ~5.2734 seconds so the candidate array remains capped at 16,384 rather than growing without bound.

## Portable executable validation

Swift 6.2.1 / x86_64-unknown-linux-gnu production-source-shaped harness:

- 5 complete runs
- 8/8 assertions PASS on every run
- wall time: 0.02 s on each run
- max RSS: 24,524 / 24,592 / 24,524 / 24,492 / 24,456 kB
- observed section-cancellation latency:
  - 0.255 ms
  - 0.377 ms
  - 0.313 ms
  - 0.302 ms
  - 0.473 ms
- worst observed: ~0.473 ms

The cancellation timing is Linux scheduler evidence only. It is not an iPhone latency guarantee.

## W09 regression preservation

The W13 cancellable hardener preserves the prior varied-structure fixture semantics:

`intro -> verse -> pre-chorus -> chorus -> verse -> pre-chorus -> chorus -> bridge -> chorus -> outro`

Also verified:

- repeated structural family reuse,
- ABA canonical family reuse,
- local undecided chord evidence remains `X` with no functional label/confidence,
- bounded cluster stress completes without unbounded prototype growth.

`SongSectionCancellationComplexityTests.swift` typechecks against an `-enable-testing` portable `MoisesAudioCore`-shaped module exposing the exact W13 APIs: PASS.

## PARITY status

**NON_PARITY.** This wave improves cancellation safety and long-track computational behavior only.

It does not satisfy MOI-P016 or MOI-P021 because the following remain HQ Late Integration gates:

- rights-cleared varied-structure real audio,
- current-iPhone Moises section boundary / functional-label differential,
- section navigation and loop integration,
- physical-iPhone cancellation responsiveness,
- physical-iPhone memory pressure / peak RSS / thermal / battery evidence.

Synthetic/portable tests and complexity models must not promote PARITY.
