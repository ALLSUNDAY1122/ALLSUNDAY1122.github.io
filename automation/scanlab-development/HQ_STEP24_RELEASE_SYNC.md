# STEP24 — Round3 verified product source to signed release branch
Date 2026-10-21 JST. Build/Apple upload NOT yet executed.

## Independent actual state
Product feature/splat-native-ios-poc HEAD 69f365816bb1ae61a558f40778279b507bd705d6; PR #5624 MERGED with merge SHA01b08971a313045b3e5dc4aec79cc19d47ad1c38. Latest native product CI run39444336078 SUCCESS. Release branch release/scanlab-testflight HEAD3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a is historical/stale. Its Codemagic YAML is the only existing signed scanlab-ios workflow; product codemagic.yaml is for other apps. Gateway S16 builds release branch, not feature branch.

## Release staging implementation (not production release branch)
Created attempt/scanlab-hq-release-source-sync-20261021-a1 from release HEAD3cbd4dcf. GitHub tree operation replaced exactly the splat-native-ios subtree with product subtree SHA757a14502078705deebecfb4bcd1720d0c58f2c0, preserving release root and codemagic.yaml blob SHA49b4456a833c70ef474342ee11194b9e46dbc30c. Commit ba6d751008246d6ea51166d4fd125f14b9eaa32c. Remote readback confirmed same subtree SHA and YAML blob SHA. Draft release-source PR #5634 targets release/scanlab-testflight; only this native subtree is changed, no unrelated root paths.
GitHub PR native test run39452914519 QUEUED at readback; targeted test jobs started. Do not claim full CI PASS yet, do not merge until successful.

## Acceptance before upload
1. Native CI and source tree SHA readback stable; confirm Xcode26 SDK, signing and unique next Build number via fresh Apple readback.
2. Merge PR #5634 only into release/scanlab-testflight; verify source subtree SHA exact product hash and sign config unchanged.
3. Trigger Codemagic scanlab-ios only after branch/code identity confirmed. Verify build's branch, commit, artifact and upload; do not submit to App Store.
4. ASC latest Build processing + internal tester group assignment must be independently read back. Previous Build18 was last confirmed in October 20 isolated readback; not presumed latest on October21.

## Safety boundary
No new signed IPA, no Codemagic build start, no Apple Upload or App Review Submit done by this STEP. Worker1 stopped; Worker2 owns two development scopes, HQ owns release.