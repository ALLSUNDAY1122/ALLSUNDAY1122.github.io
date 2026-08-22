# L4-M02 validation — BPM / beat / musical-key analysis

Date: 2026-08-22 JST
Lane: `LANE-4-IOS-ANALYSIS`
Frozen epoch contract SHA: `be1c84314db182d6eee5097de34e017af1a4a7de`
PARITY rows touched by evidence only: `MOI-P009`, `MOI-P011`
PARITY promotion: **none**

## Implemented surface

L4-M02 implements a project-owned, model-free baseline behind the frozen `MusicAnalyzing` contract:

- `AnalysisSignal` — mono PCM analysis input owned by Lane 4;
- `AnalysisSignalLoading` — dependency-injection seam for a later app-owned file loader, so Lane 4 does not copy IO code;
- `ProjectOwnedMusicAnalyzer` — returns the frozen `AnalysisSnapshot` with tempo/beat/key populated and later chord/section fields left for L4-M03/M04;
- `TempoBeatAnalyzer` — onset-envelope, autocorrelation/periodicity, tempo prior, half/double-tempo suppression, beat-phase alignment and confidence;
- `MusicalKeyAnalyzer` — Hann-windowed Goertzel pitch-class energy, 12-bin chroma, major/minor profile scoring and confidence/unknown handling;
- `AnalysisBenchmarkRunner` — AN-001-compatible core tempo/beat/key metrics and machine-readable rows;
- SwiftPM wiring and XCTest coverage.

No third-party MIR runtime/model is embedded. No `IO/**`, `Library/**`, `Playback/**`, `DSP/**` or `Separation/**` implementation was copied into the Lane-4 branch. `Shared/**`, `App/**`, Queue and `PARITY_MATRIX.json` were not edited.

## Algorithm decisions

### BPM / beat

The implementation follows the prior AN-001 project-owned baseline:

1. sanitize non-finite samples;
2. frame RMS/log-energy onset strength;
3. positive energy flux and low-level floor removal;
4. transientness gate to prevent sustained harmonic material from becoming a fake pulse train;
5. normalized onset autocorrelation across the configured 55–210 BPM range;
6. broad tempo prior centered near 120 BPM;
7. explicit faster-subdivision check to suppress half-tempo collapse when the doubled candidate is comparably supported;
8. local onset alignment around an inferred beat lattice;
9. confidence from periodicity correlation plus beat/onset alignment.

### Musical key

The implementation is a legally clean baseline with no pretrained weights:

1. silence/non-finite guards;
2. multiple uniformly distributed analysis windows;
3. Hann weighting;
4. project-owned Goertzel energy extraction over MIDI 36...83;
5. 12-bin pitch-class aggregation;
6. minimum active-pitch-class gate;
7. Krumhansl-style major/minor profile cosine scoring for 24 candidates;
8. best-vs-second score margin converted to confidence;
9. below-threshold material remains unknown (`nil`) instead of forcing a key.

The current baseline deliberately emits only `major` or `minor`. Modal/modulating material remains part of the later real-audio quality gate and must not be inferred as PARITY from these unit fixtures.

## Failure-driven corrections inside the Macro Bundle

Three concrete defects were exposed during implementation and corrected before acceptance:

1. **180 BPM collapsed to ~90 BPM.** Autocorrelation naturally favored a lower metrical level. A half-lag floor/ceil subdivision comparison now penalizes slower candidates when the faster pulse is comparably supported.
2. **Sustained C-major harmony produced a false BPM.** A transientness gate based on onset peakiness and high-onset-frame density now returns no tempo for a sustained chord while preserving C-major key detection.
3. **Beat timestamps were phase-shifted by roughly one analysis frame.** Onset timestamps are now anchored to the frame-end analysis position before local lattice alignment; the synthetic 70 ms beat F-score moved into the 0.918–0.958 range.

## Swift build/test evidence

Worker environment:

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
```

A local temporary SwiftPM harness was reconstructed from the frozen contract subset plus the exact current Lane-4 Analysis sources because the execution container cannot resolve github.com for a direct clone.

Final targeted L4-M02 regression:

```text
swift test --disable-sandbox
TempoKeyAnalysisTests: 6/6 PASS
0 failures, 0 unexpected
```

Coverage includes:

- 120 BPM + C major through the frozen `MusicAnalyzing` adapter;
- 90 BPM + A minor;
- 180 BPM half-tempo regression;
- silence, short audio, non-finite input;
- sustained-tonal false-tempo rejection;
- chromatic/ambiguous-key rejection;
- benchmark metric relationships;
- benchmark JSON and frozen `AnalysisSnapshot` Codable round-trip.

The prior L4-M01 canonical Worker regression was 21/21 PASS before these additive Analysis changes. The current Worker environment cannot perform a direct checkout of the full GitHub branch, so this evidence does **not** falsely claim a fresh canonical 27/27 checkout run. The new Analysis source itself compiled and its six new tests passed under Swift 6.2.1; HQ checkpoint integration should rerun the full canonical suite.

## Synthetic benchmark evidence

Machine-readable run:

- `Analysis/benchmarks/L4-M02_SYNTHETIC_BENCHMARK.json`
- fixture declaration: `Analysis/benchmarks/L4-M02_FIXTURE_MANIFEST.json`

All three fixtures are generated project-owned unit signals and have:

```text
synthetic_only = true
parity_eligible = false
peak_rss_mb = null
thermal = null
```

Observed sanity metrics from one Linux run:

| Fixture | Estimated BPM | tempo rel. error | Beat F @ 70 ms | median beat abs. error | Key | exact key |
|---|---:|---:|---:|---:|---|---:|
| 120 BPM / C major | 120.00 | 0.0000 | 0.9583 | 0.0060 s | C major | 1 |
| 90 BPM / A minor | 89.5522 | 0.00498 | 0.9444 | 0.00767 s | A minor | 1 |
| 180 BPM / C major | 181.8182 | 0.01010 | 0.9180 | 0.0060 s | C major | 1 |

Analysis wall time for these 10–12 second synthetic signals was approximately 0.084–0.087 s on this Linux execution host (RTF ~0.0070–0.0087). These timings are useful only as implementation sanity data; they are not iPhone performance evidence.

## Benchmark/evidence boundary

The AN-001 final gate still requires rights-cleared real audio across multiple genres and difficult cases. This bundle does not have that corpus. In particular the following remain unproven:

- live drums / tempo drift;
- weak or absent percussion;
- syncopation and meter ambiguity;
- octave/metrical-level behavior on real recordings;
- modal material and modulation/key changes;
- confidence calibration on real music;
- full AN-001 beat continuity/Cemgil metrics;
- iPhone wall time/RSS/thermal/battery;
- Moises differential behavior.

Therefore `MOI-P009` and `MOI-P011` remain **MISSING**. Synthetic accuracy must not be used as a PARITY promotion.

## Late Integration handoff

HQ should later:

1. inject an app-owned, rights-safe `AnalysisSignalLoading` implementation using the IO/Library result without moving IO code into Lane 4;
2. run the Project Golden MIR rights-cleared real-audio set;
3. collect exact/octave-aware BPM, 70 ms beat F plus continuity/Cemgil, exact/weighted key and confidence calibration;
4. record iPhone runtime/RSS/thermal/battery;
5. compare against current Moises on the same lawful fixture set;
6. keep P009/P011 MISSING until those gates support a higher state.
