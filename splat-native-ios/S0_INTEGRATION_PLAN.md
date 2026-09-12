# Scaniverse Parity — S0 Integration Plan

Updated: 2026-08-15
Branch: `feature/splat-native-ios-poc`

## Purpose

This file is the integration contract for S0. Specialist branches are developed in parallel and intentionally overlap shared files. S0 must preserve subsystem behavior rather than accepting whichever branch happens to merge last.

## Current integration queue

| Lane | PR | Integration state |
|---|---:|---|
| S1 Capture / Tracking | #4158 | BLOCKED — #4149 software storage-failure path; then device gate |
| S2 3DGS Reconstruction | #4155 | BLOCKED — #4157 memory/splat budget + #4149 overlap |
| S3 Viewer / Edit / Measure | #4162 | BLOCKED — #4152 large-scene memory; current-head CI required |
| S4 Mesh / Photogrammetry | #4156 | BLOCKED — #4149 + #4153 lifecycle |
| S5 Library / Lifecycle | #4163 | BLOCKED — #4149 + #4151 durable completion |
| S6 Export / Video / Share | #4154 | BLOCKED — #4152 + trusted-completion dependency on S5; current-head CI required |
| S7 Account / Map / Discover | #4164 | BLOCKED — least-privilege migration exists in branch but live deployment/regression is not complete |
| S8 Adversarial QA | #4150 | AUDITOR — preserve validated resilience fixes; final Sev-1/2 gate |

Issue #4148 is no longer a software integration blocker: code/CI side is fixed, but real-device interruption/background recovery still remains a later human-only gate.

## Shared-file ownership rules

These files are not allowed to be resolved by whole-file replacement during integration:

- `SplatNative/ScanModel.swift`
- `SplatNative/ScanModel+SessionLifecycle.swift`
- `SplatNative/RootScanView.swift`
- `SplatNative/ContentView.swift`
- `SplatNative/SplatViewer.swift`
- `project.yml`
- shared validation / build workflows

For every shared-file conflict, S0 must resolve at behavior level:

1. list every specialist behavior touching the conflict;
2. preserve all non-contradictory behaviors;
3. choose one explicit owner for contradictory policy;
4. add a regression gate before accepting the resolution;
5. compare the integrated file with every contributing branch after resolution.

## Dependency order

Do not interpret this as blind merge order. It is the order in which contracts must stabilize.

1. **S8 resilience invariants** — no silent storage failure, no partial-result promotion, no unbounded resource path.
2. **S5 lifecycle contract** — authoritative project identity, raw retention, durable completion, reopen/reprocess semantics.
3. **S1 capture contract** — frames/poses/coverage/resume/recovery feed the S5 project lifecycle.
4. **S2 reconstruction contract** — consumes S1/S5 raw data, emits a trusted committed Splat and checkpoint semantics.
5. **S4 mesh contract** — shares capture/lifecycle rules and must not create orphan project storage.
6. **S3 viewer/edit contract** — consumes trusted S2/S5 asset and edit persistence.
7. **S6 export/video contract** — consumes trusted S3/S4/S5 representations; must not infer completion from record alignment.
8. **S7 sharing/backend contract** — uploads only explicit, trusted completed assets after local workflows remain functional offline.
9. **S8 integrated adversarial pass** — full cross-feature regression before any device-only acceptance claim.

## Software gate before integration candidate

S0 does not create an integration candidate while any of these remain true:

- unresolved software Sev-1 or Sev-2;
- current-head required CI is red, cancelled because a newer head exists, or has not run;
- a backend migration required by the current client is not deployed to the intended development backend;
- a specialist PR claims a human-only gate while current source still contains a software acceptance failure;
- output validity is inferred only from filenames, UI labels, byte alignment, screenshots, or fixtures.

## Integration candidate gate

After specialist software blockers close:

1. snapshot every specialist HEAD SHA;
2. create a dedicated S0 integration-candidate branch from the current integration branch;
3. integrate dependency contracts without whole-file overwrite;
4. run all specialist static/unit/simulator gates on the candidate;
5. run the cross-feature scenario:
   `capture → interrupt/recover → save raw → process Splat → reopen → edit/measure → export PLY/SPZ/video → share → unpublish/delete`;
6. run the Mesh path separately through save/reopen/export lifecycle;
7. verify offline capture/personal processing still work with S7 present;
8. verify low-storage, corrupt/partial output, large-scene, and cancellation paths fail visibly and recoverably;
9. only then advance to TestFlight/device-only gates.

## Human-only gate boundary

S0 may request user action only after software integration is green and the remaining evidence truly requires a physical iPhone, LiDAR-capable hardware, Apple-authenticated external UI, legal/trademark judgment, or final public-release approval.

A green compile, simulator run, or specialist statement is not enough to move a software defect into the human-only category.
