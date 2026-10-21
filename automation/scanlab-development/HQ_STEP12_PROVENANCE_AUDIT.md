# STEP12 HQ — live worker CI and provenance discrepancy
2026-10-20 JST. Integration HOLD.

## Current data
- Queue control HEAD 7196cc2776f38fe9260c6cf5fa244fba4c5563c0, task statuses HQ/W1/W2 CLAIMED epoch1; locks valid.
- Base feature/splat-native-ios-poc 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged.
- W1 HEAD 31ba91fdd7f6a550952ab0a814692377033783cf, ahead4 and unchanged; PR #5620 Native CI run 39354568521 previously FAILED static mesh durability contract before XCTest, not ready.
- W2 HEAD d6060d9f827b173ab5b5bb3609e36777426a7129, ahead13, PR #5619. Changed Swift publish no owner delete on lost ACK, library nonmutating census, viewer units/sidecar tests, ExportAdmissionTests; native run 39358283715 FAILED static test before XCTest.

## W2 runner evidence discrepancy requiring investigation
- Runner job 118418141043 traceback: splat-native-ios/scripts/d2_hq_integration_contracts.mjs line 65; AssertionError "The input did not match the regular expression /cleanupFailedDraft/" implying positive assert.match source.
- But connector readback of that exact path at W2 HEAD d6060d9f shows line65: assert.doesNotMatch(trustedPublish, /cleanupFailedDraft|scanlab-delete-scan/).
- These cannot be assumed identical scripts without checking the actual synthetic merge checkout. GitHub run event pull_request and run HEAD d6060d9f. PR metadata's pull_requests[] may lag head. Need inspect checkout SHA and blob actually executed, rather than weaken current safe no-delete code.
- HQ posted precise comment #6282122227 on PR #5619. The historical full XCTest ExportAdmission invalid JSON issue remains without a newly passing XCTest record.

## Conditions
- No W1 full Native CI PASS, W2 latest CI static failure; both integration HOLD.
- No source merge, Codemagic build, Apple upload, group changes or App Store submit.
- Next: verify W2 runner script/check-out identity and correct obsolete contract; W1 mesh durability contract and XCTest; rerun passing full CI, read claim epoch, then serial integration.
