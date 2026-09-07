from __future__ import annotations

import copy
import hashlib
import json
import os
import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

EVAL = Path(__file__).resolve().parents[1] / "Evaluation"
if str(EVAL) not in sys.path:
    sys.path.insert(0, str(EVAL))

import live_separation_benchmark as e03


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def wav(path: Path, *, frames: int = 800, rate: int = 8000, value: int = 1000) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        samples = [int(value if i % 2 == 0 else -value) for i in range(frames)]
        handle.writeframes(struct.pack("<" + "h" * len(samples), *samples))


class E03Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.out = self.root / "e03-out"
        self.env = {"PROVIDER_TOKEN": "test-secret-only-in-process"}
        self.modes = [
            ("m2", "TWO_STEM", "m2", "v1", "standard", ["vocals", "instrumental"]),
            ("m4", "CORE_FOUR_STEM", "m4", "v2", "standard", ["vocals", "drums", "bass", "other"]),
            ("mc", "CUSTOM_INSTRUMENT", "mc", "v3", "standard", ["vocals", "guitar"]),
            ("mh", "HIFI_ADVANCED", "mh", "v4", "hifi", ["vocals", "drums", "bass", "other"]),
        ]
        self.fixtures = {}
        e02_rows = []
        for idx, (mid, _, _, _, _, roles) in enumerate(self.modes, 1):
            group = "G1" if mid in {"m2", "m4"} else "G2"
            fid = f"FX-{mid}"
            mix = self.root / "media" / f"{fid}-mix.wav"
            wav(mix, value=1000 + idx)
            manifest = {
                "schema_version": 1,
                "fixture_id": fid,
                "class": "PROJECT_OWNED_REAL_MULTITRACK" if group == "G1" else "RIGHTS_CLEARED_REAL_REFERENCE",
                "title_alias": fid,
                "rights_record_id": f"RIGHTS-{fid}",
                "rights_basis": "private verified test fixture only",
                "rights_status": "VERIFIED",
                "redistribution_allowed": False,
                "commercial_engineering_use_allowed": True,
                "reference_service_submission_allowed": True,
                "real_recorded_music": True,
                "synthetic": False,
                "requested_roles": roles,
                "genre_bucket": "test",
                "hard_cases": [],
                "duration_seconds": 0.1,
                "sample_rate_hz": 8000,
                "channels": 1,
                "mixture": {"path": mix.relative_to(self.root).as_posix(), "sha256": sha(mix)},
            }
            if group == "G1":
                refs = {}
                for role_index, role in enumerate(roles, 1):
                    p = self.root / "media" / f"{fid}-{role}.wav"
                    wav(p, value=400 + role_index)
                    refs[role] = {"path": p.relative_to(self.root).as_posix(), "sha256": sha(p)}
                manifest["reference_stems"] = refs
            fixture_path = self.root / "fixtures" / f"{fid}.json"
            fixture_path.parent.mkdir(parents=True, exist_ok=True)
            fixture_path.write_text(json.dumps(manifest), encoding="utf-8")
            self.fixtures[mid] = fixture_path
            e02_rows.append({
                "fixture_id": fid,
                "group": group,
                "manifest_sha256": sha(fixture_path),
                "mixture_sha256": sha(mix),
            })
        self.e01 = {
            "schema_version": 1,
            "evidence_kind": "COMMERCIAL_ROUTE_APPROVAL",
            "evidence_state": e03.EVIDENCE_STATE,
            "result": "READY_FOR_LIVE_PROVIDER_GATE",
            "parity_claim": "NONE",
            "provider": {
                "provider_id": "APPROVED_PROVIDER",
                "models": [
                    {"model_name": name, "model_version": version, "quality_profile": quality, "canonical_roles": roles}
                    for _, _, name, version, quality, roles in self.modes
                ],
            },
            "credential_preflight": {
                "environment_names": ["PROVIDER_TOKEN"],
                "all_present": True,
                "values_persisted": False,
                "server_side_only": True,
                "client_distribution_prohibited": True,
                "repository_exact_secret_scan": "PASS",
            },
            "approval_manifest_identity_sha256": "1" * 64,
        }
        self.e02 = {
            "schema_version": 1,
            "evidence_kind": "RIGHTS_CLEARED_REAL_AUDIO_INTAKE",
            "evidence_state": e03.EVIDENCE_STATE,
            "intake_state": "READY_FOR_HQ_LIVE_AUDIO_GATE",
            "parity_state": "NON_PARITY_EVIDENCE_ONLY",
            "a19_corpus_lock_sha256": "2" * 64,
            "e02_rights_intake_lock_sha256": "3" * 64,
            "fixtures": e02_rows,
        }
        self.plan = {
            "schema_version": 1,
            "evidence_state": e03.EVIDENCE_STATE,
            "benchmark_id": "E03-TEST",
            "execution": {
                "provider_command": ["driver", "--fixture", "{fixture}", "--run", "{project_run}", "--idempotency", "{idempotency_key}"],
                "timeout_seconds": 30,
                "max_attempts_per_run": 2,
                "driver_guarantees_stable_idempotency": True,
            },
            "requirements": {
                "minimum_successful_runs_per_mode": 2,
                "minimum_g1_objective_runs": 2,
                "max_final_failure_fraction": 0.0,
                "max_retry_fraction": 0.5,
                "require_two_stem": True,
                "require_core_four_stem": True,
                "require_custom_instrument": True,
                "hifi_required_by_reference": True,
            },
            "modes": [
                {"mode_id": mid, "mode_class": klass, "model_name": name, "model_version": version,
                 "quality_profile": quality, "target_roles": roles, "required": True}
                for mid, klass, name, version, quality, roles in self.modes
            ],
            "cases": [
                {"case_id": f"C-{mid}", "fixture_manifest": path.relative_to(self.root).as_posix(),
                 "mode_id": mid, "repeat_count": 2, "run_manifest_template": f"runs/{mid}-{{repeat}}.json"}
                for mid, path in self.fixtures.items()
            ],
        }

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _write_valid_run(self, run_path: Path, fixture_path: Path, mode: dict, *, provider="APPROVED_PROVIDER", model=None, version=None, topology="server") -> None:
        fixture = json.loads(fixture_path.read_text())
        results = []
        for index, role in enumerate(mode["target_roles"], 1):
            artifact = self.root / "artifacts" / (run_path.stem + f"-{role}.wav")
            if fixture["class"] == "PROJECT_OWNED_REAL_MULTITRACK":
                reference = self.root / fixture["reference_stems"][role]["path"]
                artifact.parent.mkdir(parents=True, exist_ok=True)
                artifact.write_bytes(reference.read_bytes())
            else:
                wav(artifact, value=600 + index)
            results.append({
                "role": role,
                "container": "wav",
                "sample_rate_hz": 8000,
                "channels": 1,
                "frame_count": 800,
                "duration_seconds": 0.1,
                "artifact_path": artifact.relative_to(self.root).as_posix(),
                "sha256": sha(artifact),
            })
        payload = {
            "schema_version": 1,
            "run_id": "RUN-" + run_path.stem,
            "fixture_id": fixture["fixture_id"],
            "provider": {
                "provider_id": provider,
                "provider_kind": "PROJECT_APPROVED_COMMERCIAL",
                "model_name": model or mode["model_name"],
                "model_version": version or mode["model_version"],
                "execution_topology": topology,
                "commercial_approval_basis_id": "E01",
            },
            "timing_ms": {"upload": 10, "queue": 20, "inference": 30, "download": 40, "total": 100},
            "cost": {"currency": "USD", "total": 0.25, "credits": None, "basis": "private provider billing record"},
            "results": results,
        }
        run_path.parent.mkdir(parents=True, exist_ok=True)
        run_path.write_text(json.dumps(payload), encoding="utf-8")

    def _completed(self, code=0, stdout="", stderr=""):
        class C:
            returncode = code
        item = C()
        item.stdout = stdout
        item.stderr = stderr
        return item

    def _driver(self, *, fail_first=False):
        calls = {}
        def run(argv, **kwargs):
            run_path = Path(argv[argv.index("--run") + 1])
            fixture_path = Path(argv[argv.index("--fixture") + 1])
            key = str(run_path)
            calls[key] = calls.get(key, 0) + 1
            if fail_first and calls[key] == 1:
                return self._completed(75, stderr='{"stable_error_code":"SEP_RATE_LIMITED"}')
            mode_id = run_path.stem.split("-")[0]
            mode = next(row for row in self.plan["modes"] if row["mode_id"] == mode_id)
            self._write_valid_run(run_path, fixture_path, mode)
            return self._completed(0)
        return run

    def _execute(self, *, plan=None, e01=None, e02=None, out=None, driver=None):
        with mock.patch.object(e03.subprocess, "run", side_effect=driver or self._driver()):
            return e03.run_live_benchmark(
                plan=plan or self.plan,
                root=self.root,
                e01_evidence=e01 or self.e01,
                e02_evidence=e02 or self.e02,
                output_dir=out or self.out,
                env=self.env,
            )

    def test_happy_path_privacy_and_resume(self):
        report = self._execute()
        self.assertEqual(report["benchmark_state"], "READY_FOR_HQ_E03_LIVE_REVIEW")
        self.assertEqual(report["summary"]["logical_run_count"], 8)
        self.assertEqual(report["summary"]["successful_runs"], 8)
        self.assertEqual(report["summary"]["g1_objective_run_count"], 4)
        self.assertTrue(all(report["acceptance_checks"].values()))
        encoded = json.dumps(report)
        self.assertNotIn(self.env["PROVIDER_TOKEN"], encoded)
        self.assertNotIn("private provider billing record", encoded)
        first_lock = report["e03_live_benchmark_lock_sha256"]
        report2 = self._execute()
        self.assertEqual(first_lock, report2["e03_live_benchmark_lock_sha256"])

    def test_e01_e02_and_runtime_credential_fail_closed(self):
        bad_e01 = copy.deepcopy(self.e01); bad_e01["result"] = "PENDING_EXTERNAL_CREDENTIAL"
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_E01_NOT_READY"):
            self._execute(e01=bad_e01)
        bad_e02 = copy.deepcopy(self.e02); bad_e02["intake_state"] = "PENDING"
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_E02_NOT_READY"):
            self._execute(e02=bad_e02)
        with mock.patch.object(e03.subprocess, "run", side_effect=self._driver()):
            with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_RUNTIME_CREDENTIAL_MISSING"):
                e03.run_live_benchmark(plan=self.plan, root=self.root, e01_evidence=self.e01, e02_evidence=self.e02, output_dir=self.out, env={})

    def test_mode_contracts_fail_closed(self):
        p = copy.deepcopy(self.plan); p["modes"][0]["target_roles"] = ["vocals", "drums"]
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_TWO_STEM_ROLES"):
            self._execute(plan=p)
        p = copy.deepcopy(self.plan); p["modes"][2]["target_roles"] = ["vocals", "other"]
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_CUSTOM_NOT_ADDITIONAL"):
            self._execute(plan=p)
        p = copy.deepcopy(self.plan); p["modes"] = [row for row in p["modes"] if row["mode_class"] != "HIFI_ADVANCED"]
        p["cases"] = [row for row in p["cases"] if row["mode_id"] != "mh"]
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_REQUIRED_MODE_CLASS_MISSING"):
            self._execute(plan=p)

    def test_fixture_and_e02_binding_fail_closed(self):
        e02 = copy.deepcopy(self.e02); e02["fixtures"][0]["manifest_sha256"] = "f" * 64
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_FIXTURE_E02_SHA_MISMATCH"):
            self._execute(e02=e02)
        fixture = self.fixtures["mc"]
        payload = json.loads(fixture.read_text()); payload["synthetic"] = True
        fixture.write_text(json.dumps(payload), encoding="utf-8")
        e02 = copy.deepcopy(self.e02)
        for row in e02["fixtures"]:
            if row["fixture_id"] == "FX-mc": row["manifest_sha256"] = sha(fixture)
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_FIXTURE_INVALID"):
            self._execute(e02=e02)

    def test_preexisting_unbound_and_session_identity_mutation(self):
        run = self.root / "runs" / "m2-1.json"
        self._write_valid_run(run, self.fixtures["m2"], self.plan["modes"][0])
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_PREEXISTING_RUN_UNBOUND"):
            self._execute()
        run.unlink()
        self._execute()
        p = copy.deepcopy(self.plan); p["requirements"]["max_retry_fraction"] = 0.25
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_SESSION_IDENTITY_MISMATCH"):
            self._execute(plan=p)

    def test_retry_measurement_and_policy(self):
        report = self._execute(driver=self._driver(fail_first=True))
        self.assertEqual(report["summary"]["runs_with_retry"], 8)
        self.assertEqual(report["benchmark_state"], "LIVE_BENCHMARK_FAILED")
        self.assertFalse(report["acceptance_checks"]["retry_fraction"])
        self.assertTrue(all(run["retry_count"] == 1 for run in report["runs"]))

    def test_bound_run_mutation_and_missing_artifact(self):
        self._execute()
        run = self.root / "runs" / "m2-1.json"
        run.write_text(run.read_text() + " ", encoding="utf-8")
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_BOUND_RUN_MUTATED"):
            self._execute()
        run.write_text(run.read_text().rstrip(), encoding="utf-8")
        session = json.loads((self.out / "e03-session.json").read_text())
        logical = "C-m2:r001"
        session["runs"][logical]["run_manifest_sha256"] = sha(run)
        (self.out / "e03-session.json").write_text(json.dumps(session), encoding="utf-8")
        payload = json.loads(run.read_text())
        artifact = self.root / payload["results"][0]["artifact_path"]
        artifact.unlink()
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_RUN_INVALID"):
            self._execute()

    def test_provider_model_topology_and_artifact_guards(self):
        mode = self.plan["modes"][0]; fixture = json.loads(self.fixtures["m2"].read_text())
        run_path = self.root / "direct.json"
        for kwargs, code in [
            ({"provider":"OTHER"}, "L1E03_RUN_PROVIDER_MISMATCH"),
            ({"model":"other-model"}, "L1E03_RUN_MODEL_MISMATCH"),
            ({"topology":"device"}, "L1E03_RUN_TOPOLOGY"),
        ]:
            self._write_valid_run(run_path, self.fixtures["m2"], mode, **kwargs)
            run = json.loads(run_path.read_text())
            with self.assertRaisesRegex(e03.BenchmarkError, code):
                e03.validate_project_run(run, fixture, self.root, e03.validate_e01(self.e01), mode)
        self._write_valid_run(run_path, self.fixtures["m2"], mode)
        run = json.loads(run_path.read_text())
        run["results"][0]["artifact_path"] = None
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_RUN_INVALID"):
            e03.validate_project_run(run, fixture, self.root, e03.validate_e01(self.e01), mode)

    def test_execution_idempotency_path_and_case_guards(self):
        p = copy.deepcopy(self.plan); p["execution"]["driver_guarantees_stable_idempotency"] = False
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_IDEMPOTENCY_UNPROVEN"):
            self._execute(plan=p)
        p = copy.deepcopy(self.plan); p["execution"]["provider_command"] = ["driver", "{project_run}"]
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_IDEMPOTENCY_NOT_PASSED"):
            self._execute(plan=p)
        p = copy.deepcopy(self.plan); p["cases"][0]["run_manifest_template"] = "../escape-{repeat}.json"
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_PATH_UNSAFE"):
            self._execute(plan=p)
        p = copy.deepcopy(self.plan); p["cases"][0]["repeat_count"] = 1
        with self.assertRaisesRegex(e03.BenchmarkError, "L1E03_REPEAT_PLAN_INSUFFICIENT"):
            self._execute(plan=p)


if __name__ == "__main__":
    unittest.main()
