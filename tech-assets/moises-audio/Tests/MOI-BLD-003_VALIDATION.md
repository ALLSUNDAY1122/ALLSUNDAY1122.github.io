# MOI-BLD-003 — SwiftPM Library contract integration validation

Captured: 2026-08-22 15:26 JST
Owner: Moises-Worker-4
Work branch: `moises/wp4-analysis-platform`

## Scope

- Include HQ-owned `Shared/LibraryContracts.swift` in the explicit `MoisesAudioCore` SwiftPM source list.
- Keep the existing 13 XCTest cases green.
- Add four library-contract regression tests.
- Do not edit Shared/App/PARITY.

## HQ blocker resolution

The earlier exact contract integration exposed that `PersistedProjectSnapshot: Hashable` stores `ProcessingSnapshot?` while `ProcessingSnapshot` was not Hashable. HQ fixed the Shared contract at `facd51a2724a68a5e1cdedbf2ace5e88a28711fc` by adding Hashable conformance to `ProcessingSnapshot`.

Canonical re-read at task resume confirmed:

`public struct ProcessingSnapshot: Equatable, Hashable, Codable, Sendable`

## Worker branch changes

- `Package.swift`: adds `Shared/LibraryContracts.swift` to target sources.
- `Tests/MoisesAudioCoreTests/LibraryContractTests.swift`: four tests covering:
  1. `ProjectUserEdits` Codable round-trip including stem mix/practice state.
  2. `PersistedProjectSnapshot` Codable round-trip including processing and stem artifacts.
  3. `SetlistSnapshot` deterministic position ordering.
  4. `ProcessingRecoveryPlan` Codable round-trip with associated values.

## Test evidence

Environment: Swift 6.2.1, `x86_64-unknown-linux-gnu`.

Command: `swift test --disable-sandbox`

Result:

- Existing `SeparationQualityTests`: 8 passed.
- Existing `DomainContractCoordinatorTests`: 5 passed.
- New `LibraryContractTests`: 4 passed.
- Total: **17 tests, 0 failures, 0 unexpected**.

The local harness was reconstructed from the current GitHub canonical source text plus the Worker branch Package/test changes. Comments/formatting in the temporary local copy are not product artifacts and do not affect the compiled contracts or test behavior.

## Boundaries

- No `Shared/**` or `App/**` changes by Worker 4.
- No PARITY promotion. This task validates build/contracts only.
- iOS/AVFoundation/AVFAudio compile and simulator/device evidence belong to `MOI-BLD-IOS-001`.
