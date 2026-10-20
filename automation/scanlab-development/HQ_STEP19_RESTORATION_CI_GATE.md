# STEP19 — latest head double-PR CI audit
2026-10-20 JST — independent HQ. RELEASE HOLD.

## Live readback
Queue control HEAD b96837c26877371616502a15f00eaa5408373b01, blob ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd. Former W1 task now WORKER_2 epoch2, viewer WORKER_2 epoch1, HQ epoch1. Worker1 stopped; no contact.
App feature/splat-native-ios-poc SHA 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged.
Viewer/publish PR #5619 HEAD c1f7f150d3cf3d85f0f6c38277029df99c5f304a, full Native iOS run 39374009604 SUCCESS with 248 XCTest and 0 failures, static/memory/privacy/smoke PASS. CI_GREEN for current viewer HEAD, not proof that all T37-T39 production privacy fault injection is done.
Native takeover PR #5622 HEAD 7934b750b701c5d999f135a43fd5510ad3cebd42, latest Native iOS run 39376012429 FAILURE: 247 XCTest with 2 assertions from ONE test SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity (line162 completionEvidenceMismatch, line167 prior backup still present). Other static/memory/depth/privacy/smoke checks PASS at this HEAD. Prior Native HEAD37a13dea72 run39374005638 succeeded 245/0; older result cannot certify newest code.

## Action and hypothesis
HQ PR #5622 comment6284491597 requests pinpoint failure along SHA-backed previous-result asset restore, old seal, APFS replaceItem and mtime/ctime; preserve good previous backup on failed validation and do not weaken fail-closed assertions.
HQ triggered GitHub rerun of failed workflow run jobs for 39376012429; result pending at report write.
Code inspection confirms SplatCompletionVerifier.verifyWithDigest delegates to recoverTrustedPreviousAndVerify, which masks inner failures as completionEvidenceMismatch; SplatPreviousResultEvidence/materializeExactFile verifies SHA copy and swaps output, and SplatStrongCompletionEvidence.verifyOrSeal uses seal/evidence timestamps and inode snapshots. These are hypotheses only, not verified root cause.

## Gate
Both Worker2 scopes remain distinct fenced branches, PRs draft, no merge. Integration and T40 blocked until native HEAD CI pass repeatably and both scope acceptances independently evaluated. No Codemagic, Apple upload, Internal TestFlight group assignment or App Review submit. Last verified ASC latest Build18.