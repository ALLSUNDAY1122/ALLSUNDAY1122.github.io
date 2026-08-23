import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest


MODULE_PATH = pathlib.Path(__file__).resolve().parents[1] / "Server" / "audioshake_api.py"
spec = importlib.util.spec_from_file_location("audioshake_api", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)

AudioShakeAPIError = module.AudioShakeAPIError
AudioShakeConfig = module.AudioShakeConfig
AudioShakeClient = module.AudioShakeClient
parse_task_state = module.parse_task_state


class StubClient(AudioShakeClient):
    def __init__(self):
        super().__init__(AudioShakeConfig(api_key="server-secret"))
        self.requests = []
        self.next_payload = {"id": "task-1"}
        self.payload_by_path = {}

    def _json_request(self, method, path, body=None):
        self.requests.append((method, path, body))
        if path in self.payload_by_path:
            return self.payload_by_path[path]
        return self.next_payload


class PagingStubClient(AudioShakeClient):
    def __init__(self, pages):
        super().__init__(AudioShakeConfig(api_key="server-secret"))
        self.pages = pages
        self.requests = []

    def list_tasks(self, *, skip=0, take=100):
        self.requests.append((skip, take))
        page = skip // take
        return tuple(self.pages[page]) if page < len(self.pages) else ()


class AudioShakeAPITests(unittest.TestCase):
    def test_rejects_non_https_base_url(self):
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_INSECURE_BASE_URL"):
            AudioShakeClient(AudioShakeConfig(api_key="x", base_url="http://api.audioshake.ai"))

    def test_rejects_header_injection_in_api_key(self):
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_API_KEY_INVALID"):
            AudioShakeClient(AudioShakeConfig(api_key="x\r\nevil: true"))

    def test_creates_exact_four_stem_wav_task(self):
        client = StubClient()
        task_id = client.create_separation_task(
            "asset-1", ["vocals", "drums", "bass", "other"], metadata={"project_id": "p1"}
        )
        self.assertEqual(task_id, "task-1")
        method, path, body = client.requests[-1]
        self.assertEqual((method, path), ("POST", "/tasks"))
        self.assertEqual(
            body["targets"],
            [
                {"model": "vocals", "formats": ["wav"]},
                {"model": "drums", "formats": ["wav"]},
                {"model": "bass", "formats": ["wav"]},
                {"model": "other", "formats": ["wav"]},
            ],
        )
        self.assertEqual(json.loads(body["metadata"]), {"project_id": "p1"})

    def test_rejects_unknown_target(self):
        client = StubClient()
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_UNSUPPORTED_TARGET"):
            client.create_separation_task("asset-1", ["vocals", "magic_stem"])

    def test_processing_fraction_uses_completed_targets_only(self):
        state = parse_task_state(
            {
                "id": "task-1",
                "targets": [
                    {"model": "vocals", "status": "completed", "output": [{"format": "wav", "link": "https://out.example/v.wav"}]},
                    {"model": "drums", "status": "processing", "output": []},
                    {"model": "bass", "status": "processing", "output": []},
                    {"model": "other", "status": "completed", "output": [{"format": "wav", "link": "https://out.example/o.wav"}]},
                ],
            }
        )
        self.assertEqual(state.phase, "separating")
        self.assertEqual(state.fraction_complete, 0.5)
        self.assertTrue(state.retryable)

    def test_ready_requires_wav_output_for_every_target(self):
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_WAV_OUTPUT_MISSING"):
            parse_task_state({"id": "task-1", "targets": [{"model": "vocals", "status": "completed", "output": [{"format": "mp3", "link": "https://out.example/v.mp3"}]}]})

    def test_rejects_insecure_output_link(self):
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_OUTPUT_URL_INSECURE"):
            parse_task_state({"id": "task-1", "targets": [{"model": "vocals", "status": "completed", "output": [{"format": "wav", "link": "http://out.example/v.wav"}]}]})

    def test_error_target_becomes_stable_failure(self):
        state = parse_task_state({"id": "task-1", "targets": [{"model": "vocals", "status": "error", "error": {"code": 422}, "output": []}, {"model": "drums", "status": "processing", "output": []}]})
        self.assertEqual(state.phase, "failed")
        self.assertEqual(state.stable_error_code, "AUDIOSHAKE_TARGET_ERROR_422")
        self.assertFalse(state.retryable)

    def test_rejects_metadata_over_vendor_limit(self):
        client = StubClient()
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_METADATA_TOO_LARGE"):
            client.create_separation_task("asset-1", ["vocals"], metadata={"x": "a" * 5000})

    def test_rejects_unserializable_metadata(self):
        client = StubClient()
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_METADATA_INVALID"):
            client.create_separation_task("asset-1", ["vocals"], metadata={"x": object()})

    def test_rejects_empty_and_oversize_asset_without_network(self):
        client = StubClient()
        with tempfile.TemporaryDirectory() as directory:
            empty = pathlib.Path(directory) / "empty.wav"
            empty.write_bytes(b"")
            with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_SOURCE_EMPTY"):
                client.upload_asset(empty)
            huge = pathlib.Path(directory) / "huge.wav"
            with huge.open("wb") as handle:
                handle.truncate(module.AUDIOSHAKE_MAX_ASSET_BYTES + 1)
            with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_SOURCE_TOO_LARGE"):
                client.upload_asset(huge)

    def test_list_tasks_uses_documented_pagination(self):
        client = StubClient()
        client.payload_by_path["/tasks?skip=100&take=50"] = [{"id": "task-1", "metadata": "{}"}]
        tasks = client.list_tasks(skip=100, take=50)
        self.assertEqual(tasks[0]["id"], "task-1")
        self.assertEqual(client.requests[-1][:2], ("GET", "/tasks?skip=100&take=50"))

    def test_list_tasks_rejects_invalid_page_parameters(self):
        client = StubClient()
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_LIST_SKIP_INVALID"):
            client.list_tasks(skip=-1)
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_LIST_TAKE_INVALID"):
            client.list_tasks(take=101)

    def test_list_tasks_rejects_non_list_response(self):
        client = StubClient()
        client.next_payload = {"id": "not-a-list"}
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_TASK_LIST_INVALID"):
            client.list_tasks()

    def test_find_tasks_by_metadata_exact_match(self):
        metadata = {"logical_job_id": "abc", "requested_models": ["vocals"]}
        encoded = json.dumps(metadata, separators=(",", ":"), sort_keys=True)
        client = PagingStubClient([[{"id": "task-a", "metadata": "{}"}, {"id": "task-b", "metadata": encoded}]])
        self.assertEqual(client.find_tasks_by_metadata(metadata), ("task-b",))

    def test_find_tasks_by_metadata_scans_multiple_pages(self):
        metadata = {"logical_job_id": "abc"}
        encoded = json.dumps(metadata, separators=(",", ":"), sort_keys=True)
        first = [{"id": f"filler-{i}", "metadata": "{}"} for i in range(100)]
        second = [{"id": "task-match", "metadata": encoded}]
        client = PagingStubClient([first, second])
        self.assertEqual(client.find_tasks_by_metadata(metadata), ("task-match",))
        self.assertEqual(client.requests, [(0, 100), (100, 100)])

    def test_find_tasks_by_metadata_returns_multiple_distinct_matches(self):
        metadata = {"logical_job_id": "abc"}
        encoded = json.dumps(metadata, separators=(",", ":"), sort_keys=True)
        client = PagingStubClient([[{"id": "task-a", "metadata": encoded}, {"id": "task-b", "metadata": encoded}, {"id": "task-a", "metadata": encoded}]])
        self.assertEqual(client.find_tasks_by_metadata(metadata), ("task-a", "task-b"))

    def test_find_tasks_scan_limit_fails_closed_instead_of_false_absence(self):
        metadata = {"logical_job_id": "not-present"}
        full_page = [{"id": f"task-{i}", "metadata": "{}"} for i in range(100)]
        client = PagingStubClient([full_page])
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_TASK_SCAN_LIMIT_REACHED"):
            client.find_tasks_by_metadata(metadata, max_pages=1)


if __name__ == "__main__":
    unittest.main()
