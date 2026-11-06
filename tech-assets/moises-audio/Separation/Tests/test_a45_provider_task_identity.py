import sys
import unittest
from dataclasses import dataclass
from pathlib import Path

SERVER = Path(__file__).resolve().parents[1] / "Server"
PROFILES = Path(__file__).resolve().parents[1] / "Profiles"
sys.path.insert(0, str(SERVER))

from audioshake_api import (
    AudioShakeAPIError,
    AudioShakeClient,
    AudioShakeConfig,
    parse_task_state,
)
from advanced_capabilities import AdvancedCapabilityError, load_advanced_role_catalog
from canonical_advanced_provider import CanonicalAdvancedAudioShakeAdapter


def completed_target(model: str, link: str | None = None):
    return {
        "model": model,
        "status": "completed",
        "output": [{"format": "wav", "link": link or f"https://out.example/{model}.wav"}],
    }


def model(model_id: str, *, access: str = "enabled"):
    return {
        "id": model_id,
        "category": "instrumentStemSeparation",
        "access": access,
        "outputFormats": ["wav"],
        "creditsPerMinute": 1,
    }


class StubAudioShakeClient(AudioShakeClient):
    def __init__(self, payload):
        super().__init__(AudioShakeConfig(api_key="server-secret"))
        self.payload = payload
        self.requests = []

    def _json_request(self, method, path, body=None):
        self.requests.append((method, path, body))
        return self.payload


@dataclass(frozen=True)
class RawTarget:
    model: str
    status: str = "completed"
    output_url: str | None = "https://out.example/stem.wav"
    error_code: str | None = None


@dataclass(frozen=True)
class RawState:
    task_id: str
    phase: str = "ready"
    fraction_complete: float = 1.0
    retryable: bool = False
    stable_error_code: str | None = None
    targets: tuple[RawTarget, ...] = ()


class CanonicalClient:
    def __init__(self, state, *, models=None, fail_models: bool = False):
        self.state = state
        self.models = models or [model("guitar"), model("keys")]
        self.fail_models = fail_models
        self.requests = []

    def _json_request(self, method, path, body=None):
        self.requests.append((method, path, body))
        if path == "/models":
            if self.fail_models:
                raise RuntimeError("models unavailable")
            return {"models": self.models}
        if path == "/tasks":
            return {"id": "task-1"}
        raise RuntimeError(path)

    def get_task_state(self, task_id):
        return self.state

    def upload_asset(self, source_path):
        return "asset-1"

    def find_tasks_by_metadata(self, metadata):
        return ("task-1",)


class A45ProviderTaskIdentityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = load_advanced_role_catalog(PROFILES / "advanced_role_catalog.v1.json")

    def test_low_level_get_rejects_response_task_id_mismatch(self):
        client = StubAudioShakeClient({"id": "task-other", "targets": [completed_target("vocals")]})
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_TASK_ID_MISMATCH"):
            client.get_task_state("task-expected")
        self.assertEqual(client.requests, [("GET", "/tasks/task-expected", None)])

    def test_low_level_get_accepts_exact_task_identity(self):
        client = StubAudioShakeClient({"id": "task-expected", "targets": [completed_target("vocals")]})
        state = client.get_task_state("task-expected")
        self.assertEqual(state.task_id, "task-expected")
        self.assertEqual(state.phase, "ready")

    def test_duplicate_provider_model_targets_fail_closed(self):
        payload = {
            "id": "task-1",
            "targets": [completed_target("vocals"), completed_target("vocals")],
        }
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_TARGET_MODEL_DUPLICATE"):
            parse_task_state(payload)

    def test_multiple_wav_outputs_for_one_target_are_ambiguous(self):
        payload = {
            "id": "task-1",
            "targets": [{
                "model": "vocals",
                "status": "completed",
                "output": [
                    {"format": "wav", "link": "https://out.example/a.wav"},
                    {"format": "wav", "link": "https://out.example/b.wav"},
                ],
            }],
        }
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_WAV_OUTPUT_AMBIGUOUS"):
            parse_task_state(payload)

    def test_https_output_without_hostname_is_rejected(self):
        payload = {"id": "task-1", "targets": [completed_target("vocals", "https:///stem.wav")]}
        with self.assertRaisesRegex(AudioShakeAPIError, "AUDIOSHAKE_OUTPUT_URL_INSECURE"):
            parse_task_state(payload)

    def test_canonical_boundary_rejects_task_id_mismatch(self):
        client = CanonicalClient(RawState(task_id="task-other", targets=(RawTarget("guitar"),)))
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_TASK_ID_MISMATCH"):
            adapter.get_task_state("task-expected")
        self.assertEqual(client.requests, [])

    def test_canonical_boundary_rejects_missing_task_identity(self):
        class MissingIdentity:
            phase = "ready"
            fraction_complete = 1.0
            retryable = False
            stable_error_code = None
            targets = (RawTarget("guitar"),)

        client = CanonicalClient(MissingIdentity())
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_TASK_STATE_INVALID"):
            adapter.get_task_state("task-1")
        self.assertEqual(client.requests, [])

    def test_canonical_duplicate_provider_target_fails_before_mapping(self):
        state = RawState(
            task_id="task-1",
            targets=(RawTarget("guitar"), RawTarget("guitar")),
        )
        client = CanonicalClient(state)
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_OUTPUT_MODEL_DUPLICATE"):
            adapter.get_task_state("task-1")
        self.assertEqual(client.requests, [])

    def test_existing_task_observation_does_not_require_models_discovery(self):
        state = RawState(
            task_id="task-1",
            targets=(RawTarget("guitar"), RawTarget("keys")),
        )
        client = CanonicalClient(state, fail_models=True)
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        observed = adapter.get_task_state("task-1")
        self.assertEqual(tuple(target.model for target in observed.targets), ("guitar", "piano_keys"))
        self.assertEqual(client.requests, [])

    def test_existing_task_maps_catalog_model_even_if_current_access_would_be_gated(self):
        state = RawState(task_id="task-1", targets=(RawTarget("keys"),))
        client = CanonicalClient(state, models=[model("keys", access="request_access")])
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        observed = adapter.get_task_state("task-1")
        self.assertEqual(observed.targets[0].model, "piano_keys")
        self.assertEqual(client.requests, [])

    def test_new_task_preflight_still_requires_live_model_discovery(self):
        state = RawState(task_id="task-1", targets=(RawTarget("guitar"),))
        client = CanonicalClient(state, fail_models=True)
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_MODEL_DISCOVERY_FAILED"):
            adapter.preflight_separation(("guitar",))
        self.assertEqual(client.requests[0][:2], ("GET", "/models"))

    def test_unknown_provider_output_model_still_fails_closed_without_discovery(self):
        state = RawState(task_id="task-1", targets=(RawTarget("future_magic"),))
        client = CanonicalClient(state, fail_models=True)
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_OUTPUT_MODEL_UNKNOWN"):
            adapter.get_task_state("task-1")
        self.assertEqual(client.requests, [])

    def test_invalid_canonical_task_id_fails_before_any_provider_call(self):
        client = CanonicalClient(RawState(task_id="task-1", targets=(RawTarget("guitar"),)))
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_TASK_ID_INVALID"):
            adapter.get_task_state("")
        self.assertEqual(client.requests, [])


if __name__ == "__main__":
    unittest.main()
