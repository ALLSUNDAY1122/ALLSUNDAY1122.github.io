import json
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path

from privacy_safe_observability import (
    ObservabilityError,
    PrivacySafeObservability,
    assert_privacy_safe_payload,
)

JOB = "a" * 32
JOB2 = "b" * 32


def code_of(cm):
    return cm.exception.code


@dataclass
class LongTrackStub:
    upload_milliseconds: int = 120
    upload_bytes: int = 1000
    download_milliseconds: int = 350
    download_bytes: int = 4000
    stable_error_code: str | None = None


@dataclass
class FaultStub:
    stable_error_code: str = "SEP_PROVIDER_RATE_LIMITED"
    operation_retryable: bool = True


class ObservabilityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "obs" / "evidence.json"
        self.clock = 1000
        self.obs = PrivacySafeObservability(self.path, now_epoch=lambda: self.clock)

    def tearDown(self):
        self.tmp.cleanup()

    def register(self, job=JOB, **overrides):
        data = dict(
            logical_job_id=job,
            profile_id="sep.basic.v1",
            target_count=4,
            provider_kind="audioshake",
            model_name="canonical-separation",
            model_version="v1",
            currency="USD",
            estimated_cost="0.250000",
            duration_milliseconds=180000,
            source_bytes=12345678,
        )
        data.update(overrides)
        return self.obs.register_job(**data)

    def test_register_hashes_logical_job_and_persists_no_raw_id(self):
        rec = self.register()
        self.assertNotEqual(rec.job_ref_hash, JOB)
        raw = self.path.read_text()
        self.assertNotIn(JOB, raw)
        self.assertNotIn("logical_job_id", raw)
        self.assertEqual(len(rec.job_ref_hash), 64)

    def test_register_is_idempotent_for_same_identity(self):
        a = self.register()
        self.clock += 5
        b = self.register()
        self.assertEqual(a.job_ref_hash, b.job_ref_hash)
        self.assertEqual(b.created_at_epoch, 1000)

    def test_register_conflict_fails_closed(self):
        self.register()
        with self.assertRaises(ObservabilityError) as cm:
            self.register(profile_id="sep.other.v1")
        self.assertEqual(code_of(cm), "SEP_OBS_REGISTRATION_CONFLICT")

    def test_invalid_job_id_rejected(self):
        with self.assertRaises(ObservabilityError) as cm:
            self.register(job="bad")
        self.assertEqual(code_of(cm), "SEP_OBS_LOGICAL_JOB_ID_INVALID")

    def test_url_like_provider_identifier_rejected(self):
        with self.assertRaises(ObservabilityError) as cm:
            self.register(provider_kind="https://evil")
        self.assertEqual(code_of(cm), "SEP_OBS_PROVIDER_INVALID")

    def test_phase_aggregation(self):
        self.register()
        self.obs.record_phase(JOB, phase="upload", elapsed_milliseconds=100, bytes_transferred=1000)
        self.clock += 1
        self.obs.record_phase(
            JOB,
            phase="upload",
            elapsed_milliseconds=50,
            bytes_transferred=500,
            retry_count_delta=1,
            failed=True,
            stable_error_code="SEP_PROVIDER_UPLOAD_TIMEOUT",
        )
        e = self.obs.evidence(JOB)
        stat = e["phase_stats"]["upload"]
        self.assertEqual(stat["attempts"], 2)
        self.assertEqual(stat["retry_count"], 1)
        self.assertEqual(stat["elapsed_milliseconds"], 150)
        self.assertEqual(stat["bytes_transferred"], 1500)
        self.assertEqual(stat["failure_count"], 1)
        self.assertEqual(stat["last_error_code"], "SEP_PROVIDER_UPLOAD_TIMEOUT")

    def test_retry_count_cannot_exceed_attempts(self):
        self.register()
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.record_phase(JOB, phase="poll", elapsed_milliseconds=1, retry_count_delta=2)
        self.assertEqual(code_of(cm), "SEP_OBS_RETRY_COUNT_INVALID")

    def test_failed_phase_requires_stable_code(self):
        self.register()
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.record_phase(JOB, phase="poll", elapsed_milliseconds=1, failed=True)
        self.assertEqual(code_of(cm), "SEP_OBS_FAILED_PHASE_ERROR_REQUIRED")

    def test_free_text_error_rejected(self):
        self.register()
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.record_phase(
                JOB, phase="poll", elapsed_milliseconds=1, failed=True,
                stable_error_code="provider timed out at https://secret"
            )
        self.assertEqual(code_of(cm), "SEP_OBS_ERROR_CODE_INVALID")

    def test_artifact_hash_recording(self):
        self.register()
        self.obs.record_artifact(JOB, role="vocals", sha256="a"*64, byte_count=999)
        e = self.obs.evidence(JOB)
        self.assertEqual(e["artifacts"]["vocals"]["sha256"], "a"*64)
        self.assertEqual(e["artifacts"]["vocals"]["byte_count"], 999)

    def test_artifact_conflict_fails_closed(self):
        self.register()
        self.obs.record_artifact(JOB, role="vocals", sha256="a"*64, byte_count=999)
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.record_artifact(JOB, role="vocals", sha256="b"*64, byte_count=999)
        self.assertEqual(code_of(cm), "SEP_OBS_ARTIFACT_CONFLICT")

    def test_artifact_path_not_accepted_as_role(self):
        self.register()
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.record_artifact(JOB, role="../../vocals", sha256="a"*64, byte_count=1)
        self.assertEqual(code_of(cm), "SEP_OBS_ARTIFACT_ROLE_INVALID")

    def test_actual_cost_idempotent_and_conflict_safe(self):
        self.register()
        self.obs.record_cost_actual(JOB, actual_cost="0.3")
        self.obs.record_cost_actual(JOB, actual_cost="0.300000")
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.record_cost_actual(JOB, actual_cost="0.4")
        self.assertEqual(code_of(cm), "SEP_OBS_ACTUAL_COST_CONFLICT")

    def test_finalize_failed_requires_code(self):
        self.register()
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.finalize(JOB, terminal_state="failed")
        self.assertEqual(code_of(cm), "SEP_OBS_TERMINAL_ERROR_REQUIRED")

    def test_terminal_conflict_rejected(self):
        self.register()
        self.obs.finalize(JOB, terminal_state="ready")
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.finalize(JOB, terminal_state="deleted")
        self.assertEqual(code_of(cm), "SEP_OBS_TERMINAL_STATE_CONFLICT")

    def test_ready_evidence_has_non_parity_marker(self):
        self.register()
        self.obs.finalize(JOB, terminal_state="ready")
        e = self.obs.evidence(JOB)
        self.assertEqual(e["parity_state"], "NON_PARITY_EVIDENCE_ONLY")

    def test_long_track_bridge_captures_only_aggregate_numbers(self):
        self.register()
        self.obs.capture_long_track_summary(JOB, LongTrackStub())
        e = self.obs.evidence(JOB)
        self.assertEqual(e["phase_stats"]["upload"]["bytes_transferred"], 1000)
        self.assertEqual(e["phase_stats"]["output_download"]["bytes_transferred"], 4000)

    def test_long_track_bridge_rejects_url_in_error_code(self):
        self.register()
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.capture_long_track_summary(
                JOB, LongTrackStub(stable_error_code="https://signed.example/file?token=x")
            )
        self.assertEqual(code_of(cm), "SEP_OBS_ERROR_CODE_INVALID")

    def test_cost_bridge_ignores_unknown_sensitive_fields(self):
        self.register()
        self.obs.capture_cost_evidence(
            JOB,
            {
                "actual_cost": "0.5",
                "provider_task_id": "secret-task",
                "signed_url": "https://example.invalid/?token=x",
                "filename": "song.wav",
            },
        )
        raw = self.path.read_text()
        self.assertNotIn("secret-task", raw)
        self.assertNotIn("song.wav", raw)
        self.assertNotIn("https://", raw)
        self.assertEqual(self.obs.evidence(JOB)["actual_cost"], "0.5")

    def test_fault_bridge_records_only_stable_code_not_raw_message(self):
        self.register()
        self.obs.capture_fault(JOB, FaultStub(), phase="poll", elapsed_milliseconds=20)
        raw = self.path.read_text()
        self.assertIn("SEP_PROVIDER_RATE_LIMITED", raw)
        self.assertEqual(self.obs.evidence(JOB)["phase_stats"]["poll"]["retry_count"], 0)

    def test_defense_scan_rejects_forbidden_key(self):
        with self.assertRaises(ObservabilityError) as cm:
            assert_privacy_safe_payload({"schema_version": 1, "api_key": "abc"})
        self.assertEqual(code_of(cm), "SEP_OBS_PRIVACY_FORBIDDEN_KEY")

    def test_defense_scan_rejects_signed_url_value_even_under_innocent_key(self):
        with self.assertRaises(ObservabilityError) as cm:
            assert_privacy_safe_payload({"schema_version": 1, "note": "https://x/?X-Amz-Signature=abc"})
        self.assertEqual(code_of(cm), "SEP_OBS_PRIVACY_FORBIDDEN_VALUE")

    def test_defense_scan_rejects_raw_bytes(self):
        with self.assertRaises(ObservabilityError) as cm:
            assert_privacy_safe_payload({"schema_version": 1, "blob": b"audio"})
        self.assertEqual(code_of(cm), "SEP_OBS_PRIVACY_VALUE_TYPE_FORBIDDEN")

    def test_forbidden_key_variants_fail_closed(self):
        for key in [
            "api_key", "secret_token", "authorization", "filename",
            "source_path", "signed_url", "provider_task_id", "provider_asset_id",
            "idempotency_key", "raw_audio",
        ]:
            with self.subTest(key=key):
                with self.assertRaises(ObservabilityError):
                    assert_privacy_safe_payload({"schema_version": 1, key: "x"})

    def test_forbidden_value_variants_fail_closed(self):
        for value in [
            "https://example.test/signed",
            "http://example.test",
            "file:///tmp/song.wav",
            "Bearer abc",
            "-----BEGIN PRIVATE KEY-----",
            "x-amz-signature=abc",
            "token=abc",
            "api_key=abc",
        ]:
            with self.subTest(value=value):
                with self.assertRaises(ObservabilityError):
                    assert_privacy_safe_payload({"schema_version": 1, "status": value})

    def test_corrupt_store_fails_closed(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text("{bad", encoding="utf-8")
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.evidence(JOB)
        self.assertEqual(code_of(cm), "SEP_OBS_STORE_CORRUPT")

    def test_schema_rejects_injected_forbidden_key_on_load(self):
        rec = self.register()
        raw = json.loads(self.path.read_text())
        raw["jobs"][rec.job_ref_hash]["signed_url"] = "https://secret"
        self.path.write_text(json.dumps(raw), encoding="utf-8")
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.evidence(JOB)
        self.assertEqual(code_of(cm), "SEP_OBS_STORE_RECORD_INVALID")

    def test_multiple_jobs_isolated(self):
        self.register(JOB)
        self.register(JOB2, profile_id="sep.basic.v2")
        self.obs.record_phase(JOB, phase="poll", elapsed_milliseconds=5)
        self.assertNotIn("poll", self.obs.evidence(JOB2)["phase_stats"])

    def test_orchestrator_bridge_ignores_sensitive_job_fields_and_relative_paths(self):
        self.register()
        class Record:
            stable_error_code = None
            project_id = "project-secret"
            asset_id = "asset-secret"
            source_sha256 = "b"*64
            provider_asset_id = "provider-asset-secret"
            provider_task_id = "provider-task-secret"
            idempotency_key_hash = "c"*64
            request_fingerprint = "d"*64
            outputs = [{
                "model": "vocals",
                "relative_path": f"{JOB}/private-song-name.wav",
                "sha256": "e"*64,
                "bytes": 222,
                "download_url": "https://signed.example/?token=secret",
            }]
        self.obs.capture_orchestrator_record(JOB, Record())
        raw = self.path.read_text()
        for forbidden in [
            "project-secret", "asset-secret", "provider-asset-secret", "provider-task-secret",
            "private-song-name.wav", "https://signed.example", "request_fingerprint",
        ]:
            self.assertNotIn(forbidden, raw)
        self.assertEqual(self.obs.evidence(JOB)["artifacts"]["vocals"]["sha256"], "e"*64)

    def test_orchestrator_bridge_rejects_invalid_artifact_hash(self):
        self.register()
        class Record:
            stable_error_code = None
            outputs = [{"model": "vocals", "sha256": "not-a-hash", "bytes": 222}]
        with self.assertRaises(ObservabilityError) as cm:
            self.obs.capture_orchestrator_record(JOB, Record())
        self.assertEqual(code_of(cm), "SEP_OBS_ARTIFACT_HASH_INVALID")

    def test_machine_schema_documents_required_and_forbidden_fields(self):
        schema = self.obs.machine_schema()
        self.assertEqual(schema["record"]["job_ref_hash"], "sha256")
        self.assertTrue(schema["forbidden"]["api_key_or_secret"])
        self.assertTrue(schema["forbidden"]["signed_or_download_url"])
        self.assertEqual(schema["parity_state"], "NON_PARITY_EVIDENCE_ONLY")

    def test_serialized_record_contains_no_forbidden_key_names(self):
        self.register()
        self.obs.record_phase(JOB, phase="poll", elapsed_milliseconds=5)
        payload = json.loads(self.path.read_text())
        assert_privacy_safe_payload(payload)

    def test_invalid_currency_rejected(self):
        with self.assertRaises(ObservabilityError) as cm:
            self.register(currency="usd")
        self.assertEqual(code_of(cm), "SEP_OBS_CURRENCY_INVALID")

    def test_nonfinite_cost_rejected(self):
        with self.assertRaises(ObservabilityError) as cm:
            self.register(estimated_cost="NaN")
        self.assertEqual(code_of(cm), "SEP_OBS_ESTIMATED_COST_INVALID")


if __name__ == "__main__":
    unittest.main()
