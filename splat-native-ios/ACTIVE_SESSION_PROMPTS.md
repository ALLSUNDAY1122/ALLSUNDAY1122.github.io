# Scaniverse同等化｜Active Session Prompts v2

Updated: 2026-08-15 17:53 JST

## Split baseline

- Integration branch: `feature/splat-native-ios-poc`
- Green baseline commit: `78c543ea794796a6f968bf8ffa7da9ec4f229c33`
- CI evidence: `Splat Native iOS Build` run `31871549531` = success
- Integration PR: #4145

The active structure is now **Integration HQ 2 + A2/B2/C2/D2**.

Do not continue new development on the old A/B/C/D branches. They remain migration/reference sources. Old B/C/D contain lane-only commits that are not all ancestors of the integration baseline, so those changes must be inspected and semantically ported when still useful; never replace an integrated shared file wholesale from an old branch.

## Start gate

A2-D2 branches have been created from the green baseline, but full parallel implementation starts only after Integration HQ 2 completes the shared-boundary cleanup and CI is green again.

HQ2 first separates shared responsibilities enough that A2 and C2 do not repeatedly compete for the same giant `ScanModel.swift` surface. The intended responsibility boundaries are at minimum:

- capture / AR session input
- reconstruction / training
- persistence / resume / reprocess lifecycle
- session interruption / app lifecycle

This is a structural boundary cleanup, not permission to change user behavior arbitrarily.

After the HQ2 boundary commit is green, A2-D2 must sync to that integration HEAD before substantial implementation begins.

---

# Integration HQ 2

**User chat opener:** `Scaniverse同等化 統合本部②開始`

**Branch:** `feature/splat-native-ios-poc`

Read first:
1. Notion `Scaniverse同等化｜4開発班＋統合本部 v2.0`
2. `splat-native-ios/NEXT_CHAT_HANDOFF.md`
3. `splat-native-ios/ACTIVE_SESSION_PROMPTS.md`
4. `splat-native-ios/SCANIVERSE_PARITY_PLAN.md`
5. PR #4145 latest HEAD and CI

Mission:
- perform the shared-boundary cleanup first
- keep behavior and green baseline intact while reducing cross-lane edit collisions
- run full relevant CI after structural changes
- once green, advance A2-D2 branch refs to the new HQ2 baseline before telling those sessions to begin implementation
- continuously integrate completed lane waves back into one working app
- own shared navigation/contracts, semantic conflict resolution, cross-lane bugs, privacy/security/accessibility/performance, regression gates, TestFlight candidate and final parity ledger

Do not become a passive coordinator. Implement integration fixes directly.

Immediate known product gaps after the baseline:
- finished saved project `新規` flow is still destructive and should preserve saved work
- add a non-destructive leave/project-home path and process-later UX
- ARWorldMap persistence currently has an asynchronous durability race that needs an explicit save-draft completion contract
- verify captured-project processability after relaunch before first generation, especially point-cloud preparation
- parity ledger is stale relative to recent library/cold-resume integration

---

# A2 — Capture → On-device Gaussian Splat

**User chat opener:** `Scaniverse同等化 A2開始`

**Branch:** `scaniverse/a2-capture-reconstruction`

Before implementation:
- confirm the HQ2 shared-boundary gate is complete and this branch is synced to that green integration HEAD
- inspect old `scaniverse/a-capture-reconstruction` only as a migration source
- compare old lane-only changes against current integrated behavior; port only improvements that are still missing

Own:
- ARKit capture/tracking/coverage/guidance
- pose/intrinsics/RGB/depth/feature ingestion
- object/room/outdoor capture policy
- interruption/background/tracking recovery and relocalization
- pause/resume and long-scan/storage handling
- LiDAR use/ignore behavior
- pre-reconstruction quality gates
- on-device Gaussian initialization/training/densification/pruning/SH
- sky/background handling
- Enhance/retrain
- reconstruction checkpointing
- memory/splat budgets, thermal recovery and processing instrumentation

Finish only at practical parity on representative real-device captures. Compile or `.splat` existence is not completion.

---

# B2 — Splat View/Edit/Measure + Mesh

**User chat opener:** `Scaniverse同等化 B2開始`

**Branch:** `scaniverse/b2-view-edit-mesh`

Before implementation:
- confirm the HQ2 shared-boundary gate is complete and sync to the green integration HEAD
- inspect old `scaniverse/b-view-edit-mesh` because it contains commits not fully ancestral to integration
- semantically recover useful lane-only work without overwriting newer integrated lifecycle/capture code

Own:
- Splat initial framing/orbit/true pan/zoom/reset
- crop/exposure/contrast/measurement/edit persistence
- large-scene renderer safety
- real Mesh capture/reconstruction for LiDAR and non-LiDAR paths
- geometry refinement, texture, trim/edit, metric measurement
- AR/object viewing
- raw-to-Mesh reprocess and Mesh asset contract

No placeholder or visual fallback may be counted as Mesh parity.

---

# C2 — Library / Resume / Reprocess / Export / Video

**User chat opener:** `Scaniverse同等化 C2開始`

**Branch:** `scaniverse/c2-library-export`

Before implementation:
- confirm the HQ2 shared-boundary gate is complete and sync to the green integration HEAD
- inspect old `scaniverse/c-library-export` because it contains commits not fully ancestral to integration
- preserve the current trusted-result and cold-resume work; do not replace `ScanModel` or store files wholesale from legacy sources

Own:
- durable local library/thumbnails/project metadata
- raw retention/process later/capture resume
- app-kill and interrupted-write recovery
- safe atomic result commit and previous-good-result preservation
- Splat/Mesh reprocess lifecycle
- safe delete/restore/storage migration/low-storage
- real interoperable PLY/SPZ/OBJ/FBX/GLB/USDZ/STL/point-cloud outputs within parity scope
- independent-reader validation
- video export/camera path/aspect/cancel cleanup/memory preflight
- iOS share sheet and browser-share package contract

Known first checks:
- WorldMap save completion race
- process-later UX
- point-cloud readiness when generating after relaunch
- non-destructive return/new-scan behavior

---

# D2 — Account / Publish / Browser / Map / Discover

**User chat opener:** `Scaniverse同等化 D2開始`

**Branch:** `scaniverse/d2-share-discover`

Before implementation:
- confirm the HQ2 shared-boundary gate is complete and sync to the green integration HEAD
- inspect old `scaniverse/d-share-discover`; it contains lane-only backend/UI commits not fully ancestral to integration
- migrate only verified current service behavior, secrets-free config and valid schema/function work

Own:
- auth/account/profile lifecycle
- explicit upload only; local capture/process remains offline-capable
- public/unlisted/private semantics
- durable asset storage and browser-view URLs
- real interactive browser viewer
- opt-in geotagging, Map and Discover/feed
- opening another published scan
- owner unpublish/delete and account deletion
- rate limiting/moderation/reporting/abuse/privacy safeguards
- network-related App Store privacy/review declarations

Hardcoded demo content does not count as parity.

---

## Common operating loop

For every session:

`fetch actual source of truth → identify largest owned parity gap → implement → test/build/runtime evidence → harsh review → improve → add regression gate → repeat`

Rules:
- do not stop for routine progress reporting
- do not ask for `次` unless the next step is genuinely human-only
- three attempts with no progress triggers source-of-truth refresh and a different method
- branch commit count is not progress until behavior integrates into the real flow
- changes to shared cross-lane contracts must be surfaced to HQ2 rather than independently redefined
- real-device/Apple-auth/legal/final-release actions remain legitimate human gates
