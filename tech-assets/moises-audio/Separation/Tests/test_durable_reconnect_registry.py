import hashlib
import json
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from durable_reconnect_registry import (
    DurableReconnectService,
    DurableRecoveryError,
    _logical_identity,
)


class BackendError(RuntimeError):
    def __init__(self, code, *, retryable=False, status=None):
        self.code = code
        self.retryable = retryable
        self.status = status
        super().__init__(code)


@dataclass
class Job:
    logical_job_id: str
    idempotency_key_hash: str
    request_fingerprint: str
    project_id: str
    asset_id: str
    source_sha256: str
    requested_models: list[str]
    state: str = "separating"
    provider_asset_id: str | None = "provider-asset-1"
    provider_task_id: str | None = "provider-task-1"
    provider_phase: str | None = "separating"
    fraction_complete: float = 0.25
    stable_error_code: str | None = None
    retryable: bool = True
    outputs_committed: bool = False


class FakeBackend:
    def __init__(self):
        self.jobs = {}
        self.start_calls = 0
        self.observe_calls = 0
        self.collect_calls = 0
        self.reconcile_calls = 0
        self.observe_error = None
        self.collect_error = None
        self.start_error_after_persist = None
        self.reconcile_mode = "none"
        self.observed_phase = "separating"
        self.observed_fraction = 0.25
        self.observed_error_code = None
        self.observed_retryable = True

    def start(self, *, source_path, project_id, asset_id, models, idempotency_key):
        self.start_calls += 1
        logical_job_id, key_hash = _logical_identity(idempotency_key)
        source_sha = hashlib.sha256(Path(source_path).read_bytes()).hexdigest()
        canonical_models = sorted(set(models))
        request_fp = hashlib.sha256(
            json.dumps(
                {"project": project_id, "asset": asset_id, "source": source_sha, "models": sorted(canonical_models)},
                sort_keys=True,
            ).encode()
        ).hexdigest()
        existing = self.jobs.get(logical_job_id)
        if existing is None:
            existing = Job(
                logical_job_id=logical_job_id,
                idempotency_key_hash=key_hash,
                request_fingerprint=request_fp,
                project_id=project_id,
                asset_id=asset_id,
                source_sha256=source_sha,
                requested_models=list(canonical_models),
            )
            self.jobs[logical_job_id] = existing
        if self.start_error_after_persist is not None:
            raise self.start_error_after_persist
        return existing

    def get(self, logical_job_id):
        if logical_job_id not in self.jobs:
            raise BackendError("SEP_JOB_NOT_FOUND", retryable=False, status=404)
        return self.jobs[logical_job_id]

    def observe(self, logical_job_id):
        self.observe_calls += 1
        if self.observe_error is not None:
            raise self.observe_error
        job = self.get(logical_job_id)
        job.provider_phase = self.observed_phase
        job.state = self.observed_phase
        job.fraction_complete = self.observed_fraction
        job.stable_error_code = self.observed_error_code
        job.retryable = self.observed_retryable
        return job

    def collect_ready_outputs(self, logical_job_id):
        self.collect_calls += 1
        if self.collect_error is not None:
            raise self.collect_error
        job = self.get(logical_job_id)
        job.outputs_committed = True
        job.state = "ready"
        job.provider_phase = "ready"
        job.fraction_complete = 1.0
        job.retryable = False
        return job

    def reconcile_ambiguous_start(self, logical_job_id):
        self.reconcile_calls += 1
        job = self.get(logical_job_id)
        if self.reconcile_mode == "unique":
            job.provider_task_id = "provider-task-recovered"
            job.state = "separating"
            job.provider_phase = "separating"
            return job
        if self.reconcile_mode == "unresolved":
            job.state = "start_reconciliation_unresolved"
            job.stable_error_code = "SEP_PROVIDER_START_NOT_FOUND"
            job.retryable = False
            return job
        if self.reconcile_mode == "duplicate":
            job.state = "duplicate_provider_tasks_detected"
            job.stable_error_code = "SEP_PROVIDER_DUPLICATE_TASKS_DETECTED"
            job.retryable = False
            raise BackendError(job.stable_error_code, retryable=False)
        return job


@dataclass
class CancelRecord:
    cancel_requested: bool = True


class FakeCancellationService:
    def __init__(self):
        self.observe_calls = 0
        self.cancelled = set()
        self.provider_phase = "ready"

    def get_cancellation(self, logical_job_id):
        return CancelRecord() if logical_job_id in self.cancelled else None

    def observe(self, logical_job_id):
        self.observe_calls += 1
        return {
            "phase": "cancelled",
            "fractionComplete": 1.0,
            "retryable": True,
            "stableErrorCode": "SEP_CANCEL_RACE_PROVIDER_COMPLETED_OUTPUT_DISCARDED",
            "cancellationTruth": {
                "logicalCancelled": True,
                "providerPhaseAfterCancel": self.provider_phase,
                "outputDisposition": "discard",
            },
        }


class DurableReconnectTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.source = root / "song-private-name.wav"
        self.source.write_bytes(b"audio-bytes")
        self.registry_path = root / "recovery" / "jobs.json"
        self.backend = FakeBackend()
        self.cancel = FakeCancellationService()
        self.clock_value = 1000

        def clock():
            self.clock_value += 1
            return self.clock_value

        self.clock = clock
        self.service = DurableReconnectService(
            backend=self.backend,
            registry_path=self.registry_path,
            cancellation_service=self.cancel,
            now_epoch_ms=self.clock,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def start(self, key="idem-secret", profile="sep.basic.v1", models=("vocals", "drums")):
        return self.service.start(
            source_path=self.source,
            project_id="project-1",
            asset_id="asset-1",
            requested_profile_id=profile,
            models=models,
            idempotency_key=key,
        )

    def test_begin_intent_is_durable_before_backend_start_and_redacts_secret(self):
        record = self.service.begin_intent(
            project_id="project-1", asset_id="asset-1",
            requested_profile_id="sep.basic.v1", models=["vocals", "drums"],
            idempotency_key="raw-secret-key",
        )
        self.assertEqual(record.state, "intent")
        self.assertEqual(self.backend.start_calls, 0)
        text = self.registry_path.read_text(encoding="utf-8")
        self.assertNotIn("raw-secret-key", text)
        self.assertNotIn(str(self.source), text)
        self.assertNotIn(self.source.name, text)
        self.assertIn("idempotency_key_hash", text)

    def test_intent_survives_crash_before_backend_start(self):
        record = self.service.begin_intent(
            project_id="project-1", asset_id="asset-1",
            requested_profile_id="sep.basic.v1", models=["vocals"],
            idempotency_key="before-start",
        )
        restarted = DurableReconnectService(
            backend=self.backend, registry_path=self.registry_path, now_epoch_ms=self.clock
        )
        snap = restarted.recover(record.logical_job_id)
        self.assertEqual(snap.logical_phase, "unknown")
        self.assertEqual(snap.stable_error_code, "SEP_RECOVERY_BACKEND_NOT_STARTED")
        self.assertTrue(snap.retryable)
        self.assertEqual(self.backend.start_calls, 0)
        job = restarted.start(
            source_path=self.source, project_id="project-1", asset_id="asset-1",
            requested_profile_id="sep.basic.v1", models=["vocals"],
            idempotency_key="before-start",
        )
        self.assertEqual(job.logical_job_id, record.logical_job_id)
        self.assertEqual(self.backend.start_calls, 1)

    def test_start_binds_profile_backend_identity_and_survives_service_restart(self):
        job = self.start()
        record = self.service.get_record(job.logical_job_id)
        self.assertEqual(record.state, "bound")
        self.assertEqual(record.requested_profile_id, "sep.basic.v1")
        self.assertEqual(record.request_fingerprint, job.request_fingerprint)
        self.assertEqual(record.source_sha256, job.source_sha256)
        restarted = DurableReconnectService(
            backend=self.backend, registry_path=self.registry_path,
            cancellation_service=self.cancel, now_epoch_ms=self.clock,
        )
        snapshot = restarted.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "separating")
        self.assertEqual(snapshot.source, "provider")
        self.assertEqual(self.backend.observe_calls, 1)

    def test_provider_snapshot_overrides_stale_nonterminal_cache(self):
        job = self.start()
        self.backend.observed_fraction = 0.8
        first = self.service.recover(job.logical_job_id)
        self.assertEqual(first.fraction_complete, 0.8)
        self.backend.observed_fraction = 0.2
        second = self.service.recover(job.logical_job_id)
        self.assertEqual(second.logical_phase, "separating")
        self.assertEqual(second.fraction_complete, 0.2)
        self.assertGreater(second.revision, first.revision)

    def test_provider_ready_is_collected_before_user_ready(self):
        job = self.start()
        self.backend.observed_phase = "ready"
        self.backend.observed_fraction = 1.0
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "ready")
        self.assertTrue(snapshot.outputs_committed)
        self.assertEqual(self.backend.collect_calls, 1)

    def test_remote_ready_copy_failure_is_not_published_as_ready(self):
        job = self.start()
        self.backend.observed_phase = "ready"
        self.backend.observed_fraction = 1.0
        self.backend.collect_error = BackendError("SEP_STORAGE_PREFLIGHT_INSUFFICIENT", retryable=True)
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "recovering")
        self.assertEqual(snapshot.provider_phase, "ready")
        self.assertFalse(snapshot.outputs_committed)
        self.assertTrue(snapshot.retryable)

    def test_committed_local_outputs_survive_provider_retention_disappearance(self):
        job = self.start()
        job.outputs_committed = True
        job.state = "ready"
        job.provider_phase = "ready"
        self.backend.observe_error = BackendError("AUDIOSHAKE_HTTP_404", status=404)
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "ready")
        self.assertEqual(snapshot.source, "server_committed_outputs")
        self.assertEqual(self.backend.observe_calls, 0)

    def test_network_loss_does_not_reuse_stale_cache_as_current(self):
        job = self.start()
        first = self.service.recover(job.logical_job_id)
        self.assertEqual(first.logical_phase, "separating")
        self.backend.observe_error = BackendError("NET_DOWN", retryable=True)
        second = self.service.recover(job.logical_job_id)
        self.assertEqual(second.logical_phase, "unknown")
        self.assertEqual(second.previous_phase, "separating")
        self.assertTrue(second.retryable)
        self.assertEqual(second.source, "authority_unavailable")

    def test_provider_404_becomes_nonretryable_unknown_without_recreate(self):
        job = self.start()
        self.backend.observe_error = BackendError("AUDIOSHAKE_HTTP_404", status=404)
        starts_before = self.backend.start_calls
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "unknown")
        self.assertEqual(snapshot.stable_error_code, "SEP_RECOVERY_PROVIDER_JOB_MISSING")
        self.assertFalse(snapshot.retryable)
        self.assertEqual(self.backend.start_calls, starts_before)

    def test_local_terminal_failure_is_authoritative_without_provider_call(self):
        job = self.start()
        job.state = "upload_failed"
        job.provider_phase = None
        job.provider_task_id = None
        job.stable_error_code = "UPLOAD_NET"
        job.retryable = True
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "failed")
        self.assertEqual(snapshot.stable_error_code, "UPLOAD_NET")
        self.assertEqual(self.backend.observe_calls, 0)

    def test_ambiguous_start_reconciles_unique_task_without_second_start(self):
        job = self.start()
        job.state = "start_ambiguous"
        job.provider_phase = None
        job.provider_task_id = None
        self.backend.reconcile_mode = "unique"
        starts_before = self.backend.start_calls
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "separating")
        self.assertEqual(self.backend.reconcile_calls, 1)
        self.assertEqual(self.backend.start_calls, starts_before)
        self.assertEqual(self.service.get_record(job.logical_job_id).provider_task_id, "provider-task-recovered")

    def test_ambiguous_start_no_match_remains_unknown_and_no_repost(self):
        job = self.start()
        job.state = "start_ambiguous"
        job.provider_phase = None
        job.provider_task_id = None
        self.backend.reconcile_mode = "unresolved"
        starts_before = self.backend.start_calls
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "unknown")
        self.assertEqual(snapshot.stable_error_code, "SEP_PROVIDER_START_NOT_FOUND")
        self.assertFalse(snapshot.retryable)
        self.assertEqual(self.backend.start_calls, starts_before)

    def test_duplicate_provider_tasks_persist_nonretryable_unknown_snapshot(self):
        job = self.start()
        job.state = "start_ambiguous"
        job.provider_phase = None
        job.provider_task_id = None
        self.backend.reconcile_mode = "duplicate"
        starts_before = self.backend.start_calls
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "unknown")
        self.assertEqual(snapshot.stable_error_code, "SEP_PROVIDER_DUPLICATE_TASKS_DETECTED")
        self.assertFalse(snapshot.retryable)
        self.assertEqual(snapshot.source, "server_reconciliation")
        self.assertEqual(self.backend.start_calls, starts_before)

    def test_logical_cancel_wins_ready_race_and_never_collects_outputs(self):
        job = self.start()
        self.cancel.cancelled.add(job.logical_job_id)
        self.backend.observed_phase = "ready"
        before = self.backend.collect_calls
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "cancelled")
        self.assertEqual(snapshot.provider_phase, "ready")
        self.assertEqual(snapshot.source, "server_logical_cancel")
        self.assertEqual(self.backend.collect_calls, before)
        self.assertEqual(self.cancel.observe_calls, 1)

    def test_deleted_tombstone_cannot_be_resurrected_by_provider_state(self):
        job = self.start()
        deleted = self.service.mark_deleted(job.logical_job_id)
        self.assertEqual(deleted.logical_phase, "deleted")
        observe_before = self.backend.observe_calls
        self.backend.observed_phase = "ready"
        snapshot = self.service.recover(job.logical_job_id)
        self.assertEqual(snapshot.logical_phase, "deleted")
        self.assertEqual(self.backend.observe_calls, observe_before)
        with self.assertRaisesRegex(DurableRecoveryError, "SEP_RECOVERY_JOB_TOMBSTONED"):
            self.service.begin_intent(
                project_id="project-1", asset_id="asset-1",
                requested_profile_id="sep.basic.v1", models=["vocals", "drums"],
                idempotency_key="idem-secret",
            )

    def test_unregistered_backend_job_is_not_silently_adopted(self):
        job = self.backend.start(
            source_path=self.source, project_id="project-1", asset_id="asset-1",
            models=["vocals"], idempotency_key="legacy-key",
        )
        with self.assertRaisesRegex(DurableRecoveryError, "SEP_RECOVERY_JOB_NOT_REGISTERED"):
            self.service.recover(job.logical_job_id)

    def test_backend_identity_mismatch_fails_closed(self):
        job = self.start()
        job.requested_models = ["vocals"]
        with self.assertRaisesRegex(DurableRecoveryError, "SEP_RECOVERY_BACKEND_MODELS_MISMATCH"):
            self.service.recover(job.logical_job_id)

    def test_start_exception_after_backend_persist_still_binds_for_relaunch(self):
        self.backend.start_error_after_persist = BackendError("SEP_PROVIDER_START_AMBIGUOUS", retryable=False)
        with self.assertRaisesRegex(BackendError, "SEP_PROVIDER_START_AMBIGUOUS"):
            self.start(key="ambiguous-key", models=("vocals",))
        logical_job_id, _ = _logical_identity("ambiguous-key")
        record = self.service.get_record(logical_job_id)
        self.assertEqual(record.state, "bound")
        self.assertIsNotNone(record.request_fingerprint)

    def test_same_idempotency_key_different_profile_conflicts(self):
        self.service.begin_intent(
            project_id="project-1", asset_id="asset-1",
            requested_profile_id="sep.basic.v1", models=["vocals"],
            idempotency_key="same-key",
        )
        with self.assertRaisesRegex(DurableRecoveryError, "SEP_RECOVERY_INTENT_CONFLICT"):
            self.service.begin_intent(
                project_id="project-1", asset_id="asset-1",
                requested_profile_id="sep.custom.v1", models=["vocals"],
                idempotency_key="same-key",
            )

    def test_same_models_different_order_is_same_canonical_intent(self):
        first = self.service.begin_intent(
            project_id="project-1", asset_id="asset-1",
            requested_profile_id="sep.basic.v1", models=["vocals", "drums"],
            idempotency_key="order-key",
        )
        second = self.service.begin_intent(
            project_id="project-1", asset_id="asset-1",
            requested_profile_id="sep.basic.v1", models=["drums", "vocals"],
            idempotency_key="order-key",
        )
        self.assertEqual(first.logical_job_id, second.logical_job_id)
        self.assertEqual(second.requested_models, ("drums", "vocals"))

    def test_corrupt_registry_fails_closed(self):
        self.registry_path.parent.mkdir(parents=True, exist_ok=True)
        self.registry_path.write_text("{not-json", encoding="utf-8")
        with self.assertRaisesRegex(DurableRecoveryError, "SEP_RECOVERY_REGISTRY_CORRUPT"):
            self.service.begin_intent(
                project_id="p1", asset_id="a1", requested_profile_id="sep.basic.v1",
                models=["vocals"], idempotency_key="key",
            )

    def test_recovery_attempt_count_is_durable_across_restarts(self):
        job = self.start()
        self.service.recover(job.logical_job_id)
        restarted = DurableReconnectService(
            backend=self.backend, registry_path=self.registry_path, now_epoch_ms=self.clock
        )
        restarted.recover(job.logical_job_id)
        self.assertEqual(restarted.get_record(job.logical_job_id).recovery_attempts, 2)

    def test_recover_all_preserves_deleted_and_refreshes_active(self):
        first = self.start(key="one", models=("vocals",))
        second = self.start(key="two", models=("drums",))
        self.service.mark_deleted(second.logical_job_id)
        snapshots = self.service.recover_all()
        self.assertEqual(snapshots[first.logical_job_id].logical_phase, "separating")
        self.assertEqual(snapshots[second.logical_job_id].logical_phase, "deleted")

    def test_bound_registry_remains_privacy_safe(self):
        self.start(key="top-secret-idempotency")
        text = self.registry_path.read_text(encoding="utf-8")
        self.assertNotIn("top-secret-idempotency", text)
        self.assertNotIn(self.source.name, text)
        self.assertNotIn(str(self.source), text)
        self.assertNotIn("https://", text)

    def test_unknown_snapshot_retains_previous_phase_only_as_diagnostic(self):
        job = self.start()
        self.backend.observed_fraction = 0.7
        good = self.service.recover(job.logical_job_id)
        self.assertEqual(good.logical_phase, "separating")
        self.backend.observe_error = BackendError("TLS_DOWN", retryable=True)
        bad = self.service.recover(job.logical_job_id)
        self.assertEqual(bad.logical_phase, "unknown")
        self.assertEqual(bad.previous_phase, "separating")
        self.assertNotEqual(bad.logical_phase, bad.previous_phase)


if __name__ == "__main__":
    unittest.main()
