# HM2 canonical technical execution result

- Checked UTC: 2026-11-22T05:22:52.233918+00:00
- Bank SHA-256: `e7a9cecff4e7df7c645d790360b1fe0246390063c7066ac547b3e1058b1c1386`
- Actual Node canonical exit: `1`
- Canonical exact bytes: **False**
- Readiness command exit: `1`
- technical_errors: `["UNREVIEWED_BANK_SHA", "CANONICAL_REGENERATION_FAILED"]`
- submission_blockers: `["178_QUESTION_INDEPENDENT_REVIEW_PENDING", "ALTERNATIVE_Q0_178_DOUBLE_CHECK_AND_300_RIGHTS_PENDING", "CURRENT_BUILD_ASC_READBACK_MISSING", "CLAUDE_300_ID_COMMIT_CSV_NOT_IMPORTED", "ACTUAL_APP_SCREENSHOTS_NOT_STORED"]`
- Python 18-case unittest exit: `0`
- Technical verification: **FAIL**

This is a technical check; it does not approve Q0 content/rights, allow TestFlight or submit to Apple.

## Node canonical stdout/stderr

```text
hm2-source-evidence-v2.js:143
    throw new Error('HM2 R05 LAW10 Q1 format patch stale input');
    ^

Error: HM2 R05 LAW10 Q1 format patch stale input
    at hm2-source-evidence-v2.js:143:11
    at hm2-source-evidence-v2.js:153:3
    at Script.runInContext (node:vm:149:12)
    at Object.runInContext (node:vm:301:6)
    at load (/home/runner/work/ALLSUNDAY1122.github.io/ALLSUNDAY1122.github.io/ios/health-manager-2/export-canonical-snapshot.cjs:12:6)
    at Object.<anonymous> (/home/runner/work/ALLSUNDAY1122.github.io/ALLSUNDAY1122.github.io/ios/health-manager-2/export-canonical-snapshot.cjs:15:34)
    at Module._compile (node:internal/modules/cjs/loader:1781:14)
    at Object..js (node:internal/modules/cjs/loader:1913:10)
    at Module.load (node:internal/modules/cjs/loader:1505:32)
    at Function._load (node:internal/modules/cjs/loader:1309:12)

Node.js v22.23.5

```

## Readiness stdout/stderr

```text
{"technical_errors": ["UNREVIEWED_BANK_SHA", "CANONICAL_REGENERATION_FAILED"], "submission_blockers": ["178_QUESTION_INDEPENDENT_REVIEW_PENDING", "ALTERNATIVE_Q0_178_DOUBLE_CHECK_AND_300_RIGHTS_PENDING", "CURRENT_BUILD_ASC_READBACK_MISSING", "CLAUDE_300_ID_COMMIT_CSV_NOT_IMPORTED", "ACTUAL_APP_SCREENSHOTS_NOT_STORED"], "submission_ready": false}

```

## Unittest tail

```text
test_complete_fixture_structure (test_hm2_alternative_q0_gate.GateTests.test_complete_fixture_structure) ... ok
test_copied_review_content_fails (test_hm2_alternative_q0_gate.GateTests.test_copied_review_content_fails) ... ok
test_duplicate_reviewer_fails (test_hm2_alternative_q0_gate.GateTests.test_duplicate_reviewer_fails) ... ok
test_fake_artifact_sha_fails (test_hm2_alternative_q0_gate.GateTests.test_fake_artifact_sha_fails) ... ok
test_missing_independence_attestation_fails (test_hm2_alternative_q0_gate.GateTests.test_missing_independence_attestation_fails) ... ok
test_missing_nonofficial_notice_fails (test_hm2_alternative_q0_gate.GateTests.test_missing_nonofficial_notice_fails) ... ok
test_missing_rights_file_fails (test_hm2_alternative_q0_gate.GateTests.test_missing_rights_file_fails) ... ok
test_nonobject_double_check_payload_fails (test_hm2_alternative_q0_gate.GateTests.test_nonobject_double_check_payload_fails) ... ok
test_nonobject_double_review_row_fails (test_hm2_alternative_q0_gate.GateTests.test_nonobject_double_review_row_fails) ... ok
test_nonobject_rights_payload_fails (test_hm2_alternative_q0_gate.GateTests.test_nonobject_rights_payload_fails) ... ok
test_nonobject_rights_row_fails (test_hm2_alternative_q0_gate.GateTests.test_nonobject_rights_row_fails) ... ok
test_null_double_check_payload_fails (test_hm2_alternative_q0_gate.GateTests.test_null_double_check_payload_fails) ... ok
test_null_rights_payload_fails (test_hm2_alternative_q0_gate.GateTests.test_null_rights_payload_fails) ... ok
test_positive_official_supervision_claim_fails (test_hm2_alternative_q0_gate.GateTests.test_positive_official_supervision_claim_fails) ... ok
test_same_review_artifact_fails (test_hm2_alternative_q0_gate.GateTests.test_same_review_artifact_fails) ... ok
test_same_session_fails (test_hm2_alternative_q0_gate.GateTests.test_same_session_fails) ... ok
test_stale_bank_hash_fails (test_hm2_alternative_q0_gate.GateTests.test_stale_bank_hash_fails) ... ok
test_wrong_choice_text_fails (test_hm2_alternative_q0_gate.GateTests.test_wrong_choice_text_fails) ... ok

----------------------------------------------------------------------
Ran 18 tests in 0.814s

OK

```
