# Scan Lab STEP 02 — Release Governance Evidence

Date: 2026-10-20. State: IN_PROGRESS. App Review Submit prohibited.

## Live GitHub verification
- Parity baseline: feature/splat-native-ios-poc @ 2bcbbd6128863739ad168610cd2e3f8e3b01b458
- PR #4145: open/draft/unmerged
- Queue: automation/scanlab-development/queue.json on branch automation/scanlab-hq-control-20261020
- SCANLAB-HQ-001: CLAIMED with CAS and remote read-back, attempt 1, claim epoch 1, token SCANLAB-HQ-001-a1-20261020
- Worker tasks SCANLAB-W1-001 and SCANLAB-W2-001: READY, not claimed
- This attempt branch: attempt/scanlab-hq-001-20261020-a1

## Historical identity — live Apple check still UNKNOWN
- App ID 6803778932; Bundle jp.allsunday1122.splatlab
- Evidence: automation/scanlab-asc-readback-result.json (2026-09-10 historical readback)
- Historical Build 17: VALID / INTERNAL_ONLY / IN_BETA_TESTING
- Current Apple build/group state and next build number UNKNOWN, not assumed.
- Registry updated only in attempt branch, not merged to main/control.

## Execution state
- Production Swift edits: 0
- CI / Codemagic / IPA / Upload during this attempt: NOT_RUN
- Apple live readback / group assignment: NOT_RUN
- Route: GitHub Actions -> Codemagic, no Xcode Cloud.
- No duplicate builds, no secrets, no App Review submission.

## Next
Reviewable PR for registry and governance, then authenticated Apple readback and precise file ownership allocation before Workers alter product code.

## STEP03 (2026-10-20)
- Worker ownership contract saved at automation/scanlab-development/OWNERSHIP_CONTRACT.md.
- Existing S17 readback workflow is branch-push-triggered and writes result to shared feature branch; current HQ release governance lock does not authorize that shared branch write. Not executed. Apple current state UNKNOWN.
- Existing S17 readback fetches latest build fields but not betaGroup relationship; assignment remains unverified.
- Worker tasks remain READY; prompts do not constitute Atomic Claims. Workers must CAS and read back before edits.
- Verified example Swift anchor files on 2bcbbd61. Product code, CI, Codemagic, Apple state unchanged by this STEP.
- NEXT: implement isolated, safe ASC readback route with group assignment and then authorize Worker claims.

## STEP04 (2026-10-20) — Live Apple evidence
- Implemented isolated ASC readback at automation/scanlab-development/asc_isolated_readback.py and .github/workflows/scanlab-isolated-asc-readback.yml, with read-only GitHub contents permissions, no push to production branch.
- Run https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/39343291138 completed SUCCESS for trigger commit 686c134378389a1a2e4e33ade98ada19ad8b4b34.
- Independently retrieved job logs: PASS latest_build=18; internal_group_explicitly_linked=True; app identity assertions PASS; beta group schema PASS.
- Evidence artifact ID 12229568807 (expires after 7d), ZIP SHA256 1c33c453a1b69089ef1581e6734057e9f6ac1ef68969bd480f1d876e462cf613.
- Current processingState and internalBuildState were captured to workflow artifact but not independently inspected by HQ; retain UNKNOWN for these fields. Build 18 is live latest by ASC query.
- Workflow only READ Apple API, no new Build/Upload, no group mutations, no App Review Submit.
- Risk: Repository push also started unrelated workflows. They reported failures in GitHub runs; avoid additional broad push triggers until scope/trigger guards reviewed. No evidence of a Scan Lab product Build triggered by these failures.
- Worker queues remain READY/unclaimed; each assigned worker claims its own task by GitHub SHA CAS and reads it back.
- NEXT: harden/review isolated workflow and obtain durable evidence of processingState/internal group details; then authorize Worker Claim & P0 implementation.

## STEP05 (2026-10-20) — atomic worker delegation
- Live control Queue readback: automation/scanlab-hq-control-20261020 @ commit 7196cc2776f38fe9260c6cf5fa244fba4c5563c0.
- Atomic SHA-CAS claim update, then remote-readback verified three task claims and three resource lock records.
- W1: SCANLAB-W1-001 CLAIMED epoch 1, token SCANLAB-W1-001-a1-20261020, branch attempt/scanlab-w1-20261020-a1.
- W2: SCANLAB-W2-001 CLAIMED epoch 1, token SCANLAB-W2-001-a1-20261020, branch attempt/scanlab-w2-20261020-a1.
- Both attempt branches created successfully and independently read back at immutable baseline 2bcbbd6128863739ad168610cd2e3f8e3b01b458.
- Ownership delegation was performed by HQ; individual Worker chats must independently read-back the token and lock before any source change. Do not generate a second claim for already CLAIMED tasks.
- P0 Swift code changes, CI verification and new Codemagic Build: NOT_RUN.
- Future integration requires head reread plus lock epoch recheck. Existing PR #4145 stays draft/unmerged.
- NEXT: each Worker executes first P0 implementation under their claimed attempt branch; HQ integrates only independently verified PRs and validates Build18 evidence baseline.

## STEP06 (2026-10-20 09:34 JST)
- W1 remote HEAD dc1dc00c5452f9ffdac6a3c889fce49be0acc8a9; exactly one changed file CapturePolicy.swift, +12 lines. Validation of current pose and timestamp added, prior pose and orthonormality still unverified. No test status contexts returned.
- W2 remote HEAD 1d2aab05fbbc6783d7a7c840779206810ada8e35; only W2_STEP04_FINDINGS.md added. Describes uncalibrated meters and read-time sidecar write, no fix yet. No test status contexts returned.
- Independent integration review: automation/scanlab-development/HQ_STEP06_INTEGRATION_REVIEW.md, HOLD both workers; do not merge or build.
- Queue claims unchanged epoch1; other work remains isolated. Apple live latest Build18 from STEP04.
- NEXT: complete P0 changes and obtain targeted XCTest/CI evidence per worker, then merge in serial after rechecking live locks.

## STEP08 — 2026-10-20
- Control Queue CLAIMED W1/W2 epoch 1; live worker HEAD W1=f5bb67a83f0d912ed56c64e180b41b7e0b7507b8, W2=c1b836d69cd84fa8fb91c66e87cfae3e4cd36aa3.
- W1 expanded to 3 production files: CapturePolicy.swift, MeshScanModel.swift, ScanModel.swift. Native iOS run 39350766509 SKIPPED due to workflow job `if` restrictions on worker attempt branches; no passing full native suite verified.
- W2 remains same HEAD. Native iOS run 39348580713 FAILED 245 XCTest / 2 failure, invalid primary JSON still unrepaired after export preflight/materialization.
- HQ root-cause inspection: SplatViewerEditStore.load() now read-only (desirable), but export preflight/materializer and two preexisting tests expect explicit durable repair. No code ownership crossing by HQ.
- Detailed contract: automation/scanlab-development/HQ_STEP08_RECOVERY_CI_CONTRACT.md. W1/W2 integration HOLD. No merge, Codemagic, Apple Upload, new Build, or App Review Submit.
- NEXT: explicit export repair (W2) plus nonmutating viewer read test, W1 pose/generation tests, full native CI via eligible PR/check.

## STEP10 — 2026-10-20
- W1 HEAD 31ba91fdd7 unchanged: PR #5620 native static contract FAILURE, XCTest not reached. HQ PR comment 6281537287 posted.
- W2 HEAD c2e66169b76f: Library read-only census added. Full native CI run 39354704378 FAILED: 245 tests, 1 failure Export preflight backup recovery. HQ PR comment 6281537703 posted.
- HQ independent review written: automation/scanlab-development/HQ_STEP10_REVIEW.md.
- Both tasks CLAIMED epoch1 unchanged; neither integrated; no new Codemagic/Apple build/upload/review.
- NEXT: Worker-specific fixes and passing complete CI before integration.

## STEP11 — 2026-10-20
- Worker1 HEAD 31ba91f unchanged; full Native iOS CI run 39354568521 failed old mesh durability static contract before XCTest; PR #5620 actionable escalation comment 6281816710.
- Worker2 HEAD 30b9a777 (11 commits); Swift publish ACK failure no longer triggers destructive owner cleanup. Full Native iOS CI run 39356743067 failed old Node contract requiring literal cleanupFailedDraft, before XCTest; PR #5619 actionable comment 6281816314. Previous corrupt primary export recovery failure still unverified.
- HQ review automation/scanlab-development/HQ_STEP11_AUDIT.md. Both HOLD, no release.

## STEP13 — 2026-10-20
- W2 HEAD 285933362b6d: native CI run 39360508896 SUCCESS; 245 XCTest executed, 0 failures, static checks PASS. Separate smoke/privacy/memory CI GREEN. Source assertion for old destructive cleanup corrected.
- CI_GREEN does not imply full P0 acceptance. ExportAdmission test now checks corrupted primary remains byte-for-byte unchanged, but does not prove actual export uses backed-up settings. Lost ACK source-only sentinel and T38 revocation race are not sufficient security proof. HQ comment PR #5619 ID 6282411350 and audit HQ_STEP13_CI_GREEN_SEMANTICS_GATES.md.
- W1 HEAD 31ba91fd stagnant; Native PR CI 39354568521 static failure; no passing full XCTest.
- Both locks CLAIMED epoch1; neither code branch merged. Apple last live Build18; no new build/upload/review.

## STEP14 — 2026-10-20
- W2 HEAD 26839ecc8a51 ahead17; Native iOS run 39362812776 SUCCESS, 245 XCTest / 0 failures; privacy/smoke/S10/S12 success. Publish temporary package retained on uncertain ACK, removed only after confirmed server outcome. Outstanding: bounded retention/reconciliation, real lost-ACK fault tests, T38 revocation/republish, backup settings applied on export. HQ PR #5619 comment 6282770714.
- W1 HEAD 31ba91fdd7 stagnant, Native CI run 39354568521 static mesh durability failure, XCTest blocked. HQ PR #5620 comment 6282772587.
- HQ audit automation/scanlab-development/HQ_STEP14_RELEASE_RISK_REVIEW.md. Both source branches unmerged; no Codemagic, Apple upload, TestFlight update, App Review submit. Apple last live Build18.

## STEP15 — 2026-10-20
- W1 reset source `MeshScanModel.reset()` confirmed nondestructive: guard before generation change, projectURL detach without removeItem. Old static check assumed removeItem existed and failed. HQ created separate branch `attempt/scanlab-hq-mesh-contract-20261020-a1` fork W1 HEAD 31ba91fd and patched only `scripts/test_mesh_durability_contract.py` to verify nondestructive reset invariant. Companion commit a050e1fd78de, Draft PR #5621 into W1 attempt. Pull request Native iOS run 39367475853 IN_PROGRESS at readback, not PASS. W1 source branch unchanged.
- W2 HEAD 26839ecc unchanged, prior Native CI run 39362812776 SUCCESS (245 XCTest, 0 failures); T37/T38 fault injection and staging reconciliation still pending.
- HQ audit `automation/scanlab-development/HQ_STEP15_MESH_CONTRACT_PATCH.md`. Worker locks epoch1 maintained, product unmerged. No new Codemagic, Apple upload, TestFlight assignment, App Review submission.

## User-directed worker stop and transfer — 2026-10-20
- WORKER_1 stopped by user due to persistent safety-gated GitHub write attempts. No further tasks or messages directed to W1.
- Control Queue atomically CAS updated commit b96837c26877371616502a15f00eaa5408373b01; remote readback content SHA ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd. W1 task SCANLAB-W1-001 transferred owner WORKER_2, attempt2/claim epoch2, token SCANLAB-W1-001-a2-W2-20261020 and native resource lock epoch2. Old epoch1 fenced out. W2 task remains unchanged CLAIMED epoch1; HQ CLAIMED epoch1.
- New takeover branch attempt/scanlab-w1-takeover-w2-20261020-a2 created from companion commit a050e1fd78de (original W1 head + HQ nondestructive Mesh reset static contract correction). Draft PR #5622 to product feature; original #5620 and companion #5621 historical/unmerged. W2 original PR #5619 stays active on its own branch (HEAD 067902285e71c15af5d53623b66b9d06688d622f at transfer check).
- Ownership contract amended by HQ. PR #5619 transfer notice comment 6283158823. Native iOS run 39367980809 IN_PROGRESS on takeover PR at check; not PASS yet. No integration, Codemagic, Apple upload or App Review submit.
- Sole implementation worker is now W2 for T34–T39; each task still has a separate fenced branch/claim. HQ alone owns integration/release.

## STEP16 — 2026-10-20 (after W1->W2 transfer)
- Queue readback: former W1 task owner WORKER_2 epoch2, native lock epoch2. Original W2 task WORKER_2 epoch1. HQ epoch1. Worker1 stopped, no contact.
- Native successor PR #5622 head a050e1fd78de. Companion PR #5621 run39367475853 Native CI SUCCESS 245/0; successor PR #5622 run39367980809 Native CI FAILURE 245 tests / 2 failed assertions in SplatCompletionVerifierTests restoration/previous trusted asset cleanup (completionEvidenceMismatch). Differing PR merge bases may explain effective source differences; needs runner SHA/readback, not assume flakiness.
- HQ commented PR #5622 ID6283324587, triggered rerun failed workflow run jobs for 39367980809; attempt2 IN_PROGRESS at readback. HQ investigation file HQ_STEP16_TRANSFER_QA.md.
- Current W2 T37-39 head 067902285e71, release acceptance still OPEN. No integration, Codemagic, Apple upload or App Review submit. Prior latest Apple Build18.

## STEP17 — 2026-10-20
- User-stopped Worker1 remains stopped; ownership Queue b96837c epoch2 native assigned to Worker2, its viewer/publish task epoch1 unchanged.
- PR #5622 native takeover head fe50fa70f80 (8 commits ahead); native run39369790036 IN_PROGRESS. Previous run39367980809 attempt2 CANCELLED, not PASS.
- PR #5619 viewer/publish head 38a3887cb0dd (25 ahead); run39369794864 native FAILED, 248 tests with 2 assertions in SplatCompletionVerifierTests trusted previous restoration (completionEvidenceMismatch, prior trusted backup retained). Other targeted CI success cannot override this.
- HQ commented #5619 comment6283650982 and #5622 comment6283651429 to Worker2, and wrote HQ_STEP17_CURRENT_HEAD_CI.md with shared recovery diagnosis. Both PRs draft/unmerged. No Codemagic/Apple/new TestFlight/App Review submit.

## STEP18 — 2026-10-20
- Queue lock/claims unchanged since transfer: owner WORKER_2 both implementation tasks, native epoch2, viewer epoch1. Worker1 stopped.
- Native PR #5622 HEAD 439a75f9f8: Mesh generation-fenced frame writes, camera pose/previous pose/time negative tests. Smoke/Privacy/S9/S10/S12 success; full Native run39371960452 IN_PROGRESS, not PASS at readback.
- Viewer PR #5619 HEAD 38a3887cb0: latest Native run39369794864 FAILED, 248 XCTest / 2 assertions in SplatCompletionVerifierTests previous-result integrity recovery. Both PRs still HOLD.
- HQ comments PR5622 6283899051 and PR5619 6283899425; HQ audit HQ_STEP18_DUAL_PR_GATE.md. No merge/Build/TestFlight/App Review.

### STEP18 late verified CI readback
- Native takeover PR #5622 HEAD 439a75f9f80278ade8899c3c0726b268e194e914 full Native iOS run39371960452 completed SUCCESS, integrated XCTest 245 tests / 0 failures and static checks PASS. This supersedes the earlier IN_PROGRESS readback in STEP18. Worker2's native change set is CI_GREEN; additional P0 acceptance/combined T40 remain needed.
- Viewer PR #5619 HEAD38a3887c latest run39369794864 FAILED 248 XCTest / 2 assertions; do NOT merge or release combined app yet.

## STEP19 — 2026-10-20
- Current T37-T39 PR #5619 HEAD c1f7f150d3cf: native run39374009604 SUCCESS with 248 XCTest/0 failures; same-HEAD privacy/smoke/depth/memory targets PASS. CI green but remaining security acceptance still separate.
- Current T34-T36 takeover PR #5622 HEAD 7934b750b701: native run39376012429 FAILED 247 XCTest, 2 assertions in one prior trusted result restoration test (completionEvidenceMismatch, backup retained); same-HEAD targeted jobs PASS. Prior success on old head37a13dea72 not sufficient.
- HQ direct comment PR5622 #6284491597, failed-jobs rerun requested on run39376012429; rerun pending. HQ evidence HQ_STEP19_RESTORATION_CI_GATE.md. Ownership unchanged: native Worker2 epoch2, viewer Worker2 epoch1. Worker1 stopped. Do not merge/build/upload.

## STEP20 — 2026-10-20
- Worker2 native head dbcc8ba02cff: Native CI run39380199091 SUCCESS 247 XCTest/0. Worker2 Viewer head18987c29eda: Native CI run39380203683 SUCCESS 249 XCTest/0. Current Queue verified native epoch2, viewer epoch1, HQ epoch1; Worker1 stopped.
- HQ isolated integration branch attempt/scanlab-hq-t40-integration-20261020-a1 created from native head. Viewer-to-isolated HQ PR #5623 merged successfully (expected head18987c29eda); merge SHA 0c0b7207c80e9c6294a4d7487d1de92de04ca46b, independently read-back.
- Draft combined QA PR #5624 opened to feature/splat-native-ios-poc; NOT merged. Combined PR Native run39382480195 in progress at readback; other targeted checks started. Evidence HQ_STEP20_INTEGRATED_T40.md.
- No production merge, Codemagic, Apple upload, TestFlight update, App Review submission. Last live ASC Build18.

## STEP21 — 2026-10-20
- T40 combined integration PR #5624 Native iOS run39382480195 completed SUCCESS, 251 XCTest/0 failures, static + Mesh repeated tests. Smoke/Privacy/S9/S10/S12/S13 success. Live Auth E2E SKIPPED (missing test identity), physical QA/privacy revocation acceptance outstanding.
- Verified PR #5624 expected HEAD0c0b7207, marked ready, merged into product `feature/splat-native-ios-poc` at new SHA01b08971a313045b3e5dc4aec79cc19d47ad1c38; remote branch readback exact match. Postmerge CI pending at original observation.
- Release source `release/scanlab-testflight` HEAD3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a differs 7 unique commits. HQ isolated release-sync branch `attempt/scanlab-hq-release-sync-20261020-a1` from it; Draft PR #5625 pointing product source there, mergeable true but very broad 227 files / 1528 commits. NOT MERGED. Existing S16/S21 gateway tied to older release materialization needs validation before build.
- HQ report HQ_STEP21_T40_PRODUCT_AND_RELEASE_GATE.md. No Codemagic Start, Apple Upload, TestFlight assignment or App Review submit.

### STEP21 release candidate verification amendment
- Release-sync Draft PR #5625 synthetic checkout SHA2fe980a4e6a681b84b88f32aa34570afd98ef458 hit S2 reconstruction static test line142 (expects legacy Self.preparePointCloudPLY); release recipe uses SplatDepthSeedBuilder.preparePointCloudPLY, both after Task.detached. This failure is isolated to synthetic release lineage, not product T40 run. On this run auth live E2E PASS (sign in/profile RLS/refresh/signout).
- HQ patched isolated release recipe static test to validate legacy OR pinned epoch5 dense preparation after detached, before dataset, under independent branch attempt/scanlab-hq-release-contract-20261020-a1. Commit f73a50caec6, Draft PR #5626; Native CI run39385146100 QUEUED at check, no PASS claim. Release/scanlab-testflight untouched.
- Do not run legacy S16/S21 gateway until release candidate source/pinning/security and build number readback is confirmed. No Codemagic trigger/Apple upload.

## STEP22 — 2026-10-20
- PR #5624 was truly MERGED (commit 01b08971a313) into product feature/splat-native-ios-poc; GitHub branch readback matches. Prior integrated PR combined run39382480195 was 251 XCTest/0 failures.
- Post-merge PR #5625 synthetic merge SHA2fe980a triggered Native CI run39384694423 failure at S2 source contract before XCTest; source in synthetic merge uses SplatDepthSeedBuilder.preparePointCloudPLY rather than legacy Self.preparePointCloudPLY (product HEAD unchanged). Live auth E2E in same run PASSED.
- HQ fixed only reconstruction contract Python to accept either implementation in detached worker, before GaussianDataset and never in finishCapture. Isolated branch attempt/scanlab-hq-s2-s13-contract-20261020-a1 commit6bb72e0688, Draft PR #5627 to product. PR Native CI run39412070392 IN_PROGRESS; not yet merged. Audit HQ_STEP22_PRODUCTION_CI_LINEAGE.md.
- Queue W2 native epoch2, W2 viewer epoch1 and HQ epoch1 read back intact; Worker1 stopped. No Codemagic, Apple upload, TestFlight assignment or App Review submit. Apple latest confirmed Build18, not freshly re-read this STEP.

## STEP23 — 2026-10-20
- PR #5627 one-file reconstruction contract fix merged to product with SHA69f365816bb1ae61a558f40778279b507bd705d6, from verified 251 XCTest/0 Native run39412070392. Latest product CI run39425625513 IN_PROGRESS at readback.
- Release candidate assembled on isolated branch attempt/scanlab-hq-release-sync-20261020-a1 via PR #5625 merge SHA781466ef84c9db9f1be6ccabf07b67f1082beb71. Real release/scanlab-testflight unchanged SHA3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a.
- Draft release-candidate QA PR #5628 to real release branch exists but is UNMERGED; full Native CI run39425853659 in progress at readback. Source lineage diverges by 227 changed files and requires full acceptance; isolated Codemagic scanlab-ios checks Xcode26+, epoch5 recipe, Apple Build+1, signing and TestFlight-only publishing.
- Neither unsafe S16/S21 gateway triggered. No Codemagic build, Apple upload, TestFlight assignment or App Review submit. HQ evidence HQ_STEP23_RELEASE_CANDIDATE.md.
