# S8 Adversarial QA Ledger

Updated: 2026-08-15
Branch: `scaniverse/s8-adversarial-qa`
Integration source: `feature/splat-native-ios-poc`

## Severity policy

- **Sev-1:** data loss, crash loop, privacy/security violation, unusable core scan flow, or release-blocking failure with no safe workaround.
- **Sev-2:** major functional failure, silent corruption, stalled core flow, or reliability defect that commonly forces a rescan/retry.
- **Sev-3:** polish, accessibility, performance, or edge-case defect that does not invalidate the core result.

S8 cannot clear the final gate while any Sev-1 or Sev-2 remains unresolved.

## Current findings

| ID | Severity | Area | Finding | Owner | State |
|---|---|---|---|---|---|
| #4148 | Sev-2 | interruption / tracking | interruption recovery resets AR tracking while retaining pre-interruption capture data, risking mixed coordinate frames | S1 | OPEN |
| #4149 | Sev-2 | low storage / filesystem | capture frame write failure could silently stall capture progress | S8 + S5 | FIX IMPLEMENTED; CI / device verification pending |

## Automated gates

| Gate | State | Evidence / requirement |
|---|---|---|
| Static product checks | PASS on previous S0 baseline; re-run pending latest S8 HEAD | `scripts/validate.sh` |
| Privacy manifest syntax / local-only declarations | PASS on previous S0 baseline; re-run pending latest S8 HEAD | `PrivacyInfo.xcprivacy` + `validate.sh` |
| License files bundled / pinned dependencies | PASS on previous S0 baseline; re-run pending latest S8 HEAD | `validate.sh` + generated Xcode project checks |
| iPhone Release compile without signing | PASS on previous S0 baseline; re-run pending latest S8 HEAD | GitHub Actions |
| msplat runtime XCTest | CI GAP FOUND and fixed in S8 | workflow now boots an available iPhone simulator and runs `xcodebuild ... test` instead of only `build-for-testing` |
| Capture storage-write failure regression gate | ADDED; run pending | `failCaptureStorage` + `validate.sh` |

## Adversarial matrix

| Scenario | Automated | Real-device | Current result | Next action |
|---|---:|---:|---|---|
| Camera permission denied | partial | required | pending | verify explicit recoverable failure on device |
| AR session failure | static callback gate | required | pending | inject / reproduce device failure where practical |
| Interruption during capture | no | required | **FAIL / #4148 Sev-2** | S1 fix, then S8 re-test |
| Background → foreground during capture | no | required | pending; overlaps interruption risk | re-test after #4148 fix |
| Background / lock during generation | no | required | pending | evaluate lifecycle / resume behavior after S5 persistence integration |
| Low / exhausted free storage during frame capture | static regression gate | required | code fix implemented | CI then device pressure test |
| Failure writing dataset metadata | code surfaces failure | required | partial | verify storage-full UX and idle-timer recovery |
| Offline operation | static local-only gate | optional | PASS for current PoC | re-audit when S7 network surfaces land |
| Corrupt saved project | not yet applicable | required later | blocked by S5 persistent library | add fixture tests when S5 storage format lands |
| Huge `.splat` output | no | required | pending | load / render stress fixture after S4 export path lands |
| Long scan / max-frame path | partial static | required | pending | device stress test |
| Memory pressure | no | required | pending | device stress test |
| Battery / thermal | no | required | pending | device matrix and long generation run |
| Viewer rapid rotate / zoom / reset | no | required | pending | UI stress test after S3 viewer parity lands |
| VoiceOver / accessibility labels | no | required | pending | accessibility audit after consumer UI stabilizes |
| Dynamic Type / text clipping | no | required | pending | accessibility audit after consumer UI stabilizes |
| Privacy / local processing claims | yes | review required before release | current local-only implementation consistent | re-audit S7 and App Store metadata together |
| TestFlight install / launch / real scan | no | required | HUMAN / APPLE GATE | execute only after integrated parity candidate exists |

## Release-blocking dependencies observed by S8

1. #4148 must be fixed and re-tested before S8 can report no unresolved Sev-2.
2. Latest S8 HEAD must pass the modified CI with the msplat XCTest actually executing.
3. S1-S7 integration must land before S8 can complete the full compatibility / corrupt-project / export / network / sharing matrix.
4. Final thermal, memory, interruption, permission, accessibility, and representative Scaniverse side-by-side checks require a real iPhone/TestFlight candidate.

## S8 handoff rule

For every new S0 integration wave:

1. fast-forward / merge the latest S0 state into S8,
2. re-run automated gates,
3. execute the matrix against newly integrated surfaces,
4. classify each failure Sev-1 / Sev-2 / Sev-3,
5. fix S8-owned cross-cutting defects directly,
6. route subsystem defects to S1-S7 with reproduction and acceptance criteria,
7. do not mark S8 complete until Sev-1 = 0 and Sev-2 = 0.
