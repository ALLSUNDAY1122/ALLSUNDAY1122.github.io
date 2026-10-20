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
