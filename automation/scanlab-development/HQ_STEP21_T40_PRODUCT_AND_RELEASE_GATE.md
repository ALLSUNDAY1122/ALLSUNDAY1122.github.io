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