import json
import sys
import tempfile
import unittest
from pathlib import Path

SERVER = Path(__file__).resolve().parents[1] / "Server"
PROFILES = Path(__file__).resolve().parents[1] / "Profiles"
sys.path.insert(0, str(SERVER))

from advanced_capabilities import (
    AdvancedAudioShakeAdapter,
    AdvancedCapabilityError,
    build_audioshake_capabilities,
    discover_audioshake_models,
    load_advanced_role_catalog,
    normalize_provider_output_models,
    parse_audioshake_models,
    public_capability_snapshot,
    validate_canonical_role_combination,
)


def model(
    model_id,
    *,
    access="enabled",
    category="instrumentStemSeparation",
    formats=("wav", "mp3"),
    credits=1,
    limits=None,
):
    value = {
        "id": model_id,
        "category": category,
        "access": access,
        "outputFormats": list(formats),
        "creditsPerMinute": credits,
    }
    if limits is not None:
        value["limits"] = limits
    return value


class StubClient:
    def __init__(self, payload):
        self.payload = payload
        self.requests = []
        self.uploads = 0

    def _json_request(self, method, path, body=None):
        self.requests.append((method, path, body))
        if path == "/models":
            return self.payload
        if path == "/tasks":
            return {"id": "task-advanced"}
        raise RuntimeError(path)

    def upload_asset(self, source_path):
        self.uploads += 1
        return "asset-1"

    def get_task_state(self, task_id):
        return {"id": task_id}

    def find_tasks_by_metadata(self, metadata):
        return ("task-a",)


class AdvancedCapabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = load_advanced_role_catalog(PROFILES / "advanced_role_catalog.v1.json")

    def test_catalog_non_parity(self):
        self.assertEqual(self.catalog.parity_state, "NON_PARITY_EVIDENCE_ONLY")

    def test_catalog_contains_required_advanced_families(self):
        for role in ("guitar", "piano_keys", "strings", "winds"):
            self.assertIn(role, self.catalog.roles)

    def test_guitar_is_direct_reference_floor_only(self):
        self.assertEqual(
            self.catalog.roles["guitar"].reference_state,
            "DIRECT_CURRENT_IPHONE_CONFIRMED",
        )
        self.assertEqual(
            self.catalog.roles["piano_keys"].reference_state,
            "UNVERIFIED_CURRENT_IPHONE",
        )

    def test_professional_modules_represented_but_unverified(self):
        for role in (
            "lead_vocals",
            "backing_vocals",
            "electric_guitar",
            "acoustic_guitar",
            "acoustic_piano",
        ):
            self.assertEqual(
                self.catalog.roles[role].reference_state,
                "UNVERIFIED_CURRENT_IPHONE",
            )

    def test_parse_account_models(self):
        snapshot = parse_audioshake_models(
            {"models": [model("guitar"), model("keys"), model("wind")]}
        )
        self.assertEqual(
            snapshot.enabled_instrument_models,
            frozenset({"guitar", "keys", "wind"}),
        )

    def test_request_access_not_enabled(self):
        snapshot = parse_audioshake_models(
            {"models": [model("guitar", access="request_access")]}
        )
        self.assertEqual(snapshot.enabled_instrument_models, frozenset())

    def test_non_wav_not_enabled_for_lane_output(self):
        snapshot = parse_audioshake_models(
            {"models": [model("guitar", formats=("mp3",))]}
        )
        self.assertEqual(snapshot.enabled_instrument_models, frozenset())

    def test_duplicate_model_fails_closed(self):
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_MODEL_DUPLICATE"):
            parse_audioshake_models({"models": [model("guitar"), model("guitar")]})

    def test_bad_model_id_fails_closed(self):
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_MODEL_ID_INVALID"):
            parse_audioshake_models({"models": [model("../guitar")]})

    def test_invalid_access_fails_closed(self):
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_MODEL_ACCESS_INVALID"):
            parse_audioshake_models({"models": [model("guitar", access="maybe")]})

    def test_build_maps_provider_ids_to_canonical_roles(self):
        snapshot = parse_audioshake_models(
            {
                "models": [
                    model("guitar"),
                    model("keys"),
                    model("strings"),
                    model("wind"),
                ]
            }
        )
        capabilities = build_audioshake_capabilities(snapshot, catalog=self.catalog)
        self.assertEqual(capabilities.role_model_map["piano_keys"], "keys")
        self.assertEqual(capabilities.role_model_map["winds"], "wind")
        self.assertTrue(capabilities.supports_custom_selection)

    def test_build_excludes_gated_professional_model(self):
        snapshot = parse_audioshake_models(
            {
                "models": [
                    model("guitar"),
                    model("vocals_lead", access="request_access"),
                ]
            }
        )
        capabilities = build_audioshake_capabilities(snapshot, catalog=self.catalog)
        self.assertNotIn("lead_vocals", capabilities.role_model_map)

    def test_build_never_infers_hifi(self):
        snapshot = parse_audioshake_models({"models": [model("guitar")]})
        capabilities = build_audioshake_capabilities(snapshot, catalog=self.catalog)
        self.assertEqual(capabilities.quality_mode_map, {"standard": None})
        self.assertNotIn("hifi", capabilities.quality_mode_map)

    def test_no_enabled_instrument_models_fails_closed(self):
        snapshot = parse_audioshake_models(
            {"models": [model("guitar", access="request_access")]}
        )
        with self.assertRaisesRegex(
            AdvancedCapabilityError,
            "SEP_ADV_NO_ENABLED_INSTRUMENT_MODELS",
        ):
            build_audioshake_capabilities(snapshot, catalog=self.catalog)

    def test_max_target_policy_validation(self):
        snapshot = parse_audioshake_models({"models": [model("guitar")]})
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_MAX_TARGETS_INVALID"):
            build_audioshake_capabilities(snapshot, catalog=self.catalog, max_targets=0)

    def test_semantic_overlap_guitar_aggregate_and_electric_rejected(self):
        with self.assertRaisesRegex(
            AdvancedCapabilityError,
            "SEP_ADV_ROLE_COMBINATION_OVERLAPS",
        ):
            validate_canonical_role_combination(
                ("guitar", "electric_guitar"),
                catalog=self.catalog,
            )

    def test_semantic_overlap_vocals_aggregate_and_lead_rejected(self):
        with self.assertRaisesRegex(
            AdvancedCapabilityError,
            "SEP_ADV_ROLE_COMBINATION_OVERLAPS",
        ):
            validate_canonical_role_combination(
                ("vocals", "lead_vocals"),
                catalog=self.catalog,
            )

    def test_distinct_lead_and_backing_allowed(self):
        self.assertEqual(
            validate_canonical_role_combination(
                ("lead_vocals", "backing_vocals"),
                catalog=self.catalog,
            ),
            ("lead_vocals", "backing_vocals"),
        )

    def test_target_limit_enforced(self):
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_TARGET_LIMIT_EXCEEDED"):
            validate_canonical_role_combination(
                ("vocals", "drums", "bass"),
                catalog=self.catalog,
                max_targets=2,
            )

    def test_output_normalization_maps_back_to_canonical(self):
        self.assertEqual(
            normalize_provider_output_models(
                ("guitar", "piano_keys"),
                ("guitar", "keys"),
                ("keys", "guitar"),
            ),
            ("guitar", "piano_keys"),
        )

    def test_output_extra_missing_fails_closed(self):
        with self.assertRaisesRegex(
            AdvancedCapabilityError,
            "SEP_ADV_OUTPUT_MODEL_SET_MISMATCH",
        ):
            normalize_provider_output_models(
                ("guitar", "piano_keys"),
                ("guitar", "keys"),
                ("guitar", "wind"),
            )

    def test_output_duplicate_fails_closed(self):
        with self.assertRaisesRegex(
            AdvancedCapabilityError,
            "SEP_ADV_OUTPUT_MODEL_DUPLICATE",
        ):
            normalize_provider_output_models(
                ("guitar", "piano_keys"),
                ("guitar", "keys"),
                ("guitar", "guitar"),
            )

    def test_adapter_discovers_before_upload(self):
        client = StubClient({"models": [model("guitar")]})
        adapter = AdvancedAudioShakeAdapter(client, catalog=self.catalog)
        self.assertEqual(adapter.upload_asset("song.wav"), "asset-1")
        self.assertEqual(client.requests[0][1], "/models")
        self.assertEqual(client.uploads, 1)

    def test_adapter_rejects_unenabled_model_before_post(self):
        client = StubClient(
            {"models": [model("guitar"), model("keys", access="request_access")]}
        )
        adapter = AdvancedAudioShakeAdapter(client, catalog=self.catalog)
        with self.assertRaisesRegex(
            AdvancedCapabilityError,
            "SEP_ADV_PROVIDER_MODEL_NOT_ENABLED",
        ):
            adapter.create_separation_task("asset-1", ("keys",))
        self.assertFalse(any(path == "/tasks" for _, path, _ in client.requests))

    def test_adapter_posts_enabled_advanced_model(self):
        client = StubClient({"models": [model("guitar"), model("keys")]})
        adapter = AdvancedAudioShakeAdapter(client, catalog=self.catalog)
        task = adapter.create_separation_task(
            "asset-1",
            ("guitar", "keys"),
            metadata={"logical_job_id": "abc"},
        )
        self.assertEqual(task, "task-advanced")
        post = [request for request in client.requests if request[1] == "/tasks"][0]
        self.assertEqual(
            post[2]["targets"],
            [
                {"model": "guitar", "formats": ["wav"]},
                {"model": "keys", "formats": ["wav"]},
            ],
        )
        self.assertEqual(json.loads(post[2]["metadata"]), {"logical_job_id": "abc"})

    def test_public_snapshot_marks_hifi_unverified(self):
        snapshot = parse_audioshake_models({"models": [model("guitar")]})
        public = public_capability_snapshot(snapshot, catalog=self.catalog)
        self.assertEqual(public["hifi_provider_mapping"], "UNVERIFIED_FAIL_CLOSED")
        self.assertEqual(public["parity_state"], "NON_PARITY_EVIDENCE_ONLY")

    def test_discovery_error_is_stable_fail_closed(self):
        class BadClient(StubClient):
            def _json_request(self, method, path, body=None):
                raise RuntimeError("net")

        with self.assertRaisesRegex(
            AdvancedCapabilityError,
            "SEP_ADV_MODEL_DISCOVERY_FAILED",
        ):
            discover_audioshake_models(BadClient({}))

    def test_corrupt_catalog_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "catalog.json"
            path.write_text("{bad", encoding="utf-8")
            with self.assertRaisesRegex(
                AdvancedCapabilityError,
                "SEP_ADV_CATALOG_UNREADABLE",
            ):
                load_advanced_role_catalog(path)


if __name__ == "__main__":
    unittest.main()
