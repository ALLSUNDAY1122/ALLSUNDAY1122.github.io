# Scaniverse Functional Parity Program

Updated: 2026-08-24 14:48 JST

## Goal

Independently implement an iOS app that reaches functional and practical-quality parity with the current consumer Scaniverse experience. Do not copy Scaniverse proprietary source code, trademark, logo, artwork, models, training data, or other protected assets.

Parity means comparable user outcomes, real data/output, usability, speed, stability, recovery, and practical result quality. Requirements, compile success, simulator/fixture success, CI success, signed archive, or TestFlight distribution alone are not parity.

## Source of truth

- Notion: `Scaniverse同等化｜4開発班＋統合本部 v2.0`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Working root: `splat-native-ios/`
- Integration branch: `feature/splat-native-ios-poc`
- Integration PR: `#4145`
- A2: `scaniverse/a2-capture-reconstruction`
- B2: `scaniverse/b2-view-edit-mesh`
- C2: `scaniverse/c2-library-export`
- D2: `scaniverse/d2-share-discover`
- Supabase production: `gybchnyqlqwmajwkhsly`

Fixed SHAs are evidence, not permanent source of truth. Every work session must re-read live state first.

## Current validated app-source

`595c1d1d3468dd85594a958d8750264d9db91f50`

Build 3以降に反映された重要な実source差分:

- persisted viewer editをexport / video / publishの実outputへmaterialize
- 外部actionが古いviewer stateを読むraceを避けるためedit persistenceを即時化
- crop片側handleだけを動かした場合、未操作側tailを暗黙に切らないopen-ended endpoint semantics

Validated app-source automated gates:

- Splat Native Privacy Preflight: PASS
- Splat Smoke Diagnostic: PASS
- Splat Native iOS Build: PASS

最新HQに対するA2/B2/C2/D2 fresh compareは4 branchすべて `ahead_by=0`。未統合Worker成果なし。

## Current Internal TestFlight candidate — Build 4

Build 3は現行app-sourceより古いためhistorical candidateへ降格。現在の物理比較対象は **Build 4**。

- release branch: `testflight/splat-native-ios-20260824-build4`
- release commit: `bdb1488b101c3855edc52687b5dd230748297a62`
- release差分: TestFlight用 `codemagic.yaml` のみ
- Codemagic build: `6a8bd803c391bffc3d7617ce`
- Codemagic status: `finished`
- App Store Connect app: `6803778932`
- bundle: `jp.allsunday1122.splatlab`
- build resource: `219264e6-587a-49f2-96b1-0850d5a8ad4c`
- build number: `4`
- `processingState=VALID`
- `buildAudienceType=INTERNAL_ONLY`
- `expired=false`
- `usesNonExemptEncryption=false`
- `internalBuildState=IN_BETA_TESTING`
- internal beta group `sun`: assigned
- tester count: `1`
- App Store Review submission: false
- external beta review submission: false

Evidence:

- `splat-native-ios/evidence/scaniverse-build4-release.json`
- `splat-native-ios/evidence/scaniverse-build4-actions-probe.json`
- release gate Actions run `32694020324`: SUCCESS

## Supabase production

2026-08-24 14:43 JST fresh read-only state:

- project: `ACTIVE_HEALTHY`
- `auth.users=1`
- `scanlab_profiles=1`
- `scanlab_scans=0`
- `scanlab_reports=0`
- `scanlab_blocks=0`

Active Edge Functions:

- `scanlab-public` v12
- `scanlab-publish` v12
- `scanlab-delete-account` v4
- `scanlab-visibility` v5
- `scanlab-delete-scan` v7
- `scanlab-unpublish` v2
- `scanlab-upload` v1

A real generated trusted scan does not yet exist in production, so publish/share lifecycle parity remains unproven.

## Current parity ledger

| Area | State | Remaining proof | Owner |
|---|---|---|---|
| ARKit capture / tracking / live coverage guidance | PARTIAL | Build 4 real-device continuity, responsiveness, image-quality rejection, recovery and Golden comparison | A/HQ |
| On-device Gaussian Splat reconstruction | PARTIAL | representative-object physical output quality, processing time, thermal/memory behavior and recovery | A |
| Splat viewer / edit / measure | PARTIAL | Build 4 device usability, edit persistence/output materialization, crop behavior and practical measurement | B/HQ |
| Mesh reconstruction / texture / edit / measure / AR | PARTIAL | physical result quality and complete device workflow proof | B |
| Local library / raw retention / process later / reopen / reprocess | NEAR_PARITY | Build 4 cold-reopen/process-later/reprocess physical proof | C/HQ |
| Export / video interoperability | NEAR_PARITY | Build 4 generated edited assets/video, external-read usability and memory proof | C/B |
| Auth / session / profile | NEAR_PARITY | production live E2E passes; Build 4 device UX proof remains | D/HQ |
| Publish / durable browser URL / visibility / Map / Discover | PARTIAL | real Build 4 generated trusted scan production lifecycle E2E | D/HQ |
| Integrated release candidate | NEAR_PARITY | Build 4 VALID/internal distribution established; physical end-to-end parity gate remains | HQ |
| Integrated full app flow | PARTIAL | Build 4 `capture → coverage → finish → processing → 3D result → save → library reopen` | HQ/A-D |

No row may become `PARITY` solely from compile, simulator, fixture, CI, signed build, TestFlight upload/distribution, screen transition, placeholder output, fake 3D, or synthetic backend data.

## Current blocking gate — Build 4 physical device

Use the actual TestFlight Build 4 on a representative iPhone and compare with the Scaniverse Golden Reference.

Required flow:

`capture → coverage → finish → processing → 3D result → save → library reopen`

Minimum physical acceptance:

1. Active capture hides bottom tabs.
2. Real ARKit feature-point-derived red/green coverage heatmap updates continuously with camera movement.
3. Camera remains responsive; tracking loss, pause/resume and interruption recovery are usable.
4. Clearly dark-clipped, blown-highlight or strongly blurred/low-detail frames are rejected rather than silently degrading the dataset.
5. Finish does not falsely succeed from redundant views alone.
6. Processing progress corresponds to real reconstruction work; no fake progress, crash, permanent hang or unusable thermal/memory failure.
7. Result is a real Gaussian Splat, not rough/fake 3D or disconnected placeholder geometry.
8. Golden comparison shows no obvious unacceptable deficit in missing regions, duplication, color, detail, volume/3D impression, stability, time, or required user effort.
9. Orbit / pan / zoom / reset are practically usable.
10. Viewer edits persist and the same meaning is reflected in saved/exported/video/publish output.
11. Moving only one crop endpoint does not silently cut the untouched opposite tail.
12. Save succeeds and Library cold reopen shows the same completed asset.
13. Process-later/reprocess paths remain recoverable where applicable.

Capture/reconstruction/viewer/library must not be promoted to `PARITY` before this physical gate passes.

## Production trusted-scan gate after physical quality passes

Use the real trusted scan generated by Build 4. Do not substitute synthetic or hardcoded data.

Required lifecycle:

`explicit publish → durable asset URL → separate browser viewer → public/unlisted/private → Discover → Map only with explicit geotag opt-in → unpublish → republish → owner delete`

Acceptance also includes:

- local scan/process remains offline-capable until explicit network action
- private/unlisted/public semantics are enforced
- unlisted access token is not leaked into ordinary server-visible URL components
- public scans can appear in Discover without forced geotag
- Map requires explicit location opt-in
- owner lifecycle and deletion clean up metadata/assets safely
- block/report/moderation/rate-limit contracts do not regress
- account deletion remains recoverable/safe until intentionally executed

## Functional parity scope

### A — Capture / Splat generation

- guided Splat capture on supported iPhones
- ARKit tracking, coverage and recovery
- object/room/outdoor capture behavior
- pause/resume and interruption recovery
- quality rejection and finish-quality gates
- on-device Gaussian Splat reconstruction
- retained raw capture, checkpoint/retry, Enhance/reprocess
- sky/background handling where applicable
- bounded thermal/memory behavior

### B — View / edit / measure / Mesh

- useful initial Splat framing
- orbit, true pan, zoom, reset
- crop, exposure, contrast
- measurement with meaningful scale contract where supported
- edit persistence and output materialization
- Mesh capture/reconstruction including applicable LiDAR/non-LiDAR paths
- Mesh cleanup/texture/edit/measurement/AR viewing
- Mesh reprocess from retained raw data

### C — Library / lifecycle / export / video

- persistent local library and thumbnails
- save before processing / process later
- reopen after relaunch
- resume/reprocess/recovery
- safe project delete/storage lifecycle
- PLY/SPZ and relevant model/point-cloud exports
- OBJ/FBX/GLB/USDZ interoperability within parity scope
- video export and share sheet
- trusted browser-share package

### D — Account / publish / browser / discover

- auth/session/profile
- explicit trusted upload/publish
- public/unlisted/private
- durable browser-view URL
- opt-in geotag
- Map/Discover/public profile browsing
- opening other users' public scans
- unpublish/republish/delete/account deletion
- report/block/moderation/rate limit/privacy safeguards

## Frozen legacy branches

The old S1-S8 branches are evidence/migration sources only. Do not resume development there.

- `scaniverse/s1-capture`
- `scaniverse/s2-splat-reconstruction`
- `scaniverse/s3-splat-viewer-edit`
- `scaniverse/s4-mesh-photogrammetry`
- `scaniverse/s5-library-lifecycle`
- `scaniverse/s6-export-video-share`
- `scaniverse/s7-map-discover-backend`
- `scaniverse/s8-adversarial-qa`

## Completion rule

The program is complete only when:

1. Build 4 (or a later source-identical/fix successor) passes real-device capture/reconstruction/viewer/library quality against Golden Reference.
2. A real trusted scan passes production publish/share/visibility/Discover/Map/owner lifecycle E2E.
3. Any defects found in those gates are fixed and re-run without creating new unverified source drift.
4. Current parity ledger rows required for the public Scaniverse-equivalent experience are promoted based on runtime evidence, not assumptions.
5. PR #4145 remains draft/unmerged until those gates are satisfied and final integration review is complete.

Older detailed Build 2/Build 3 and legacy-lane evidence remains available in Git history and Notion history; it is not repeated here to avoid stale state being mistaken for the current gate.
