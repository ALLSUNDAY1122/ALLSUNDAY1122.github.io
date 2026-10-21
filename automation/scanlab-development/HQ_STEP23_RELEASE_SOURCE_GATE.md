# STEP23 — production integration readback and release source provenance
2026-10-21 JST. Release candidate HOLD pending source sync.

## Verified production state
PR #5624 merged as 01b08971a313045b3e5dc4aec79cc19d47ad1c38. Product feature/splat-native-ios-poc now 69f365816bb1ae61a558f40778279b507bd705d6, two commits ahead of PR merge, latest comparison shows only splat-native-ios/scripts/test_reconstruction_contracts.py changed.
Native iOS run39444336078 SUCCESS for current product SHA, integrated XCTest 251 tests 0 failures. Smoke, Privacy, S9, S10, S12, S13 and S14 workflows SUCCESS for that head.
Control Queue still native WORKER_2 epoch2, viewer WORKER_2 epoch1, HQ epoch1. W1 stopped.

## Apple read-only evidence
HQ updated trigger automation/scanlab-development/asc-readback-trigger.json via commit 2dc3d020496245aab147ca3223f2f93ca6bb3a4f. Workflow Scan Lab Isolated ASC Build and Internal Group Readback run39456131379 SUCCESS. Logs: latest_build=18 and internal_group_explicitly_linked=True. Artifact id12281336252, zip SHA256 ed78eb827bb3299eac162d782471ffbe37b6bf7384b8816d3ec46e4e763c5f2b (expires 2026-10-27T16:17:46Z). This is READ-ONLY; does not indicate new app source uploaded.

## Release source divergence
Codemagic scanlab-ios workflow uses release/scanlab-testflight, current HEAD 3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a, NOT current product HEAD. Comparison shows diverged: product 1530 ahead and release 7 ahead, 227 changed files; cannot safely initiate build of old release branch.
Created DRAFT source sync PR #5635 from current product SHA69f365816bb1 to release/scanlab-testflight. GitHub mergeable=true but merge state=unstable, CI/source provenance and 7 release-only commits must be reviewed before release-branch write. No merge.
Legacy S16 gateway on product branch triggers only by modifying automation/scanlab-release-request.json; its build branch is release/scanlab-testflight. S21 materialization also pushes to release branch, so direct invocation without fenced source review would risk overwriting current verified source.

## Next
Audit seven release-only commits; produce fenced release source integration candidate, validate Codemagic immutable recipe and signed artifact provenance; then request one unique Internal TestFlight build and verify Apple processing+internal group after upload. No App Review submission.
