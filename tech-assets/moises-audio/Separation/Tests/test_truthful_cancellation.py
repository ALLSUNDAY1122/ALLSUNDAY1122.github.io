import json
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from truthful_cancellation import CancellationTruthError, TruthfulCancellationService


@dataclass
class Job:
    logical_job_id: str
    provider_task_id: str | None = "task-1"
    provider_phase: str = "separating"
    fraction_complete: float = 0.4
    retryable: bool = True
    stable_error_code: str | None = None


class FakeBackend:
    def __init__(self):
        self.job = Job("a" * 32)
        self.observe_calls = 0
        self.collect_calls = 0

    def get(self, logical_job_id):
        if logical_job_id != self.job.logical_job_id:
            raise RuntimeError("missing")
        return self.job

    def observe(self, logical_job_id):
        self.observe_calls += 1
        return self.job

    def collect_ready_outputs(self, logical_job_id):
        self.collect_calls += 1
        return ["ok"]


class FakeProvider:
    def __init__(self, receipt=None):
        self.receipt = receipt
        self.cancel_calls = 0
        self.error = None

    def cancel_task(self, task_id):
        self.cancel_calls += 1
        if self.error:
            raise self.error
        return self.receipt


class ProviderError(RuntimeError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


class NoCancelProvider:
    pass


class CancellationTruthTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.backend = FakeBackend()
        self.provider = FakeProvider("accepted")
        self.registry = self.root / "cancel" / "registry.json"
        self.service = TruthfulCancellationService(
            backend=self.backend,
            provider=self.provider,
            registry_path=self.registry,
        )
        self.job_id = "a" * 32

    def tearDown(self):
        self.tmp.cleanup()

    def test_cancel_persists_logical_intent_and_output_discard(self):
        record = self.service.request_cancel(self.job_id)
        self.assertTrue(record.cancel_requested)
        self.assertEqual(record.output_disposition, "discard")
        raw = json.loads(self.registry.read_text())
        persisted = raw["records"][self.job_id]
        self.assertTrue(persisted["cancel_requested"])
        self.assertEqual(persisted["output_disposition"], "discard")

    def test_upstream_accepted_is_not_claimed_confirmed(self):
        record = self.service.request_cancel(self.job_id)
        self.assertEqual(record.logical_state, "cancelled_logical")
        self.assertEqual(record.upstream_cancel_state, "requested")
        self.assertEqual(record.stable_error_code, "SEP_CANCEL_UPSTREAM_REQUESTED")

    def test_upstream_confirmed_is_recorded_authoritatively(self):
        self.provider.receipt = "confirmed"
        record = self.service.request_cancel(self.job_id)
        self.assertEqual(record.logical_state, "cancelled_upstream_confirmed")
        self.assertEqual(record.upstream_cancel_state, "confirmed")

    def test_provider_without_cancel_capability_is_truthfully_unsupported(self):
        service = TruthfulCancellationService(
            backend=self.backend,
            provider=NoCancelProvider(),
            registry_path=self.registry,
        )
        record = service.request_cancel(self.job_id)
        self.assertEqual(record.upstream_cancel_state, "unsupported")
        self.assertEqual(record.stable_error_code, "SEP_CANCEL_UPSTREAM_NOT_SUPPORTED")

    def test_cancel_error_preserves_logical_cancel_without_claiming_upstream_stop(self):
        self.provider.error = ProviderError("VENDOR_CANCEL_TIMEOUT")
        record = self.service.request_cancel(self.job_id)
        self.assertEqual(record.logical_state, "cancelled_logical")
        self.assertEqual(record.upstream_cancel_state, "unknown_after_error")
        self.assertEqual(record.stable_error_code, "VENDOR_CANCEL_TIMEOUT")

    def test_invalid_provider_receipt_fails_truthfully(self):
        self.provider.receipt = "probably"
        record = self.service.request_cancel(self.job_id)
        self.assertEqual(record.upstream_cancel_state, "unknown_invalid_receipt")
        self.assertEqual(record.stable_error_code, "SEP_CANCEL_UPSTREAM_RECEIPT_INVALID")

    def test_repeated_cancel_is_idempotent_and_does_not_repeat_provider_call(self):
        first = self.service.request_cancel(self.job_id)
        second = self.service.request_cancel(self.job_id)
        self.assertEqual(self.provider.cancel_calls, 1)
        self.assertEqual(first.logical_state, second.logical_state)
        self.assertEqual(second.request_count, 2)

    def test_unbound_job_can_be_logically_cancelled_without_fake_provider_cancel(self):
        self.backend.job.provider_task_id = None
        record = self.service.request_cancel(self.job_id)
        self.assertEqual(record.logical_state, "cancelled_unbound")
        self.assertEqual(record.upstream_cancel_state, "not_addressable")
        self.assertEqual(self.provider.cancel_calls, 0)

    def test_collect_is_blocked_after_cancel_even_if_provider_is_ready(self):
        self.service.request_cancel(self.job_id)
        self.backend.job.provider_phase = "ready"
        with self.assertRaisesRegex(CancellationTruthError, "SEP_CANCELLED_OUTPUT_DISCARDED"):
            self.service.collect_ready_outputs(self.job_id)
        self.assertEqual(self.backend.collect_calls, 0)

    def test_ready_vs_cancel_race_returns_cancelled_and_records_discard(self):
        self.service.request_cancel(self.job_id)
        self.backend.job.provider_phase = "ready"
        self.backend.job.fraction_complete = 1.0
        snapshot = self.service.observe(self.job_id)
        self.assertEqual(snapshot["phase"], "cancelled")
        self.assertEqual(
            snapshot["stableErrorCode"],
            "SEP_CANCEL_RACE_PROVIDER_COMPLETED_OUTPUT_DISCARDED",
        )
        self.assertEqual(snapshot["cancellationTruth"]["providerPhaseAfterCancel"], "ready")
        self.assertEqual(snapshot["cancellationTruth"]["outputDisposition"], "discard")

    def test_provider_failure_after_cancel_does_not_resurrect_active_state(self):
        self.service.request_cancel(self.job_id)
        self.backend.job.provider_phase = "failed"
        self.backend.job.stable_error_code = "VENDOR_FAILED"
        snapshot = self.service.observe(self.job_id)
        self.assertEqual(snapshot["phase"], "cancelled")
        self.assertEqual(snapshot["stableErrorCode"], "VENDOR_FAILED")
        self.assertEqual(
            self.service.get_cancellation(self.job_id).logical_state,
            "cancelled_provider_failed",
        )

    def test_provider_cancelled_phase_confirms_upstream_stop(self):
        self.service.request_cancel(self.job_id)
        self.backend.job.provider_phase = "cancelled"
        snapshot = self.service.observe(self.job_id)
        truth = snapshot["cancellationTruth"]
        self.assertEqual(truth["upstreamCancelState"], "confirmed")
        self.assertEqual(truth["logicalState"], "cancelled_upstream_confirmed")

    def test_confirmed_receipt_contradicted_by_separating_state_is_flagged(self):
        self.provider.receipt = "confirmed"
        self.service.request_cancel(self.job_id)
        self.backend.job.provider_phase = "separating"
        snapshot = self.service.observe(self.job_id)
        self.assertEqual(
            snapshot["cancellationTruth"]["upstreamCancelState"],
            "confirmation_contradicted",
        )
        self.assertEqual(snapshot["stableErrorCode"], "SEP_CANCEL_CONFIRMATION_CONTRADICTED")

    def test_public_snapshot_keeps_existing_client_phase_compatible(self):
        self.service.request_cancel(self.job_id)
        snapshot = self.service.observe(self.job_id)
        self.assertEqual(snapshot["phase"], "cancelled")
        self.assertIn("cancellationTruth", snapshot)
        self.assertTrue(snapshot["cancellationTruth"]["logicalCancelled"])

    def test_uncancelled_job_delegates_normal_observe_and_collect(self):
        snapshot = self.service.observe(self.job_id)
        self.assertEqual(snapshot["phase"], "separating")
        self.assertEqual(self.service.collect_ready_outputs(self.job_id), ["ok"])
        self.assertEqual(self.backend.collect_calls, 1)

    def test_registry_survives_service_restart(self):
        self.service.request_cancel(self.job_id)
        restarted = TruthfulCancellationService(
            backend=self.backend,
            provider=self.provider,
            registry_path=self.registry,
        )
        record = restarted.get_cancellation(self.job_id)
        self.assertTrue(record.cancel_requested)
        with self.assertRaisesRegex(CancellationTruthError, "SEP_CANCELLED_OUTPUT_DISCARDED"):
            restarted.collect_ready_outputs(self.job_id)

    def test_corrupt_registry_fails_closed(self):
        self.registry.parent.mkdir(parents=True, exist_ok=True)
        self.registry.write_text("{bad json", encoding="utf-8")
        with self.assertRaisesRegex(CancellationTruthError, "SEP_CANCEL_REGISTRY_CORRUPT"):
            self.service.request_cancel(self.job_id)

    def test_invalid_logical_job_id_is_rejected(self):
        with self.assertRaisesRegex(CancellationTruthError, "SEP_CANCEL_LOGICAL_JOB_ID_INVALID"):
            self.service.request_cancel("not-a-job")


if __name__ == "__main__":
    unittest.main()
