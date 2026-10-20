# HQ2 STEP37 — targeted Native recovery triage (Worker2 ownership intact)

Date: 2026-10-21 JST. HQ governance note only, no Native source modifications.

## Remote proof
- Worker2 Native attempt HEAD remains `dbcc8ba02cff0daad56593fc36c733167664f0f0`, Viewer `18987c29eda1ea4c4e49dda103f1e005d9b868d9`.
- Candidate `4f3a0de772df8e8d87e4d5b4932d717d596f17d8`; Native CI run 39433258555 FAILED (251 tests, 2 assertion failures in one test case).
- HQ governance queue claim epoch1; Worker2 Native claim epoch2. Resource Lock not transferred.
- PR #5637 read-only provenance Preflight succeeded: Actions run 39512100373. This does not override Native CI failure.

## Precise reproduction target
`splat-native-ios/SplatNativeTests/SplatCompletionVerifierTests.swift`
`testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity`
- Test performs old source strong verification, protects previous backup, commits newer same-size source, seals newer source, writes same-size corruption restoring mtime, expects automatic trusted old recovery.
- First assertion (line 162): throws `completionEvidenceMismatch`.
- Second assertion (line 167): backup still present because recovery never reached successful-discard boundary.

## Direct high-information diagnostic split
In Worker2-owned `SplatPreviousResultIntegrityRecovery.recoverTrustedPreviousAfterIntegrityFailure`:
1. Immediately before the first `guard`, diagnose (sanitized): current evidence reread equality.
2. Diagnose whether snapshot JSON decode, version, file name and previous backup byte count pass.
3. Diagnose `snapshotCanRecover` as THREE independent comparisons: old.size==new.size, old.completedAt<=new.completedAt, snapshot.preservedAt<=new.completedAt. Print Date ISO8601 with fractional seconds in test fixtures only.
4. Independently diagnose backup SHA and staged-partial SHA, without logging asset bytes.
5. Record whether the function exits `false`, throws, or returns `true`.
6. On `true` but verifier failure, compare restored evidence generation, output modification timestamp and `SplatStrongCompletionEvidence.Seal.matches(restoredEvidence)`. Verify mtime <= restored completedAt before attempting reseal.
7. If an early guard rejects, add a focused test for its predicate. Do NOT remove the guard or broaden rollback eligibility to make this test pass.
8. If complete recovery happens but resealing fails, retain original backup and fix the proven metadata/epoch mismatch, not SHA validation.

## Expected regression acceptance
- Valid previous same-size asset + authentic evidence: restores the exact SHA-verified bytes, preserves manifest recovery flag, drops backup *only after verification*.
- Corrupt backup / wrong generation / changed evidence: fail closed and preserve data without false TRUSTED status.
- Interrupted recovery: no remove-before-verified-copy, no trusted backup loss.
- Full Native XCTest PASS on actual repair commit; no skipped tests and no manual Apple upload prior to release gate.

## Coordination/limits
Worker2 must enact the Native fix through its already-owned task. This document is not an execution trigger and HQ2 cannot dispatch a separate chat. Worker1 remains stopped.
RELEASE NO-GO until full Native CI and release post-checks.
