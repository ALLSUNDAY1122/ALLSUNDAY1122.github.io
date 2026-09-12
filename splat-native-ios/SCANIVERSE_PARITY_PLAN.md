# Scaniverse Functional Parity Program

Updated: 2026-09-10 11:18 JST

## Goal

Independently implement an iOS 3D scanning app that reaches practical-quality parity with the current consumer Scaniverse experience without copying proprietary source code, trademarks, artwork, models, text, stages, training data or other protected assets.

Parity means comparable real-device outcomes in reconstruction quality, rendering, scan UX, editing, save/reopen, export/share, performance and stability. Compile success, fixture/CI success, a signed archive or TestFlight distribution alone are not parity.

## Live source of truth

- Notion: `Scaniverse同等化｜4開発班＋統合本部 v2.0`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Working root: `splat-native-ios/`
- HQ branch: `feature/splat-native-ios-poc`
- Integration PR: `#4145`
- Supabase production: `gybchnyqlqwmajwkhsly`
- Golden / physical evidence: Dropbox `/Scaniverse` and available Project files

Every cycle must re-read live GitHub, Notion, Supabase and physical evidence. Historical SHAs and old TestFlight builds are evidence only.

## 2026-09-10 11:18 JST Macro Loop checkpoint

The current reconstruction compatibility epoch remains `recipeVersion=5`. The direct plane-sweep quality changes already present in this lineage are robust multi-view cost aggregation, local additive exposure normalization and bounded/allocation-free inner-loop geometry reuse.

This macro loop removed the epoch-5 distribution blocker without changing those reconstruction algorithms:

1. The failed release path was reproduced and traced to stale release-contract symbols after materialization. The release workflow still grepped for `seedDepthFrames` / `seedColorFrames`, while the current materializer emits `depthSeedFrames` and `colorFrames: seedFrames`.
2. S21 was repaired and split into Linux-safe contract checks. Materialization, S14 dense reconstruction contract, S15 pose diagnostic contract and materialized app callsites all passed.
3. The release architecture was then made immutable: GitHub materializes and verifies the epoch-5 source once; Codemagic no longer executes `apply_s13_depth_seed.py`. Codemagic verifies the already-materialized callsites, runs the macOS release contracts, signs that same source and submits only to Internal TestFlight.
4. S21 now rejects any future release configuration that reintroduces build-time reconstruction-source materialization. The immutable-release verification run completed SUCCESS.
5. Codemagic build `6aa21077fc7a270bc6de5bd6` completed successfully. App Store Connect readback identifies the resulting latest candidate as **Build 17**, `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `buildAudienceType=INTERNAL_ONLY`, `expired=false`.
6. As an independent UX sidecar, the training screen no longer invents processing stages from training percentage. Before Gaussian optimization starts it reports preparation of the initial 3D/training data; once training starts it reports actual Splat optimization with the current/target iteration count.

Fresh external state in this cycle:

- Supabase production: `ACTIVE_HEALTHY`; `auth.users=1`, `scanlab_profiles=1`, `scanlab_scans=0`, `scanlab_reports=0`, `scanlab_blocks=0`.
- Dropbox `/Scaniverse`: five comparison files; no new epoch-5 same-RAW physical result was found.
- Available Project-file search likewise found no new Build-17 physical reconstruction evidence.
- Golden reference remains approximately 259,243 splats (SH3) for the supplied Scaniverse SPZ and 28,792 vertices plus texture for the supplied mesh export.
- PR #4145 remains human-merge-only and must not be merged automatically.

## Current P0 — physically validate Build 17 on retained same RAW

The distribution blocker is resolved. Do not claim a Scaniverse geometry gap reduction from Build 17 availability alone.

Gate sequence:

1. Update the existing iPhone installation to **TestFlight Build 17 without deleting the app**.
2. Use `同じ撮影から再生成` on the retained capture.
3. Require seed source `planeSweep` or genuine hardware `depth`, current epoch 5, standard 7000 iterations, coherent completed geometry, and save/reopen persistence.
4. Compare the completed output with the Scaniverse Golden reference for missing regions, duplicated shells/fragments, holes/floating geometry, color/detail and stable 3D impression.

If final geometry still fragments, use the already-existing S15/S18/S19 evidence once, then branch by evidence:

- pose anomaly → tracking/relocalization becomes P0;
- smooth pose + severely fragmented seed → plane-sweep geometric consistency remains P0;
- smooth pose + coherent seed + fragmented final output → trainer/render/persistence becomes P0.

Do not keep extending diagnostic infrastructure if it already distinguishes these branches.

## Existing same-RAW diagnostic bundle

- `splat-native-ios/scripts/package_same_raw_diagnostic.py`
- `splat-native-ios/scripts/diagnose_s19_seed_geometry.py`
- read-only; no pose, seed or trainer mutation
- records pose diagnostics, same-RAW identity, seed source/cache epoch, artifact hashes/sizes and geometry connectivity
- S19 excludes trailing sky seeds via `geometryPointCount` and only marks severe fragmentation when the largest component is <35% and at least four components each contain >=2% of geometry points

These diagnostics support root-cause isolation; they do not prove visible quality improvement.

## Current parity ledger

| Area | State | Remaining proof |
|---|---|---|
| Reconstruction / geometry | **P0 / PARTIAL** | Build 17 same-RAW `planeSweep`/depth + 7000 completion + coherent final geometry |
| Color / texture / appearance | PARTIAL | coherent Build-17 output vs Golden |
| Splat / mesh rendering | PARTIAL | trusted coherent output; view-dependent stability and physical appearance |
| Camera / scan UX | PARTIAL | real-device continuity, coverage guidance, tracking/relocalization proof |
| Edit UX | PARTIAL | crop/exposure/contrast/measurement on a trusted coherent result and persistence |
| Save / reopen | PARTIAL | Build-17 physical persistence proof |
| Export / share | NEAR_PARITY | external-read/share proof from trusted edited asset |
| Performance / memory / thermal | PARTIAL | repeatable physical run without terminal degradation |
| Crash / data consistency | PARTIAL | same-RAW reprocess, save/reopen and cold-recovery physical proof |
| Real-device visual quality | **P0 dependent** | Golden comparison after coherent reconstruction exists |
| Production publish lifecycle | PARTIAL | real trusted scan lifecycle; `scanlab_scans=0` currently |

No row may become `PARITY` solely from compile, simulator, fixture, CI, signed build, TestFlight distribution, screen transitions, placeholder output or synthetic backend data.

## Historical physical baseline

The latest trusted physical failure completed reconstruction but remained spatially fragmented/disconnected. Earlier same-RAW regeneration reached the trainer from a sparse `rawFeaturePoints` seed and produced a high splat count without coherent geometry, demonstrating that completion/count alone is insufficient. S14 introduced RGB multi-view dense initialization, hardware depth remains first priority, and raw feature points remain fail-closed fallback. The current epoch-5 lineage further refines the non-LiDAR plane-sweep matcher described above.

Build 15 / epoch 2 remains historical evidence. Build 17 / epoch 5 is now the preferred physical comparison candidate.

## Completion rule

The program is complete only when:

1. capture → reconstruction → viewer → edit → save/reload → export/share passes on a representative real iPhone flow;
2. resulting geometry is physically coherent and acceptably close to the Scaniverse Golden reference across representative captures;
3. no fatal crash/data loss or unresolved P0/P1 remains;
4. performance, memory and thermal behavior are repeatable enough for practical use;
5. a real trusted scan passes required production visibility/publish/owner lifecycle E2E;
6. #4145 remains draft/unmerged until all final physical/integration checks pass and a human explicitly decides to merge.
