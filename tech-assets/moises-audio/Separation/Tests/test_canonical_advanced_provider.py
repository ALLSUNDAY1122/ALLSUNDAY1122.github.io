import json
import sys
import unittest
from dataclasses import dataclass
from pathlib import Path

SERVER = Path(__file__).resolve().parents[1] / "Server"
PROFILES = Path(__file__).resolve().parents[1] / "Profiles"
sys.path.insert(0, str(SERVER))

from advanced_capabilities import AdvancedCapabilityError, load_advanced_role_catalog
from canonical_advanced_provider import CanonicalAdvancedAudioShakeAdapter


def model(model_id, access="enabled"):
    return {"id": model_id, "category": "instrumentStemSeparation", "access": access,
            "outputFormats": ["wav"], "creditsPerMinute": 1}


@dataclass(frozen=True)
class RawTarget:
    model: str
    status: str = "completed"
    output_url: str | None = "https://out.test/x.wav"
    error_code: str | None = None


@dataclass(frozen=True)
class RawState:
    task_id: str = "task-1"
    phase: str = "ready"
    fraction_complete: float = 1.0
    retryable: bool = False
    stable_error_code: str | None = None
    targets: tuple[RawTarget, ...] = ()


class Client:
    def __init__(self, models, state=None):
        self.models = models
        self.state = state or RawState(targets=(RawTarget("guitar"), RawTarget("keys")))
        self.requests = []
        self.upload_calls = 0

    def _json_request(self, method, path, body=None):
        self.requests.append((method, path, body))
        if path == "/models":
            return {"models": self.models}
        if path == "/tasks":
            return {"id": "task-1"}
        raise RuntimeError(path)

    def upload_asset(self, source_path):
        self.upload_calls += 1
        return "asset-1"

    def get_task_state(self, task_id):
        return self.state

    def find_tasks_by_metadata(self, metadata):
        return ("task-1",)


class CanonicalBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = load_advanced_role_catalog(PROFILES / "advanced_role_catalog.v1.json")

    def adapter(self, client):
        return CanonicalAdvancedAudioShakeAdapter(client, catalog=self.catalog)

    def test_canonical_keys_translate_only_at_post_boundary(self):
        client = Client([model("guitar"), model("keys")])
        task = self.adapter(client).create_separation_task("asset-1", ("guitar", "piano_keys"))
        self.assertEqual(task, "task-1")
        post = [r for r in client.requests if r[1] == "/tasks"][0][2]
        self.assertEqual(post["targets"], [
            {"model": "guitar", "formats": ["wav"]},
            {"model": "keys", "formats": ["wav"]},
        ])

    def test_disabled_canonical_role_never_posts(self):
        client = Client([model("guitar"), model("keys", "request_access")])
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_PROVIDER_MODEL_NOT_ENABLED"):
            self.adapter(client).create_separation_task("asset-1", ("piano_keys",))
        self.assertFalse(any(path == "/tasks" for _, path, _ in client.requests))

    def test_provider_output_models_return_as_canonical_roles(self):
        client = Client([model("guitar"), model("keys")])
        state = self.adapter(client).get_task_state("task-1")
        self.assertEqual(tuple(t.model for t in state.targets), ("guitar", "piano_keys"))

    def test_unknown_provider_output_model_fails_closed(self):
        state = RawState(targets=(RawTarget("magic"),))
        client = Client([model("guitar")], state=state)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_OUTPUT_MODEL_UNKNOWN"):
            self.adapter(client).get_task_state("task-1")

    def test_discovery_precedes_user_media_upload(self):
        client = Client([model("guitar")])
        self.adapter(client).upload_asset("song.wav")
        self.assertEqual(client.requests[0][1], "/models")
        self.assertEqual(client.upload_calls, 1)

    def test_metadata_stays_canonical_and_privacy_safe(self):
        client = Client([model("guitar")])
        self.adapter(client).create_separation_task(
            "asset-1", ("guitar",), metadata={"requested_roles": ["guitar"]}
        )
        post = [r for r in client.requests if r[1] == "/tasks"][0][2]
        self.assertEqual(json.loads(post["metadata"]), {"requested_roles": ["guitar"]})

    def test_semantic_overlap_rejected_before_post(self):
        client = Client([model("guitar"), model("guitar_electric")])
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_ROLE_COMBINATION_OVERLAPS"):
            self.adapter(client).create_separation_task("asset-1", ("guitar", "electric_guitar"))
        self.assertFalse(any(path == "/tasks" for _, path, _ in client.requests))


if __name__ == "__main__":
    unittest.main()
