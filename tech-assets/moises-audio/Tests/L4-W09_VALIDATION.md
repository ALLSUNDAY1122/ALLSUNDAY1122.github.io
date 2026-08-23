# L4-W09 Validation — Song Section Varied-Structure / Functional-Label Hardening

Date: 2026-08-23 JST

## Scope

Lane 4 only. No `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Global Queue, work-package, lane-plan, resource-lock, or other-Lane code changed.

Goal: harden MOI-P016 preparation beyond the L4-M04 baseline so varied song structures are represented conservatively and repeatably without treating synthetic evidence as PARITY.

## Production changes

- Added `Analysis/SongSectionHardener.swift` as a post-detection hardening stage.
- Wired `ProjectOwnedMusicAnalyzer` to route section results through the hardener.
- Added local low-chord-coverage handling: a locally undecided segment fails closed to structural `X`, nil functional label, and nil confidence instead of inheriting an invented section family.
- Added adjacent false-boundary suppression when both neighboring descriptors have sufficient decided evidence, very high structural similarity, and low novelty.
- Re-clusters surviving segments into canonical first-seen structural families (`A`, `B`, `C`, ...), enabling deterministic repeated-family and A/B/A reuse behavior.
- Adds conservative functional semantics for `intro`, `verse`, `pre-chorus`, `chorus`, `bridge`, and `outro`.
- `pre-chorus` requires a repeated family that precedes the inferred chorus on at least two occurrences.
- `bridge` requires a unique, bounded interior family located between established chorus occurrences, with a conservative fallback only for a unique segment between repeated matching neighbors.
- Verse/chorus labels are withheld when repeated-family energy separation is too weak, preserving structural labels while leaving functional semantics unknown.
- Added machine-readable diagnostics for section count, unknown-duration ratio, functional-decision ratio, and duration-weighted mean confidence.

## Edge / negative / recovery behavior

- Empty or unusable section input returns explicit whole-track `X` rather than an invented functional section.
- Zero/empty signal returns no section result.
- Section coordinates are clamped to the source duration and zero-length segments are removed.
- Local undecided chord coverage does not contaminate repeated-family clustering.
- Adjacent near-duplicates are merged before structural family assignment, reducing transient false boundaries.
- Ambiguous repeated A/B families with near-equal energy retain structural reuse but do not receive invented verse/chorus semantics.
- Confidence remains nil on local unknown regions.

## Portable executable validation

Environment: Swift 6.2.1, `x86_64-unknown-linux-gnu`.

The exact production `SongSectionHardener.swift` was compiled and executed against frozen-contract-shaped stubs for `AnalysisSignal`, `ChordEvent`, `SongSection`, `MusicAnalysisConfiguration`, and `SongSectionAnalyzer`.

Result: **6/6 adversarial groups PASS; 18/18 assertions PASS**.

Validated groups:

1. varied functional structure: intro → verse → pre-chorus → chorus → verse → pre-chorus → chorus → bridge → chorus → outro
2. A/B/A structural family reuse
3. false-boundary suppression for two adjacent near-duplicate fragments
4. localized undecided region fails closed to `X`
5. ambiguous repeated families do not invent verse/chorus
6. diagnostic unknown/function decision coverage

Five executable runs completed with wall times `0.01, 0.00, 0.01, 0.01, 0.00` seconds. This is portable Linux functional evidence only, not an iPhone performance benchmark.

Committed XCTest coverage: `Tests/MoisesAudioCoreTests/SongSectionHardeningTests.swift` adds deterministic regression coverage for the same W09 behaviors.

Machine-readable evidence: `Analysis/benchmarks/L4-W09_SECTION_STRUCTURE_ADVERSARIAL.json`.

## Evidence classification

**NON_PARITY**.

All W09 adversarial fixtures are project-generated synthetic material. They prove deterministic behavior of the hardening logic but cannot satisfy MOI-P016 by themselves.

## Remaining MOI-P016 Late Integration gates

- rights-cleared real audio spanning varied structures and genres
- current-iPhone Moises differential capture for section boundaries and exposed functional labels
- real-song false-boundary and missed-boundary measurement
- section-driven navigation / looping UX validation after HQ cross-Lane integration
- physical-iPhone latency, long-track stability, and UI synchronization evidence
- HQ final `PARITY_MATRIX.json` judgment

W09 does not promote MOI-P016 from `MISSING`.
