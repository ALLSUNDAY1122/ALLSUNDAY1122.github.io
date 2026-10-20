# HQ2 STEP29 — Worker2 Native recovery: verified XCTest acceptance

Date: 2026-10-21 JST
Task: SCANLAB-W1-001 / WORKER_2 / epoch 2 / claim SCANLAB-W1-001-a2-W2-20261020
Lock: scanlab:native-capture-reconstruction-export / epoch 2
Queue readback SHA: ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd
Branch: attempt/scanlab-w2-native-recovery-20261021-e2
Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/5636
Baseline: candidate 4f3a0de772df8e8d87e4d5b4932d717d596f17d8
Tested source HEAD: 5cbac91f44385e205a331409728df2d834a98a98

## Diagnosis and repair
Baseline Native CI 39433258555: 251 tests, 2 assertions in one test due to completionEvidenceMismatch for same-size prior result recovery.
Metadata-only witness in successful case: schemaOK=true; sameSize=true; timestampPredicate=true; backupBytesMatch=true; resultBytesMatch=true. The preservedAt <= failedEvidence.completedAt generation predicate is demonstrably true.
SHA-verified clone promotion now uses same-directory atomic POSIX rename to avoid inheriting the corrupt destination's file metadata. Verified original SHA, file type, timestamp and commit-generation checks are retained. Fail-closed paths preserve the independently trusted backup.

Commits:
- a011932c3d5a2e107006b7227680b603eec1fed2 diagnostics
- 66d201040e61e81a35c8b7634d6cbe2e2d283294 corrupt backup and timestamp negative tests
- d07499edc22d2566abeaf0beff84b9d45466ba73 atomic promotion fix
- 1539708777e69caa744d72b609144e650879c935 stale evidence test
- 5cbac91f44385e205a331409728df2d834a98a98 prior evidence checkpoint

## Completed Native iOS verification
Run: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/39494065875
Native iOS Build: completed SUCCESS, job 118874974319.
Integrated XCTest: 254 executed, 0 failures, 0 unexpected.
Explicit PASS: testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity; testIntegrityRecoveryRejectsCorruptBackupWithoutDeletingEitherResult; testIntegrityRecoveryRejectsUnprovenFuturePreservationTimestamp; testRecoveryRejectsChangedCommitEvidenceAndPreservesBackup.
Same-source Privacy Preflight, Smoke Diagnostic, S10 and S12: SUCCESS.
This evidence-only commit is not a new source test execution.

## Handoff
Code has green Native CI and is ready for independent HQ2 verification, not authorized release.
PR stays DRAFT/unmerged. No worker-side release promotion, Codemagic, Apple upload or App Review submission.
Real-device storage fault acceptance and T40 integration remain HQ2 gates.
