# Scaniverse Functional Parity Program

Updated: 2026-08-15

## Goal

Build an independently implemented iOS app that reaches functional and practical-quality parity with the current consumer Scaniverse experience before any product-specific `omochabako` adaptation begins.

This does **not** mean copying Scaniverse proprietary source code, trademark, logo, artwork, or copyrighted assets. It means independently reproducing the same user outcomes, core workflows, real data types, failure recovery, and comparable practical quality.

## Source of truth

- Notion: `Scaniverse同等化｜4開発班＋統合本部 v2.0`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Working root: `splat-native-ios/`
- Integration branch: `feature/splat-native-ios-poc`
- Current internal brand while parity work is incomplete: `Scan Lab`
- `omochabako` branding and memory-specific UX are forbidden in this root until the parity gate passes.

## Why the program was reorganized

The initial S0-S8 decomposition produced substantial code in separate branches but too little integration. Capture, reconstruction, viewer, lifecycle and export lanes repeatedly modified the same shared app files, while QA/integration became separate administrative roles. That structure is retired.

The active program now has **four product-building lanes plus one integration headquarters**. QA is embedded into every lane. Integration HQ also writes code and continuously produces one integrated app.

## Active build lanes

### A — Capture → On-device Gaussian Splat
Branch: `scaniverse/a-capture-reconstruction`

Owns the complete Splat creation experience: ARKit capture/tracking/coverage, frame/depth/point ingestion, pause/resume/relocalization, quality gates, on-device 3DGS initialization/training, sky/background handling, Enhance, checkpointing, output validation, processing time, memory and thermal behavior.

Legacy sources: old S1 + S2.

### B — Splat View/Edit/Measure + Mesh
Branch: `scaniverse/b-view-edit-mesh`

Owns everything after a 3D asset is created that changes how it is viewed or geometrically represented: Splat framing/orbit/pan/zoom/crop/exposure/contrast/measurement and the complete Mesh path including LiDAR/non-LiDAR reconstruction, texture, trim/edit, metric measurement and AR/object viewing.

Legacy sources: old S3 + S4.

### C — Library / Resume / Reprocess / Export / Video
Branch: `scaniverse/c-library-export`

Owns durable local projects and all output from them: scan library, raw retention, process later, resume/reprocess, crash recovery, storage lifecycle, safe completion contracts, PLY/SPZ/model exports, video, interoperability, memory-safe large exports, iOS share sheet and the trusted browser-share package.

Legacy sources: old S5 + S6.

### D — Account / Publish / Browser / Map / Discover
Branch: `scaniverse/d-share-discover`

Owns the intentional network layer only: auth/account, explicit upload, public/unlisted/private semantics, durable browser viewer URLs, opt-in geotagging, Map/Discover/feed, opening others’ scans, unpublish/delete, rate limits, moderation, abuse/privacy controls and network-related App Store declarations.

Legacy source: old S7.

### Integration HQ
Branch: `feature/splat-native-ios-poc`

Owns shared app shell/navigation, A-D contracts, semantic merges, cross-lane bugs, integrated CI/runtime flows, removal of duplicate implementations, privacy/security/accessibility/performance integration, TestFlight candidates and the final harsh-review loop. HQ is not a passive manager.

Old S8 is retired. Its findings are acceptance requirements in A-D/HQ rather than a separate QA product lane.

## Frozen legacy migration sources

Do not continue development on these branches. They are evidence/migration sources only:

- `scaniverse/s1-capture` → A
- `scaniverse/s2-splat-reconstruction` → A
- `scaniverse/s3-splat-viewer-edit` → B
- `scaniverse/s4-mesh-photogrammetry` → B
- `scaniverse/s5-library-lifecycle` → C
- `scaniverse/s6-export-video-share` → C
- `scaniverse/s7-map-discover-backend` → D
- `scaniverse/s8-adversarial-qa` → findings redistributed to A-D/HQ

## Baseline: current Scaniverse consumer feature surface

### Capture / Splat generation — A

- Splat capture on supported non-LiDAR and LiDAR iPhones.
- Continuous guided capture.
- Robust camera pose tracking and recovery.
- Object, room and outdoor capture behavior that does not falsely complete on redundant views.
- Resume capture after stopping/interruption.
- Long-scan guidance / failure-risk warning.
- LiDAR depth use/ignore architecture where supported.
- Fully on-device personal Splat processing without requiring Internet.
- Photorealistic Gaussian Splat output.
- Useful color/detail/reflection behavior rather than rough textured geometry.
- Outdoor sky/background artifact handling.
- Reprocess/enhance a retained raw capture.
- Bounded memory/thermal behavior and recoverable failure states.

### Viewing/editing + Mesh — B

- Useful initial Splat view.
- Orbit / true pan / zoom / reset.
- Crop.
- Exposure / contrast.
- Measurement.
- Edit persistence where practical.
- Mesh capture/reconstruction.
- LiDAR and non-LiDAR paths where appropriate.
- Geometry cleanup/refinement.
- Texturing.
- Mesh crop/edit/measurement.
- Metric scale contract where supported.
- Mesh reprocess from retained raw data.

### Library / lifecycle / export — C

- Persistent local scan library and thumbnails.
- Open saved scan after app relaunch.
- Raw capture retention.
- Save before processing / process later.
- Resume.
- Reprocess to Splat or Mesh where supported.
- Crash/interrupted-write recovery.
- Safe delete/storage lifecycle.
- Splat PLY and SPZ export.
- Mesh/model formats supported by parity scope including OBJ / FBX / GLB / USDZ and relevant point-cloud outputs.
- Real interoperability rather than extension-only files.
- Video export with comparable camera controls/aspect choices.
- iOS share sheet.
- Trusted package for browser sharing.

### Discovery / public sharing — D

- Account/authentication for publishing.
- Public/unlisted/private semantics.
- Explicit upload only; local scan/process remains offline-capable.
- Durable interactive browser-view link.
- Opt-in geotagging.
- Map browsing.
- Discover/feed.
- Open another user-published scan.
- Owner unpublish/delete and account deletion.
- Rate limits/moderation/abuse/privacy safeguards.

## Parity state model

Every row is one of:

- `MISSING`: no working implementation.
- `PARTIAL`: real implementation exists but major user outcome/quality/recovery is missing.
- `NEAR_PARITY`: workflow is substantially present but measurable or obvious user-facing gaps remain.
- `PARITY`: comparable workflow, real output, recovery path, and practical quality demonstrated.

No build lane may mark itself complete while an owned row remains below `PARITY` unless the immediate blocker is explicitly human-only.

## Consolidation ledger — 2026-08-15

These states deliberately do not award parity merely because a legacy branch contains substantial code. The first job of A-C is to combine the paired legacy implementations and then re-run software/runtime gates as one coherent lane.

| Area | State | Evidence / next proof | Owner |
|---|---|---|---|
| ARKit Splat capture/tracking | PARTIAL | old S1 has substantial adaptive/recovery implementation; must be absorbed with A reconstruction and retested | A |
| Spatial coverage / guidance | PARTIAL | old S1 object/scene coverage exists; integrated real-device proof pending | A |
| Capture pause/resume/relocalization | PARTIAL | old S1 implementation exists; integrated device continuity proof pending | A |
| Long-scan/storage failure handling | PARTIAL | old S1/S8 fixes exist; consolidation with durable C contract required | A/HQ |
| On-device Gaussian Splat training | PARTIAL | old S2 has real msplat reconstruction/resource work; real-device side-by-side quality not proven | A |
| Sky/background handling | PARTIAL | old S2 conservative sky seeding exists; outdoor quality proof pending | A |
| Enhance/retrain | PARTIAL | old S2 training path exists; integrated user entry + real-device result pending | A/B |
| Initial Splat view/orbit/zoom/reset | PARTIAL | old S3 implementation exists but not yet consolidated into B + real-device validated | B |
| True pan/crop/exposure/contrast/measure | PARTIAL | old S3 branch contains implementation work; integrated acceptance pending | B |
| Mesh capture/reconstruction | PARTIAL | old S4 contains extensive real algorithms; physical result still not parity proven | B |
| Mesh texturing/edit/measurement/AR | PARTIAL | old S4 implementations exist; real output parity gate remains | B |
| Local library / raw lifecycle | PARTIAL | old S5 persistent store/recovery implementation exists; must be consolidated with C exports | C |
| Process later/resume/reprocess | PARTIAL | old S5 implementation exists; integrated asset contracts pending | C |
| Splat PLY/SPZ export | PARTIAL | old S6 real conversion/read-back tests exist; trusted C lifecycle integration pending | C |
| Model/point-cloud export | PARTIAL | old S6 real exporters exist; B Mesh contract integration and physical interop proof pending | C/B |
| Video export | PARTIAL | old S6 Metal/AVFoundation implementation exists; integrated device/memory proof pending | C |
| Browser-share package | PARTIAL | old S6 package contract exists; D service upload/link integration pending | C/D |
| Account/auth/publish backend | PARTIAL | old S7 implementation exists; durable live-service runtime proof pending | D |
| Public/unlisted/private + owner controls | PARTIAL | backend/UI foundations exist; end-to-end live proof pending | D |
| Browser viewer/shareable URL | PARTIAL | old S7 browser viewer exists; real uploaded asset integration pending | D |
| Map/Discover | PARTIAL | old S7 backend/UI work exists; real-content end-to-end proof pending | D |
| Integrated full app flow | MISSING | legacy branches are not yet one coherent build | HQ |
| Integrated performance/privacy/accessibility/release regression | PARTIAL | old S8 findings/CI exist but must be redistributed and run against integrated candidate | HQ/A-D |

## Harsh-review ownership

There is no separate QA lane. Each owner must attack its own work after every substantial change.

### A must absorb these old adversarial findings
- capture storage failure must terminate visibly and recoverably
- interruption/background/tracking recovery must not corrupt coverage/pose continuity
- 3DGS densification must have an explicit memory/splat budget
- processing under thermal/memory pressure must pause/recover instead of drifting toward jetsam

### B must absorb
- viewer state must be connected to the real app, not only tests
- huge Splat scenes need memory-safe rendering policy/LOD or a fail-safe
- Mesh project lifecycle must not leave unreachable data after cancel/reset

### C must absorb
- partial/aligned `.splat` must never be mistaken for a completed asset
- export must consume only trusted completed assets
- huge export/video paths must preflight memory and clean partial outputs
- lifecycle low-storage/write failures must be recoverable and visible

### D must absorb
- privacy declarations must match actual network use
- publish is explicit opt-in, not automatic
- delete/unpublish/account deletion must actually remove or retire user content
- moderation/rate-limit/abuse contracts are required before public release

### HQ must absorb
- TestFlight candidate must contain current integration HEAD and fail closed if stale
- integrated VoiceOver/basic accessibility and UI consistency
- dependency licenses/privacy manifest/release declarations
- no unresolved Sev-1/Sev-2 before a release candidate

## Hard anti-cheating rules

1. A screenshot, fake progress, prebundled scan, textured polygon, or static model does not count as reconstruction.
2. A format name in UI does not count as export unless an independent reader opens the produced file correctly.
3. A viewer feature does not count until it works on newly generated real scans, not only fixtures.
4. A capture gate does not count if a user can satisfy it with useless redundant views.
5. A quality claim does not count without representative-object evidence against Scaniverse when device evidence is applicable.
6. A compile-only test does not count as runtime validation.
7. A human-only gate must be precisely named; it cannot be a generic stopping excuse.
8. A regression discovered once must become an automated or repeatable gate.
9. Branch commit count is not progress unless the code is integrated into a coherent user flow.

## Representative test set

Use repeatedly:

- textured small toy
- plush / cloth
- shoe
- ceramic object
- flower bouquet
- complex paper craft
- glossy mixed-material object
- transparent-adjacent hard case
- room corner / medium scene
- outdoor scene including sky

For physical quality parity, retain Scaniverse reference captures and Scan Lab captures from comparable paths where possible.

## Global acceptance

Consumer parity is not complete until:

1. A: capture → on-device Splat works repeatedly at comparable practical effort and quality.
2. B: Splat view/edit/measure and Mesh workflows are present and usable.
3. C: scans survive lifecycle events, can resume/reprocess, and real exports/video interoperate.
4. D: explicit publishing produces durable real sharing and real Map/Discover content with ownership/privacy controls.
5. HQ: all four are integrated into one app and cross-feature scenarios pass.
6. On-device processing time, memory and thermal behavior are usable on target device classes.
7. No unresolved Sev-1/Sev-2 remains.
8. The ledger contains no `MISSING`, `PARTIAL`, or `NEAR_PARITY` rows.
9. Only after all above does work branch into `omochabako` product adaptation.
