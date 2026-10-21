# STEP17 — Independent QA after Worker1-to-Worker2 transfer
Date: 2026-10-20 JST. Integration HOLD.

## Governance
Control Queue b96837c26877371616502a15f00eaa5408373b01, blob ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd. SCANLAB-W1-001 owner WORKER_2 epoch2 native lock epoch2; SCANLAB-W2-001 owner WORKER_2 epoch1; HQ epoch1. Worker1 stopped; no communication.

## Current source and CI
Native takeover PR #5622 HEAD fe50fa70f80bf9d6d819aec0eaeced90c43f9c7d (8 ahead), run39369790036 IN_PROGRESS at readback. Prior run39367980809 attempt2 CANCELLED, not PASS.
Viewer/Publish PR #5619 HEAD 38a3887cb0ddfb79de17f739472728aa5c342af7 (25 ahead), run39369794864 FAILURE: 248 XCTests with 2 assertions in one test SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity at lines162 (completionEvidenceMismatch) and167 (previous trusted backup remains). Latest targeted smoke/privacy/memory/depth CI successful but does not override full Native CI failure.
Previous companion PR #5621 run39367475853 245/0 success on OLD head a050e1f, not current code.

## Probable shared cause to test
SplatCompletionVerifier.verifyWithDigest delegates to recoverTrustedPreviousAndVerify after strong integrity mismatch. Helper wraps any failure in completionEvidenceMismatch. SplatPreviousResultEvidence protects SHA256 backed-up asset and metadata, SplatStrongCompletionEvidence reseals restored previous asset. Verify precise failure branch, backup snapshot and originalEvidence, APFS replaceItem/mtime behavior, and CI synthetic merge SHA. Do not weaken assertion or delete trusted backup on failed integrity.
HQ posted PR #5619 comment6283650982 and PR #5622 comment6283651429 to Worker2 only; fix belongs native T34-T36 epoch2 branch.

## Release
Product feature HEAD 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged. Both PRs draft and unmerged. No Codemagic, Apple Upload, new TestFlight Build or App Review submission. Last live Apple Build18.