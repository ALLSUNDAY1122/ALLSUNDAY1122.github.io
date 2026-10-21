# STEP22 — Product integration readback and S21 release source reconcile
Date: 2026-10-20 JST. No new TestFlight build yet.

## Verified product integration
Product PR #5624 merged 2026-10-20T07:08:01Z, merge commit 01b08971a313045b3e5dc4aec79cc19d47ad1c38. Subsequent production feature/splat-native-ios-poc HEAD 69f365816bb1ae61a558f40778279b507bd705d6; Splat Native iOS Build run39425625513 SUCCESS. Smoke, privacy and S9/S10/S12/S13/S14 runs also succeeded on same HEAD. Live auth E2E in native job was SKIPPED for missing test identity.

## Release lineage risk identified
release/scanlab-testflight HEAD 3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a diverged from product feature branch: feature is 1530 commits ahead/7 behind relative to release base; release-only changes include codemagic.yaml and four Swift files ScanModel/ScanLibraryView/RootScanView/SplatResultView. Starting Codemagic on unchanged release branch would not guarantee included T34-T39 integrated product commit. Existing S16 gateway pinned workflow scanlab-ios, Codemagic branch release/scanlab-testflight, source Build14 identity, and S21 materialization recipe epoch5; no App Review submission.

## Actual isolated reconciliation
Created attempt/scanlab-release-candidate-20261020-a1 from release branch HEAD 3cbd4dc. Opened PR #5629 from latest product feature HEAD 69f36581 into isolated candidate; merged into isolated branch with GitHub merge commit 4f3a0de772df8e8d87e4d5b4932d717d596f17d8, remote head readback confirmed. Live release/scanlab-testflight remains unchanged.
Created Draft PR #5630 (candidate against product) solely to trigger independent combined Native iOS CI on reconciled candidate. It differs from product in five release-only files, 8 commits. Native run39433258555 IN_PROGRESS on last readback. Other PR checks queued/running. This is a diagnostic release candidate and must NOT be merged into product without semantic source comparison.

## Follow-up gates
Wait for Native iOS run39433258555 PASS and validate exact S21 materialized source, signed IPA compatibility and release recipe; inspect latest Apple Build and group live before allocating a unique next Build number; only then safely promote candidate source to release/scanlab-testflight (branch lock required) and request Codemagic. No build or upload attempted in STEP22.