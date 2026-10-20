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
