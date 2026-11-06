from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from live_processing_recovery import (
    CANCEL_SCENARIOS,
    EVIDENCE_STATE,
    REQUIRED_SCENARIOS,
    RecoveryGateError,
    evaluate_campaign,
    sha256_file,
    validate_plan,
)


class LiveProcessingRecoveryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = Path(tempfile.mkdtemp())
        self.repo = self.temp / "repo"
        self.repo.mkdir()
        self.private = self.temp / "private"
        self.private.mkdir()
        self.fault = self.private / "fault.txt"
        self.fault.write_text("fault proof", encoding="utf-8")
        self.account = self.private / "account.txt"
        self.account.write_text("account proof", encoding="utf-8")

        self.e01 = {
            "schema_version": 1,
            "evidence_kind": "COMMERCIAL_ROUTE_APPROVAL",
            "evidence_state": EVIDENCE_STATE,
            "parity_claim": "NONE",
            "result": "READY_FOR_LIVE_PROVIDER_GATE",
            "approval_manifest_identity_sha256": "a" * 64,
            "credential_preflight": {
                "all_present": True,
                "server_side_only": True,
                "values_persisted": False,
            },
        }
        self.e03 = {
            "schema_version": 1,
            "evidence_kind": "LIVE_SEPARATION_BENCHMARK",
            "evidence_state": EVIDENCE_STATE,
            "parity_claim": "NONE",
            "benchmark_state": "READY_FOR_HQ_E03_LIVE_REVIEW",
            "e03_live_benchmark_lock_sha256": "b" * 64,
            "acceptance_checks": {"required": True},
        }
        self.plan = {
            "schema_version": 1,
            "evidence_state": EVIDENCE_STATE,
            "recovery_campaign_id": "R1",
            "scenarios": [
                {"scenario_id": f"S{i}", "scenario_kind": kind}
                for i, kind in enumerate(REQUIRED_SCENARIOS)
            ],
        }
        self.results = {
            scenario_id: self.valid_result(kind)
            for scenario_id, kind in validate_plan(self.plan)["scenarios"].items()
        }

    def valid_result(self, kind: str) -> dict:
        cancelled = kind in CANCEL_SCENARIOS
        return {
            "schema_version": 1,
            "evidence_state": EVIDENCE_STATE,
            "scenario_kind": kind,
            "stable_error_codes": ["SEP_TEST_" + kind],
            "project_state_after": "cancelled" if cancelled else "ready",
            "project_corrupted": False,
            "partial_result_published": False,
            "provider_create_request_count": 0 if kind == "CANCEL_UPLOAD" else 1,
            "provider_distinct_task_count": 0 if kind == "CANCEL_UPLOAD" else 1,
            "provider_cancel_request_count": 1 if cancelled else 0,
            "provider_billable_task_count": 0 if kind == "CANCEL_UPLOAD" else 1,
            "automatic_create_repost_count": 0,
            "duplicate_provider_task_detected": False,
            "reconciliation_performed": kind == "AMBIGUOUS_CREATE_RETRY",
            "logical_cancelled": cancelled,
            "logical_job_identity_sha256": "d" * 64,
            "idempotency_key_sha256": "e" * 64,
            "logical_identity_preserved": True,
            "upstream_cancel_state": "confirmed" if cancelled else "not_applicable",
            "claimed_upstream_cancelled": cancelled,
            "outputs_published_after_cancel": False,
            "relaunch_observed": kind == "RELAUNCH",
            "rate_limit_observed": kind == "RATE_LIMIT",
            "bounded_streaming_observed": kind == "LONG_TRACK",
            "storage_preflight_observed": kind == "STORAGE_PRESSURE",
            "output_expiry_resolution": (
                "verified_local_copy" if kind == "OUTPUT_EXPIRY" else "not_applicable"
            ),
            "committed_result_sha256_before": "c" * 64,
            "committed_result_sha256_after": "c" * 64,
            "provenance": {
                "fault_injection_path": "fault.txt",
                "fault_injection_sha256": sha256_file(self.fault),
                "provider_account_path": "account.txt",
                "provider_account_sha256": sha256_file(self.account),
            },
        }

    def evaluate(self) -> dict:
        return evaluate_campaign(
            plan=self.plan,
            e01=self.e01,
            e03=self.e03,
            results_by_scenario=self.results,
            repo_root=self.repo,
            private_root=self.private,
        )

    def scenario_id(self, kind: str) -> str:
        return next(
            scenario_id
            for scenario_id, value in validate_plan(self.plan)["scenarios"].items()
            if value == kind
        )

    def test_happy_campaign(self):
        report = self.evaluate()
        self.assertEqual(report["recovery_state"], "READY_FOR_HQ_E05_LIVE_REVIEW")
        self.assertEqual(len(report["scenarios"]), 10)

    def test_missing_required_scenario_plan(self):
        plan = dict(self.plan)
        plan["scenarios"] = plan["scenarios"][:-1]
        with self.assertRaises(RecoveryGateError):
            validate_plan(plan)

    def test_e01_required(self):
        self.e01["result"] = "PENDING_EXTERNAL_CREDENTIAL"
        with self.assertRaises(RecoveryGateError):
            self.evaluate()

    def test_e03_required(self):
        self.e03["benchmark_state"] = "LIVE_BENCHMARK_FAILED"
        with self.assertRaises(RecoveryGateError):
            self.evaluate()

    def test_duplicate_billing_rejected(self):
        self.results["S0"]["provider_billable_task_count"] = 2
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_DUPLICATE_BILLING"):
            self.evaluate()

    def test_distinct_provider_task_count_rejected(self):
        self.results["S0"]["provider_distinct_task_count"] = 2
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_DUPLICATE_BILLING"):
            self.evaluate()

    def test_automatic_create_repost_rejected(self):
        self.results["S0"]["automatic_create_repost_count"] = 1
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_AUTOMATIC_CREATE_REPOST"):
            self.evaluate()

    def test_logical_identity_must_persist(self):
        self.results["S0"]["logical_identity_preserved"] = False
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_LOGICAL_IDENTITY"):
            self.evaluate()

    def test_ambiguous_create_requires_reconciliation(self):
        sid = self.scenario_id("AMBIGUOUS_CREATE_RETRY")
        self.results[sid]["reconciliation_performed"] = False
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_AMBIGUOUS_CREATE"):
            self.evaluate()

    def test_ambiguous_create_second_post_rejected(self):
        sid = self.scenario_id("AMBIGUOUS_CREATE_RETRY")
        self.results[sid]["provider_create_request_count"] = 2
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_AMBIGUOUS_CREATE"):
            self.evaluate()

    def test_cancel_claim_requires_confirmation(self):
        sid = self.scenario_id("CANCEL_SEPARATING")
        self.results[sid]["upstream_cancel_state"] = "requested"
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_CANCEL_CLAIM"):
            self.evaluate()

    def test_cancel_conservative_claim_allowed(self):
        sid = self.scenario_id("CANCEL_SEPARATING")
        self.results[sid]["claimed_upstream_cancelled"] = False
        self.assertEqual(
            self.evaluate()["recovery_state"],
            "READY_FOR_HQ_E05_LIVE_REVIEW",
        )

    def test_cancel_never_publishes_output(self):
        sid = self.scenario_id("CANCEL_FINALIZING")
        self.results[sid]["outputs_published_after_cancel"] = True
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_CANCEL_SEMANTICS"):
            self.evaluate()

    def test_cancel_upload_does_not_create_task(self):
        sid = self.scenario_id("CANCEL_UPLOAD")
        self.results[sid]["provider_create_request_count"] = 1
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_CANCEL_UPLOAD_CREATED"):
            self.evaluate()

    def test_provider_cancel_request_is_idempotent(self):
        sid = self.scenario_id("CANCEL_SEPARATING")
        self.results[sid]["provider_cancel_request_count"] = 2
        with self.assertRaisesRegex(
            RecoveryGateError,
            "L1E05_CANCEL_PROVIDER_REQUEST_DUPLICATE",
        ):
            self.evaluate()

    def test_project_corruption_rejected(self):
        self.results["S0"]["project_corrupted"] = True
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_PROJECT_INTEGRITY"):
            self.evaluate()

    def test_partial_publication_rejected(self):
        self.results["S0"]["partial_result_published"] = True
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_PROJECT_INTEGRITY"):
            self.evaluate()

    def test_relaunch_must_be_observed(self):
        sid = self.scenario_id("RELAUNCH")
        self.results[sid]["relaunch_observed"] = False
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_RELAUNCH"):
            self.evaluate()

    def test_rate_limit_must_be_observed(self):
        sid = self.scenario_id("RATE_LIMIT")
        self.results[sid]["rate_limit_observed"] = False
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_RATE_LIMIT"):
            self.evaluate()

    def test_long_track_requires_bounded_streaming(self):
        sid = self.scenario_id("LONG_TRACK")
        self.results[sid]["bounded_streaming_observed"] = False
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_LONG_TRACK"):
            self.evaluate()

    def test_storage_pressure_requires_preflight(self):
        sid = self.scenario_id("STORAGE_PRESSURE")
        self.results[sid]["storage_preflight_observed"] = False
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_STORAGE_PREFLIGHT"):
            self.evaluate()

    def test_output_expiry_requires_safe_resolution(self):
        sid = self.scenario_id("OUTPUT_EXPIRY")
        self.results[sid]["output_expiry_resolution"] = "blind_new_job"
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_OUTPUT_EXPIRY"):
            self.evaluate()

    def test_external_provenance_hash_required(self):
        self.results["S0"]["provenance"]["fault_injection_sha256"] = "f" * 64
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_PROVENANCE_SHA"):
            self.evaluate()

    def test_private_evidence_must_not_be_inside_repository(self):
        private = self.repo / "private"
        private.mkdir()
        (private / "fault.txt").write_text("fault proof", encoding="utf-8")
        (private / "account.txt").write_text("account proof", encoding="utf-8")
        for result in self.results.values():
            result["provenance"]["fault_injection_sha256"] = sha256_file(private / "fault.txt")
            result["provenance"]["provider_account_sha256"] = sha256_file(private / "account.txt")
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_PRIVATE_ROOT_INSIDE"):
            evaluate_campaign(
                plan=self.plan,
                e01=self.e01,
                e03=self.e03,
                results_by_scenario=self.results,
                repo_root=self.repo,
                private_root=private,
            )

    def test_failed_closed_does_not_mutate_previous_committed_result(self):
        self.results["S0"]["project_state_after"] = "failed_closed"
        self.results["S0"]["committed_result_sha256_after"] = "f" * 64
        with self.assertRaisesRegex(RecoveryGateError, "L1E05_FAILED_CLOSED_MUTATED"):
            self.evaluate()

    def test_public_evidence_redacts_private_paths(self):
        text = json.dumps(self.evaluate())
        self.assertNotIn("fault.txt", text)
        self.assertNotIn("account.txt", text)
        self.assertNotIn("task_live_123", text)


if __name__ == "__main__":
    unittest.main()
