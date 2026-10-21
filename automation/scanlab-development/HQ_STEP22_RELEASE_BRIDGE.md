# STEP22+ — Verified product CI, ASC readback, isolated release bridge
Date: 2026-10-20 JST.

## Product completion status
PR #5624 merged at 2026-10-20T07:08:01Z, merge commit 01b08971a313045b3e5dc4aec79cc19d47ad1c38. Current product branch feature/splat-native-ios-poc HEAD69f365816bb1ae61a558f40778279b507bd705d6 includes S13/S14 seed test improvements. Native CI run39433159753 SUCCESS, 251 XCTest, 0 failures, plus relevant privacy/smoke/S9/S10/S12/S13/S14 workflows success. Live auth E2E skipped because test identity not supplied.

## Live Apple read-only verification
HQ ran isolated read-only workflow39444146086 on HQ attempt commit a155dba015bdfe856bd0481e331b68534a3d70db. SUCCESS logs: latest_build=18 and internal_group_explicitly_linked=True, correct app ID6803778932, bundle jp.allsunday1122.splatlab; upload artifact ID12274529425, digest SHA256 4407807643b9c64508ef498dcc9b766429ef48169e874aa5b340fa57d11ab683. No new Apple upload or group mutation.

## Release-source branch split hazard and actual preflight progress
Current release/scanlab-testflight HEAD3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a and product HEAD69f365816bb1 diverged. Release has 7 unique materialization commits affecting codemagic.yaml and four Swift source paths. Starting Codemagic at old release head would not build current T40 product source; prohibited.
HQ created isolated branch attempt/scanlab-hq-release-bridge-20261020-a1 from release head, opened PR #5632 from product to isolated branch, confirmed mergeable and merged ONLY to isolated branch: bridge commit42cca234e634deb0ac1fe315645216c66785b971. Codemagic.yaml retains 'Verify immutable materialized reconstruction source' and ScanModel retains depth seed inputs. No actual release branch touched.
Opened draft release promotion PR #5633 from isolated bridge to release/scanlab-testflight. PR native CI run39444484745 queued at readback; other static/privacy/smoke tests underway. Do not merge PR #5633 until full CI and preflight SHA/recipe proof. No Codemagic build started.

## Gates
Prior user decision: WORKER_1 permanently stopped; WORKER_2 implementation owner both claims native epoch2, viewer epoch1, HQ epoch1. No App Review submission. Next: verify PR #5633 synthetic merge CI and release source immutable recipe, merge with exact HEAD if safe, trigger a single pinned Codemagic build via authorized gateway, poll, verify ASC next Build and tester group assignment readback. Do not infer Build19 from Build18.