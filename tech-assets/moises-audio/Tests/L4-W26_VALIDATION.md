# L4-W26 Validation — Physical Corpus Selection Integrity

Evidence class: **NON_PARITY**. No physical iPhone, current-Moises observation, production selection policy, or production performance threshold was used.

## Objective

Close the MOI-P021 easy-subset loophole between W22 corpus sufficiency and W23/W24/W25 physical performance evidence.

## Implemented

- `AnalysisDeviceCorpusSelectionModels.swift`
- `AnalysisDeviceCorpusSelection.swift`
- `AnalysisDeviceCorpusSelectionGate.swift`
- deterministic policy/report codecs
- fail-closed HQ policy template and operator runbook
- W24 runbook prerequisite integration

Two selection modes are supported:

1. `FULL_W22_ELIGIBLE_CORPUS`: all W22 eligible fixtures are mandatory and W22 global/domain/stratum minima are inherited.
2. `HQ_APPROVED_EXACT_SUBSET`: exact fixture IDs are preapproved and explicit global, all-five-domain, and every-W22-stratum minima are required. These minima may not weaken W22.

W26 also requires W24 fixture IDs/durations and W25 fixture/source-SHA/duration inventory to exactly match the selected canonical manifest fixtures. Downstream W25/W24 evaluation is not invoked unless W26 is ready.

## Negative / edge coverage

Portable adversarial harness: **20/20 assertions PASS in each of five clean runs**.

Covered failures include easy subset, weaker W22 floors, missing/duplicate domain or stratum requirements, unknown/duplicate selected fixtures, W24/W25 inventory mismatch, W25 source SHA mismatch, W24/W25 duration mismatch, manifest SHA swap, W22 not-ready state, ambiguous full-mode fields, and downstream-gate suppression.

Invalid W22 manifest/stratum inputs are indexed with safe first-wins maps so malformed duplicate IDs can fail closed rather than crash via `Dictionary(uniqueKeysWithValues:)` before diagnostics are produced.

## Source-shaped compilation

- Swift 6.2.1, strict concurrency source-shaped production typecheck: PASS.
- Durable `AnalysisDeviceCorpusSelectionTests.swift` parse: PASS.
- Canonical SwiftPM/Xcode XCTest remains an HQ integrated-checkout gate.

## Stress

50,000 fixtures, five Analysis domains per fixture, ten W22 strata, full-corpus binding, five clean processes:

- internal seconds: `0.597201`, `0.700763`, `0.718445`, `0.609265`, `0.618009`
- process wall seconds: `0.75`, `0.87`, `0.87`, `0.77`, `0.76`
- max RSS kB: `108740`, `108696`, `108740`, `108836`, `108756`
- all five reports: `PHYSICAL_SELECTION_READY_PENDING_HQ`, zero issues.

These numbers measure the portable W26 selection evaluator only. They are not iPhone Analysis performance evidence.

## PARITY boundary

MOI-P021 remains MISSING. `PHYSICAL_SELECTION_READY_PENDING_HQ` only establishes that the physical-performance fixture inventory is representative relative to the supplied HQ-approved W22 policy. It does not establish physical-device execution or acceptable device performance.

Remaining material gap after W26: W22/W26/W23/W25/W24 evidence files can still be replaced or assembled post-capture without a machine-enforced tamper-evident archive root. A subsequent wave should bind the required evidence artifact inventory and hashes into a deterministic archive manifest while avoiding unsupported claims of hardware attestation.
