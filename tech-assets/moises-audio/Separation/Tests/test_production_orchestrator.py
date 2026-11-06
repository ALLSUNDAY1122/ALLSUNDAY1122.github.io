import json
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from production_orchestrator import OrchestratorError, ProductionSeparationOrchestrator


@dataclass(frozen=True)
class Target:
    model: str
    status: str = "completed"
    output_url: str | None = None


@dataclass(frozen=True)
class State:
    phase: str
    fraction_complete: float
    retryable: bool = False
    stable_error_code: str | None = None
    targets: tuple[Target, ...] = ()


class FakeProvider:
    def __init__(self):
        self.upload_calls = 0
        self.create_calls = 0
        self.observe_calls = 0
        self.find_calls = 0
        self.upload_error = None
        self.create_error = None
        self.find_error = None
        self.find_matches = ()
        self.last_metadata = None
        self.state = State("separating", 0.25, True)

    def upload_asset(self, path):
        self.upload_calls += 1
        if self.upload_error:
            raise self.upload_error
        return "asset-1"

    def create_separation_task(self, asset_id, models, metadata=None):
        self.create_calls += 1
        self.last_metadata = metadata
        if self.create_error:
            raise self.create_error
        return "task-1"

    def find_tasks_by_metadata(self, metadata):
        self.find_calls += 1
        self.last_metadata = metadata
        if self.find_error:
            raise self.find_error
        return self.find_matches

    def get_task_state(self, task_id):
        self.observe_calls += 1
        return self.state


class ProviderWithoutFinder:
    def __init__(self):
        self.create_calls = 0

    def upload_asset(self, path):
        return "asset-1"

    def create_separation_task(self, asset_id, models, metadata=None):
        self.create_calls += 1
        raise ProviderFailure("VENDOR_TIMEOUT", retryable=True)

    def get_task_state(self, task_id):
        return State("separating", 0.5, True)


class ProviderFailure(RuntimeError):
    def __init__(self, code, retryable=True):
        self.code = code
        self.retryable = retryable
        super().__init__(code)


class OrchestratorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.source_root = root / "source"
        self.artifact_root = root / "artifacts"
        self.source_root.mkdir()
        self.source = self.source_root / "song.wav"
        self.source.write_bytes(b"RIFF" + b"a" * 128)
        self.registry = root / "registry" / "jobs.json"
        self.provider = FakeProvider()
        self.downloads = []

        def downloader(url, destination):
            self.downloads.append(url)
            destination.write_bytes(("WAVE:" + url).encode())

        self.orch = ProductionSeparationOrchestrator(
            provider=self.provider,
            source_root=self.source_root,
            artifact_root=self.artifact_root,
            registry_path=self.registry,
            downloader=downloader,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def start(self, **kwargs):
        values = dict(
            source_path=self.source,
            project_id="project-1",
            asset_id="asset-1",
            models=["vocals", "drums", "bass", "other"],
            idempotency_key="idem-1",
        )
        values.update(kwargs)
        return self.orch.start(**values)

    def make_ambiguous(self):
        self.provider.create_error = ProviderFailure("VENDOR_TIMEOUT", retryable=True)
        with self.assertRaises(OrchestratorError):
            self.start()
        return next(iter(self.orch.registry.load().values()))

    def test_start_persists_and_same_request_is_idempotent(self):
        first = self.start()
        second = self.start()
        self.assertEqual(first.logical_job_id, second.logical_job_id)
        self.assertEqual(self.provider.upload_calls, 1)
        self.assertEqual(self.provider.create_calls, 1)
        self.assertTrue(self.registry.exists())
        self.assertEqual(first.billing_safety_state, "single_provider_task_confirmed")

    def test_same_key_same_models_different_order_is_same_request(self):
        first = self.start()
        second = self.start(models=["other", "bass", "drums", "vocals"])
        self.assertEqual(first.logical_job_id, second.logical_job_id)
        self.assertEqual(self.provider.create_calls, 1)

    def test_same_key_different_request_fails_closed(self):
        self.start()
        with self.assertRaisesRegex(OrchestratorError, "SEP_IDEMPOTENCY_CONFLICT"):
            self.start(models=["vocals", "instrumental"])
        self.assertEqual(self.provider.create_calls, 1)

    def test_registry_survives_orchestrator_restart(self):
        first = self.start()
        restarted = ProductionSeparationOrchestrator(
            provider=self.provider,
            source_root=self.source_root,
            artifact_root=self.artifact_root,
            registry_path=self.registry,
            downloader=self.orch.downloader,
        )
        loaded = restarted.get(first.logical_job_id)
        self.assertEqual(loaded.provider_task_id, "task-1")
        self.assertEqual(loaded.source_sha256, first.source_sha256)

    def test_schema_v1_registry_migrates_on_next_save(self):
        first = self.start()
        raw = json.loads(self.registry.read_text())
        raw["schema_version"] = 1
        record = raw["jobs"][first.logical_job_id]
        for field in [
            "start_reconciliation_attempts",
            "start_reconciliation_state",
            "provider_task_match_count",
            "recovered_provider_task",
            "billing_safety_state",
        ]:
            record.pop(field, None)
        self.registry.write_text(json.dumps(raw), encoding="utf-8")
        loaded = self.orch.get(first.logical_job_id)
        self.assertEqual(loaded.start_reconciliation_attempts, 0)
        jobs = self.orch.registry.load()
        jobs[first.logical_job_id] = loaded
        self.orch.registry.save(jobs)
        self.assertEqual(json.loads(self.registry.read_text())["schema_version"], 2)

    def test_create_error_is_persisted_as_non_retryable_ambiguous(self):
        record = self.make_ambiguous()
        self.assertEqual(record.state, "start_ambiguous")
        self.assertFalse(record.retryable)
        self.assertEqual(record.billing_safety_state, "unknown_do_not_retry")
        self.assertEqual(self.provider.create_calls, 1)

    def test_ambiguous_start_unique_metadata_match_recovers_without_second_create(self):
        record = self.make_ambiguous()
        self.provider.create_error = None
        self.provider.find_matches = ("task-recovered",)
        recovered = self.orch.reconcile_ambiguous_start(record.logical_job_id)
        self.assertEqual(recovered.provider_task_id, "task-recovered")
        self.assertEqual(recovered.start_reconciliation_state, "matched")
        self.assertTrue(recovered.recovered_provider_task)
        self.assertEqual(recovered.billing_safety_state, "single_provider_task_confirmed")
        self.assertEqual(self.provider.create_calls, 1)

    def test_reconciliation_survives_restart(self):
        record = self.make_ambiguous()
        self.provider.find_matches = ("task-recovered",)
        restarted = ProductionSeparationOrchestrator(
            provider=self.provider,
            source_root=self.source_root,
            artifact_root=self.artifact_root,
            registry_path=self.registry,
            downloader=self.orch.downloader,
        )
        recovered = restarted.reconcile_ambiguous_start(record.logical_job_id)
        self.assertEqual(recovered.provider_task_id, "task-recovered")
        self.assertEqual(self.provider.create_calls, 1)

    def test_zero_reconciliation_matches_never_reposts(self):
        record = self.make_ambiguous()
        self.provider.find_matches = ()
        unresolved = self.orch.reconcile_ambiguous_start(record.logical_job_id)
        self.assertEqual(unresolved.state, "start_reconciliation_unresolved")
        self.assertEqual(unresolved.stable_error_code, "SEP_PROVIDER_START_NOT_FOUND")
        self.assertFalse(unresolved.retryable)
        self.assertEqual(unresolved.billing_safety_state, "unknown_do_not_retry")
        self.assertEqual(self.provider.create_calls, 1)

    def test_multiple_reconciliation_matches_are_billing_incident(self):
        record = self.make_ambiguous()
        self.provider.find_matches = ("task-a", "task-b")
        with self.assertRaisesRegex(OrchestratorError, "SEP_PROVIDER_DUPLICATE_TASKS_DETECTED"):
            self.orch.reconcile_ambiguous_start(record.logical_job_id)
        persisted = self.orch.get(record.logical_job_id)
        self.assertEqual(persisted.state, "duplicate_provider_tasks_detected")
        self.assertEqual(persisted.provider_task_match_count, 2)
        self.assertEqual(persisted.billing_safety_state, "billing_incident")
        self.assertEqual(self.provider.create_calls, 1)

    def test_repeated_identical_match_ids_are_deduplicated(self):
        record = self.make_ambiguous()
        self.provider.find_matches = ("task-a", "task-a")
        recovered = self.orch.reconcile_ambiguous_start(record.logical_job_id)
        self.assertEqual(recovered.provider_task_id, "task-a")
        self.assertEqual(recovered.provider_task_match_count, 1)

    def test_reconciliation_lookup_error_is_nonretryable_for_create(self):
        record = self.make_ambiguous()
        self.provider.find_error = ProviderFailure("LIST_NET", retryable=True)
        with self.assertRaises(OrchestratorError) as caught:
            self.orch.reconcile_ambiguous_start(record.logical_job_id)
        self.assertFalse(caught.exception.retryable)
        persisted = self.orch.get(record.logical_job_id)
        self.assertEqual(persisted.state, "start_reconciliation_error")
        self.assertEqual(persisted.billing_safety_state, "unknown_do_not_retry")
        self.assertEqual(self.provider.create_calls, 1)

    def test_provider_without_reconciliation_capability_requires_manual_review(self):
        provider = ProviderWithoutFinder()
        orch = ProductionSeparationOrchestrator(
            provider=provider,
            source_root=self.source_root,
            artifact_root=self.artifact_root,
            registry_path=self.registry,
            downloader=self.orch.downloader,
        )
        with self.assertRaises(OrchestratorError):
            orch.start(
                source_path=self.source,
                project_id="project-1",
                asset_id="asset-1",
                models=["vocals"],
                idempotency_key="idem-1",
            )
        record = next(iter(orch.registry.load().values()))
        with self.assertRaisesRegex(OrchestratorError, "SEP_PROVIDER_RECONCILIATION_UNSUPPORTED"):
            orch.reconcile_ambiguous_start(record.logical_job_id)
        self.assertEqual(orch.get(record.logical_job_id).billing_safety_state, "manual_review_required")
        self.assertEqual(provider.create_calls, 1)

    def test_recovery_metadata_binds_models_and_request_fingerprint(self):
        record = self.make_ambiguous()
        self.provider.find_matches = ()
        self.orch.reconcile_ambiguous_start(record.logical_job_id)
        metadata = self.provider.last_metadata
        self.assertEqual(metadata["logical_job_id"], record.logical_job_id)
        self.assertEqual(metadata["requested_models"], ["bass", "drums", "other", "vocals"])
        self.assertEqual(metadata["request_fingerprint"], record.request_fingerprint)
        self.assertNotIn("idempotency_key", metadata)

    def test_upload_error_persists_stable_failure(self):
        self.provider.upload_error = ProviderFailure("UPLOAD_NET", retryable=True)
        with self.assertRaises(OrchestratorError) as caught:
            self.start()
        self.assertTrue(caught.exception.retryable)
        raw = json.loads(self.registry.read_text())
        record = next(iter(raw["jobs"].values()))
        self.assertEqual(record["state"], "upload_failed")
        self.assertEqual(record["stable_error_code"], "UPLOAD_NET")

    def test_observe_updates_authoritative_provider_state(self):
        record = self.start()
        self.provider.state = State("separating", 0.75, True)
        observed = self.orch.observe(record.logical_job_id)
        self.assertEqual(observed.provider_phase, "separating")
        self.assertEqual(observed.fraction_complete, 0.75)

    def test_recovered_task_can_be_observed(self):
        record = self.make_ambiguous()
        self.provider.find_matches = ("task-recovered",)
        recovered = self.orch.reconcile_ambiguous_start(record.logical_job_id)
        self.provider.state = State("separating", 0.8, True)
        observed = self.orch.observe(recovered.logical_job_id)
        self.assertEqual(observed.fraction_complete, 0.8)
        self.assertEqual(self.provider.create_calls, 1)

    def test_ready_outputs_are_atomically_copied_and_manifested(self):
        record = self.start()
        targets = tuple(Target(model=m, output_url=f"https://example.test/{m}.wav") for m in record.requested_models)
        self.provider.state = State("ready", 1.0, False, targets=targets)
        result = self.orch.collect_ready_outputs(record.logical_job_id)
        self.assertTrue(result.outputs_committed)
        final = self.artifact_root / record.logical_job_id
        self.assertTrue((final / "manifest.json").exists())
        manifest = json.loads((final / "manifest.json").read_text())
        self.assertEqual(manifest["parity_state"], "NON_PARITY_EVIDENCE_ONLY")

    def test_missing_target_fails_before_committing_any_output(self):
        record = self.start()
        self.provider.state = State("ready", 1.0, False, targets=(Target("vocals", output_url="https://example.test/v.wav"),))
        with self.assertRaisesRegex(OrchestratorError, "SEP_OUTPUT_TARGET_SET_INVALID"):
            self.orch.collect_ready_outputs(record.logical_job_id)
        self.assertFalse((self.artifact_root / record.logical_job_id).exists())

    def test_copy_failure_cleans_staging_and_keeps_job_uncommitted(self):
        record = self.start()
        targets = tuple(Target(model=m, output_url=f"https://example.test/{m}.wav") for m in record.requested_models)
        self.provider.state = State("ready", 1.0, False, targets=targets)
        count = {"n": 0}

        def failing_downloader(url, destination):
            count["n"] += 1
            if count["n"] == 2:
                raise OrchestratorError("COPY_FAIL", retryable=True)
            destination.write_bytes(b"ok")

        self.orch.downloader = failing_downloader
        with self.assertRaisesRegex(OrchestratorError, "COPY_FAIL"):
            self.orch.collect_ready_outputs(record.logical_job_id)
        self.assertFalse((self.artifact_root / record.logical_job_id).exists())
        self.assertFalse(self.orch.get(record.logical_job_id).outputs_committed)

    def test_source_outside_owned_root_is_rejected(self):
        outside = Path(self.tmp.name) / "outside.wav"
        outside.write_bytes(b"audio")
        with self.assertRaisesRegex(OrchestratorError, "SEP_SOURCE_OUTSIDE_ROOT"):
            self.start(source_path=outside)

    def test_corrupt_registry_fails_closed(self):
        self.registry.parent.mkdir(parents=True, exist_ok=True)
        self.registry.write_text("{bad json", encoding="utf-8")
        with self.assertRaisesRegex(OrchestratorError, "SEP_REGISTRY_CORRUPT"):
            self.start()

    def test_registry_never_persists_raw_idempotency_key(self):
        self.start(idempotency_key="super-secret-logical-key")
        text = self.registry.read_text()
        self.assertNotIn("super-secret-logical-key", text)


if __name__ == "__main__":
    unittest.main()
