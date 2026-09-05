# Scaniverse Parity — 4 Build Lanes

Updated: 2026-08-15

## Structure

There is one integration headquarters and four implementation-heavy build lanes.

| Role | Branch | User-visible responsibility |
|---|---|---|
| Integration HQ | `feature/splat-native-ios-poc` | integrate A-D, shared app shell, cross-lane fixes, integrated CI/runtime flows, final harsh-review fixes |
| A — Capture → Splat | `scaniverse/a-capture-reconstruction` | press Scan → capture/track → on-device Gaussian Splat is actually generated |
| B — View/Edit + Mesh | `scaniverse/b-view-edit-mesh` | view/edit/measure Splat + capture/reconstruct/edit/measure Mesh |
| C — Library + Export | `scaniverse/c-library-export` | keep scans safely → resume/reprocess → export/video/share correctly |
| D — Share/Discover | `scaniverse/d-share-discover` | account → explicit publish → browser URL → Map/Discover → unpublish/delete |

The previous S0-S8 structure is retired. Old S1-S8 branches are frozen migration sources only; do not start new development on them.

## Common operating rule

The target is independently implemented functional and practical-quality parity with the current consumer Scaniverse iOS experience. Do not copy Scaniverse proprietary source, trademark, logo, artwork, or copyrighted assets.

Every lane works by loop engineering:

`inspect actual state → compare with Scaniverse → identify the largest real gap → implement → build/test/runtime-check → harsh review → improve → repeat`

Rules:

- QA is part of every build lane; there is no separate QA-only lane.
- A green compile is not completion.
- “PoCとして十分” and “後で改善” are not parity arguments.
- Never fake reconstruction, exports, network behavior, processing progress, Map/Discover content, or replace Gaussian Splat with textured polygons.
- Add a regression gate after every meaningful defect fix.
- Continue without asking the user for “next” until the immediate next action truly requires a physical-device, Apple-authenticated, legal, or final-product human judgment.
- When a change crosses lane boundaries, record the dependency and let Integration HQ resolve the shared contract rather than creating two competing implementations.
- Integration HQ is not passive management: it implements shared shell/contracts, resolves semantic conflicts, fixes cross-lane bugs, and runs integrated harsh-review loops.

## Migration rule

The new branches intentionally preserve the strongest existing implementation as their starting point. Their first task is to absorb the paired legacy source semantically. Do not choose one whole shared file and discard the other implementation.

- A starts from old S2 and must absorb `scaniverse/s1-capture`.
- B starts from old S4 and must absorb `scaniverse/s3-splat-viewer-edit`.
- C starts from old S6 and must absorb `scaniverse/s5-library-lifecycle`.
- D starts from old S7 and continues that implementation directly.
- Old S8 findings are acceptance requirements distributed across A-D and Integration HQ; S8 is not an active lane.

---

# A — Capture → On-device Gaussian Splat

**Branch:** `scaniverse/a-capture-reconstruction`

## User story

A first-time user points the iPhone at a subject, follows lightweight guidance, completes capture, and receives a real usable Gaussian Splat on-device without needing to understand ARKit or 3DGS.

## Own all of this

### Capture
- ARKit lifecycle and permissions
- camera poses/intrinsics
- RGB frame selection
- feature points and LiDAR/depth ingestion where available
- object / room / outdoor capture policy
- overlap and spatial coverage
- near/far movement guidance
- too-fast / insufficient-feature guidance
- pause/resume and interruption recovery
- relocalization continuity
- long-scan warnings and frame limits
- Ignore LiDAR option architecture
- storage-write failures while capturing
- pre-reconstruction quality gate

### Reconstruction
- coordinate/camera-model correctness
- point/Gaussian initialization and seed colors
- optimizer/loss policy
- densification/pruning/opacity reset
- SH scheduling
- sky/background behavior
- failed-frame rejection
- standard process and Enhance/retrain
- checkpoint/resume during processing
- output validation
- memory budgets / splat ceilings
- thermal pause/recovery
- processing-time instrumentation

## Legacy inputs to preserve

- old S1 PR/source: adaptive coverage, translation-only rejection, tracking recovery, pause/resume, LiDAR toggle, 90s/180s guidance, storage hard-stop
- old S2 PR/source: colorized initialization, SH3/progressive training, resource guard, checkpoint/thermal handling, sky seeding, Enhance horizon

## Acceptance endpoint

A is not complete merely when `.splat` exists. Representative object/scene captures must repeatedly reach a visually useful Splat without obviously worse holes, doubling, initialization, or failure behavior than Scaniverse, subject to explicit real-device comparison gates.

---

# B — Splat View/Edit/Measure + Mesh

**Branch:** `scaniverse/b-view-edit-mesh`

## User story

Once a 3D asset exists, the user can inspect, correct, measure and use it. The same app also offers a real Mesh path instead of only Splat.

## Own all of this

### Splat interaction
- useful initial view / auto-framing
- orbit
- true pan
- zoom
- reset
- crop
- exposure
- contrast
- measurement
- non-destructive edit state where practical
- loading/error states
- Enhance/Reprocess entry points
- large-scene render/memory safety

### Mesh
- Mesh capture mode
- LiDAR geometry path where supported
- non-LiDAR photogrammetry/MVS path
- geometry fusion/refinement
- texture generation and visibility handling
- crop/trim
- appearance editing
- metric scale contract
- measurement
- AR/object viewing where useful
- raw reprocess to Mesh
- export-facing Mesh asset contract

## Legacy inputs to preserve

- old S3 PR/source: viewer state, editing/measurement UI and renderer work
- old S4 PR/source: LiDAR dense fusion, non-LiDAR MVS, geometry refinement, texture baking, trim, appearance, metric audit

## Acceptance endpoint

A user can open a new real scan and use Splat and Mesh workflows without obvious missing consumer controls or placeholder geometry. Viewer and Mesh quality must survive large/off-center/hard scenes and real-device comparison gates.

---

# C — Library / Resume / Reprocess / Export / Video

**Branch:** `scaniverse/c-library-export`

## User story

A scan is a durable user asset, not an ephemeral demo. It survives relaunch/crash, can be resumed or reprocessed, and can be exported in real interoperable formats.

## Own all of this

### Durable lifecycle
- persistent local scan library
- project IDs / metadata / thumbnails
- raw capture retention
- save before processing
- process later
- capture resume
- crash/interrupted-write recovery
- safe result commit
- keep previous good result during reprocess
- Splat ↔ Mesh reprocess contract
- safe delete / Recently Deleted where appropriate
- storage usage and low-storage behavior
- migration/versioning

### Output
- standards-correct Splat PLY
- SPZ
- Mesh/model exports supported by parity scope: OBJ / FBX / GLB / USDZ / STL and point-cloud outputs such as PLY/LAS where source data supports them
- independent-reader interoperability tests
- orientation/scale/color/metadata correctness
- video render
- camera paths / speed / aspect ratio
- cancellation and partial-file cleanup
- large-scene export memory preflight
- iOS share sheet
- trusted browser-share asset package consumed by D

## Legacy inputs to preserve

- old S5 PR/source: `.splatproject` store, checkpoints, process-later/resume, atomic completion, migration/recovery, trash/raw lifecycle
- old S6 PR/source: real PLY/SPZ, Assimp-based model export, RGB point cloud, H.264 video, memory preflight, browser-share integrity contract

## Acceptance endpoint

A completed or resumable scan cannot disappear during normal lifecycle events, and every advertised export is a real file that an independent consumer can open correctly. Export must accept only trusted completed assets from the lifecycle store.

---

# D — Account / Publish / Browser / Map / Discover

**Branch:** `scaniverse/d-share-discover`

## User story

Local scanning continues to work offline. Only after an explicit user action can a finished scan be uploaded and shared; published scans can be discovered and opened, and the owner can remove them.

## Own all of this

- authentication/account lifecycle
- minimal profile
- public / unlisted / private semantics
- explicit upload only
- durable asset storage and URLs
- interactive browser viewer
- publish metadata
- opt-in geotagging
- Map index
- Discover/feed
- opening another user’s scan
- owner unpublish/delete
- account deletion
- rate limits
- moderation/reporting architecture
- abuse/privacy safeguards
- backend storage lifecycle
- privacy/app-review declarations caused by networking

## Legacy input to preserve

- old S7 source: iOS account/publish shell, Supabase backend/migrations/functions, browser viewer, privacy changes

## Acceptance endpoint

No hardcoded demo content counts. Explicit publish must create a durable real share target backed by the real service, discovery must return real published assets, and privacy/ownership controls must work end-to-end.

---

# Integration HQ — this project chat

**Branch:** `feature/splat-native-ios-poc`

Own:

- the integrated app shell and navigation
- common contracts among A/B/C/D
- semantic integration of completed lane waves
- cross-lane compilation/runtime fixes
- removal of duplicate/conflicting implementations
- integrated capture → process → view/edit → save/reprocess → export → publish → discover flows
- integrated privacy/security/accessibility/performance review
- regression CI and TestFlight candidate construction
- final multi-perspective harsh-review loop
- parity ledger truthfulness

A-D should build product code. HQ should continuously turn those outputs into one working app rather than allowing branch inventory to grow indefinitely.
