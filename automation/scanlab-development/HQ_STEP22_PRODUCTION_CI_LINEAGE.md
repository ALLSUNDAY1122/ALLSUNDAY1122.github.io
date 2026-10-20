# STEP22 — production merge readback and S2/S13 CI provenance repair
Date 2026-10-20 JST.

## Verified product integration
Product PR #5624 MERGED 2026-10-20T07:08:01Z, merge commit 01b08971a313045b3e5dc4aec79cc19d47ad1c38. Remote branch feature/splat-native-ios-poc readback same commit. Pre-merge integrated Native iOS run39382480195 SUCCESS 251 XCTest/0 failures; smoke/privacy/S9/S10/S12/S13 checks PASS. This is source integration, NOT TestFlight upload.

## New post-merge CI failure provenance
Native iOS run39384694423 FAILED at step S2 reconstruction contracts, before XCTest: test_reconstruction_contracts.py line142 MODEL.index('Self.preparePointCloudPLY', detached) ValueError. Job118501810602 checkout specifically refs/remotes/pull/5625/merge commit 2fe980a, which merges product HEAD01b08971 into external/base SHA3cbd4dcfe650, NOT a direct checkout of the product branch.
Product HEAD ScanModel.swift still contains Self.preparePointCloudPLY after Task.detached, while synthetic PR merge replaces it with SplatDepthSeedBuilder.preparePointCloudPLY for S13 depth-aware seeding. The script's fixed source string is obsolete on that merge layout, even though processing remains in detached worker before GaussianDataset.
Unlike older CI, live auth E2E in run39384694423 reported PASS (sign in, profile RLS read/update, session refresh, signout). This does not prove lost-ACK/revoked grants end-to-end.

## Actual correction
Created branch attempt/scanlab-hq-s2-s13-contract-20261020-a1 from product HEAD01b08971. Changed only splat-native-ios/scripts/test_reconstruction_contracts.py to accept either `Self.preparePointCloudPLY` or `SplatDepthSeedBuilder.preparePointCloudPLY` after detached worker begins, before GaussianDataset, rejecting either call during finishCapture. Commit6bb72e0688e552d6b83f64ea2c8b0696b9bfd6f4. Draft PR #5627 targeting product. PR Native CI run39412070392 QUEUED at first check, not PASS or merged yet.

## Governance/release
Control Queue content SHA ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd: HQ epoch1, native Worker2 epoch2, viewer Worker2 epoch1; Worker1 stopped, no contact. No new Codemagic iOS build, Apple upload, TestFlight group assignment, or App Review submission. Last independently verified Apple build18 remains historical to this STEP; live present Apple state not rechecked. Release HOLD until repair PR CI, product post-merge CI, packaging and ASC readback.