# T34–T36 Worker2 takeover — 2026-10-20

Task SCANLAB-W1-001: owner WORKER_2, epoch2 token SCANLAB-W1-001-a2-W2-20261020; lock scanlab:native-capture-reconstruction-export epoch2 re-read remotely. Dedicated PR #5622, not merged. Baseline HEAD a050e1fd78deb8094178242c4515aeb2819cb64a carried HQ's Mesh durability static fix (do not duplicate).

Baseline Native CI 39367475853 SUCCESS; XCTest 245, 0 failures verified from build log. Source audit found MeshCapture generation guard was only applied to the asynchronous completion, *after* JPEG disk write. Queued old writes could still reach disk after reset. Commit 36cc862ec1d9915d75adb89412fbdd560c8a37e7 adds NSLock-protected MeshFrameWriteFence rotate at both resets and gates worker JPEG write through performIfCurrent. Commit af25f5cccf8fee74aac4c8476a73a972ca0e1e6d updates static Mesh durability contract to require fence rotation before project detachment and queued writer fencing. Source and test readback verified.

Latest new Native iOS run 39369715024 pending at report creation; no PASS claim for new commits. Remaining: live lease/reset race tests, RAW/depth and export nondestruction under fault injection, physical device L4, HQ review. No merge, TestFlight upload or App Review.

## 2026-10-20 13:50 JST follow-up
- Commit 3139f6baeae77c87e0bc0a0f9dbabda000ed6bbf CapturePolicy.swift adds isValidCameraPose validating finite, homogeneous, orthonormal, right-handed transforms, including prior pose. Invalid timestamp rejects before capture write.
- Commit ab6ce6ecd24df81ef2d3adeb0003e4f7c6c8cc6b MeshScanModel.swift applies same pose/timestamp check before scanOrigin and JPEG/RAW capture.
- Commit 7f2aa5f52617148bd23cdb2d8144d6562456507d CapturePolicyTests.swift adds negative current/prior pose and time tests.
- Remote source/test file SHA readback completed, PR #5622 head 7f2aa5f. Native run 39371900498 IN_PROGRESS on check; no full PASS claim for new edits.
- Cross-branch CI observation: W2 PR #5619 Native run 39369794864 FAILED 248 XCTest, 2 assertions (1 unexpected), SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity. Library negative tests all passed. This existing integrity recovery behavior belongs to T34-T36; do not fix by permitting unsafe cross-generation rollback or silently weaken assertions. The transient test cause remains under investigation.

## Follow-up — Mesh write-fence executable regression
Prior PR #5622 HEAD 439a75f9 Native iOS run 39371960452 SUCCESS; 245 XCTest / 0 failure, all other gates success, read from job 118461848423. New commits 485baa49 (standalone MeshFrameWriteFence.swift), 871f712a (remove inline duplicate), 1b6744ac (XCTest target source), ab994c08 (static contract source correction), 2f89dee2 (test visibility), 646a036e (race tests), 57b4ec84 (sendability-safe concurrent counter). Tests verify stale generation cannot execute write and reset serializes with in-flight writer. Remote read-back all 5 files and PR head 57b4ec84 complete. Latest full Native CI 39373930668 QUEUED at readback; latest features not yet PASS. Retain NO-GO without full CI and HQ independent integration.

## STEP04 2026-10-20 13:50 JST: executable-test coverage
Native CI run 39374005638 SUCCESS, integrated XCTest 245 executed, 0 failures; complete GitHub Actions job 118467942614. However new standalone MeshFrameWriteFenceTests were COMPILED but not selected by workflow's explicit -only-testing list. Therefore prior CI does not prove those tests actually ran. Commit fb035c2902af51e031f372a0f8d54b1b6534770a added 2 fence invariant tests within selected MeshProjectStoreTests to ensure actual CI execution. Remote code sha cd331da9ceb5791bed2c8550d1df3ecf468164fd verified. Latest Native CI run 39375928118 QUEUED at readback; requires actual passing test names and increased integrated XCTest total before acceptance. No release or merge.

## STEP05 2026-10-20 14:59 JST — completed-result integrity recovery
Native CI run39376012429 at prior HEAD7934b750 FAILED: 247 integrated XCTest, 2 assertions in one failing SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity. The newly introduced two Mesh write-fence tests were included in the 247 count; failure was not in the Mesh test suite. Investigated SplatPreviousResultIntegrityRecovery: default FileManager.replaceItemAt may carry the corrupt target file metadata to the verified backup clone, so the trusted original completion seal then rejects the replacement's newer mtime. Code commit ff5476137eea5148908e1e0f6fa5f0fb48d37595 explicitly uses replacement options [.usingNewMetadataOnly] to preserve the SHA-verified backup's file metadata while still atomically promoting bytes. Remote source blob c5a0981b467aa0421f4dc6c433b4da9912910475 verified. Native run39377998447 pending at readback: fix NOT YET VERIFIED. This is a hypothesis until XCTest accepts it; fail-closed checks and generation/SHA equality were kept unchanged.

## STEP06 validated completion — 2026-10-20
At W1 takeover HEAD 646af36e5c09b3ec47d6e1f0740a2ef30ea9a1ca, Native iOS workflow run 39378056885 completed SUCCESS (job 118480580492). Integrated XCTest executed **247 tests, 0 failures**. Explicit log readback: MeshProjectStoreTests.testCaptureFencePreservesFailureOfCurrentGeneration PASS; testCaptureFenceRejectsQueuedOldGenerationWithoutDiskSideEffects PASS; SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity PASS. All same-HEAD Privacy, Smoke, S9, S10, S12, S13 success. The verified recovery source change ff547613 preserves SHA-verified prior file metadata on atomic replacement. This is CI success, NOT real iPhone storage-fault acceptance; PR remains draft/unmerged, HQ independent audit still required.

## HQ2 STEP37 focused recovery triage — 2026-10-21 JST

STATUS: IN_PROGRESS; no native repair accepted or new full-suite CI PASS claimed.

Authority: control Queue SHA ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd; task SCANLAB-W1-001 owner WORKER_2 epoch2 token SCANLAB-W1-001-a2-W2-20261020; lock scanlab:native-capture-reconstruction-export epoch2. Previous attempt HEAD dbcc8ba02cff0daad56593fc36c733167664f0f0, PR #5622 draft. HQ2 handoffs read: HQ2_STEP29_WORKER2_RECOVERY_HANDOFF.md and HQ2_STEP37_NATIVE_RECOVERY_TRIAGE.md (HQ branch). Release candidate 4f3a0de772df8e8d87e4d5b4932d717d596f17d8, CI run39433258555 FAILED: 251 XCTest, 2 assertions in a single failing SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity. On the separate Worker2 old HEAD dbcc8ba02... native run39380199091 SUCCESS, but does not certify candidate.

Worker2 scoped triage changes (no release branch touched):
- 7cd6832726d892d0d2e496ebaa6c6b203590e2c4: test-only sanitized snapshot/commit timestamp comparisons and backup SHA witness, without user bytes.
- 280a9f9c71e9b0e0bb5a57b5ad16620ef514e4ad: DEBUG + opt-in staged diagnostic messages for evidence, backup and materialized partial; no weakening of safety guards.
- 8bc71dfbbc7081d6f2b449a087c499443b8886ac: test-only scoped diagnostic environment flag.
- 9020b2f1874e2f598705510b9d5689c42c2c9c10: expose existing generation eligibility predicate to XCTest (same behavior).
- b9446fc40f747e42d6591504d7dc1f0e04e53e6e: deterministic positive/negative generation guard tests (matching valid lineage; late preservation; backwards completion; different byte-count).
GitHub compare verified these commits are ahead of former W2 HEAD, source blob readback performed. Workflow runs on new commits not found at check, so XCTest case count / failure count on diagnostics HEAD are UNVERIFIED. Do not claim repair done, pass or merge. No unsafe rollback eligibility expansion, no customer content logged, no trusted backup deleted.

Next acceptance: retrieve full native CI on exact new HEAD and diagnostic witness, identify early false vs throwing/verification failure; fix only confirmed predicate or metadata fault, run whole XCTest 0 failures. HQ2 alone owns integration, release and Apple.
