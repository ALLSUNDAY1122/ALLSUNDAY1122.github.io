from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from privacy_retention import PrivacyRetentionError
from product_aware_start_service import (
    ProductAwareProductionStartService,
    ProductAwareStartError,
)
from reference_profiles import ProfileRegistryError

PROJECT_A = "11111111-1111-4111-8111-111111111111"
ASSET_A = "22222222-2222-4222-8222-222222222222"
LOGICAL_A = "a" * 32


class RecordingDurableReconnect:
    def __init__(self, *, job=None, begin_error=None, start_error=None):
        self.job = job or SimpleNamespace(
            logical_job_id=LOGICAL_A,
            provider_asset_id="asset-123",
            provider_task_id="task-456",
        )
        self.begin_error = begin_error
        self.start_error = start_error
        self.begin_calls = []
        self.start_calls = []

    def begin_intent(self, **kwargs):
        self.begin_calls.append(kwargs)
        if self.begin_error is not None:
            raise self.begin_error
        return SimpleNamespace(logical_job_id=LOGICAL_A)

    def start(self, **kwargs):
        self.start_calls.append(kwargs)
        if self.start_error is not None:
            raise self.start_error
        return self.job


class RecordingPrivacyRetention:
    def __init__(self, *, error=None):
        self.error = error
        self.calls = []

    def register(self, **kwargs):
        self.calls.append(kwargs)
        if self.error is not None:
            raise self.error
        return SimpleNamespace(
            provider_asset_id_hash="1" * 64,
            provider_task_id_hash="2" * 64,
        )


class StableFailure(RuntimeError):
    def __init__(self, code, *, retryable=False):
        super().__init__("detail must not escape")
        self.code = code
        self.retryable = retryable


class ProductAwareProductionStartServiceTests(unittest.TestCase):
    def make_service(self, *, durable=None, privacy=None, tier="free"):
        self.durable = durable or RecordingDurableReconnect()
        self.privacy = privacy or RecordingPrivacyRetention()
        self.tier_calls = []

        def resolve_tier(project_id):
            self.tier_calls.append(project_id)
            if isinstance(tier, Exception):
                raise tier
            return tier

        return ProductAwareProductionStartService(
            durable_reconnect=self.durable,
            privacy_retention=self.privacy,
            account_tier_resolver=resolve_tier,
        )

    def valid_start(self, service, **overrides):
        values = {
            "source_path": Path("/server-owned/upload.bin"),
            "project_id": PROJECT_A,
            "asset_id": ASSET_A,
            "canonical_roles": ("instrumental", "vocals"),
            "quality_profile": "standard",
            "idempotency_key": "idem-123",
        }
        values.update(overrides)
        return service.start(**values)

    def test_basic_reference_profile_composes_durable_start_and_privacy_registration(self):
        service = self.make_service()

        result = self.valid_start(service)

        expected_common = {
            "project_id": PROJECT_A,
            "asset_id": ASSET_A,
            "requested_profile_id": "sep.basic.v1.vocals_instrumental",
            "models": ("vocals", "instrumental"),
            "idempotency_key": "idem-123",
        }
        self.assertEqual(self.tier_calls, [PROJECT_A])
        self.assertEqual(self.durable.begin_calls, [expected_common])
        self.assertEqual(
            self.durable.start_calls,
            [{"source_path": Path("/server-owned/upload.bin"), **expected_common}],
        )
        self.assertEqual(len(self.privacy.calls), 1)
        self.assertEqual(self.privacy.calls[0]["logical_job_id"], LOGICAL_A)
        self.assertEqual(self.privacy.calls[0]["provider_asset_id"], "asset-123")
        self.assertEqual(self.privacy.calls[0]["provider_task_id"], "task-456")
        self.assertEqual(self.privacy.calls[0]["policy"].local_policy, "until_project_delete")
        self.assertEqual(
            result,
            {
                "logical_job_id": LOGICAL_A,
                "profile_id": "sep.basic.v1.vocals_instrumental",
                "canonical_roles": ["vocals", "instrumental"],
                "quality_mode": "standard",
                "evidence_state": "NON_PARITY_EVIDENCE_ONLY",
                "parity_claim": "NONE",
            },
        )
        self.assertNotIn("provider_asset_id", result)
        self.assertNotIn("provider_task_id", result)

    def test_four_stem_reference_profile_maps_exact_current_core_models(self):
        service = self.make_service()

        result = self.valid_start(
            service,
            canonical_roles=("bass", "drums", "other", "vocals"),
        )

        self.assertEqual(result["profile_id"], "sep.basic.v1.vocals_drums_bass_other")
        self.assertEqual(
            self.durable.start_calls[0]["models"],
            ("vocals", "drums", "bass", "other"),
        )

    def test_hifi_is_not_silently_downgraded_for_basic_profile(self):
        service = self.make_service()

        with self.assertRaises(ProfileRegistryError) as caught:
            self.valid_start(service, quality_profile="hifi")

        self.assertEqual(caught.exception.code, "SEP_PROFILE_QUALITY_UNSUPPORTED_BY_REFERENCE")
        self.assertEqual(self.durable.begin_calls, [])
        self.assertEqual(self.durable.start_calls, [])
        self.assertEqual(self.privacy.calls, [])

    def test_reference_custom_selection_fails_before_backend_when_current_provider_lacks_capability(self):
        service = self.make_service(tier="pro")

        with self.assertRaises(ProfileRegistryError) as caught:
            self.valid_start(
                service,
                canonical_roles=("guitar", "vocals"),
                quality_profile="standard",
            )

        self.assertEqual(caught.exception.code, "SEP_PROVIDER_CUSTOM_SELECTION_UNSUPPORTED")
        self.assertEqual(self.durable.begin_calls, [])
        self.assertEqual(self.durable.start_calls, [])
        self.assertEqual(self.privacy.calls, [])

    def test_roles_must_remain_sorted_unique_and_reference_resolvable(self):
        service = self.make_service()

        invalid = (
            ("vocals", "instrumental"),
            ("vocals", "vocals"),
            ("Vocals",),
            ("winds",),
        )
        expected_codes = (
            "SEP_START_ROLES_NONCANONICAL",
            "SEP_START_ROLES_NONCANONICAL",
            "SEP_START_ROLES_INVALID",
            "SEP_START_PROFILE_UNRESOLVED",
        )
        for roles, expected in zip(invalid, expected_codes):
            with self.subTest(roles=roles):
                with self.assertRaises(ProductAwareStartError) as caught:
                    self.valid_start(service, canonical_roles=roles)
                self.assertEqual(caught.exception.code, expected)

        self.assertEqual(self.durable.begin_calls, [])
        self.assertEqual(self.durable.start_calls, [])
        self.assertEqual(self.privacy.calls, [])

    def test_provider_identity_must_be_complete_before_privacy_registration_or_success(self):
        durable = RecordingDurableReconnect(
            job=SimpleNamespace(
                logical_job_id=LOGICAL_A,
                provider_asset_id="asset-123",
                provider_task_id=None,
            )
        )
        service = self.make_service(durable=durable)

        with self.assertRaises(ProductAwareStartError) as caught:
            self.valid_start(service)

        self.assertEqual(caught.exception.code, "SEP_START_PROVIDER_TASK_ID_INCOMPLETE")
        self.assertEqual(len(durable.start_calls), 1)
        self.assertEqual(self.privacy.calls, [])

    def test_privacy_registration_failure_blocks_success_after_durable_provider_identity(self):
        privacy = RecordingPrivacyRetention(
            error=PrivacyRetentionError("SEP_PRIVACY_REGISTRY_WRITE_FAILED", retryable=True)
        )
        service = self.make_service(privacy=privacy)

        with self.assertRaises(PrivacyRetentionError) as caught:
            self.valid_start(service)

        self.assertEqual(caught.exception.code, "SEP_PRIVACY_REGISTRY_WRITE_FAILED")
        self.assertTrue(caught.exception.retryable)
        self.assertEqual(len(self.durable.start_calls), 1)
        self.assertEqual(len(privacy.calls), 1)

    def test_backend_stable_error_is_preserved_without_privacy_success(self):
        durable = RecordingDurableReconnect(
            start_error=StableFailure("SEP_PROVIDER_START_AMBIGUOUS", retryable=False)
        )
        service = self.make_service(durable=durable)

        with self.assertRaises(ProductAwareStartError) as caught:
            self.valid_start(service)

        self.assertEqual(caught.exception.code, "SEP_PROVIDER_START_AMBIGUOUS")
        self.assertFalse(caught.exception.retryable)
        self.assertEqual(self.privacy.calls, [])

    def test_account_tier_authority_failure_is_sanitized_before_backend(self):
        service = self.make_service(tier=RuntimeError("secret account detail"))

        with self.assertRaises(ProductAwareStartError) as caught:
            self.valid_start(service)

        self.assertEqual(caught.exception.code, "SEP_START_ACCOUNT_TIER_UNAVAILABLE")
        self.assertTrue(caught.exception.retryable)
        self.assertNotIn("secret", str(caught.exception))
        self.assertEqual(self.durable.begin_calls, [])
        self.assertEqual(self.durable.start_calls, [])


if __name__ == "__main__":
    unittest.main()
