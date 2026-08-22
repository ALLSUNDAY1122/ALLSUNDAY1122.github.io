# L4-M04 validation — song sections and Analysis checkpoint

Date: 2026-08-22 JST
Lane: `LANE-4-IOS-ANALYSIS`
Frozen epoch contract SHA: `be1c84314db182d6eee5097de34e017af1a4a7de`
PARITY rows touched by evidence only: `MOI-P009`, `MOI-P011`, `MOI-P013`, `MOI-P016`
PARITY promotion: **none**

## Implemented surface

L4-M04 completes the current Lane 4 analysis surface:

- `SongSectionAnalyzer`
  - section descriptors from chord-family distribution, RMS energy, zero-crossing rate and decided chord coverage;
  - novelty-based boundary candidates with local energy-change cues;
  - local-maximum filtering, minimum-duration rules and chord-boundary snapping;
  - repeated-structure clustering into deterministic `A`, `B`, `C`... labels;
  - conservative confidence calculation;
  - explicit whole-track `X` unknown when silence or insufficient chord evidence makes structure unjustified;
  - conservative optional `intro` / `outro`; `verse` / `chorus` only when two distinct repeated *interior* structural families exist; `bridge` only under a constrained repeated-neighbor pattern;
- `ProjectOwnedMusicAnalyzer`
  - now emits one frozen `AnalysisSnapshot` containing tempo/beat, key, chords and sections;
- `SectionBenchmarkEvaluator`
  - AN-001 boundary P/R/F at 0.5 s and 3.0 s;
  - median reference-to-estimate and estimate-to-reference boundary deviation;
  - structural pairwise P/R/F;
  - Adjusted Rand Index;
  - normalized conditional entropy in both directions;
  - structural decision coverage;
  - functional macro-F1 and coverage where a functional reference exists;
- `SongSectionAnalysisTests`
  - deterministic section boundaries/cluster repetition, unknown semantics, JSON ordering, evaluator strictness and combined snapshot path;
- `LANE4_LATE_INTEGRATION_HANDOFF.md`
  - exact App/Playback/IO integration seam and source-time clock semantics.

No other Lane implementation was copied into Lane 4. `Shared/**`, `App/**`, Queue and `PARITY_MATRIX.json` remain untouched.

## Failure-driven correction

The first functional-label pass incorrectly treated the low-energy intro/outro structural family as a second repeated musical family. On the deterministic fixture that allowed the repeated interior `B` family to be mislabeled `chorus`, despite there being no independent repeated `verse` family.

The algorithm was corrected so edge sections already explained as `intro`/`outro` are excluded from verse/chorus evidence. Two distinct repeated **interior** clusters are now required before either semantic label is assigned. On the fixture, the correct conservative result is:

```text
A intro  0-4
B nil    4-12
C nil    12-20
B nil    20-28
A outro  28-32
```

This is intentional: structural repetition is known, functional semantics are not.

## Portable execution evidence

Worker environment:

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
```

The execution container still cannot resolve `github.com`, so a fresh canonical checkout and complete `swift test` cannot be truthfully claimed. Targeted branch-equivalent portable harnesses were used for the newly implemented logic and HQ must rerun the full canonical suite at checkpoint.

Targeted song-section harness after the semantic-label fix:

```text
TOTAL 8 PASS
```

Validated behaviors:

1. 32 s structural fixture creates exactly five gap-free sections at 0/4/12/20/28/32 s;
2. the two 8 s repeated regions share one structural cluster;
3. the middle contrasting region uses a distinct cluster;
4. low-energy edge sections receive `intro`/`outro` while interior semantic labels remain nil when evidence is insufficient;
5. silence returns one whole-track `X` section with nil functional label/confidence;
6. audible material whose chord evidence is all `X` returns unknown rather than fabricated A/B structure;
7. structural timeline covers the exact source duration with no gaps/overlaps;
8. edge structural grouping does not leak into verse/chorus inference.

Independent combined-input sanity checks using the existing L4-M02 algorithms on the same 32 s fixture with 0.5 s click impulses produced:

```text
TempoBeatAnalyzer: 120.0 BPM, confidence approximately 0.978
MusicalKeyAnalyzer: tonic 0 / major, confidence approximately 0.023
```

The committed `SongSectionAnalysisTests.testCombinedProjectAnalyzerPopulatesTempoKeyChordsAndSections` additionally asserts the final frozen `MusicAnalyzing` path returns non-empty tempo, key, chord and section domains together. A fresh canonical checkout is still required for HQ to execute that committed XCTest with all current branch files in one package run.

## AN-001 evaluator sanity

The exact synthetic reference/estimate returns:

```text
boundary F@0.5s = 1.0
boundary F@3.0s = 1.0
reference->estimate median boundary error = 0
estimate->reference median boundary error = 0
pairwise P/R/F = 1.0 / 1.0 / 1.0
Adjusted Rand Index = 1.0
normalized conditional entropy = 0 / 0
structural coverage = 1.0
functional macro-F1 = 1.0
```

A deliberately +1 s shifted estimate is exposed rather than hidden:

```text
boundary F@0.5s = 0.0
boundary F@3.0s = 1.0
bidirectional median boundary error = 1.0s
```

A whole-track `X` estimate drives structural coverage to 0 and degrades clustering metrics rather than being treated as a favorable abstention.

## Synthetic benchmark

Machine-readable evidence:

`Analysis/benchmarks/L4-M04_SYNTHETIC_SECTION_BENCHMARK.json`

Portable optimized section run, seven-process median:

```text
wall_seconds_median = 0.01690832100030093
RTF = 0.0005283850312594041
```

The fixture is `synthetic_only=true` / `parity_eligible=false`. `peak_rss_mb`, thermal and battery remain `null` because they were not measured.

## Lane checkpoint summary

The four v3 macro bundles now provide:

- L4-M01: standalone iOS/XcodeGen host, fail-closed cross-Lane DI/module slots and platform smoke boundary;
- L4-M02: project-owned BPM/beat and major/minor key baseline with confidence/unknown and benchmark rows;
- L4-M03: playback-clock-friendly major/minor/N/X chord timeline and chord evaluator;
- L4-M04: structural sections, conservative functional labeling, section evaluator, combined Analysis snapshot and Late Integration handoff.

This is a coherent Lane checkpoint. It is not product completion.

## Remaining gates / known gaps

Before any Lane 4 PARITY row can move from `MISSING`, HQ still needs:

- a rights-cleared multi-genre Project Golden MIR real-audio corpus;
- tempo octave errors / live drift / syncopation / weak percussion / meter ambiguity;
- modal and modulating key cases;
- current-Moises-supported complex chord vocabulary and real-audio boundary quality;
- varied song structures including pre-chorus, breakdown, solo, nonstandard order and long/quiet introductions;
- full AN-001 metrics on real audio;
- actual Xcode/iOS compilation and physical-iPhone wall time/RSS/thermal/battery/long-track evidence;
- chord/section timeline synchronization against real Playback at normal and changed speed;
- current Moises differential comparison;
- fresh canonical full SwiftPM regression after semantic Late Integration.

## PARITY statement

`MOI-P009`, `MOI-P011`, `MOI-P013` and `MOI-P016` remain `MISSING`. Synthetic/test/compile evidence in this Lane does not promote PARITY.
