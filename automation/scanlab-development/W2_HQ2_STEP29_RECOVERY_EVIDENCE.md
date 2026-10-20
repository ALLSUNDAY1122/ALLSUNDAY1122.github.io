# HQ2 STEP29 — Worker2 epoch2 Native Recovery Evidence
Date: 2026-10-21 JST

## Authorization and isolation
- Authoritative control Queue SHA: ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd
- Task SCANLAB-W1-001 / owner WORKER_2 / epoch 2 / claim SCANLAB-W1-001-a2-W2-20261020
- Resource lock scanlab:native-capture-reconstruction-export / epoch 2
- Target source baseline: release candidate 4f3a0de772df8e8d87e4d5b4932d717d596f17d8
- Dedicated branch attempt/scanlab-w2-native-recovery-20261021-e2, draft PR #5636; HQ2 owns promotion, Codemagic, Apple.
- No Worker1, control branch, product branch or release branch modifications.

## Baseline failure
HQ2 Native run 39433258555 at candidate: 251 XCTest cases, one case with two assertions failing: SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity, completionEvidenceMismatch and preserved backup not discarded. Non-deterministic prior CI does not prove recovery always succeeds.

## Commits and bounded diagnostics
- a011932c3d5a2e107006b7227680b603eec1fed2: metadata-only SCANLAB_RECOVERY_WITNESS in existing positive XCTest: schema, same-size, timestamp predicate, backup/result sizes, three timestamps. Does not print scene content or hash. Diagnostic run 39492975110 CANCELLED by subsequent commits, not PASS.
- 66d201040e61e81a35c8b7634d6cbe2e2d283294: deterministic negative XCTest tampered previous backup and future preservedAt. On rejection asserts both original backed-up and current result bytes remain unchanged.
- d07499edc22d2566abeaf0beff84b9d45466ba73: replace FileManager.replaceItemAt source-metadata ambiguity with same-directory POSIX rename of already SHA-256 verified, synchronized partial; no remove-then-move gap and no corrupt destination metadata inheritance. Existing snapshot/current-evidence generation checks and backup SHA validation remain unchanged, so a failed gate remains fail-closed.
- 1539708777e69caa744d72b609144e650879c935: negative interrupted recovery stale evidence test, preserving current output, backup and newer evidence.

## Acceptance pending
All added XCTest are in selected SplatCompletionVerifierTests suite. Last commit CI / full test count / failure count must be read after completion. No green or TestFlight claim until complete. Revalidate source and screenshots/logs on PR HEAD. The existing positive test is the legitimate same-size previous generation restoration with SHA and manifest expected flags. Remaining issue: metadata-only witnesses cannot distinguish all internal guards when CI is passing; any new failure requires bounded stage-specific diagnosis, never weakening trust.
