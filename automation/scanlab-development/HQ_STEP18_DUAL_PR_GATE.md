# STEP18 — Worker2 two-PR current-head integration gate
Date 2026-10-20 JST. Integration HOLD.

Control queue branch commit b96837c26877371616502a15f00eaa5408373b01, blob ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd; native SCANLAB-W1-001 owner WORKER_2 epoch2, viewer SCANLAB-W2-001 owner WORKER_2 epoch1, HQ epoch1. Worker1 STOPPED. Baseline feature/splat-native-ios-poc 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged.

Native takeover PR #5622 HEAD 439a75f9f80278ade8899c3c0726b268e194e914, 12 commits ahead of baseline. Added generation fence for Mesh frame writer reset races, camera pose temporal/homogeneous/orthonormal validation, negative pose/timestamp XCTest in CapturePolicyTests. Targeted Smoke, Privacy, S9, S10, S12 green on same SHA. Full Native CI run39371960452 IN_PROGRESS on check, no PASS claim. HQ PR comment6283899051.

Viewer/Library/Publish PR #5619 HEAD 38a3887cb0ddfb79de17f739472728aa5c342af7, 25 commits ahead of baseline. Full Native CI run39369794864 FAILURE, 248 XCTest / 2 assertions in 1 test SplatCompletionVerifierTests trusted prior same-size corruption recovery (completionEvidenceMismatch and backup remains). Smoke/Privacy/S10/S12/S13 pass but do not override full CI. HQ PR comment6283899425.

SplatCompletionVerifier and SplatPreviousResultEvidence/SplatStrongCompletionEvidence are shared restoration pieces; investigate trusted SHA-backed result and restored evidence + APFS replacement/mtime/ctime; do not relax tests or delete preserved backup on failure. Worker2 owns implementation work and should fix in native epoch2 branch, retest viewer branch after integration.

Both PRs draft/unmerged; no Codemagic, Apple upload, Internal TestFlight new Build or App Review submit. Last live Apple readback Build18.