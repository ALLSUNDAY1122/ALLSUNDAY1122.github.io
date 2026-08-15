# S8 Adversarial QA Ledger

Updated: 2026-08-15 11:13 JST
Branch: `scaniverse/s8-adversarial-qa`
Integration source: `feature/splat-native-ios-poc`

## Severity policy

- **Sev-1:** data loss, crash loop, privacy/security violation, unusable core scan flow, or release-blocking failure with no safe workaround.
- **Sev-2:** major functional failure, silent corruption, stalled core flow, invalid quality evidence, or reliability defect that commonly forces a rescan/retry.
- **Sev-3:** polish, accessibility, performance diagnostics, or edge-case defect that does not by itself invalidate the core result.

S8 cannot clear the final gate while any Sev-1 or Sev-2 remains unresolved.

## Current findings

| ID | Severity | Area | Finding | Owner | State |
|---|---|---|---|---|---|
| #4148 | Sev-2 | interruption / tracking | pre/post interruption poses could enter different AR world coordinates | S1 | SOFTWARE + CI PASS; real-device interruption re-test pending |
| #4149 | Sev-2 | low storage / filesystem | specialist capture branches can remain in capture mode or silently return after frame-write failure | S1/S2/S4/S5 + S8 integration | S8 fix PASS; sibling paths still OPEN |
| #4151 | Sev-2 | project recovery | active S5 trainer is not yet wired through durable two-phase Splat commit; aligned partial-output regression missing | S5 | OPEN |
| #4152 | Sev-2 | viewer / video memory | S3 viewer and S6 video export `readAll()` the full scene without a safe size / point-count budget or LOD path | S3/S6 | OPEN |
| #4153 | Sev-2 | mesh lifecycle / storage | S4 discard/reset can leave unreachable photo-heavy `.meshproject` directories | S4/S5 | OPEN |
| #4157 | Sev-2 | reconstruction memory | S2 can densify toward a 30k optimizer horizon without a memory-pressure or Gaussian-count budget | S2 | OPEN |
| #4159 | Sev-2 | viewer integration / build | S3 made `SplatViewerState` mandatory but legacy `RootScanView` still calls `SplatViewer(url:)`, leaving the app target red | S3 | OPEN |
| #4161 | Sev-2 | TestFlight release integrity | stale TestFlight branch was not mechanically required to contain current S0 | S8/S0 | FAIL-CLOSED FIX VERIFIED; keep OPEN until post-integration sync turns ancestry gate green |
| #4160 | Sev-3 | CI diagnostics | pre-device xcodebuild failures can stop before compiler diagnostics are retained/published | S8 / shared CI | OPEN |

No Sev-1 was found in this audit wave.

## Sibling branch gate snapshot

| Lane | Current evidence | S8 decision |
|---|---|---|
| S0 | integration HEAD remains `5b9e003d546dad0d68b6d4aff1fa4f34d69f3ecb`; sibling work not integrated | baseline only |
| S1 | HEAD `c50b01b9d6cb0982751b4a145173af7388cee5d5`; latest build #251 PASS | code/CI clear for #4148, device gate remains; #4149 remains |
| S2 | PR #4155 HEAD `702ba2da848e716aaef1efcdaaec80d2d2555ce5`; latest CI PASS | PARTIAL; blocked by #4157 + device quality/thermal/memory evidence |
| S3 | HEAD `b5626aa49cba508546acf7e4b1f4d42def9e5c7e`; latest S3 viewer gate FAIL at Simulator app build | BLOCKED; #4159 concrete app integration mismatch + #4152 memory blocker |
| S4 | PR #4156 HEAD `9d8906e82c1dbc26c054cb0050e12f6a832d52fe`; anti-placeholder + unsigned device build PASS | PARTIAL; #4149/#4153 remain |
| S5 | HEAD `45034bd445d3f811e64025cbe0991c31a7ba1dfe`; latest observed CI PASS | PARTIAL; #4149/#4151 remain |
| S6 | PR #4154 HEAD `b3d2677a1b0f91013ee12a289874e239e3a1d83f`; latest test-bundle build FAIL, later runtime/device steps skipped | BLOCKED; #4152 remains; #4160 prevents useful retained failure detail |
| S7 | identical to S0, ahead 0 | functional MISSING; no S8 defect classification yet |
| S8 | HEAD `2eec95031bd31cc50923b722c252f6ff539a8118` before this ledger-only update | full automated baseline PASS on workflow #254 / run `31858032455` |
| TestFlight release branch | `testflight/splat-native-ios` is still stale versus S0; S8 added ancestry enforcement | intentionally BLOCKED until synced after S0 integration (#4161) |

A historical green run does not clear a newer red HEAD.

## Automated S8 gates

| Gate | State | Evidence / requirement |
|---|---|---|
| Static product checks | PASS | `scripts/validate.sh` on S8 HEAD |
| Privacy manifest syntax / current local-only declarations | PASS for pre-S7 implementation | `PrivacyInfo.xcprivacy` + `validate.sh`; must be redesigned when S7 networking/data collection lands |
| License files bundled / pinned dependencies | PASS | `validate.sh` + generated Xcode project checks |
| iPhone Release compile without signing | PASS | S8 workflow #254 |
| msplat runtime XCTest | PASS | S8 workflow #254 boots an iPhone Simulator and executes `xcodebuild ... test`; compile-only gap removed |
| Capture storage-write failure regression gate | PASS on S8 implementation | `failCaptureStorage` + `validate.sh`; integration must not regress when sibling ScanModel changes land |
| VoiceOver labels / progress values added by S8 | static implementation present | real VoiceOver audit still required on integrated candidate |
| TestFlight current-S0 ancestry | PASS as fail-closed behavior | stale branch is intentionally rejected by `Refuse stale TestFlight source`; post-integration green proof still required |
| Apple upload Xcode/SDK version | runtime guard added on TestFlight Codemagic | require Xcode major >=26 and iOS SDK major >=26 before signed IPA build |

## Current Apple release requirements verified by S8

Verified against Apple Developer documentation on 2026-08-15:

- App Store Connect uploads for iOS require Xcode 26 or later and the iOS 26 SDK or later as of 2026-04-28. TestFlight Codemagic now fails if it resolves below those major versions.
- Age Rating is required app information. The final App Store human-release checklist must include the current App Store Connect age-rating questionnaire; this is not an Internal TestFlight blocker.
- `submit_to_app_store: false` remains mandatory during parity work. Internal TestFlight is a quality-comparison distribution path, not a release approval.

## Adversarial matrix

| Scenario | Automated | Real-device | Current result | Next action |
|---|---:|---:|---|---|
| Camera permission denied | partial | required | pending | verify explicit recoverable failure on integrated device build |
| AR session failure | static callback gate | required | pending | inject / reproduce device failure where practical |
| Interruption during capture | S1 software + CI | required | software path fixed / #4148 | real-device interruption re-test; close only after same-coordinate continuation is proven |
| Background → foreground during capture | S1 recovery path | required | software path improved | test lock/background/foreground after integration |
| Background / lock during generation | partial via S2 checkpoints + S5 recovery | required | pending | integrate S2/S5 then kill/suspend/relaunch stress |
| Low / exhausted free storage during frame capture | S8 regression gate | required | S8 fix PASS; sibling regressions #4149 | preserve hard failure during integration, then fill-storage device test |
| Failure writing dataset metadata | code surfaces some failures | required | partial | verify storage-full UX and idle-timer recovery across S1/S2/S4/S5 |
| Offline operation | static local-only gate | optional pre-S7 | PASS for current PoC | re-audit per-feature offline behavior when S7 network surfaces land |
| Corrupt saved project / manifest | S5 backup tests | required later | improved but PARTIAL | add S8 corruption fixtures after S5 integration; include truncated output (#4151) |
| Huge `.splat` viewer load | none | required | **FAIL / #4152** | bounded/LOD loading before device stress |
| Huge `.splat` video export | none | required | **FAIL / #4152** | preflight/bounded loading before encoder allocation |
| Dense 3DGS training / Enhance | thermal tests only | required | **FAIL / #4157** | memory/Gaussian budget + checkpointed memory-pressure pause |
| Long scan / max-frame path | partial static | required | pending | integrated device stress test |
| Battery / thermal | S2 serious/critical thermal pause | required | partial | long generation runs and restart validation |
| Mesh discard/retry storage | none | required | **FAIL / #4153** | integrate Mesh project lifecycle with S5 trash/cleanup semantics |
| Viewer app integration | S3 CI | no | **FAIL / #4159** | restore stateful RootScanView integration and green app build |
| Viewer rapid rotate / zoom / edit / reset | S3 unit intent; current CI red | required | pending | recover S3 CI, then UI stress |
| VoiceOver / accessibility labels | partial static | required | pending | accessibility audit after consumer UI stabilizes |
| Dynamic Type / text clipping | no | required | pending | accessibility audit after integrated UI stabilizes |
| Privacy / data collection claims | current local-only static gate | review required before release | valid only before S7 | S7 must introduce an explicit data inventory, consent/upload semantics and matching Privacy/App Store disclosures |
| TestFlight source freshness | TestFlight preflight ancestry check | no | **FAIL-CLOSED / #4161** | synchronize release branch only after S0 creates an integrated candidate, then require green preflight |
| TestFlight install / launch / real scan | no | required | HUMAN / APPLE GATE NOT YET REACHED | execute only after software blockers and red CIs are cleared and S0 integrates a candidate |

## Release-blocking dependencies observed by S8

1. Resolve software Sev-2 #4149, #4151, #4152, #4153, #4157 and #4159 before asking the user for physical-device QA.
2. #4148 is narrowed to device verification only; do not close it until interruption/background recovery is confirmed on real hardware.
3. Recover S3 and S6 current-head CI to green. S1, S2, S4 and S5 are green at their latest observed heads.
4. Integrate S1-S7 through S0 while preserving S8's storage-failure and runtime-test protections.
5. Re-run S8 automated gates against the integrated S0 candidate; sibling green runs are not cross-feature integration evidence.
6. Synchronize `testflight/splat-native-ios` only after that integrated candidate exists. #4161 now intentionally blocks stale release source.
7. Only then run real iPhone interruption, permission, low-storage, corrupt-project, large-scene, long-generation, peak memory/thermal/battery, VoiceOver/Dynamic Type, representative Scaniverse side-by-side, and Internal TestFlight install/launch/real-scan checks.
8. S7 is still MISSING. When networking/public sharing lands, remove the assumption that the whole product is local-only and re-audit Privacy Manifest/App Store privacy metadata together.
9. Before final App Store submission (separate from Internal TestFlight), complete current App Store Connect age-rating information and retain the explicit human submission approval gate.

## S8 handoff rule

For every new S0 integration wave:

1. fast-forward / merge the latest S0 state into S8,
2. re-run automated gates,
3. execute the matrix against newly integrated surfaces,
4. classify each failure Sev-1 / Sev-2 / Sev-3,
5. fix S8-owned cross-cutting defects directly,
6. route subsystem defects to S1-S7 with reproduction and acceptance criteria,
7. do not mark S8 complete until Sev-1 = 0 and Sev-2 = 0.
