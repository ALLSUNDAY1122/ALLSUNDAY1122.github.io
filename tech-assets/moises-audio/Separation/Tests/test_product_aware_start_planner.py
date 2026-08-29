from __future__ import annotations

from pathlib import Path
import sys
import unittest

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from product_aware_start_planner import (
    ProductAwareStartPlanner,
    ProductAwareStartPlannerError,
)
from reference_profiles import ProviderCapabilities, audioshake_core_capabilities


class ProductAwareStartPlannerTests(unittest.TestCase):
    def test_free_two_stem_request_resolves_reference_profile_and_provider_models(self):
        planner = ProductAwareStartPlanner(capabilities=audioshake_core_capabilities())

        plan = planner.plan(
            canonical_roles=("instrumental", "vocals"),
            quality_profile="standard",
            account_tier="free",
        )

        self.assertEqual(plan.profile_id, "sep.basic.v1.vocals_instrumental")
        self.assertEqual(plan.canonical_roles, ("instrumental", "vocals"))
        self.assertEqual(plan.quality_mode, "standard")
        self.assertEqual(plan.provider_models, ("vocals", "instrumental"))
        self.assertEqual(plan.provider_key, "audioshake-core-current-adapter")

    def test_free_four_stem_request_resolves_exact_fixed_profile(self):
        planner = ProductAwareStartPlanner(capabilities=audioshake_core_capabilities())

        plan = planner.plan(
            canonical_roles=("bass", "drums", "other", "vocals"),
            quality_profile="standard",
            account_tier="free",
        )

        self.assertEqual(plan.profile_id, "sep.basic.v1.vocals_drums_bass_other")
        self.assertEqual(plan.provider_models, ("vocals", "drums", "bass", "other"))

    def test_unknown_reference_role_set_fails_before_provider_planning(self):
        planner = ProductAwareStartPlanner(capabilities=audioshake_core_capabilities())

        with self.assertRaises(ProductAwareStartPlannerError) as caught:
            planner.plan(
                canonical_roles=("drums", "vocals"),
                quality_profile="standard",
                account_tier="free",
            )

        self.assertEqual(caught.exception.code, "SEP_START_PROFILE_UNRESOLVED")

    def test_custom_reference_request_requires_trusted_entitlement(self):
        planner = ProductAwareStartPlanner(capabilities=audioshake_core_capabilities())

        with self.assertRaises(ProductAwareStartPlannerError) as caught:
            planner.plan(
                canonical_roles=("bass", "guitar", "vocals"),
                quality_profile="standard",
                account_tier="free",
            )

        self.assertEqual(caught.exception.code, "SEP_PROFILE_ENTITLEMENT_REQUIRED")

    def test_current_provider_capability_rejects_unimplemented_custom_selection(self):
        planner = ProductAwareStartPlanner(capabilities=audioshake_core_capabilities())

        with self.assertRaises(ProductAwareStartPlannerError) as caught:
            planner.plan(
                canonical_roles=("bass", "guitar", "vocals"),
                quality_profile="standard",
                account_tier="premium",
            )

        self.assertEqual(caught.exception.code, "SEP_PROVIDER_CUSTOM_SELECTION_UNSUPPORTED")

    def test_non_default_provider_quality_token_is_not_silently_dropped(self):
        planner = ProductAwareStartPlanner(
            capabilities=ProviderCapabilities(
                provider_key="test-provider",
                role_model_map={"vocals": "vocals", "guitar": "guitar", "bass": "bass"},
                quality_mode_map={"standard": None, "hifi": "provider-hifi"},
                supports_custom_selection=True,
                max_targets=3,
            )
        )

        with self.assertRaises(ProductAwareStartPlannerError) as caught:
            planner.plan(
                canonical_roles=("bass", "guitar", "vocals"),
                quality_profile="hifi",
                account_tier="pro",
            )

        self.assertEqual(caught.exception.code, "SEP_PRODUCTION_QUALITY_TRANSPORT_UNSUPPORTED")

    def test_roles_must_remain_transport_canonical(self):
        planner = ProductAwareStartPlanner(capabilities=audioshake_core_capabilities())

        for roles in (
            ("vocals", "instrumental"),
            ("instrumental", "instrumental"),
            ("Instrumental", "vocals"),
            (),
            "instrumental,vocals",
        ):
            with self.subTest(roles=roles):
                with self.assertRaises(ProductAwareStartPlannerError):
                    planner.plan(
                        canonical_roles=roles,
                        quality_profile="standard",
                        account_tier="free",
                    )

    def test_reference_quality_policy_is_enforced_before_provider_start(self):
        planner = ProductAwareStartPlanner(capabilities=audioshake_core_capabilities())

        with self.assertRaises(ProductAwareStartPlannerError) as caught:
            planner.plan(
                canonical_roles=("instrumental", "vocals"),
                quality_profile="hifi",
                account_tier="pro",
            )

        self.assertEqual(caught.exception.code, "SEP_PROFILE_QUALITY_UNSUPPORTED_BY_REFERENCE")


if __name__ == "__main__":
    unittest.main()
