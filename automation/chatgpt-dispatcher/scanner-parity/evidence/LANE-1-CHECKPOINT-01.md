# LANE-1 Product Lane Checkpoint 01

## Lane
- worker: `worker1`
- lane: `LANE-1-PRODUCT`
- branch: `scanner-parity/worker1-product-lane`
- baseline integration: `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`
- autonomous lane policy effective: `2026-08-23T16:35:00+09:00`

## Completed milestones
1. SwiftUI app shell and navigation/state machine
2. Video/photo input plus permission/failure recovery

## Implementation
- `scanner-parity/ProductFlow/**`
  - pure ProductFlow state/reducer
  - selectingInput -> ready -> processing -> review/export -> completed transitions
  - fail-closed empty input
  - cancellation/retry while preserving imported input
  - camera permission state independent from Photos/Files import
- `scanner-parity/AppShell/**`
  - reusable SwiftUI App scene and NavigationStack root
  - PhotosPicker for image/video input
  - Files importer for image/movie input
  - AVFoundation camera permission adapter
  - camera denial does not block Photos/Files path
  - video import uses Transferable FileRepresentation rather than loading the whole movie as Data
  - visible processing/review/export/failure states
  - retry and choose-different-input recovery actions

## Verification
Local Swift toolchain: `Swift 6.2.1`, Linux x86_64.

ProductFlow fixture:
- `scanner-parity/Tests/ProductFlow/ProductFlowStateTests.swift`
- result: `7/7 PASS`
- covers URL dedupe, empty-input fail-close, retry, review-before-export, camera-denial preservation, cancel/retry preservation.

AppShell source contract:
- `scanner-parity/Tests/AppShell/source_contract_test.py`
- result: `7/7 PASS`
- covers NavigationStack, photo+video picker, Files importer, permission recovery copy, video FileRepresentation, reducer-backed store, retry UI.

Package build:
- `swift build --package-path scanner-parity/ProductFlow` -> PASS
- `swift build --package-path scanner-parity/AppShell` -> PASS

Important limitation:
- Linux package build validates package graph and unguarded code only. SwiftUI/PhotosUI/AVFoundation implementations are conditionally excluded on Linux.
- Therefore this checkpoint does NOT claim iPhoneOS Apple SDK compile PASS. The lane milestone `Apple SDK compile fixture and major product-flow test` remains pending and will provide that evidence later.

## Scope audit
All new code is inside LANE-1 write scope:
- `scanner-parity/AppShell/**`
- `scanner-parity/ProductFlow/**`
- `scanner-parity/Tests/AppShell/**`
- `scanner-parity/Tests/ProductFlow/**`
- `automation/chatgpt-dispatcher/scanner-parity/evidence/LANE-1-*.md`

Shared Contract was not modified. No Golden Dataset decision was made.

## Next lane milestone
`integrated pipeline orchestration adapter`

Per AUTONOMOUS_LANES policy, no intermediate PR is opened. Only the final lane PR will target `scanner-parity/integration`.
