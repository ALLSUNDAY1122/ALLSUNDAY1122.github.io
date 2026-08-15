# Scaniverse Functional Parity Program

Updated: 2026-08-15

## Goal

Build an independently implemented iOS app that reaches functional and practical-quality parity with the current consumer Scaniverse experience before any product-specific `omochabako` adaptation begins.

This does **not** mean copying Scaniverse proprietary source code, trademark, logo, artwork, or copyrighted assets. It means independently reproducing the same user outcomes, core workflows, data types, and comparable practical quality.

## Source of truth

- Notion: `Scaniverse同等化｜9セッション分割・統括正本 v1.0`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Working root: `splat-native-ios/`
- Integration branch: `feature/splat-native-ios-poc`
- Current internal brand while parity work is incomplete: `Scan Lab`
- `omochabako` branding and memory-specific UX are forbidden in this root until parity gate passes.

## Baseline: current Scaniverse consumer feature surface

The parity baseline is the consumer iOS feature set visible in Scaniverse 5.2.x / current official support material as of 2026-08.

### Capture

- Splat capture on supported non-LiDAR and LiDAR iPhones.
- Mesh capture with LiDAR / photogrammetry paths where appropriate.
- Continuous guided capture.
- Robust camera pose tracking and recovery.
- Resume scan after stopping.
- Save raw scan and process later.
- Long-scan guidance / failure-risk warning.
- Option to ignore LiDAR where supported.

### Splat reconstruction

- Fully on-device processing for personal Splat generation.
- No Internet required for capture + personal processing.
- Photorealistic Gaussian Splat output.
- High-detail color / lighting / reflections / transparency behavior.
- Better initial camera pose than simply using frame 0.
- Outdoor sky artifact handling / segmentation.
- Reprocess old raw scans as Splat.
- Optional additional enhancement/retraining pass.

### Splat viewing/editing

- Orbit / pan / zoom.
- Stable useful initial view.
- Crop.
- Exposure adjustment.
- Contrast adjustment.
- Measurement where supported by the consumer iOS app.
- Non-destructive edit state where practical.

### Mesh

- Mesh reconstruction.
- Texturing.
- Crop/edit.
- Measurement.
- Reprocess raw capture.
- Export workflows compatible with common 3D tools.

### Library / lifecycle

- Local scan library.
- Thumbnails.
- Open saved scan.
- Raw capture retention.
- Process later.
- Resume.
- Reprocess to a different representation.
- Delete with safe confirmation.
- Storage lifecycle that survives normal app relaunch.

### Export / sharing

- Splat export: PLY and SPZ.
- Mesh/model exports to the formats supported by the current iOS consumer app, including OBJ / FBX / GLB / USDZ and relevant point-cloud formats.
- Video export with controllable camera movement / aspect ratio comparable to the consumer workflow.
- iOS sharing.
- Shareable browser-view link.

### Discovery / public sharing

- Public/unlisted publishing equivalent.
- Global map browsing equivalent.
- Discover/feed equivalent.
- Open another user-published 3D scan.
- Account/authentication needed for publishing.
- Delete/unpublish own content.
- Backend abuse/moderation constraints designed before public release.

## Parity state model

Every row is one of:

- `MISSING`: no working implementation.
- `PARTIAL`: real implementation exists but major user outcome/quality/recovery is missing.
- `NEAR_PARITY`: workflow is substantially present but measurable or obvious user-facing gaps remain.
- `PARITY`: comparable workflow, real output, recovery path, and practical quality demonstrated.

No session may mark itself complete while a row in its ownership remains below `PARITY` unless the blocker is an explicit human-only gate.

## Initial parity ledger

| Area | State | Current evidence | Owner |
|---|---|---|---|
| Splat ARKit capture | PARTIAL | real frames + poses + points | S1 |
| Spatial coverage guidance | PARTIAL | 12-sector horizontal coverage | S1 |
| Resume scan | MISSING | none | S1/S5 |
| Save raw / process later | PARTIAL | raw project written but no library workflow | S5 |
| Long-scan warning | PARTIAL | max-frame failure, not Scaniverse-like time guidance | S1 |
| Splat on-device training | PARTIAL | msplat pipeline builds; real-device quality not proven | S2 |
| Sky segmentation | MISSING | none | S2 |
| Enhance/retrain | MISSING | none | S2/S3 |
| Initial useful view | NEAR_PARITY | robust auto-framing implemented, not real-device validated | S3 |
| Orbit/zoom/reset | NEAR_PARITY | working code path, real-device validation pending | S3 |
| Pan | MISSING | current gesture rotates only | S3 |
| Crop Splat | MISSING | none | S3 |
| Exposure/contrast | MISSING | none | S3 |
| Measurement | MISSING | none | S3/S4 |
| Mesh capture | MISSING | none | S4 |
| Mesh reconstruction/texturing | MISSING | none | S4 |
| Local library | MISSING | none | S5 |
| Reprocess raw scan | MISSING | none | S5 |
| PLY Splat export | MISSING | current output is .splat only | S6 |
| SPZ export | MISSING | none | S6 |
| Model export formats | MISSING | none | S4/S6 |
| Video export | MISSING | none | S6 |
| Shareable browser URL | PARTIAL | signed private Storage URL + interactive browser viewer implemented; merged-site E2E pending | S6/S7 |
| Public/unlisted publish | PARTIAL | explicit private/unlisted/public publish path, owner unpublish/delete, server guards implemented; real-account E2E pending | S7 |
| Map/Discover | PARTIAL | real public feed + geotagged Map + remote Splat viewer implemented with no dummy content; device E2E pending | S7 |
| Account/auth | PARTIAL | Supabase email auth, profile, account/cloud deletion, support/privacy links implemented; real-account E2E pending | S7 |
| UGC moderation/blocking | PARTIAL | content confirmation, server text guard, report auto-hide, moderation hold, user blocking implemented; adversarial E2E pending | S7/S8 |
| Device performance matrix | MISSING | build-only evidence | S8 |
| Release/adversarial regression | PARTIAL | CI exists; parity-specific gates incomplete | S8 |

## S7 explicit human-only gate

S7 must remain below `PARITY` until a real iPhone/TestFlight run demonstrates: login, private save, unlisted browser link, public Map/Discover visibility, other-account like/report/block, report auto-hide, owner unpublish/delete, and account/cloud deletion. The exact sequence and backend evidence are recorded in `S7_HANDOFF.md`.

## Hard anti-cheating rules

1. A screenshot, fake progress, prebundled scan, textured polygon, or static model does not count as reconstruction.
2. A format name in UI does not count as export unless a third-party reader can open the produced file.
3. A viewer feature does not count until it works on a newly generated real scan, not only a fixture.
4. A capture gate does not count if a user can satisfy it while staying on one side of the object.
5. A quality claim does not count without side-by-side representative-object evidence against Scaniverse.
6. A test that only compiles does not count as runtime validation.
7. A human-only gate must be precisely named; it cannot be used as a generic stopping excuse.
8. Regression discovered once must become an automated or repeatable gate.

## Representative test set

Use at least these categories repeatedly:

- textured small toy
- plush / cloth
- shoe
- ceramic object
- flower bouquet
- complex paper craft
- glossy mixed-material object
- transparent-adjacent object (expected hard case)
- room corner / medium scene
- outdoor scene including sky

For each, retain Scaniverse reference captures and Scan Lab captures from similar paths whenever possible.

## Global acceptance

Consumer parity is not complete until:

1. Core capture/processing/viewing can be used without instructions at roughly comparable effort.
2. Splat generation succeeds repeatedly on representative inputs rather than one curated object.
3. Obvious holes, double geometry, bad initialization, and severe color failure are not materially worse in the majority of representative scans.
4. On-device processing time and thermal behavior are usable on the target iPhone class.
5. Splat edit, measure, lifecycle, export, and reprocess workflows are present.
6. Mesh workflow is present.
7. Sharing/link/map/discover surface is functionally present for parity scope.
8. S8 adversarial review has no Sev-1 / Sev-2 findings.
9. S0 parity ledger contains no `MISSING`, `PARTIAL`, or `NEAR_PARITY` rows.
10. Only after all above does work branch into `omochabako` product adaptation.
