import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
PROFILES_DIR = Path(__file__).resolve().parents[1] / "Profiles"
sys.path.insert(0, str(SERVER_DIR))

from reference_profiles import (
    ProfileRegistryError,
    ProviderCapabilities,
    audioshake_core_capabilities,
    load_registry,
    negotiate_provider,
    public_registry_snapshot,
    resolve_request,
    validate_output_completeness,
)


class ReferenceProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry_path = PROFILES_DIR / "reference_profiles.v1.json"
        cls.registry = load_registry(cls.registry_path)

    def request(self, profile_id, tier="free", roles=(), quality="standard"):
        return resolve_request(
            profile_id,
            account_tier=tier,
            selected_roles=roles,
            quality_mode=quality,
            registry=self.registry,
        )

    def test_registry_has_stable_minimum_profiles(self):
        self.assertEqual(
            set(self.registry.profiles),
            {
                "sep.basic.v1.vocals_instrumental",
                "sep.basic.v1.vocals_drums_bass_other",
                "sep.custom.v1.reference_floor",
            },
        )

    def test_registry_is_explicit_non_parity(self):
        self.assertEqual(self.registry.parity_state, "NON_PARITY_EVIDENCE_ONLY")

    def test_public_snapshot_is_vendor_neutral(self):
        text = json.dumps(public_registry_snapshot(self.registry), sort_keys=True).lower()
        self.assertNotIn("audioshake", text)
        self.assertNotIn("vendor", text)
        self.assertIn("sep.basic.v1.vocals_instrumental", text)

    def test_basic_two_stem_resolves_exact_roles(self):
        request = self.request("sep.basic.v1.vocals_instrumental")
        self.assertEqual(request.canonical_roles, ("vocals", "instrumental"))

    def test_basic_four_stem_resolves_exact_roles(self):
        request = self.request("sep.basic.v1.vocals_drums_bass_other")
        self.assertEqual(request.canonical_roles, ("vocals", "drums", "bass", "other"))

    def test_fixed_profile_cannot_be_overridden(self):
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_FIXED_SELECTION_OVERRIDE_FORBIDDEN"):
            self.request("sep.basic.v1.vocals_instrumental", roles=("vocals",))

    def test_custom_requires_premium(self):
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_ENTITLEMENT_REQUIRED"):
            self.request("sep.custom.v1.reference_floor", tier="free", roles=("vocals", "guitar"))

    def test_custom_requires_non_empty_selection(self):
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_CUSTOM_SELECTION_REQUIRED"):
            self.request("sep.custom.v1.reference_floor", tier="premium")

    def test_custom_allows_only_directly_confirmed_reference_floor_roles(self):
        request = self.request(
            "sep.custom.v1.reference_floor",
            tier="premium",
            roles=("vocals", "guitar", "bass"),
        )
        self.assertEqual(request.canonical_roles, ("vocals", "guitar", "bass"))
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_CUSTOM_ROLE_NOT_REFERENCE_CONFIRMED"):
            self.request("sep.custom.v1.reference_floor", tier="premium", roles=("drums",))

    def test_custom_duplicate_role_rejected(self):
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_SELECTED_ROLES_DUPLICATE"):
            self.request("sep.custom.v1.reference_floor", tier="premium", roles=("vocals", "vocals"))

    def test_hifi_requires_pro(self):
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_HIFI_ENTITLEMENT_REQUIRED"):
            self.request(
                "sep.custom.v1.reference_floor",
                tier="premium",
                roles=("vocals", "guitar"),
                quality="hifi",
            )
        request = self.request(
            "sep.custom.v1.reference_floor",
            tier="pro",
            roles=("vocals", "guitar"),
            quality="hifi",
        )
        self.assertEqual(request.quality_mode, "hifi")

    def test_hifi_is_not_inferred_for_basic_profiles(self):
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_QUALITY_UNSUPPORTED_BY_REFERENCE"):
            self.request("sep.basic.v1.vocals_drums_bass_other", tier="pro", quality="hifi")

    def test_current_audioshake_adapter_negotiates_basic_profiles(self):
        caps = audioshake_core_capabilities()
        request = self.request("sep.basic.v1.vocals_drums_bass_other")
        plan = negotiate_provider(request, caps, registry=self.registry)
        self.assertEqual(plan.provider_models, ("vocals", "drums", "bass", "other"))
        self.assertIsNone(plan.provider_quality_token)

    def test_current_audioshake_adapter_fails_closed_for_custom(self):
        request = self.request(
            "sep.custom.v1.reference_floor", tier="premium", roles=("vocals", "guitar")
        )
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROVIDER_CUSTOM_SELECTION_UNSUPPORTED"):
            negotiate_provider(request, audioshake_core_capabilities(), registry=self.registry)

    def test_hifi_requires_provider_quality_capability(self):
        request = self.request(
            "sep.custom.v1.reference_floor",
            tier="pro",
            roles=("vocals", "guitar"),
            quality="hifi",
        )
        caps = ProviderCapabilities(
            provider_key="test-standard-only",
            role_model_map={"vocals": "v", "guitar": "g"},
            quality_mode_map={"standard": None},
            supports_custom_selection=True,
        )
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROVIDER_QUALITY_MODE_UNSUPPORTED"):
            negotiate_provider(request, caps, registry=self.registry)

    def test_provider_missing_role_fails_closed(self):
        request = self.request("sep.basic.v1.vocals_instrumental")
        caps = ProviderCapabilities(
            provider_key="test-missing-role",
            role_model_map={"vocals": "v"},
            quality_mode_map={"standard": None},
            supports_custom_selection=False,
        )
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROVIDER_ROLE_UNSUPPORTED"):
            negotiate_provider(request, caps, registry=self.registry)

    def test_provider_role_map_collision_fails_closed(self):
        request = self.request("sep.basic.v1.vocals_instrumental")
        caps = ProviderCapabilities(
            provider_key="test-collision",
            role_model_map={"vocals": "same", "instrumental": "same"},
            quality_mode_map={"standard": None},
            supports_custom_selection=False,
        )
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROVIDER_ROLE_MAP_COLLISION"):
            negotiate_provider(request, caps, registry=self.registry)

    def test_provider_target_limit_enforced(self):
        request = self.request("sep.basic.v1.vocals_drums_bass_other")
        caps = ProviderCapabilities(
            provider_key="test-limit",
            role_model_map={r: r for r in request.canonical_roles},
            quality_mode_map={"standard": None},
            supports_custom_selection=False,
            max_targets=3,
        )
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROVIDER_TARGET_LIMIT_EXCEEDED"):
            negotiate_provider(request, caps, registry=self.registry)

    def test_provider_incompatible_combination_enforced(self):
        request = self.request("sep.basic.v1.vocals_drums_bass_other")
        caps = ProviderCapabilities(
            provider_key="test-incompatible",
            role_model_map={r: r for r in request.canonical_roles},
            quality_mode_map={"standard": None},
            supports_custom_selection=False,
            incompatible_role_sets=(frozenset({"vocals", "other"}),),
        )
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROVIDER_ROLE_COMBINATION_UNSUPPORTED"):
            negotiate_provider(request, caps, registry=self.registry)

    def test_output_completeness_requires_exact_set(self):
        request = self.request("sep.basic.v1.vocals_drums_bass_other")
        self.assertEqual(
            validate_output_completeness(request, ("other", "bass", "vocals", "drums")),
            request.canonical_roles,
        )
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_OUTPUT_SET_INCOMPLETE"):
            validate_output_completeness(request, ("vocals", "drums", "bass"))
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_OUTPUT_SET_INCOMPLETE"):
            validate_output_completeness(request, ("vocals", "drums", "bass", "other", "guitar"))

    def test_duplicate_output_role_rejected_before_set_comparison(self):
        request = self.request("sep.basic.v1.vocals_instrumental")
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_OUTPUT_ROLE_DUPLICATE"):
            validate_output_completeness(request, ("vocals", "vocals"))

    def test_unknown_profile_fails_closed(self):
        with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_UNKNOWN"):
            self.request("sep.unknown.v1")

    def test_corrupt_registry_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry.json"
            path.write_text("{bad", encoding="utf-8")
            with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_REGISTRY_UNREADABLE"):
                load_registry(path)

    def test_registry_rejects_duplicate_profile_id(self):
        raw = json.loads(self.registry_path.read_text())
        raw["profiles"].append(copy.deepcopy(raw["profiles"][0]))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry.json"
            path.write_text(json.dumps(raw), encoding="utf-8")
            with self.assertRaisesRegex(ProfileRegistryError, "SEP_PROFILE_DUPLICATE_ID"):
                load_registry(path)


if __name__ == "__main__":
    unittest.main()
