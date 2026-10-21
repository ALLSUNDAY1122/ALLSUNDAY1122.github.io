# STEP10 — HQ Worker P0 review and actionable PR requests
Date: 2026-10-20 JST. State IN_PROGRESS. No release.

## Current canonical state
- Control Queue SCANLAB-HQ-001, SCANLAB-W1-001, SCANLAB-W2-001 all CLAIMED epoch1, lock records unchanged. Control sha 7196cc2776f38fe9260c6cf5fa244fba4c5563c0.
- App integration baseline 2bcbbd6128863739ad168610cd2e3f8e3b01b458.
- W1 HEAD 31ba91fdd7f6a550952ab0a814692377033783cf, 4 commits; no new commit since STEP09. Draft PR #5620.
- W2 HEAD c2e66169b76f4391b14cded1c2b7179a78f93ee0, 7 commits; changed ScanLibraryView.swift (+96/-3) implementing read-only census. Draft PR #5619.

## CI evidence and source inspection
- W1 PR Native iOS run 39354568521 FAILED in static checks. test_mesh_durability_contract.py line54 ValueError because expected reset source shape is absent. XCTest not reached. No proof of bad durability or valid replacement; fix must retain invariant.
- W2 Native iOS run 39354704378 FAILED; 245 tests, 1 failure. SplatExportAdmissionTests.testPreflightRecoversViewerEditsBeforeExportMaterialization; corrupt primary invalid JSON remains after export preflight. Other targeted privacy/memory/smoke gates PASS but do not make release PASS.
- W2 new ScanLibraryReadOnlyCensus.inspect(rootURL:) counts manifest-corrupt/unsafe project dirs as unknown rather than silently empty; uses BoundedFileReader and read-only directory traversal. Proof that no files change and backup integrity still needed, including nonregular directory/symlink edge cases.

## Posted direct PR comments
- PR #5620 comment 6281537287: preserve Mesh reset durability invariant; complete test and full CI.
- PR #5619 comment 6281537703: explicit exporter repair vs viewer no-write semantics, secure generation/symlink/race handling; add read-only census negative tests.
- HQ owns neither worker's Swift source. Both workers must resolve in their own attempt branch with current epoch lock.
- No merge, Codemagic build, Apple upload, Internal TestFlight Build update, or App Store submission.

## Next
Check W1/W2 latest heads, PR comments, and complete CI. If passing, perform serial integration with independent T40 QA; otherwise keep HOLD and classify same repeat failure for escalation.
