# L4-W20 Validation — Raw current-Moises observation derivation

Evidence class: **NON_PARITY_PORTABLE_SYNTHETIC**.

## Objective

Remove trust in manually transcribed current-iPhone Moises Analysis quality metrics. Raw observations are now the input; canonical Worker-owned scoring derives the quality metrics before W19 repeatability/provenance and W18 Project-vs-Reference comparison.

## Implemented

- `AnalysisReferenceRawObservationSet` binds raw observations to the W19 capture-set ID and exact Golden manifest ID/SHA-256.
- Exact observation identity is `runID + fixtureID + domain`.
- `OBSERVED`, `NO_DECISION`, `UNSUPPORTED`, and `UNSCORABLE` are explicit states.
- Unsupported/unscorable observations fail closed rather than being converted to artificial zero scores.
- Raw observations must reference evidence artifacts already bound to the corresponding W19 row.
- W19 row metadata is checked against the canonical Golden manifest.
- Tempo, beat, key, chord, and structure metrics are recomputed from raw observations and canonical annotations.
- Beat/chord/structure use existing evaluator cardinality gates before scoring.
- Invalid/overlapping raw timelines are rejected before normalization can hide them.
- Derived metric key sets must exactly equal the W19 declared key sets.
- Declared and derived metric values must agree within a fixed `1e-9` relative numeric-identity tolerance. This is serialization/math identity only, not a quality threshold.
- Only a clean derivation emits a derived W19 capture set.
- `validateAndCompileReference(...)` enforces W20 -> W19 -> audited Reference in one path before W18 can consume the Reference report.
- Raw/derivation/compilation JSON codecs use deterministic sorted-key ISO-8601 encoding.

## Durable XCTest coverage

`Tests/MoisesAudioCoreTests/AnalysisReferenceRawObservationTests.swift` covers:

1. exact tempo raw recomputation;
2. wrong declared metric rejection;
3. omitted `decision_emitted` metric-set rejection;
4. legitimate tempo `NO_DECISION` -> `decision_emitted=0`;
5. unsupported/unscorable fail-closed behavior;
6. missing and unexpected raw-row detection;
7. artifact and manifest binding;
8. domain/payload exclusivity;
9. exact beat timeline canonical scoring;
10. exact key canonical scoring;
11. overlapping chord rejection before evaluator normalization;
12. deterministic raw codec round-trip;
13. two-run raw-derived tempo -> W19 validation -> audited Reference compilation.

Canonical SwiftPM/Xcode XCTest execution remains an HQ integrated-checkout gate.

## Portable Swift 6.2.1 validation

Production-source-shaped typecheck: **PASS**.

Optimized harness, five clean runs:

- run 1: `13/13 PASS`, 50,000 rows, internal 0.274485 s, wall 0.30 s, RSS 123372 kB
- run 2: `13/13 PASS`, internal 0.468851 s, wall 0.49 s, RSS 123304 kB
- run 3: `13/13 PASS`, internal 0.289327 s, wall 0.31 s, RSS 123360 kB
- run 4: `13/13 PASS`, internal 0.274780 s, wall 0.30 s, RSS 123164 kB
- run 5: `13/13 PASS`, internal 0.456634 s, wall 0.49 s, RSS 123320 kB

The portable harness exercised valid raw tempo derivation, declared-value mismatch, missing row, unsupported observation, true no-decision, evidence binding, manifest-hash binding, duplicate raw keys, unexpected rows, payload mismatch, codec round-trip, and 50,000-row exact derivation.

## PARITY boundary

No real current-iPhone Moises observation, rights-cleared production track, Project physical-iPhone run, or approved differential tolerance was used in W20. Therefore W20 does not change MOI-P009/P011/P013/P016/P021 and does not establish PARITY.

HQ Late Integration still owns actual Reference capture, exact artifact/manifest retention, production tolerance approval, device evidence, W18 differential execution, and `PARITY_MATRIX.json` judgment.
