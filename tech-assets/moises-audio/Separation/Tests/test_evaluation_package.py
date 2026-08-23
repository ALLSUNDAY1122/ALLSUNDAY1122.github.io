from __future__ import annotations

import json
import math
import struct
import sys
import tempfile
import unittest
import wave
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Evaluation"))
from evaluation_core import EvaluationError, evaluate_run, sha256_file, streaming_si_sdr, validate_fixture_manifest, validate_listening_records, validate_run_manifest


def write_wav(path: Path, samples: list[float], sample_rate: int = 8000, channels: int = 1) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ints = [max(-32768, min(32767, int(round(value * 32767)))) for value in samples]
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(channels)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(struct.pack("<" + "h" * len(ints), *ints))


def tone(length: int, frequency: float, sample_rate: int = 8000, gain: float = 0.2) -> list[float]:
    return [gain * math.sin(2 * math.pi * frequency * index / sample_rate) for index in range(length)]


class EvaluationPackageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.roles = ["vocals", "drums", "bass", "other"]
        stems = {
            "vocals": tone(8000, 220),
            "drums": tone(8000, 330),
            "bass": tone(8000, 110),
            "other": tone(8000, 440),
        }
        for role, values in stems.items():
            write_wav(self.root / f"refs/{role}.wav", values)
            write_wav(self.root / f"out/{role}.wav", values)
        mixture = [sum(stems[role][i] for role in self.roles) for i in range(8000)]
        write_wav(self.root / "mix.wav", mixture)
        self.fixture = {
            "schema_version": 1,
            "fixture_id": "G1-UNIT-001",
            "class": "PROJECT_OWNED_REAL_MULTITRACK",
            "title_alias": "unit-real-fixture",
            "rights_record_id": "RIGHTS-PRIVATE-001",
            "rights_basis": "explicit project-owned written release",
            "rights_status": "VERIFIED",
            "redistribution_allowed": False,
            "commercial_engineering_use_allowed": True,
            "reference_service_submission_allowed": True,
            "real_recorded_music": True,
            "synthetic": False,
            "requested_roles": self.roles,
            "mixture": {"path": "mix.wav", "sha256": sha256_file(self.root / "mix.wav")},
            "reference_stems": {
                role: {"path": f"refs/{role}.wav", "sha256": sha256_file(self.root / f"refs/{role}.wav")}
                for role in self.roles
            },
            "duration_seconds": 1.0,
            "sample_rate_hz": 8000,
            "channels": 1,
            "genre_bucket": "unit-test-only",
            "hard_cases": [],
        }
        self.run = {
            "schema_version": 1,
            "run_id": "RUN-001",
            "fixture_id": self.fixture["fixture_id"],
            "provider": {
                "provider_id": "test-provider",
                "provider_kind": "PROJECT_OWNED",
                "model_name": "test-model",
                "model_version": "1.0.0",
                "execution_topology": "server",
                "commercial_approval_basis_id": "MODEL-RIGHTS-001",
            },
            "timing_ms": {"upload": 10, "queue": 5, "inference": 100, "download": 10, "total": 130},
            "cost": {"currency": "USD", "total": 0.01, "credits": 1.0, "basis": "test fixture only"},
            "results": [
                {
                    "role": role,
                    "artifact_path": f"out/{role}.wav",
                    "sha256": sha256_file(self.root / f"out/{role}.wav"),
                    "container": "wav",
                    "sample_rate_hz": 8000,
                    "channels": 1,
                    "frame_count": 8000,
                    "duration_seconds": 1.0,
                    "source_url": None,
                    "source_url_expires_at": None,
                }
                for role in self.roles
            ],
        }

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def assertCode(self, code: str, func, *args, **kwargs) -> None:
        with self.assertRaises(EvaluationError) as caught:
            func(*args, **kwargs)
        self.assertEqual(caught.exception.code, code)

    def test_valid_g1_and_identical_metrics(self) -> None:
        summary = validate_fixture_manifest(self.fixture, self.root, purpose="PARITY_CANDIDATE")
        self.assertTrue(summary["objective_reference_available"])
        evidence = evaluate_run(self.fixture, self.run, self.root, purpose="REGRESSION")
        self.assertEqual(evidence["parity_state"], "NON_PARITY_EVIDENCE_ONLY")
        self.assertGreater(evidence["objective_metrics"]["per_stem"]["vocals"]["si_sdr_db"], 100)
        self.assertLess(evidence["objective_metrics"]["mixture_reconstruction"]["normalized_rmse"], 0.001)

    def test_missing_commercial_rights_rejected(self) -> None:
        fixture = dict(self.fixture, commercial_engineering_use_allowed=False)
        self.assertCode("EVAL_RIGHTS_COMMERCIAL_DENIED", validate_fixture_manifest, fixture, self.root, purpose="PARITY_CANDIDATE")

    def test_g2_missing_reference_submission_right_rejected(self) -> None:
        fixture = dict(self.fixture)
        fixture["class"] = "RIGHTS_CLEARED_REAL_REFERENCE"
        fixture["reference_service_submission_allowed"] = False
        fixture.pop("reference_stems")
        self.assertCode("EVAL_REFERENCE_SUBMISSION_DENIED", validate_fixture_manifest, fixture, self.root)

    def test_synthetic_fixture_cannot_enter_parity(self) -> None:
        fixture = dict(self.fixture)
        fixture.update({"class": "LICENSED_SYNTHETIC", "real_recorded_music": False, "synthetic": True})
        self.assertCode("EVAL_SYNTHETIC_ONLY_PARITY_FORBIDDEN", validate_fixture_manifest, fixture, self.root, purpose="PARITY_CANDIDATE")

    def test_generated_signal_cannot_enter_parity(self) -> None:
        fixture = dict(self.fixture)
        fixture.update({"class": "GENERATED_SIGNAL", "real_recorded_music": False, "synthetic": True})
        self.assertCode("EVAL_SYNTHETIC_ONLY_PARITY_FORBIDDEN", validate_fixture_manifest, fixture, self.root, purpose="PARITY_CANDIDATE")

    def test_missing_rights_record_id_rejected(self) -> None:
        fixture = dict(self.fixture, rights_record_id="")
        self.assertCode("EVAL_SCHEMA_REQUIRED", validate_fixture_manifest, fixture, self.root)

    def test_missing_result_stem_rejected(self) -> None:
        run = dict(self.run, results=self.run["results"][:-1])
        self.assertCode("EVAL_RESULT_STEM_MISSING", validate_run_manifest, run, self.fixture, self.root)

    def test_duplicate_result_stem_rejected(self) -> None:
        duplicate = dict(self.run["results"][0])
        run = dict(self.run, results=self.run["results"] + [duplicate])
        self.assertCode("EVAL_RESULT_ROLE_DUPLICATE", validate_run_manifest, run, self.fixture, self.root)

    def test_expired_remote_only_result_rejected(self) -> None:
        future_run = json.loads(json.dumps(self.run))
        first = future_run["results"][0]
        first["artifact_path"] = None
        first["sha256"] = None
        first["source_url"] = "https://example.invalid/output.wav"
        first["source_url_expires_at"] = "2026-01-01T00:00:00Z"
        self.assertCode(
            "EVAL_RESULT_REMOTE_EXPIRED", validate_run_manifest, future_run, self.fixture, self.root,
            now=datetime(2026, 8, 22, tzinfo=timezone.utc)
        )

    def test_hash_mismatch_rejected(self) -> None:
        fixture = json.loads(json.dumps(self.fixture))
        fixture["mixture"]["sha256"] = "0" * 64
        self.assertCode("EVAL_HASH_MISMATCH", validate_fixture_manifest, fixture, self.root)

    def test_sample_rate_mismatch_rejected_for_objective_metric(self) -> None:
        write_wav(self.root / "out/vocals.wav", tone(16000, 220, sample_rate=16000), sample_rate=16000)
        self.assertCode("EVAL_SAMPLE_RATE_MISMATCH", streaming_si_sdr, self.root / "refs/vocals.wav", self.root / "out/vocals.wav")

    def test_provider_version_is_required(self) -> None:
        run = json.loads(json.dumps(self.run))
        run["provider"]["model_version"] = ""
        self.assertCode("EVAL_SCHEMA_REQUIRED", validate_run_manifest, run, self.fixture, self.root)

    def test_listening_score_out_of_range_rejected(self) -> None:
        record = self.listening_pair()[0]
        record["scores"]["bleed"] = 5
        self.assertCode("EVAL_LISTENING_SCORE", validate_listening_records, [record], self.fixture)

    def test_parity_listening_requires_both_systems_for_every_role(self) -> None:
        records = self.listening_pair()
        self.assertCode("EVAL_LISTENING_PAIR_MISSING", validate_listening_records, records, self.fixture, purpose="PARITY_CANDIDATE")

    def test_schema_documents_are_machine_readable(self) -> None:
        schemas = Path(__file__).resolve().parents[1] / "Evaluation" / "schemas"
        names = ["fixture-rights.schema.json", "run-evidence-input.schema.json", "blind-listening.schema.json", "evidence-output.schema.json"]
        for name in names:
            data = json.loads((schemas / name).read_text(encoding="utf-8"))
            self.assertEqual(data["$schema"], "https://json-schema.org/draft/2020-12/schema")

    def test_valid_full_blind_pairs_pass_format_gate(self) -> None:
        records = []
        for role in self.roles:
            records.extend(self.listening_pair(role=role))
        summary = validate_listening_records(records, self.fixture, purpose="PARITY_CANDIDATE")
        self.assertEqual(summary["record_count"], 8)

    def listening_pair(self, role: str = "vocals") -> list[dict]:
        scores = {name: 3 for name in (
            "target_preservation", "bleed", "musical_noise", "transient_integrity",
            "timbre_formant_integrity", "stereo_phase_integrity", "low_frequency_integrity",
            "reverb_ambience", "overall_practice_usability"
        )}
        base = {
            "run_id": "LISTEN-001",
            "fixture_id": self.fixture["fixture_id"],
            "stem": role,
            "scores": scores,
            "notes": [],
            "listener_id": "listener-anon-1",
            "timestamp": "2026-08-22T08:00:00Z",
        }
        project = dict(base, system_blind_id="A", revealed_system="PROJECT")
        reference = dict(base, system_blind_id="B", revealed_system="REFERENCE")
        return [project, reference]


if __name__ == "__main__":
    unittest.main()
