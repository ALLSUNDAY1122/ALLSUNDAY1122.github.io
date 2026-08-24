import hashlib
import tempfile
import unittest
from pathlib import Path

from runtime_authority_live_gate import (
    CANCEL_SCENARIOS,
    EVIDENCE_STATE,
    REQUIRED_SCENARIOS,
    RuntimeAuthorityError,
    evaluate_gate,
)

H = lambda value: hashlib.sha256(value.encode()).hexdigest()


def e07(route_kind="LICENSED_LOCAL_INFERENCE_SDK", authority_kind="LOCAL_RUNTIME"):
    return {
        "schema_version": 1,
        "tool_version": "L1-E07-v1",
        "evidence_kind": "PROVIDER_FALLBACK_SUBSTITUTION_CONFORMANCE",
        "evidence_state": EVIDENCE_STATE,
        "conformance_state": (
            "READY_FOR_HQ_E07_SUBSTITUTION_REVIEW"
            if authority_kind == "HOSTED_PROVIDER_ACCOUNT"
            else "CONFORMANT_REQUIRES_GENERIC_LIVE_AUTHORITY_GATE"
        ),
        "parity_claim": "NONE",
        "substitution_id": "sub-1",
        "route_id": "route-1",
        "route_kind": route_kind,
        "replaced_route_id": "old",
        "capacity_authority": {"kind": authority_kind, "provenance_sha256": H("authority")},
        "runtime": {
            "runtime_id": "rt",
            "model_name": "m",
            "model_version": "1",
            "quality_profile": "standard",
            "artifact_sha256": H("artifact"),
        },
        "compatibility": {
            "legacy_e05_e06_hosted_account_schema_compatible": authority_kind == "HOSTED_PROVIDER_ACCOUNT",
            "generic_capacity_authority_live_gate_required": authority_kind != "HOSTED_PROVIDER_ACCOUNT",
            "shared_app_contract_changed": False,
            "provider_neutral_publication_contract_preserved": True,
        },
        "e07_substitution_lock_sha256": H("e07-lock"),
    }


def plan(route_kind="LICENSED_LOCAL_INFERENCE_SDK"):
    return {
        "schema_version": 1,
        "evidence_state": EVIDENCE_STATE,
        "parity_claim": "NONE",
        "gate_id": "gate-1",
        "route_id": "route-1",
        "route_kind": route_kind,
        "scenarios": list(REQUIRED_SCENARIOS),
        "policy": {
            "maximum_non_cancel_degraded_fraction": 0.2,
            "require_capacity_attestation": True,
            "engineering_policy_not_reference_fact": True,
        },
    }


def result(kind, authority_kind="LOCAL_RUNTIME", state=None):
    cancel = kind in CANCEL_SCENARIOS
    return {
        "schema_version": 1,
        "evidence_state": EVIDENCE_STATE,
        "scenario_kind": kind,
        "stable_error_codes": ["SEP_TEST"] if kind == "INPUT_INTERRUPTION" else [],
        "project_state_after": state or ("cancelled" if cancel else "ready"),
        "project_corrupted": False,
        "partial_result_published": False,
        "work_start_request_count": 0 if kind == "CANCEL_PRE_START" else 1,
        "distinct_execution_count": 0 if kind == "CANCEL_PRE_START" else 1,
        "upstream_cancel_request_count": 1 if cancel and kind != "CANCEL_PRE_START" else 0,
        "billable_execution_count": 0 if kind == "CANCEL_PRE_START" else 1,
        "automatic_start_repost_count": 0,
        "duplicate_execution_detected": False,
        "reconciliation_performed": kind == "AMBIGUOUS_START_RETRY",
        "logical_cancelled": cancel,
        "outputs_published_after_cancel": False,
        "logical_job_identity_sha256": H("job"),
        "idempotency_key_sha256": H("idempotency"),
        "logical_identity_preserved": True,
        "upstream_cancel_state": "requested" if cancel else "not_applicable",
        "claimed_upstream_cancelled": False,
        "relaunch_observed": kind == "RELAUNCH",
        "capacity_limit_observed": kind == "CAPACITY_LIMIT",
        "bounded_streaming_observed": kind == "LONG_TRACK",
        "storage_preflight_observed": kind == "STORAGE_PRESSURE",
        "output_availability_resolution": (
            "verified_project_copy" if kind == "OUTPUT_AVAILABILITY_LOSS" else "not_applicable"
        ),
        "runtime_artifact_sha256": H("artifact"),
        "authority": {
            "kind": authority_kind,
            "provenance_path": "authority.txt",
            "provenance_sha256": H("authority"),
        },
        "fault_injection": {"path": "fault.txt", "sha256": H("fault")},
    }


def capacity(authority_kind="LOCAL_RUNTIME", statuses=("ADEQUATE", "ADEQUATE", "ADEQUATE")):
    return {
        "schema_version": 1,
        "evidence_kind": "RUNTIME_AUTHORITY_CAPACITY_SNAPSHOT",
        "evidence_state": EVIDENCE_STATE,
        "parity_claim": "NONE",
        "route_id": "route-1",
        "captured_at": "2026-08-24T00:00:00Z",
        "authority": {"kind": authority_kind, "provenance_sha256": H("authority")},
        "measurement": {"path": "capacity.txt", "sha256": H("capacity")},
        "capacity": {
            "execution_capacity_status": statuses[0],
            "cost_headroom_status": statuses[1],
            "throughput_headroom_status": statuses[2],
        },
        "privacy": {
            "authority_ids_emitted": False,
            "raw_capacity_values_emitted": False,
            "raw_billing_records_emitted": False,
            "private_paths_emitted": False,
        },
    }


class RuntimeAuthorityLiveGateTests(unittest.TestCase):
    def run_gate(
        self,
        route_kind="LICENSED_LOCAL_INFERENCE_SDK",
        authority_kind="LOCAL_RUNTIME",
        statuses=("ADEQUATE", "ADEQUATE", "ADEQUATE"),
        mutate=None,
    ):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            repo = root / "repo"
            private = root / "private"
            repo.mkdir()
            private.mkdir()
            (private / "authority.txt").write_text("authority", encoding="utf-8")
            (private / "fault.txt").write_text("fault", encoding="utf-8")
            (private / "capacity.txt").write_text("capacity", encoding="utf-8")
            E = e07(route_kind, authority_kind)
            P = plan(route_kind)
            R = {kind: result(kind, authority_kind) for kind in REQUIRED_SCENARIOS}
            C = capacity(authority_kind, statuses)
            if mutate:
                mutate(E, P, R, C)
            return evaluate_gate(
                plan=P,
                e07=E,
                e07_source_sha256=H("e07-physical"),
                results_by_scenario=R,
                capacity=C,
                repo_root=repo,
                private_root=private,
            )

    def assertCode(self, code, mutate):
        with self.assertRaises(RuntimeAuthorityError) as ctx:
            self.run_gate(mutate=mutate)
        self.assertEqual(ctx.exception.code, code)

    def test_three_authority_kinds_pass(self):
        self.assertEqual(self.run_gate()["gate_state"], "READY_FOR_HQ_E08_LIVE_REVIEW")
        self.assertEqual(
            self.run_gate("ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER", "HOSTED_PROVIDER_ACCOUNT")["gate_state"],
            "READY_FOR_HQ_E08_LIVE_REVIEW",
        )
        self.assertEqual(
            self.run_gate(
                "PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE",
                "PROJECT_OWNED_RUNTIME",
            )["gate_state"],
            "READY_FOR_HQ_E08_LIVE_REVIEW",
        )

    def test_capacity_unknown_and_insufficient(self):
        self.assertEqual(
            self.run_gate(statuses=("UNKNOWN", "ADEQUATE", "ADEQUATE"))["gate_state"],
            "PENDING_EXTERNAL_EVIDENCE",
        )
        self.assertEqual(
            self.run_gate(statuses=("INSUFFICIENT", "ADEQUATE", "ADEQUATE"))["gate_state"],
            "LIVE_AUTHORITY_REJECTED",
        )

    def test_authority_and_runtime_binding(self):
        self.assertCode(
            "L1E08_E07_AUTHORITY_KIND_MISMATCH",
            lambda E, P, R, C: E["capacity_authority"].update(kind="HOSTED_PROVIDER_ACCOUNT"),
        )
        self.assertCode(
            "L1E08_AUTHORITY_KIND_MISMATCH",
            lambda E, P, R, C: R["INPUT_INTERRUPTION"]["authority"].update(kind="HOSTED_PROVIDER_ACCOUNT"),
        )
        self.assertCode(
            "L1E08_FAKE_PROVIDER_ACCOUNT_FORBIDDEN",
            lambda E, P, R, C: R["INPUT_INTERRUPTION"]["authority"].update(provider_account_id="fake"),
        )
        self.assertCode(
            "L1E08_RUNTIME_ARTIFACT_MISMATCH",
            lambda E, P, R, C: R["INPUT_INTERRUPTION"].update(runtime_artifact_sha256=H("other")),
        )

    def test_duplicate_and_ambiguous_start_safety(self):
        self.assertCode(
            "L1E08_DUPLICATE_EXECUTION_OR_BILLING",
            lambda E, P, R, C: R["RELAUNCH"].update(distinct_execution_count=2),
        )
        self.assertCode(
            "L1E08_DUPLICATE_EXECUTION_OR_BILLING",
            lambda E, P, R, C: R["RELAUNCH"].update(billable_execution_count=2),
        )
        self.assertCode(
            "L1E08_AUTOMATIC_START_REPOST_FORBIDDEN",
            lambda E, P, R, C: R["AMBIGUOUS_START_RETRY"].update(automatic_start_repost_count=1),
        )
        self.assertCode(
            "L1E08_AMBIGUOUS_START_NOT_RECONCILED",
            lambda E, P, R, C: R["AMBIGUOUS_START_RETRY"].update(reconciliation_performed=False),
        )

    def test_cancel_truthfulness(self):
        self.assertCode(
            "L1E08_CANCEL_PRE_START_EXECUTED",
            lambda E, P, R, C: R["CANCEL_PRE_START"].update(work_start_request_count=1),
        )
        self.assertCode(
            "L1E08_CANCEL_SEMANTICS_FAIL",
            lambda E, P, R, C: R["CANCEL_EXECUTING"].update(outputs_published_after_cancel=True),
        )
        self.assertCode(
            "L1E08_CANCEL_REQUEST_DUPLICATE",
            lambda E, P, R, C: R["CANCEL_FINALIZING"].update(upstream_cancel_request_count=2),
        )
        self.assertCode(
            "L1E08_CANCEL_CLAIM_UNTRUTHFUL",
            lambda E, P, R, C: R["CANCEL_EXECUTING"].update(claimed_upstream_cancelled=True),
        )

    def test_required_recovery_observations(self):
        self.assertCode(
            "L1E08_RELAUNCH_NOT_OBSERVED",
            lambda E, P, R, C: R["RELAUNCH"].update(relaunch_observed=False),
        )
        self.assertCode(
            "L1E08_CAPACITY_LIMIT_NOT_OBSERVED",
            lambda E, P, R, C: R["CAPACITY_LIMIT"].update(capacity_limit_observed=False),
        )
        self.assertCode(
            "L1E08_LONG_TRACK_NOT_STREAMED",
            lambda E, P, R, C: R["LONG_TRACK"].update(bounded_streaming_observed=False),
        )
        self.assertCode(
            "L1E08_STORAGE_PREFLIGHT_NOT_OBSERVED",
            lambda E, P, R, C: R["STORAGE_PRESSURE"].update(storage_preflight_observed=False),
        )
        self.assertCode(
            "L1E08_OUTPUT_AVAILABILITY_UNSAFE",
            lambda E, P, R, C: R["OUTPUT_AVAILABILITY_LOSS"].update(
                output_availability_resolution="recreated_new_job"
            ),
        )
        self.assertCode(
            "L1E08_INPUT_INTERRUPTION_CODE_MISSING",
            lambda E, P, R, C: R["INPUT_INTERRUPTION"].update(stable_error_codes=[]),
        )

    def test_integrity_identity_and_capacity_privacy(self):
        self.assertCode(
            "L1E08_PROJECT_INTEGRITY_FAIL",
            lambda E, P, R, C: R["RELAUNCH"].update(project_corrupted=True),
        )
        self.assertCode(
            "L1E08_PROJECT_INTEGRITY_FAIL",
            lambda E, P, R, C: R["RELAUNCH"].update(partial_result_published=True),
        )
        self.assertCode(
            "L1E08_LOGICAL_IDENTITY_NOT_PRESERVED",
            lambda E, P, R, C: R["RELAUNCH"].update(logical_identity_preserved=False),
        )
        self.assertCode(
            "L1E08_CAPACITY_AUTHORITY_KIND_MISMATCH",
            lambda E, P, R, C: C["authority"].update(kind="HOSTED_PROVIDER_ACCOUNT"),
        )
        self.assertCode(
            "L1E08_CAPACITY_AUTHORITY_PROVENANCE_MISMATCH",
            lambda E, P, R, C: C["authority"].update(provenance_sha256=H("other")),
        )
        self.assertCode(
            "L1E08_CAPACITY_PRIVACY_FAIL",
            lambda E, P, R, C: C["privacy"].update(authority_ids_emitted=True),
        )

    def test_scenario_sets_and_degradation_policy(self):
        self.assertCode("L1E08_SCENARIO_SET_INVALID", lambda E, P, R, C: P["scenarios"].pop())
        self.assertCode("L1E08_RESULT_SET_MISMATCH", lambda E, P, R, C: R.pop("RELAUNCH"))
        report = self.run_gate(
            mutate=lambda E, P, R, C: [
                R[k].update(project_state_after="recoverable")
                for k in ("RELAUNCH", "CAPACITY_LIMIT")
            ]
        )
        self.assertEqual(report["gate_state"], "LIVE_AUTHORITY_REJECTED")

    def test_public_output_privacy_and_non_parity(self):
        report = self.run_gate()
        self.assertEqual(report["parity_claim"], "NONE")
        self.assertEqual(report["evidence_state"], EVIDENCE_STATE)
        self.assertTrue(all(value is False for value in report["privacy"].values()))
        serialized = str(report)
        self.assertNotIn("authority.txt", serialized)
        self.assertNotIn("fault.txt", serialized)
        self.assertNotIn("capacity.txt", serialized)


if __name__ == "__main__":
    unittest.main()
