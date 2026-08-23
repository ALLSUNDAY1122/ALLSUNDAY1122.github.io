# LANE-2 Post-Integration Privacy Refresh

- worker: `worker2`
- refreshed branch: `scanner-parity/worker2-privacy-refresh`
- base: latest `scanner-parity/integration`
- final Privacy PASS owner: HQ Release Gate

## Current verdict

**PRIVACY REMEDIATION IMPLEMENTED ON WORKER1 BRANCH, NOT YET CANONICAL.**

The two release blockers identified after HQ final composition were re-reviewed against Worker1 PR #4531 head `0877b6cbc7cabea84025f51dfbf08f8cadff7f54`.

### P2-INT-001 — raw input / processing workspace lifecycle

Worker1 now implements a coherent crash-recovery lifecycle:

- managed input media is stored under `Application Support/ScannerParity/Imports` only while active resume may be required;
- the managed import root is excluded from device backup;
- inputs are explicitly purgeable;
- active processing workspace is excluded from backup;
- successful completion stages the final BookPackage under `Completed/<bookID>`;
- a terminal schema-v3 checkpoint stores only final package URL, review metadata and page count;
- raw inputs and the full per-book processing workspace are purged after terminal completion is safely persisted;
- final local staging is deleted when export/session retention ends;
- malformed or stale checkpoint state is invalidated fail-closed.

Worker2 Privacy assessment: **acceptable in principle**. Application Support is not itself a Privacy failure when retention is resume-scoped, backup-excluded and deterministically purged.

### P2-INT-002 — camera purpose-string requirement

Worker1 removed the unused `AVCaptureDevice` permission code and the camera-permission UI. PhotosPicker and Files remain supported input paths.

Worker2 Privacy assessment: **resolved by removal**. If camera APIs are reintroduced later, the strengthened lifecycle gate requires `NSCameraUsageDescription` representation.

## Verification read-back

Worker1 PR #4531 head `0877b6cbc7cabea84025f51dfbf08f8cadff7f54` has GitHub Actions run `32630365479` with conclusion `success` for `Scanner Parity Apple Validation`.

That establishes Apple compilation and the then-current source-contract/privacy checks for the Worker1 branch. It does **not** by itself establish final Privacy PASS because the stronger Worker2 lifecycle gate was still on a divergent PR branch.

## Worker2 gate refresh

The old Worker2 follow-up PR #4530 diverged from the latest integration. Worker2 therefore created `scanner-parity/worker2-privacy-refresh` directly from the latest integration and reapplied only Worker2-owned Privacy/Security changes:

1. `PrivacyStaticAuditor` reports all release-blocking findings separately from informational/review findings.
2. External network, analytics and external-AI egress remain fail-closed and non-bypassable.
3. `ProcessingStorageLifecycleAuditor` verifies:
   - managed import backup exclusion;
   - managed import purgeability;
   - deterministic processing-workspace purge when intermediate stages are written to persistent app storage;
   - camera purpose-string presence only when camera APIs are actually present.
4. Fixtures explicitly verify that a camera-free product does not require `NSCameraUsageDescription`.
5. `run-lane2-privacy-gate.sh` runs the lifecycle auditor against the final assembled AppShell sources/resources.

## Canonical completion condition

Final Privacy PASS may be asserted only after all of the following are true on the same canonical integration checkout:

1. Worker1 #4531-equivalent lifecycle remediation is integrated without regression.
2. The refreshed Worker2 lifecycle gate is integrated.
3. `scanner-parity/Tests/SecurityHardening/run-lane2-privacy-gate.sh` passes on that combined tree.
4. Final Apple product validation also passes on that same head.

Golden Dataset availability/SHA status is unrelated to this Privacy gate.
