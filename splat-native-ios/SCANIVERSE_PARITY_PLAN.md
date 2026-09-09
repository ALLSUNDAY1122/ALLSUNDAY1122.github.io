# Scaniverse Functional Parity Program

Updated: 2026-09-09 21:00 JST

## Goal

Independently implement an iOS app that reaches functional and practical-quality parity with the current consumer Scaniverse experience. Do not copy Scaniverse proprietary source code, trademark, logo, artwork, models, training data, text, stages, or other protected assets.

Parity means comparable user outcomes, real reconstruction quality, usability, speed, stability, recovery, editing, export/share behavior, and practical result quality. Requirements, compile success, simulator/fixture success, CI success, signed archive, or TestFlight distribution alone are not parity.

## Live source of truth

- Notion: `Scaniverse同等化｜4開発班＋統合本部 v2.0`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Working root: `splat-native-ios/`
- HQ branch: `feature/splat-native-ios-poc`
- Integration PR: `#4145`
- Supabase production: `gybchnyqlqwmajwkhsly`
- Golden / physical evidence: Dropbox `/Scaniverse`

Fixed SHAs are evidence only. Every work cycle must re-read live GitHub, Notion, Supabase and physical evidence before deciding the next blocker.

## Current integrated HQ state

Fresh audit on 2026-09-09:

- PR #4145: `open / draft / unmerged`
- PR #4145 head: `a5d5b3a77c5cd1ff912b382a9a93ae0fdb774fe0`
- PR #4145 base: `main`
- #4145 must remain unmerged until the physical parity gate and final integration review pass.
- S13→S14→S14D→HQ machine integration was already completed.
- The integrated HQ machine gate had passed at the current Build 14 app-source lineage; machine success is evidence, not parity.

## Current Internal TestFlight candidate — Build 14

Build 14 is the current physical comparison candidate.

- release branch: `testflight/splat-native-ios-20260903-build14`
- signed Gate Action: `33761097673` — SUCCESS
- signed commit: `fe9e1c24e73fe5542c2b0fa6869983456092109f`
- signed Codemagic: `6a99756109c439ed22acd91c`
- artifact: `Splat_Lab_Native.ipa`
- App Store Connect readback Codemagic: `6a9977da70cbb2e04fed4a20` — finished
- Version: `1.0.0`
- Build: `14`
- `processingState=VALID`
- TestFlight: internal testing only
- App Store submission: false
- external beta review submission: false
- release evidence: `splat-native-ios/evidence/scaniverse-build14-release.json`

The release cleanup head is `c2754715`; its source difference from the signed commit is workflow/evidence cleanup only. Do not treat TestFlight VALID as parity.

## Reconstruction history that determines the current P0

The latest physical failure was not a generic UI or resource-budget issue.

- S13 same-raw regeneration reached the trainer with `rawFeaturePoints · depth 0 frames · geometry 7581`.
- Training completed to a viewer result of `386,763 / 386,763 splats`.
- The completed result was still spatially fragmented/disconnected and did not form a coherent representation of the captured object.
- Therefore physical reconstruction quality remained FAIL even though regeneration and completion flow worked.

S14 then added non-LiDAR RGB multi-view dense initialization:

- `SplatSoftwareDepthSeedBuilder.swift`
- software plane-sweep depth from saved RGB + ARKit pose
- hardware depth remains first priority
- software `planeSweep` is used when hardware depth is insufficient
- `rawFeaturePoints` is only the fail-closed fallback
- the S14 active seed recipe is separated so an old S13 raw-feature-point checkpoint cannot silently mask the S14 experiment

This change passed machine gates and reached Build 14. Its physical effect has not yet been proven.

## Current only P0 — Build 14 same-RAW physical reconstruction gate

Do not add unrelated UI/features while this gate is unresolved.

The next human/device action is intentionally one experiment:

1. Do not delete the app.
2. Update the existing installation to TestFlight Build 14.
3. If the existing capture appears under `最近削除`, restore it.
4. Use `同じ撮影から再生成` on that same RAW capture.
5. Keep evidence from the run through completed 3D result.

Acceptance requires all of the following:

- seed source is `planeSweep`, or genuine hardware `depth`; `rawFeaturePoints` means the S14 hypothesis was not exercised and is a gate failure/inconclusive result.
- the standard reconstruction reaches all 7000 iterations without terminal resource/thermal/memory pause.
- the completed model is a coherent reconstruction rather than separated spatial fragments, duplicated shells, or disconnected placeholder-like geometry.
- the same completed output is judged against the Scaniverse Golden reference for missing regions, duplication, geometric coherence, color, detail and stable 3D impression.
- save/reopen must preserve the same completed asset; machine completion alone is insufficient.

If Build 14 uses `planeSweep`/hardware depth and still produces the same class of fragmentation, stop tuning resource/UI/seed-source routing. The next P0 becomes S15 camera-pose and multi-view geometric consistency refinement.

## Golden / physical evidence state

Fresh Dropbox `/Scaniverse` audit on 2026-09-09 found five files and no newer Build 14 physical recording/output:

- `こうへい - RPReplay_Final1787926603.mp4`
- `こうへい - result.ply`
- `こうへい - result.spz`
- `こうへい - RPReplay_Final1787958095.mp4`
- `こうへい - RPReplay_Final1787989688.mp4`

The newest file in that folder is from 2026-08-29 UTC. Therefore Build 14 physical parity cannot be promoted from current Dropbox evidence.

## Supabase production

Fresh read-only audit on 2026-09-09:

- project: healthy/available
- `auth.users=1`
- `public.scanlab_profiles=1`
- `public.scanlab_scans=0`
- `public.scanlab_reports=0`
- `public.scanlab_blocks=0`

Important schema note: current production tables are prefixed `scanlab_*`; the old shorthand `public.profiles/scans/reports/blocks` is stale and must not be used in future audits.

Because `scanlab_scans=0`, production publish/share lifecycle parity is still unproven. Do not use synthetic or hardcoded scans to close that gate.

## Current parity ledger

| Area | State | Remaining proof |
|---|---|---|
| ARKit capture / tracking / live coverage guidance | PARTIAL | Build 14 device continuity/responsiveness and Golden comparison |
| On-device Gaussian Splat reconstruction | **P0 / PARTIAL** | Build 14 same-RAW `planeSweep`/depth run, 7000 completion, coherent final geometry |
| Splat viewer / edit / measure | PARTIAL | trusted coherent Build 14 result on device; persistence/materialization/usability |
| Mesh reconstruction / texture / edit / measure / AR | PARTIAL | physical result quality and complete device workflow proof |
| Local library / raw retention / process later / reopen / reprocess | NEAR_PARITY | Build 14 same-RAW restore/reprocess and cold reopen proof |
| Export / video interoperability | NEAR_PARITY | trusted Build 14 edited asset/video external-read proof |
| Auth / session / profile | NEAR_PARITY | production live path exists; final device UX proof remains |
| Publish / durable browser URL / visibility / Map / Discover | PARTIAL | real trusted Build 14 scan lifecycle E2E; production scan count is currently zero |
| Integrated release candidate | NEAR_PARITY | Build 14 VALID/internal distribution established; physical quality gate remains |
| Integrated full app flow | PARTIAL | coherent capture/reconstruct result then save/reopen/export/share on device |

No row may become `PARITY` solely from compile, simulator, fixture, CI, signed build, TestFlight upload/distribution, screen transitions, placeholder output, fake 3D, or synthetic backend data.

## Gate after reconstruction quality passes

Only after the Build 14 reconstruction result is physically trusted, run the same real scan through:

`viewer/edit → save → cold reopen → export/video → explicit publish → durable browser URL → separate browser viewer → public/unlisted/private → Discover → Map only with explicit geotag opt-in → unpublish → republish → owner delete`

Acceptance includes:

- viewer edits persist and are materialized into saved/exported/video/published output
- crop endpoints do not silently remove the untouched opposite tail
- external formats are readable and practically useful
- local scan/process remains offline-capable until explicit network action
- public/unlisted/private semantics are enforced
- Map location remains opt-in
- owner deletion cleans metadata/assets safely
- report/block/moderation/rate-limit/account-deletion contracts do not regress

## Priority rule for future cycles

At each cycle, score only real remaining gaps by device impact × user visibility × recurrence × dependency-unblocking effect. Prefer one deep quality blocker over many shallow TODOs.

Current ordering:

1. Build 14 same-RAW physical reconstruction quality.
2. If fragmented with real `planeSweep`/depth: camera-pose / multi-view consistency.
3. Only after coherent trusted output: viewer/edit/save/reopen/export/share lifecycle.
4. Only after a trusted real scan exists: production publish/discover/map lifecycle.

## Completion rule

The program is complete only when:

1. capture → reconstruction → viewer → edit → save/reload → export/share passes on a representative real iPhone flow;
2. the resulting geometry is physically coherent and acceptably close to the Scaniverse Golden reference across representative captures;
3. no fatal crash/data loss or unresolved P0/P1 remains;
4. performance, memory and thermal behavior are repeatable enough for practical use;
5. a real trusted scan passes production visibility/publish/owner lifecycle E2E;
6. #4145 remains draft/unmerged until all final physical/integration checks pass and a human explicitly decides to merge.
