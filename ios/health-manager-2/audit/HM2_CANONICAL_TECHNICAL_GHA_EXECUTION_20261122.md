# HM2 canonical technical execution result

- Checked UTC: 2026-11-22T03:55:41.616459+00:00
- Bank SHA-256: `434de86ab795d369a1ef52f16a0cf57cab7054b72f6aac952aa7805fb3872177`
- Actual Node canonical exit: `0`
- Canonical exact bytes: **True**
- Readiness command exit: `0`
- technical_errors: `[]`
- submission_blockers: `["178_QUESTION_INDEPENDENT_REVIEW_PENDING", "ALTERNATIVE_Q0_178_DOUBLE_CHECK_AND_300_RIGHTS_PENDING", "CURRENT_BUILD_ASC_READBACK_MISSING", "CLAUDE_300_ID_COMMIT_CSV_NOT_IMPORTED", "ACTUAL_APP_SCREENSHOTS_NOT_STORED"]`
- Python 18-case unittest exit: `0`
- Technical verification: **PASS**

This is a technical check; it does not approve Q0 content/rights, allow TestFlight or submit to Apple.

## Node canonical stdout/stderr

```text
PASS HM2_LIVE_LAW_PINS {"assertions":17,"questionIds":13}
REVIEW_REQUIRED HM2_LEGACY_TOPIC_METADATA {"originalPins":24,"apparentStale":19,"examples":["健康診断後の医師等の意見聴取","自発的健康診断後の意見聴取","衛生管理者の選任期限","衛生委員会記録の保存","暑熱な場所の基準","法定労働時間（日）","法定労働時間（週）","6時間超の休憩"],"independentReviewMarked":177}
PASS HM2_CANONICAL_JSON {"total":300,"uniqueStems":300,"choiceDrift":0,"correctAnswerDrift":0,"groups":30,"sha256":"434de86ab795d369a1ef52f16a0cf57cab7054b72f6aac952aa7805fb3872177","bytes":605819,"path":"/home/runner/work/ALLSUNDAY1122.github.io/ALLSUNDAY1122.github.io/ios/health-manager-2/release-questions.json"}
NOTE: Snapshot is not an independent legal/medical content review or iOS device test.

```

## Readiness stdout/stderr

```text
{"technical_errors": [], "submission_blockers": ["178_QUESTION_INDEPENDENT_REVIEW_PENDING", "ALTERNATIVE_Q0_178_DOUBLE_CHECK_AND_300_RIGHTS_PENDING", "CURRENT_BUILD_ASC_READBACK_MISSING", "CLAUDE_300_ID_COMMIT_CSV_NOT_IMPORTED", "ACTUAL_APP_SCREENSHOTS_NOT_STORED"], "submission_ready": false}

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
Ran 18 tests in 0.257s

OK

```
