# STEP23 — verified product merge and isolated release candidate
Date: 2026-10-20 JST. No Apple/Codemagic build dispatched.

## Product CI
PR #5624 had merged to product SHA01b08971a313045b3e5dc4aec79cc19d47ad1c38. HQ PR #5627 only modified splat-native-ios/scripts/test_reconstruction_contracts.py, passing Native CI run39412070392 with 251 XCTest / 0 failures. Marked #5627 ready and merged with expected head6bb72e0688e552d6b83f64ea2c8b0696b9bfd6f4, GitHub merge SHA69f365816bb1ae61a558f40778279b507bd705d6; independently verified feature/splat-native-ios-poc HEAD same.
Product HEAD latest native run39425625513 in progress at readback; targeted static Privacy/S9/S10/S12/S13/S14 successful on same SHA. Do not call full native CI pass until done.

## Release lineage assembly on isolated branch
Actual release/scanlab-testflight HEAD3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a was never changed. HQ isolation attempt/scanlab-hq-release-sync-20261020-a1 started from it. PR #5625 from feature into isolated branch was verified mergeable; 227 files, 1530 commits across divergent history; merged ONLY into isolated branch with expected feature HEAD69f365816bb1ae61a558f40778279b507bd705d6. Merged commit781466ef84c9db9f1be6ccabf07b67f1082beb71 readback.
Opened release-candidate QA Draft PR #5628 from isolation to release/scanlab-testflight without merging. This started Native iOS CI run39425853659, in progress on readback, plus privacy/depth/quality/memory/smoke gates.
Release Codemagic workflow scanlab-ios on isolated branch requires Xcode26+, strict S13/S14 epoch5 materialization, dynamic latest Apple TestFlight Build +1, signing keychain and appId6803778932 / bundle jp.allsunday1122.splatlab, submission to TestFlight true, App Store false. Actual isolated release branch has not been materialized/merged to real release branch. Legacy S21 workflow mutates live release branch and S16 gateway writes product source. Neither triggered.

## Not proven
Live Apple latest Build / beta group newly readback, Codemagic app/workflow identity, verified release candidate full Native CI, sign/IPA/tester group, real device Golden / auth security. No Codemagic Build, Upload, Internal TestFlight Build update or App Store Review Submit.
Control queue ownership remains HQ epoch1, Worker2 native epoch2/viewer epoch1, Worker1 stopped.

## Next
Inspect run39425853659 and product CI 39425625513, inspect GitHub release-candidate synthetic checkout hash/files/CI, address any failures on isolated branch only. Before building, verify release source provenance and Apple dynamic build number, group readback and authorized delivery chain.