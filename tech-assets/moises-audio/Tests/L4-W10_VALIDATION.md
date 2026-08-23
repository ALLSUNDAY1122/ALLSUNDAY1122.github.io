# L4-W10 Validation — Combined Analysis confidence / cross-feature robustness

Date: 2026-08-23 JST

## Scope

Lane 4 only. No `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Queue, work-package, lane-plan, resource-lock, or other Worker Lane file was changed.

Goal: make the combined Analysis product boundary fail closed when otherwise independent BPM/beat/key/chord/section analyzers produce malformed, internally contradictory, low-evidence, or non-serializable product state.

## Production changes

- Added `Analysis/AnalysisSnapshotRobustness.swift`.
- Added `Analysis/AnalysisSnapshotHealthBenchmark.swift`.
- `ProjectOwnedMusicAnalyzer` now sanitizes the loaded signal before analysis and hardens the combined `AnalysisSnapshot` before returning it.
- Added both new production sources to `Package.swift`.

### Signal recovery

- Clean audio returns through the sanitizer without allocating a rewritten sample buffer.
- `NaN`, `+infinity`, and `-infinity` samples are replaced with zero.
- Pathological but finite amplitudes are bounded to `+/-16` to prevent one corrupt sample from dominating downstream energy/chroma calculations.

### Tempo / beat integrity

- BPM must be finite and remain inside the configured product tempo range.
- confidence must be finite, inside `0...1`, and satisfy the configured minimum.
- beat timestamps are clipped to the source duration, sorted, and deduplicated.
- fewer than two usable beats fails closed to no tempo decision.
- median beat-derived BPM must agree with emitted BPM within 12%; contradictory tempo/beat output fails closed rather than exposing inconsistent UI state.

### Key integrity

- product snapshot only accepts the currently verified-safe `major` / `minor` modes.
- unsupported/modal mode labels are dropped at the product boundary.
- invalid or sub-threshold confidence fails closed.
- this does not remove the internal modal-detection work; it prevents unverified vocabulary from escaping as product truth.

### Chord timeline integrity

- non-finite/zero-duration events are discarded.
- events are clipped and ordered against source duration.
- gaps become explicit `X` intervals.
- overlaps are trimmed into a single non-overlapping product timeline.
- product labels are restricted to major/minor roots plus `N` / `X`; unsupported complex labels become `X` rather than a false simple chord.
- invalid confidence becomes unknown.

### Section cross-feature integrity

- section intervals are clipped, sorted, gap-filled, and overlap-normalized.
- invalid functional vocabulary is removed.
- functional labels require the configured minimum confidence.
- if decided chord coverage is below `minimumSectionChordCoverage`, the section result becomes one full-duration `X` section with no functional semantic. This prevents a structurally confident-looking chorus/verse output when its principal harmonic evidence is unknown.

### Deterministic persistence / benchmark diagnostics

- canonical snapshot JSON uses sorted keys and is byte-identical for identical hardened values.
- `AnalysisSnapshotHealthBenchmark` emits durable health metrics using the existing Analysis benchmark schema.
- metrics include beat monotonicity, chord/section coverage, unknown fractions, gap/overlap seconds, functional coverage, invalid-confidence count, canonical encode success, and canonical byte count.
- the health row explicitly carries `INTEGRITY_METRICS_NOT_MIR_ACCURACY_EVIDENCE`.

## Portable executable validation

Environment: Swift 6.2.1, `x86_64-unknown-linux-gnu`.

Production guard behavior compiled against frozen-contract-shaped stubs and executed: **PASS**.

- 15 / 15 executable assertions PASS.
- non-finite sanitization PASS.
- extreme finite clamp PASS.
- contradictory tempo/beat fail-closed PASS.
- modal key fail-closed PASS.
- valid 120 BPM + C major preservation PASS.
- chord gap/overlap/unsupported-vocabulary normalization PASS.
- low chord-evidence section suppression PASS.
- supported/confident functional-section filtering PASS.
- canonical JSON determinism PASS.
- gap/overlap/confidence health diagnostics PASS.

Five harness wall-time runs: `0.02, 0.01, 0.01, 0.01, 0.02` seconds.

8,000,000-sample clean-signal sanitizer scans: `0.0053, 0.0053, 0.0050, 0.0049, 0.0049` seconds. This is Linux portable guard cost only, not a full MIR or iPhone performance benchmark.

Committed XCTest source typechecks against an `-enable-testing` portable MoisesAudioCore-shaped module: **PASS**.

Snapshot-health benchmark portable execution: **PASS**. Synthetic fixture correctly reports `parityEligible = false` and retains the explicit non-accuracy limitation.

Machine-readable evidence:

- `Analysis/benchmarks/L4-W10_COMBINED_ANALYSIS_ROBUSTNESS.json`

## Evidence classification

**NON_PARITY**.

This Wave hardens correctness and evidence integrity. It does not demonstrate music-analysis accuracy against real recordings and does not promote any PARITY row.

## Remaining HQ Late Integration gates

`MOI-P009`, `MOI-P011`, `MOI-P013`, and `MOI-P016` remain `MISSING` until their respective rights-cleared real-audio benchmarks, current-iPhone Moises differential evidence, and physical-iPhone validation are complete.

Additionally pending:

- canonical integrated `swift test`
- Xcode/iOS build with all four Lanes
- device memory/thermal/runtime evidence
- Moises-vs-project differential
- HQ final `PARITY_MATRIX` judgment
