# STEP21 — T40 251 XCTest PASS, controlled product merge, release lineage preflight
2026-10-20 JST. TestFlight NOT YET SENT. App Review submit prohibited.

## Readback and QA
Control Queue b96837c26877371616502a15f00eaa5408373b01: HQ owner epoch1; native SCANLAB-W1-001 WORKER_2 epoch2; viewer SCANLAB-W2-001 WORKER_2 epoch1. Worker1 stopped.
T40 isolated integration commit 0c0b7207c80e9c6294a4d7487d1de92de04ca46b; PR #5624 Native iOS run39382480195 SUCCESS with 251 XCTest / 0 failures, static tests, additional Mesh compatibility tests. Smoke/Privacy/S9/S10/S12/S13 successful at matching SHA. Live Auth E2E SKIPPED due to missing test identity; cannot claim live authentication/privacy correctness or physical golden quality.
PR #5624 changed 27 files; mergeable clean into feature branch. HQ marked ready and merged it with expected HEAD exact check. GitHub merge SHA 01b08971a313045b3e5dc4aec79cc19d47ad1c38; remote readback confirmed feature/splat-native-ios-poc HEAD exactly this SHA. This is a PRODUCT DEVELOPMENT branch merge, not signed IPA or Apple delivery.

## Release lineage safety
release/scanlab-testflight HEAD 3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a diverges (7 unique release commits, 1528 source commits ahead). Existing S16 release gateway pinned workflow scanlab-ios, release/scanlab-testflight and historical Build14 app_id; S21 materialization updates this release branch from older epoch5 recipe, pushes without HQ attempt-fence and could overwrite/mix unverified inputs. Do not blindly run old request workflows.
HQ created isolated release sync branch attempt/scanlab-hq-release-sync-20261020-a1 from release HEAD and Draft PR #5625 from feature source. Mergeable true but 227 changed files, 1528 commits. Only for impact/recipe audit, NOT merged. Need explicit source lineage, S21 materialization semantics, codemagic build-number uniqueness, signer, TestFlight internal group and ASC readback before any build request.

## Pending
Product merged HEAD post-merge Native run39384562304 was queued/in_progress at last readback; former combined PR success is pinned to predecessor SHA. External auth E2E, live revocation, physical scanner quality still unverified; they must be clearly flagged in TestFlight acceptance.
No Codemagic build/start, Apple Upload, new TestFlight assignment, or App Review submission in STEP21.
## Late STEP21 discovery: synthetic release merge and CI source mismatch
- PR #5625 pull_request Native run39384694423 FAILED at S2 reconstruction static contract test_reconstruction_contracts.py:142, before XCTest. Auth E2E on this run actually PASS (password sign-in, profile RLS read/update, refresh, read after refresh, sign-out); the T40 integration PR run with different scope had skipped auth E2E. Keep these differentiated.
- Runner checked out synthetic merge `refs/remotes/pull/5625/merge` SHA 2fe980a4e6a681b84b88f32aa34570afd98ef458, NOT raw product feature HEAD01b08971. Explicit file readback: product calls `Self.preparePointCloudPLY` after Task.detached, but release parent3cbd4dc and synthetic merge use `SplatDepthSeedBuilder.preparePointCloudPLY` after Task.detached. Existing static test rigidly requires only legacy call and raises ValueError. This is release recipe compatibility, not a product XCTest regression. PR #5625 comment6285492589.
- HQ created isolated branch `attempt/scanlab-hq-release-contract-20261020-a1` from synthetic merge SHA, patched ONLY scripts/test_reconstruction_contracts.py to assert exactly one supported preparation method after detached before dataset and require explicit S13/S14 recipeVersion5 for dense path. Commit f73a50caec6c64fd482d0226cfa08391651e3e9e. Draft PR #5626 into isolated release-sync branch, Native CI run39385146100 QUEUED on readback. No release branch changes and no Codemagic triggered.
- PR #5625/5626 each touch 227 files due to divergent release history; do not merge merely to fix a test. Reconcile release lineage and validated build request first.

## Release contract PR #5626 subsequent test correction
- Initial PR #5626 Native CI run39385146100 FAILED at S2 static before XCTest due to HQ patch referring to Path without import (file already imports pathlib and defines ROOT). This was a patch authoring error, not a Swift failure.
- HQ corrected isolated contract to use `(ROOT / 'SplatNative' / 'SplatDepthSeedBuilder.swift').read_text()` through the existing pathlib root. Latest isolated contract commit 83aa33bfd7323188dfa21361b4655fb0e6bf8bdb. Native PR CI run39385373495 PENDING at readback; do not call PASS. Release branch/Apple unchanged.
