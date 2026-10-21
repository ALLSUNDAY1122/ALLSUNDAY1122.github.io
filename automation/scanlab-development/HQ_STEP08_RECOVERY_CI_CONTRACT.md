# Scan Lab STEP08 — Recovery regression contract and current CI gate
Date: 2026-10-20 (JST). HQ task SCANLAB-HQ-001 claim epoch1.
Source branches re-read live before analysis.

## Live evidence
- Integration baseline feature/splat-native-ios-poc: 2bcbbd6128863739ad168610cd2e3f8e3b01b458.
- W1 attempt HEAD f5bb67a83f0d912ed56c64e180b41b7e0b7507b8; 3 commits, modifies CapturePolicy.swift, MeshScanModel.swift, ScanModel.swift. Native iOS workflow at HEAD run 39350766509 SKIPPED because normal job explicitly allows only workflow_dispatch, pull_request, base feature branch or testflight branch.
- W2 attempt HEAD c1b836d69cd84fa8fb91c66e87cfae3e4cd36aa3 unchanged; 3 commits. Native iOS run 39348580713 FAILED, 245 XCTest, 2 unexpected failures.
- Queue and resource locks remain CLAIMED epoch1 at control SHA 7196cc2776f38fe9260c6cf5fa244fba4c5563c0.
- Neither branch eligible for promotion or new Codemagic Build.

## Precise failure cause
The two tests expect corrupt primary viewer sidecar to be recovered through a valid backup AND materialization/preflight to obtain a repaired primary. W2 intentionally removed write-on-read from SplatViewerEditStore.load(). That fixes nondestructive viewer reads but leaves export repair assumptions unfulfilled.
Error in both tests: dataCorrupted/invalid JSON when test attempts to decode corrupt primary after export recovery.

1. SplatExportAdmissionTests.testPreflightRecoversViewerEditsBeforeExportMaterialization
2. SplatViewerSidecarWriteSafetyTests.testExportMaterializerRecoversSettingsFromBackup

Relevant code anchors:
- SplatViewerState.swift SplatViewerEditStore.load() lines 176–220 now returns recovered values without writes.
- SplatExportAdmission.swift preflight line ~61 calls load() but cannot assume it repairs the primary.
- SplatPersistedEditMaterializer+Cancellation.swift load() accesses only settings; same read-only semantics.
- Test files SplatExportAdmissionTests.swift and SplatViewerSidecarWriteSafetyTests.swift assert a repaired primary after export materialization.

## Required W2 contract (owned code; HQ must not edit)
- Keep SplatViewerEditStore.load() strictly read-only; corrupt/missing/unsafe/oversized primary must never mutate primary or backup on read. Assert byte-for-byte equality and no replacement after viewer load.
- Decide an explicit, separately authorized repair entry point for EXPORT preflight/materialization (not a side effect of ordinary load). The intentional repair must be generation-bound, symlink-safe, source-checked, atomic, fail-closed on races. Do not overwrite healthy backups with corrupt primary.
- Reconcile the existing two tests with the explicit repair contract. Preserve both recovered settings and repair durability without weakening safety; add a negative read-only test and unsafe symlink case.
- Run full iOS native XCTest, not just static privacy/smoke. Preserve CI run and zero-failure evidence.
- T37 lost ACK preserve publish and T38 revoked bearer cannot re-access remain P0 gates; metric display fix alone does not complete W2.

## Required W1 evidence
- Validate both previous/current pose and rigid-transform invariants before side effects/lease/disk write.
- Capture/Mesh test matrix: first good frame, malformed homogeneous row, non-finite components, nonrigid pose, stale generation, image quality rejection, no output after denial.
- Trigger the existing native workflow through a supported pull_request for the attempt branch or another scope-respecting authorized path. A normal push to worker attempt branch produces SKIPPED, not PASS. Do not use a release/TestFlight branch as a CI bypass.

## Trigger safety / HQ release
- Existing splat-native-ios.yml normal job IF is restricted; this explains observed SKIPPED W1 runs.
- Do not alter shared production branch or start Codemagic while Worker CI is red or skipped.
- GitHub Actions unrelated jobs on attempt pushes may fail; do not treat them as validated Scan Lab regressions.
- Next gate: exact HEAD and queue epoch readback, W1/W2 targeted fixes, independently passing native XCTest; then scoped serial integration / T40 independent QA.
