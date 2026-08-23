import json
import tempfile
import threading
import time
import unittest
from dataclasses import dataclass
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from long_track_io import MIB, LongTrackIOGuard, LongTrackPolicy, TransferStats
from long_track_production_orchestrator import LongTrackProductionSeparationOrchestrator
from production_orchestrator import OrchestratorError


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
        self.state = State("separating", 0.25, True)

    def upload_asset(self, path):
        self.upload_calls += 1
        return "asset-1"

    def create_separation_task(self, asset_id, models, metadata=None):
        self.create_calls += 1
        return "task-1"

    def get_task_state(self, task_id):
        return self.state


class LongTrackProductionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.source_root = root / "source"
        self.source_root.mkdir()
        self.source = self.source_root / "song.wav"
        self.source.write_bytes(b"a" * (2 * MIB))
        self.artifact_root = root / "artifacts"
        self.registry = root / "registry" / "jobs.json"
        self.telemetry = root / "registry" / "long-track.json"
        self.provider = FakeProvider()
        self.free_bytes = 2 * 1024 * MIB
        self.guard = LongTrackIOGuard(
            LongTrackPolicy(
                max_source_bytes=32 * MIB,
                chunk_bytes=MIB,
                output_estimate_ratio_per_target=2.0,
                max_output_ratio_per_target=4.0,
                minimum_estimated_stem_bytes=1,
                minimum_max_stem_bytes=1,
                safety_reserve_bytes=MIB,
            ),
            free_bytes_provider=lambda _: self.free_bytes,
        )
        self.downloads = []

        def downloader(url, destination):
            self.downloads.append(url)
            destination.write_bytes(b"w" * MIB)
            return TransferStats(MIB, 5, 1, MIB)

        self.orch = LongTrackProductionSeparationOrchestrator(
            provider=self.provider,
            source_root=self.source_root,
            artifact_root=self.artifact_root,
            registry_path=self.registry,
            downloader=downloader,
            long_track_guard=self.guard,
            long_track_telemetry_path=self.telemetry,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def start(self, key="idem-1", models=("vocals", "drums")):
        return self.orch.start(
            source_path=self.source,
            project_id="project-1",
            asset_id="asset-1",
            models=models,
            idempotency_key=key,
        )

    def ready(self, record):
        self.provider.state = State(
            "ready",
            1.0,
            False,
            targets=tuple(
                Target(model=model, output_url=f"https://example.test/{model}.wav")
                for model in record.requested_models
            ),
        )

    def test_source_limit_fails_before_provider_upload(self):
        too_small = LongTrackIOGuard(
            LongTrackPolicy(max_source_bytes=MIB, safety_reserve_bytes=0),
            free_bytes_provider=lambda _: 10 * 1024 * MIB,
        )
        orch = LongTrackProductionSeparationOrchestrator(
            provider=self.provider,
            source_root=self.source_root,
            artifact_root=self.artifact_root,
            registry_path=self.registry,
            long_track_guard=too_small,
        )
        with self.assertRaisesRegex(OrchestratorError, "SEP_SOURCE_TOO_LARGE"):
            orch.start(
                source_path=self.source,
                project_id="p1",
                asset_id="a1",
                models=["vocals"],
                idempotency_key="too-large",
            )
        self.assertEqual(self.provider.upload_calls, 0)
        self.assertEqual(self.provider.create_calls, 0)

    def test_storage_preflight_fails_before_provider_upload(self):
        self.free_bytes = 1
        with self.assertRaises(OrchestratorError) as caught:
            self.start()
        self.assertEqual(caught.exception.code, "SEP_STORAGE_PREFLIGHT_INSUFFICIENT")
        self.assertTrue(caught.exception.retryable)
        self.assertEqual(self.provider.upload_calls, 0)
        self.assertEqual(self.provider.create_calls, 0)

    def test_storage_is_rechecked_before_output_download(self):
        record = self.start()
        self.ready(record)
        self.free_bytes = 1
        with self.assertRaisesRegex(OrchestratorError, "SEP_STORAGE_PREFLIGHT_INSUFFICIENT"):
            self.orch.collect_ready_outputs(record.logical_job_id)
        self.assertEqual(self.downloads, [])
        self.assertFalse((self.artifact_root / record.logical_job_id).exists())
        self.assertFalse(self.orch.get(record.logical_job_id).outputs_committed)

    def test_success_persists_privacy_safe_transfer_telemetry(self):
        record = self.start()
        self.ready(record)
        result = self.orch.collect_ready_outputs(record.logical_job_id)
        self.assertTrue(result.outputs_committed)
        telemetry = self.orch.long_track_status(record.logical_job_id)
        self.assertEqual(telemetry.upload_bytes, self.source.stat().st_size)
        self.assertEqual(telemetry.download_bytes, 2 * MIB)
        self.assertEqual(telemetry.download_count, 2)
        self.assertEqual(telemetry.max_transfer_chunk_bytes, MIB)
        self.assertEqual(telemetry.max_parallel_transfers, 1)
        raw = self.telemetry.read_text(encoding="utf-8")
        self.assertNotIn(str(self.source), raw)
        self.assertNotIn("https://example.test", raw)
        self.assertNotIn("song.wav", raw)
        self.assertEqual(json.loads(raw)["schema_version"], 1)

    def test_oversize_custom_output_is_removed_and_never_committed(self):
        record = self.start(models=("vocals",))
        self.ready(record)
        maximum = self.orch.long_track_status(record.logical_job_id).max_single_stem_bytes

        def oversized(url, destination):
            with destination.open("wb") as handle:
                handle.truncate(maximum + 1)

        self.orch._custom_downloader = oversized
        with self.assertRaisesRegex(OrchestratorError, "SEP_OUTPUT_STREAM_TOO_LARGE"):
            self.orch.collect_ready_outputs(record.logical_job_id)
        self.assertFalse((self.artifact_root / record.logical_job_id).exists())
        self.assertFalse((self.artifact_root / (record.logical_job_id + ".staging")).exists())
        self.assertFalse(self.orch.get(record.logical_job_id).outputs_committed)

    def test_global_download_semaphore_bounds_parallel_jobs_to_one(self):
        active = 0
        peak = 0
        lock = threading.Lock()
        gate = threading.Barrier(2)

        def slow_downloader(url, destination):
            nonlocal active, peak
            with lock:
                active += 1
                peak = max(peak, active)
            try:
                time.sleep(0.05)
                destination.write_bytes(b"ok")
            finally:
                with lock:
                    active -= 1

        self.orch._custom_downloader = slow_downloader
        records = [self.start(key=f"idem-{index}", models=("vocals",)) for index in range(2)]
        # FakeProvider exposes one state for both task IDs; identical ready target is sufficient here.
        self.provider.state = State(
            "ready", 1.0, False, targets=(Target("vocals", output_url="https://example.test/v.wav"),)
        )
        errors = []

        def run(record):
            try:
                gate.wait()
                self.orch.collect_ready_outputs(record.logical_job_id)
            except Exception as exc:  # pragma: no cover - asserted below
                errors.append(exc)

        threads = [threading.Thread(target=run, args=(record,)) for record in records]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(errors, [])
        self.assertEqual(peak, 1)


if __name__ == "__main__":
    unittest.main()
