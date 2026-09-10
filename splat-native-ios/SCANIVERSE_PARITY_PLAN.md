# Scaniverse Functional Parity Program

Updated: 2026-09-10 09:43 JST

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

## 2026-09-10 09:43 JST Macro Loop checkpoint

Fresh HQ reconstruction source is now cache compatibility epoch `recipeVersion=5`; the older Build 15 / epoch-2 state below is historical evidence rather than the current physical candidate.

This macro loop changed plane-sweep reconstruction directly rather than adding another diagnostic gate:

1. Robust multi-view depth aggregation: require genuine support from at least two projected neighbors; for three/four surviving views reject extreme outliers before accepting the photometric cost.
2. Local additive exposure normalization: center neighbor-reference patch intensity differences so auto-exposure drift does not dominate geometric matching while preserving local edge/texture structure.
3. Mobile hot-loop optimization: replace dynamic temporary arrays with bounded SIMD storage and backproject each reference patch sample once per depth hypothesis, reusing that world point across neighbors. This reduces allocation and repeated camera-geometry work in the inner sweep.

The last direct source head before release orchestration was `c34fc8771e261279494f459f9b2a4c59cb49c0fc`. At that exact source head S14 RGB Dense Seed, S13 Depth Seed Geometry, S12 Quality-aware Bounded Densification, S10 Bounded Memory, S9 Memory Drain, Privacy Preflight and Smoke Diagnostic all passed. Native iOS Build was cancelled rather than failed.

The new materialized Codemagic build `6aa1f88a7784a14a74795f9b` was started from `release/scanlab-testflight` but readback reports `failed` after roughly one minute. The release branch itself contains `recipeVersion=5` and the current dense reconstruction source, so this failure is a distribution/release gate and is not evidence that the plane-sweep algorithm failed physically. A fresh human-authored poll/checkpoint commit `4c6cbb0496ff6dac91c37c00df4689d4aaf4c88a` retriggered PR CI for exact-head regression checking.

Fresh external state in this cycle:

- Supabase production: `ACTIVE_HEALTHY`; `auth.users=1`, `scanlab_profiles=1`, `scanlab_scans=0`, `scanlab_reports=0`, `scanlab_blocks=0`.
- Dropbox `/Scaniverse`: five comparison files, newest evidence still predates this epoch-5 lineage.
- No new same-RAW physical reconstruction result was found in the available Project-file search.
- PR #4145 remains human-merge-only and must not be merged automatically.

## Current P0 — distribute and physically validate epoch-5 same-RAW reconstruction

Do not claim a Scaniverse gap reduction from CI alone. The next trustworthy geometry comparison must exercise the current epoch-5 plane-sweep source on the retained same RAW capture.

Gate sequence:

1. Resolve the current Codemagic/TestFlight distribution failure without reverting the epoch-5 reconstruction changes.
2. Produce a signed internal TestFlight build from the current reconstruction lineage.
3. Update the existing iPhone installation without deleting the app.
4. Use `同じ撮影から再生成` on the retained capture.
5. Require seed source `planeSweep` or genuine hardware `depth`, standard 7000 iterations, coherent completed geometry, and save/reopen persistence.
6. Compare the completed output with the Scaniverse Golden reference for missing regions, duplicated shells/fragments, holes/floating geometry, color/detail and stable 3D impression.

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
| Reconstruction / geometry | **P0 / PARTIAL** | epoch-5 signed build + same-RAW `planeSweep`/depth + 7000 completion + coherent final geometry |
| Color / texture / appearance | PARTIAL | coherent current-lineage output vs Golden |
| Splat / mesh rendering | PARTIAL | trusted coherent output; view-dependent stability and physical appearance |
| Camera / scan UX | PARTIAL | real-device continuity, coverage guidance, tracking/relocalization proof |
| Edit UX | PARTIAL | edit operations on a trusted coherent result and persistence |
| Save / reopen | PARTIAL | current-lineage physical persistence proof |
| Export / share | NEAR_PARITY | external-read/share proof from trusted edited asset |
| Performance / memory / thermal | PARTIAL | repeatable physical run without terminal degradation |
| Crash / data consistency | PARTIAL | same-RAW reprocess, save/reopen and cold-recovery physical proof |
| Real-device visual quality | **P0 dependent** | Golden comparison after coherent reconstruction exists |
| Production publish lifecycle | PARTIAL | real trusted scan lifecycle; `scanlab_scans=0` currently |

No row may become `PARITY` solely from compile, simulator, fixture, CI, signed build, TestFlight distribution, screen transitions, placeholder output or synthetic backend data.

## Historical physical baseline

The latest trusted physical failure completed reconstruction but remained spatially fragmented/disconnected. Earlier same-RAW regeneration reached the trainer from a sparse `rawFeaturePoints` seed and produced a high splat count without coherent geometry, demonstrating that completion/count alone is insufficient. S14 introduced RGB multi-view dense initialization, hardware depth remains first priority, and raw feature points remain fail-closed fallback. The current epoch-5 lineage further refines the non-LiDAR plane-sweep matcher described above.

Build 15 / epoch 2 remains useful historical evidence, but it is no longer the preferred physical comparison candidate after the epoch-5 source changes.

## Completion rule

The program is complete only when:

1. capture → reconstruction → viewer → edit → save/reload → export/share passes on a representative real iPhone flow;
2. resulting geometry is physically coherent and acceptably close to the Scaniverse Golden reference across representative captures;
3. no fatal crash/data loss or unresolved P0/P1 remains;
4. performance, memory and thermal behavior are repeatable enough for practical use;
5. a real trusted scan passes required production visibility/publish/owner lifecycle E2E;
6. #4145 remains draft/unmerged until all final physical/integration checks pass and a human explicitly decides to merge.
