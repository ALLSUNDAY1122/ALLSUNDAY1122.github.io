# HQ2 STEP29 — Worker2 Native recovery repair handoff

Date: 2026-10-21 JST  
Scope: HQ governance/release evidence ONLY, not a Native ownership transfer.  
Queue: SCANLAB-W1-001 / WORKER_2 / claim_epoch=2 / lock=scanlab:native-capture-reconstruction-export. Worker1 remains stopped.

## Exact baseline
- Product HEAD: `69f365816bb1ae61a558f40778279b507bd705d6`
- Release candidate HEAD: `4f3a0de772df8e8d87e4d5b4932d717d596f17d8`
- Worker2 Native attempt HEAD: `dbcc8ba02cff0daad56593fc36c733167664f0f0`
- Old release HEAD: `3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a`
- CI: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/39433258555
- Test 251 cases; ONE case with TWO assertion failures. Line 162 throws `completionEvidenceMismatch` and line 167 `XCTAssertFalse` fails. No new CI on repaired code yet.

## Required Worker2 action — no assumptions of completion
1. Re-read Queue/lock and production + candidate HEAD; obtain/reconfirm epoch2 exclusive claim and work ONLY in a new authorized short-lived Native attempt. Never edit HQ control or product/release branches directly.
2. Capture bounded, non-sensitive diagnostic witnesses at each early exit in `SplatPreviousResultIntegrityRecovery.recoverTrustedPreviousAfterIntegrityFailure`: currentEvidence==failedEvidence, snapshot parse/schema, backup file type, byte counts, snapshot SHA comparison, `snapshotCanRecover` timestamp predicate, candidate partial SHA, subsequent evidence identity, result mtime and strong-seal evidence identity. Record booleans and sanitized timestamps only; no customer bytes/secrets.
3. Distinguish early `return false` from thrown errors and successful recovery followed by failed `verifyOrSeal`. Confirm whether the test's `preservedAt <= failedEvidence.completedAt` is reliably true.
4. Correct the smallest demonstrated cause. NEVER delete previously trusted backup on failed verification, waive SHA integrity, or move a corrupt file to TRUSTED. If necessary treat unprovable recovery as UNKNOWN/non-destructive.
5. Add deterministic positive + negative regression tests (legitimate same-size prior-generation restoration; corrupt backup must fail-closed without destroying previous originals; interrupted recovery); run the whole Native XCTest suite. Attach workflow URL, completed result, total case count and failed count, commit SHA to PR.
6. HQ2 alone performs T40 independent validation, release branch promotion, Codemagic and Apple read-back. No App Review submission.

## CI and release gate
Native CI on candidate `4f3a0de...` = FAIL (249/251 passed, 2 assertions in one case); prior green `69f3658...` does not certify candidate. Existing release candidate is not approved. Do not start `scanlab-ios`: Codemagic auto-uploads to internal TestFlight.

## Handoff delivery limitation
This file is a persistent instruction for the user/Worker2 session to read. GitHub file creation alone does NOT dispatch a chat instruction or cause Worker2 to run.
