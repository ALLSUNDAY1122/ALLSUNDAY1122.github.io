# HQ2 STEP28 — trusted previous result recovery diagnosis (read-only)

Date: 2026-10-21 JST. Owner: HQ / SCANLAB-HQ-001 epoch 1, governance-release scope only. This is an audit artifact, not a Native code change or CI approval.

## Frozen evidence
- Candidate `4f3a0de772df8e8d87e4d5b4932d717d596f17d8` on `attempt/scanlab-release-candidate-20261020-a1`.
- Native CI run 39433258555: 251 tests, 2 assertion failures in ONE case `SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity`. Failure at line 162 `completionEvidenceMismatch`; line 167 `XCTAssertFalse failed`.
- Product branch HEAD `69f365816bb1ae61a558f40778279b507bd705d6`; release branch `3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a`; candidate `4f3a0de772df8e8d87e4d5b4932d717d596f17d8` (read back in STEP28).

## Source-path findings (not root-cause proof)
- `SplatCompletionVerifier.verifyWithDigest` invokes `recoverTrustedPreviousAndVerify` if `SplatStrongCompletionEvidence.verifyOrSeal` fails. A failing recovery maps to `completionEvidenceMismatch`.
- Recovery entry requires current commit evidence identity, a valid snapshot, byte count and SHA verification of the backup, and `snapshotCanRecover` ordering: `snapshot.originalEvidence.completedAt <= failedEvidence.completedAt` and `snapshot.preservedAt <= failedEvidence.completedAt`.
- The recovery routine stages the backup, verifies its SHA, replaces the current asset, writes the original completion evidence, updates the manifest, then verifier runs `verifyOrSeal` again. The latest-generation strong seal may still exist; diagnosis must distinguish a false mismatch due to seal/mtime from a genuine backup hash or generation mismatch.
- Two failed assertions in the same test do NOT establish two independent defects. The second can reflect incomplete cleanup after the first failed recovery attempt.

## Owner-safe next checks for Worker2 (T34–T36, epoch2)
1. Diagnose exact failing guard without destructive operations: capture sanitized booleans for evidence reread match, snapshot decode/version, ordering predicates, backup size/SHA match, partial size/SHA, final generation evidence, recovered manifest, and strong seal identity; never log full file bytes, tokens, or user data.
2. Check whether restored asset mtime and the existing strong seal are compatible with previous completion evidence; do not weaken SHA, force success, or remove trusted backup in failure paths.
3. Add a deterministic regression for both genuine corrupted backup (fail closed, original preserved) and legitimate prior-generation recovery; gate cleanup on successful strong verification.
4. Fix only in the authorized Worker2 attempt branch and report commit/PR/CI. HQ must independently validate all 251+ XCTest and release source provenance before release promotion.

## Release gate
NO-GO. No production merge, Codemagic build, Apple upload or App Review submit authorized by this note.
