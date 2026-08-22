import importlib.util
import pathlib
import tempfile
import unittest


MODULE_PATH = pathlib.Path(__file__).resolve().parents[1] / "Server" / "audioshake_api.py"
spec = importlib.util.spec_from_file_location("audioshake_api", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
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

    def _json_request(self, method, path, body=None):
        self.requests.append((method, path, body))
        return self.next_payload


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
        self.assertIn("project_id", body["metadata"])

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
            parse_task_state(
                {
                    "id": "task-1",
                    "targets": [
                        {"model": "vocals", "status": "completed", "output": [{"format": "mp3", "link": "https://out.example/v.mp3"}]}
                    ],
                }
            )

    def test_rejects_insecure_output_link(self):
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_OUTPUT_URL_INSECURE"):
            parse_task_state(
                {
                    "id": "task-1",
                    "targets": [
                        {"model": "vocals", "status": "completed", "output": [{"format": "wav", "link": "http://out.example/v.wav"}]}
                    ],
                }
            )

    def test_error_target_becomes_stable_failure(self):
        state = parse_task_state(
            {
                "id": "task-1",
                "targets": [
                    {"model": "vocals", "status": "error", "error": {"code": 422}, "output": []},
                    {"model": "drums", "status": "processing", "output": []},
                ],
            }
        )
        self.assertEqual(state.phase, "failed")
        self.assertEqual(state.stable_error_code, "AUDIOSHAKE_TARGET_ERROR_422")
        self.assertFalse(state.retryable)

    def test_rejects_metadata_over_vendor_limit(self):
        client = StubClient()
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_METADATA_TOO_LARGE"):
            client.create_separation_task("asset-1", ["vocals"], metadata={"x": "a" * 5000})

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


if __name__ == "__main__":
    unittest.main()
