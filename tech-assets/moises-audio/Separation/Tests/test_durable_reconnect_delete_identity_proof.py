import hashlib
import json
import tempfile
import types
import unittest
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from durable_reconnect_registry import (
    DELETE_IDENTITY_BINDING_VERSION,
    DurableReconnectService,
    DurableRecoveryError,
    _logical_identity,
)


class Backend:
    def __init__(self):
        self.jobs = {}

    def start(self, *, source_path, project_id, asset_id, models, idempotency_key):
        logical_job_id, key_hash = _logical_identity(idempotency_key)
        source_sha = hashlib.sha256(Path(source_path).read_bytes()).hexdigest()
        job = types.SimpleNamespace(
            logical_job_id=logical_job_id,
            project_id=project_id,
            asset_id=asset_id,
            idempotency_key_hash=key_hash,
            request_fingerprint="a" * 64,
            source_sha256=source_sha,
            requested_models=list(models),
            provider_asset_id="provider-asset-proof",
            provider_task_id="provider-task-proof",
            state="separating",
            provider_phase="separating",
            fraction_complete=0.25,
            retryable=True,
            stable_error_code=None,
            outputs_committed=False,
        )
        self.jobs[logical_job_id] = job
        return job

    def get(self, logical_job_id):
        return self.jobs[logical_job_id]

    def observe(self, logical_job_id):
        return self.jobs[logical_job_id]

    def collect_ready_outputs(self, logical_job_id):
        return self.jobs[logical_job_id]


class DurableDeleteIdentityProofTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.source = root / "source.wav"
        self.source.write_bytes(b"proof-fixture")
        self.registry_path = root / "recovery" / "jobs.json"
        self.backend = Backend()
        self.clock = 10_000

        def now():
            self.clock += 1
            return self.clock

        self.now = now
        self.service = DurableReconnectService(
            backend=self.backend,
            registry_path=self.registry_path,
            now_epoch_ms=self.now,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def start(self):
        return self.service.start(
            source_path=self.source,
            project_id="project-1",
            asset_id="asset-1",
            requested_profile_id="sep.basic.v1",
            models=("vocals", "drums"),
            idempotency_key="delete-proof-key",
        )

    @staticmethod
    def digest(value):
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    def test_identity_bound_tombstone_clears_raw_ids_and_survives_reload(self):
        job = self.start()
        asset_hash = self.digest(job.provider_asset_id)
        task_hash = self.digest(job.provider_task_id)

        snapshot = self.service.mark_deleted(
            job.logical_job_id,
            bind_provider_identity=True,
            provider_asset_id_hash=asset_hash,
            provider_task_id_hash=task_hash,
        )
        self.assertEqual(snapshot.logical_phase, "deleted")

        record = self.service.get_record(job.logical_job_id)
        self.assertEqual(record.state, "deleted")
        self.assertIsNone(record.provider_asset_id)
        self.assertIsNone(record.provider_task_id)
        self.assertEqual(
            record.deletion_identity_binding_version,
            DELETE_IDENTITY_BINDING_VERSION,
        )
        self.assertEqual(record.deleted_provider_asset_id_hash, asset_hash)
        self.assertEqual(record.deleted_provider_task_id_hash, task_hash)

        restarted = DurableReconnectService(
            backend=self.backend,
            registry_path=self.registry_path,
            now_epoch_ms=self.now,
        )
        reloaded = restarted.get_record(job.logical_job_id)
        self.assertEqual(reloaded.deleted_provider_asset_id_hash, asset_hash)
        self.assertEqual(reloaded.deleted_provider_task_id_hash, task_hash)

    def test_identity_mismatch_fails_before_tombstone_or_raw_id_clear(self):
        job = self.start()
        with self.assertRaises(DurableRecoveryError) as caught:
            self.service.mark_deleted(
                job.logical_job_id,
                bind_provider_identity=True,
                provider_asset_id_hash="0" * 64,
                provider_task_id_hash=self.digest(job.provider_task_id),
            )
        self.assertEqual(
            caught.exception.code,
            "SEP_RECOVERY_DELETE_PROVIDER_IDENTITY_MISMATCH",
        )
        record = self.service.get_record(job.logical_job_id)
        self.assertEqual(record.state, "bound")
        self.assertEqual(record.provider_asset_id, "provider-asset-proof")
        self.assertEqual(record.provider_task_id, "provider-task-proof")
        self.assertIsNone(record.deletion_identity_binding_version)

    def test_legacy_tombstone_cannot_be_retrofitted_after_raw_ids_are_gone(self):
        job = self.start()
        asset_hash = self.digest(job.provider_asset_id)
        task_hash = self.digest(job.provider_task_id)
        self.service.mark_deleted(job.logical_job_id)

        with self.assertRaises(DurableRecoveryError) as caught:
            self.service.mark_deleted(
                job.logical_job_id,
                bind_provider_identity=True,
                provider_asset_id_hash=asset_hash,
                provider_task_id_hash=task_hash,
            )
        self.assertEqual(
            caught.exception.code,
            "SEP_RECOVERY_DELETE_IDENTITY_PROOF_UNAVAILABLE",
        )
        record = self.service.get_record(job.logical_job_id)
        self.assertIsNone(record.deletion_identity_binding_version)
        self.assertIsNone(record.deleted_provider_asset_id_hash)
        self.assertIsNone(record.deleted_provider_task_id_hash)

    def test_preproof_registry_record_remains_readable_but_unproven(self):
        job = self.start()
        payload = json.loads(self.registry_path.read_text(encoding="utf-8"))
        persisted = payload["jobs"][job.logical_job_id]
        persisted.pop("deletion_identity_binding_version", None)
        persisted.pop("deleted_provider_asset_id_hash", None)
        persisted.pop("deleted_provider_task_id_hash", None)
        self.registry_path.write_text(
            json.dumps(payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        restarted = DurableReconnectService(
            backend=self.backend,
            registry_path=self.registry_path,
            now_epoch_ms=self.now,
        )
        record = restarted.get_record(job.logical_job_id)
        self.assertEqual(record.state, "bound")
        self.assertIsNone(record.deletion_identity_binding_version)
        self.assertIsNone(record.deleted_provider_asset_id_hash)
        self.assertIsNone(record.deleted_provider_task_id_hash)


if __name__ == "__main__":
    unittest.main()
