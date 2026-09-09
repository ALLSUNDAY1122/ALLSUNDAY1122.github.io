# Scaniverse Functional Parity Program

Updated: 2026-09-10 07:12 JST

## Goal

Independently implement an iOS 3D scanning app that reaches practical-quality parity with the current consumer Scaniverse experience without copying Scaniverse proprietary source code, trademark, logo, artwork, models, training data, text, stages, or other protected assets.

Parity means comparable real-device outcomes in reconstruction quality, rendering, scan UX, editing, save/reopen, export/share, performance and stability. Compile success, fixture/CI success, signed archive or TestFlight distribution alone are not parity.

## Live source of truth

- Notion: `Scaniverse同等化｜4開発班＋統合本部 v2.0`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Working root: `splat-native-ios/`
- HQ branch: `feature/splat-native-ios-poc`
- Integration PR: `#4145`
- Supabase production: `gybchnyqlqwmajwkhsly`
- Golden / physical evidence: Dropbox `/Scaniverse` and available Project files

Every work cycle must re-read live GitHub, Notion, Supabase and physical evidence before deciding the next blocker. Historical SHAs are evidence only.

## Current integrated HQ state

Fresh audit on 2026-09-10:

- PR #4145 remains `open / draft / unmerged`; do not merge without explicit human instruction.
- Build 15 is the current physical comparison candidate and is TestFlight `VALID / IN_BETA_TESTING / INTERNAL_ONLY`.
- The Build 15 lineage includes the S14 dense-seed path, cache compatibility epoch `recipeVersion=2`, fresh-trainer invalidation and the standard 7000-iteration reconstruction contract.
- No new Build 15 same-RAW physical result was found in Dropbox, Project files or Supabase during the 07:02 JST audit.
- Supabase production is healthy with `auth.users=1`, `scanlab_profiles=1`, `scanlab_scans=0`, `scanlab_reports=0`, `scanlab_blocks=0`.
- Dropbox `/Scaniverse` still contains five comparison files; newest evidence predates Build 15 physical validation.

## Reconstruction history that determines the current P0

The latest trusted physical failure was a completed reconstruction that remained spatially fragmented/disconnected. Earlier same-RAW regeneration reached the trainer from a sparse `rawFeaturePoints` seed and produced a high splat count without coherent geometry, proving that completion/count alone is not sufficient.

S14 therefore added non-LiDAR RGB multi-view dense initialization while preserving genuine hardware depth as first priority and using raw feature points only as a fail-closed fallback. The integrated path exposes the actual seed source and protects same-RAW A/B runs from stale trainer state. Build 15 additionally invalidates older seed-cache compatibility through `recipeVersion=2`.

The physical effect of this lineage has not yet been proven on the retained same RAW capture.

## Current only P0 — Build 15 same-RAW physical reconstruction gate

Do not add unrelated UI/features or speculative geometry changes while this gate is unresolved.

The next human/device action is intentionally one experiment:

1. Do not delete the app.
2. Update the existing installation to TestFlight Build 15.
3. Restore the retained capture if needed.
4. Use `同じ撮影から再生成` on that same RAW capture.
5. Continue through completed 3D output and retain the resulting project/evidence.

Acceptance requires all of the following:

- seed source is `planeSweep` or genuine hardware `depth`; `rawFeaturePoints` is inconclusive/fail for the S14 hypothesis;
- reconstruction reaches the standard 7000 iterations without terminal resource/thermal/memory failure;
- completed geometry is coherent rather than spatially separated fragments, duplicated shells or placeholder-like geometry;
- save/reopen preserves the same trusted completed asset;
- the completed output is compared with the Scaniverse Golden reference for missing regions, duplication, geometry coherence, color/detail and stable 3D impression.

If Build 15 still fragments after exercising `planeSweep`/hardware depth, do not blindly tune resource/UI settings. Run the persisted project through the S18 diagnostic bundle, then branch by evidence:

- pose anomaly present → tracking/relocalization / camera trajectory becomes P0;
- pose smooth → plane-sweep multi-view geometric consistency becomes P0.

## S18 deterministic same-RAW diagnostic bundle

Implemented on 2026-09-10 to minimize the next external/device dependency.

- script: `splat-native-ios/scripts/package_same_raw_diagnostic.py`
- implementation commit: `202cae8222c71a44d4446282baf9c5d4722103ea`
- workflow gate commit: `5bab3dfa36a56249855e7431415dde88831374cf`
- output schema: `scanlab.same-raw-diagnostic.v1`
- read-only/diagnostic-only; it does not modify reconstruction behavior or poses
- accepts one persisted project directory and locates camera transforms
- reuses the existing S15 pose trajectory diagnostic
- records SHA-256 + byte size for transform data, seed recipe, `points3D.ply`, checkpoint candidates and completed SPZ candidates
- records selected seed-recipe metadata including cache recipe version and source
- emits deterministic same-RAW identity hashes so future A/B runs cannot accidentally compare different durable inputs

GitHub Actions run `34410824680` at exact head `5bab3dfa36a56249855e7431415dde88831374cf` completed SUCCESS. The new S18 self-test, S14 dense-seed contract, S15 pose diagnostic, S13 same-RAW materialization contract, S13→S14 materializer composition and protected reconstruction invariants all passed.

This is a diagnosability/reproducibility improvement, not proof that visible geometry improved. Geometry parity remains blocked on the Build 15 physical run.

## Current parity ledger

| Area | State | Remaining proof |
|---|---|---|
| Reconstruction / geometry | **P0 / PARTIAL** | Build 15 same-RAW `planeSweep`/depth, 7000 completion, coherent final geometry |
| Color / texture / appearance | PARTIAL | trusted coherent Build 15 output vs Golden |
| Splat / mesh rendering | PARTIAL | trusted coherent output; view-dependent stability and physical appearance |
| Camera / scan UX | PARTIAL | real-device continuity, coverage guidance, tracking/relocalization proof |
| Edit UX | PARTIAL | edit operations on a trusted coherent result and persistence |
| Export / share | NEAR_PARITY | external-read/share proof from trusted edited asset |
| Performance / memory / thermal | PARTIAL | repeatable Build 15 physical run without terminal degradation |
| Crash / data consistency | PARTIAL | same-RAW reprocess, save/reopen and cold-recovery physical proof |
| Real-device visual quality | **P0 dependent** | Golden comparison after coherent reconstruction exists |
| Production publish lifecycle | PARTIAL | real trusted scan lifecycle; `scanlab_scans=0` currently |

No row may become `PARITY` solely from compile, simulator, fixture, CI, signed build, TestFlight distribution, screen transitions, placeholder output or synthetic backend data.

## Priority rule for future cycles

At each cycle, score remaining gaps by device impact × user visibility × recurrence × dependency-unblocking effect. Current ordering is:

1. Build 15 same-RAW physical reconstruction quality.
2. If fragmented with real `planeSweep`/depth, use S18 evidence to choose camera-pose/tracking vs plane-sweep multi-view consistency.
3. Only after coherent trusted output, close viewer/edit/save/reopen/export/share and performance/thermal gaps.
4. Only after a trusted real scan exists, close production publish/discover/map lifecycle.

## Completion rule

The program is complete only when:

1. capture → reconstruction → viewer → edit → save/reload → export/share passes on a representative real iPhone flow;
2. resulting geometry is physically coherent and acceptably close to the Scaniverse Golden reference across representative captures;
3. no fatal crash/data loss or unresolved P0/P1 remains;
4. performance, memory and thermal behavior are repeatable enough for practical use;
5. a real trusted scan passes required production visibility/publish/owner lifecycle E2E;
6. #4145 remains draft/unmerged until all final physical/integration checks pass and a human explicitly decides to merge.
