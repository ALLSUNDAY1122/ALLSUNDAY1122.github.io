from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

EVALUATION_DIR = Path(__file__).resolve().parents[1] / "Evaluation"
sys.path.insert(0, str(EVALUATION_DIR))

from differential_common import (
    GateError,
    command_for_case,
    stable_idempotency_key,
    validate_plan,
    validate_system_identity,
)
from differential_review import build_blind_review


def base_plan() -> dict:
    cases = [
        ("c1", "rock", "short", ["vocals", "drums", "bass", "other"]),
        ("c2", "pop", "medium", ["vocals", "drums", "bass", "other"]),
        ("c3", "jazz", "long", ["vocals", "drums", "bass", "other"]),
        ("c4", "acoustic", "medium", ["vocals", "instrumental"]),
        ("c5", "electronic", "short", ["vocals", "drums", "bass", "other"]),
        ("c6", "live", "long", ["vocals", "drums", "bass", "other"]),
        ("c7", "classical", "medium", ["vocals", "instrumental"]),
        ("c8", "dense", "long", ["vocals", "drums", "bass", "other"]),
    ]
    return {
        "schema_version": 1,
        "batch_id": "TEST-BATCH",
        "evidence_state": "NON_PARITY_EVIDENCE_ONLY",
        "purpose": "PARITY_CANDIDATE",
        "reference_system": "MOISES_CURRENT_IPHONE",
        "legal_gate": {
            "commercial_approval_basis_id": "terms-1",
            "privacy_retention_approval_id": "privacy-1",
            "reference_comparison_rights_id": "rights-1",
            "provider_idempotency_contract_id": "idem-1",
            "production_credentials_env": ["L1M04_TEST_KEY"],
        },
        "coverage_requirements": {
            "min_cases": 8,
            "min_genres": 5,
            "required_duration_buckets": ["short", "medium", "long"],
            "required_target_role_sets": [
                ["vocals", "drums", "bass", "other"],
                ["vocals", "instrumental"],
            ],
        },
        "execution": {
            "max_attempts_per_case": 2,
            "timeout_seconds": 30,
            "driver_guarantees_stable_idempotency": True,
            "provider_command": [
                "python3", "driver.py", "--fixture", "{fixture}",
                "--output", "{project_run}", "--idempotency-key", "{idempotency_key}",
            ],
        },
        "acceptance_policy": {
            "policy_id": "policy-v1",
            "max_case_failure_rate": 0.0,
            "max_retry_fraction": 0.25,
            "max_mean_wall_time_ratio_vs_reference": 1.25,
            "min_mean_objective_si_sdr_delta_db": -0.5,
            "min_mean_listening_delta": -0.15,
            "min_worst_role_overall_usability_delta": -0.25,
            "min_reviewers_per_system_per_role": 2,
            "minimum_objective_cases": 3,
            "max_project_cost_per_audio_minute": None,
            "cost_currency": None,
        },
        "cases": [
            {
                "case_id": case_id,
                "genre": genre,
                "duration_bucket": bucket,
                "target_roles": roles,
                "fixture_manifest": f"fixtures/{case_id}.json",
                "project_run_manifest": f"runs/project/{case_id}.json",
                "reference_run_manifest": f"runs/reference/{case_id}.json",
            }
            for case_id, genre, bucket, roles in cases
        ],
    }


class DifferentialGateContractTests(unittest.TestCase):
    def assertCode(self, expected: str, callable_):
        with self.assertRaises(GateError) as caught:
            callable_()
        self.assertEqual(expected, caught.exception.code)

    def validate(self, plan: dict, root: Path):
        with patch.dict(os.environ, {"L1M04_TEST_KEY": "secret"}, clear=False):
            return validate_plan(plan, root)

    def test_01_valid_parity_plan_normalizes(self):
        with tempfile.TemporaryDirectory() as td:
            config = self.validate(base_plan(), Path(td))
            self.assertEqual("PARITY_CANDIDATE", config["purpose"])
            self.assertEqual(8, len(config["cases"]))

    def test_02_evidence_state_cannot_claim_parity(self):
        plan = base_plan()
        plan["evidence_state"] = "PARITY"
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_EVIDENCE_STATE", lambda: self.validate(plan, Path(td)))

    def test_03_reference_system_is_current_iphone_only(self):
        plan = base_plan()
        plan["reference_system"] = "MOISES_DESKTOP"
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_REFERENCE_SYSTEM", lambda: self.validate(plan, Path(td)))

    def test_04_missing_production_credentials_fail_closed(self):
        plan = base_plan()
        with tempfile.TemporaryDirectory() as td, patch.dict(os.environ, {}, clear=True):
            self.assertCode("L1M04_PRODUCTION_CREDENTIALS_MISSING", lambda: validate_plan(plan, Path(td)))

    def test_05_unsafe_credential_env_name_rejected(self):
        plan = base_plan()
        plan["legal_gate"]["production_credentials_env"] = ["BAD-NAME"]
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_CREDENTIAL_ENV_NAME", lambda: self.validate(plan, Path(td)))

    def test_06_stable_driver_must_receive_idempotency_key(self):
        plan = base_plan()
        plan["execution"]["provider_command"] = ["python3", "driver.py", "--fixture", "{fixture}"]
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_IDEMPOTENCY_KEY_NOT_PASSED", lambda: self.validate(plan, Path(td)))

    def test_07_parity_retry_requires_stable_idempotency(self):
        plan = base_plan()
        plan["execution"]["driver_guarantees_stable_idempotency"] = False
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_IDEMPOTENCY_UNPROVEN", lambda: self.validate(plan, Path(td)))

    def test_08_parity_case_floor_cannot_be_weakened(self):
        plan = base_plan()
        plan["coverage_requirements"]["min_cases"] = 1
        plan["cases"] = plan["cases"][:5]
        plan["coverage_requirements"]["min_genres"] = 1
        plan["coverage_requirements"]["required_duration_buckets"] = ["short"]
        plan["coverage_requirements"]["required_target_role_sets"] = [["vocals", "drums", "bass", "other"]]
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_PARITY_CASE_FLOOR", lambda: self.validate(plan, Path(td)))

    def test_09_parity_genre_floor_cannot_be_weakened(self):
        plan = base_plan()
        plan["coverage_requirements"]["min_genres"] = 1
        for index, case in enumerate(plan["cases"]):
            case["genre"] = "rock" if index % 2 == 0 else "pop"
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_PARITY_GENRE_FLOOR", lambda: self.validate(plan, Path(td)))

    def test_10_parity_duration_floor_cannot_be_weakened(self):
        plan = base_plan()
        plan["coverage_requirements"]["required_duration_buckets"] = ["short"]
        for case in plan["cases"]:
            case["duration_bucket"] = "short"
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_PARITY_DURATION_FLOOR", lambda: self.validate(plan, Path(td)))

    def test_11_parity_core_four_stem_floor_cannot_be_weakened(self):
        plan = base_plan()
        plan["coverage_requirements"]["required_target_role_sets"] = [["vocals", "instrumental"]]
        for case in plan["cases"]:
            case["target_roles"] = ["vocals", "instrumental"]
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_PARITY_CORE_TARGET_FLOOR", lambda: self.validate(plan, Path(td)))

    def test_12_duplicate_case_ids_rejected(self):
        plan = base_plan()
        plan["cases"][1]["case_id"] = plan["cases"][0]["case_id"]
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_CASE_DUPLICATE", lambda: self.validate(plan, Path(td)))

    def test_13_path_escape_rejected(self):
        plan = base_plan()
        plan["cases"][0]["fixture_manifest"] = "../outside.json"
        with tempfile.TemporaryDirectory() as td:
            self.assertCode("L1M04_PATH_UNSAFE", lambda: self.validate(plan, Path(td)))

    def test_14_idempotency_key_is_stable_and_case_scoped(self):
        first = stable_idempotency_key("batch", "case-a")
        second = stable_idempotency_key("batch", "case-a")
        other = stable_idempotency_key("batch", "case-b")
        self.assertEqual(first, second)
        self.assertNotEqual(first, other)

    def test_15_command_injects_same_stable_key(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            case = {
                "case_id": "case-a",
                "fixture_path": root / "fixture.json",
                "project_run_path": root / "project.json",
                "reference_run_path": root / "reference.json",
                "target_roles": ["bass", "drums", "other", "vocals"],
            }
            template = ["driver", "--key", "{idempotency_key}", "--roles", "{roles_csv}"]
            one = command_for_case(template, root, case, "batch")
            two = command_for_case(template, root, case, "batch")
            self.assertEqual(one, two)
            self.assertIn(stable_idempotency_key("batch", "case-a"), one)

    def test_16_reference_and_project_identity_are_not_interchangeable(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            run = root / "run.json"
            run.write_text(json.dumps({
                "provider": {
                    "provider_id": "MOISES_CURRENT_IPHONE",
                    "provider_kind": "REFERENCE_APP_CURRENT_IPHONE",
                }
            }), encoding="utf-8")
            validate_system_identity(run, expected="REFERENCE")
            self.assertCode("L1M04_PROJECT_IDENTITY_INVALID", lambda: validate_system_identity(run, expected="PROJECT"))

    def test_17_blind_review_requires_existing_local_artifacts(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            project = root / "project.json"
            reference = root / "reference.json"
            project.write_text(json.dumps({
                "results": [{"role": "vocals", "artifact_path": "missing-project.wav"}]
            }), encoding="utf-8")
            reference.write_text(json.dumps({
                "results": [{"role": "vocals", "artifact_path": "missing-reference.wav"}]
            }), encoding="utf-8")
            config = {
                "batch_id": "batch",
                "cases": [{
                    "case_id": "case",
                    "target_roles": ["vocals"],
                    "project_run_path": project,
                    "reference_run_path": reference,
                }],
            }
            self.assertCode(
                "L1M04_LOCAL_COMPARISON_ARTIFACT_REQUIRED",
                lambda: build_blind_review(config, root, root / "out"),
            )


if __name__ == "__main__":
    unittest.main()
