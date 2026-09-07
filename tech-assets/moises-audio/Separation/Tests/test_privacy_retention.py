import json
import tempfile
import unittest
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from privacy_retention import (
    AUDIOSHAKE_ASSET_TTL_SECONDS,
    AUDIOSHAKE_OUTPUT_LINK_TTL_SECONDS,
    PrivacyRetentionError,
    PrivacyRetentionService,
    RetentionPolicy,
    audioshake_documented_policy,
)


class FakeProvider:
    def __init__(self):
        self.asset_receipt = "confirmed"
        self.task_receipt = "confirmed"
        self.asset_calls = 0
        self.task_calls = 0
        self.raise_asset = False
        self.raise_task = False

    def delete_asset(self, object_id):
        self.asset_calls += 1
        if self.raise_asset:
            raise RuntimeError("asset timeout")
        return self.asset_receipt

    def delete_task(self, object_id):
        self.task_calls += 1
        if self.raise_task:
            raise RuntimeError("task timeout")
        return self.task_receipt


class NoDeleteProvider:
    pass


class PrivacyRetentionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.artifacts = self.root / "artifacts"
        self.registry = self.root / "privacy" / "registry.json"
        self.provider = FakeProvider()
        self.now = {"value": 1_700_000_000}
        self.service = PrivacyRetentionService(
            artifact_root=self.artifacts,
            registry_path=self.registry,
            provider=self.provider,
            now_epoch=lambda: self.now["value"],
        )
        self.job = "a" * 32
        self.asset_id = "asset-123"
        self.task_id = "task-456"

    def tearDown(self):
        self.tmp.cleanup()

    def register(self, policy=None):
        return self.service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=policy or audioshake_documented_policy(),
            created_at_epoch=self.now["value"],
        )

    def make_artifact(self):
        directory = self.artifacts / self.job
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "vocals.wav").write_bytes(b"audio")
        return directory

    def test_audioshake_documented_ttls_are_72h_and_1h(self):
        record = self.register()
        self.assertEqual(record.vendor_asset_expires_at_epoch - record.created_at_epoch, AUDIOSHAKE_ASSET_TTL_SECONDS)
        self.assertEqual(record.vendor_output_links_expire_at_epoch - record.created_at_epoch, AUDIOSHAKE_OUTPUT_LINK_TTL_SECONDS)

    def test_registry_never_stores_raw_provider_ids_or_content_paths(self):
        self.register()
        text = self.registry.read_text()
        self.assertNotIn(self.asset_id, text)
        self.assertNotIn(self.task_id, text)
        self.assertNotIn("song.wav", text)
        self.assertNotIn("http://", text)
        self.assertNotIn("https://", text)

    def test_same_registration_is_idempotent(self):
        first = self.register()
        second = self.register()
        self.assertEqual(first.logical_job_id, second.logical_job_id)

    def test_conflicting_registration_fails_closed(self):
        self.register()
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_REGISTRATION_CONFLICT"):
            self.service.register(
                logical_job_id=self.job,
                provider_asset_id="asset-other",
                provider_task_id=self.task_id,
                policy=audioshake_documented_policy(),
                created_at_epoch=self.now["value"],
            )

    def test_local_delete_is_confirmed_only_after_directory_is_absent(self):
        directory = self.make_artifact()
        self.register()
        record = self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        self.assertFalse(directory.exists())
        self.assertTrue(record.local_delete_confirmed)

    def test_delete_intent_is_persisted_before_provider_contact(self):
        self.make_artifact()
        self.register()

        class InspectingProvider(FakeProvider):
            def delete_asset(inner, object_id):
                raw = json.loads(self.registry.read_text())
                self.assertTrue(raw["records"][self.job]["local_delete_requested"])
                return super(InspectingProvider, inner).delete_asset(object_id)

        self.service.provider = InspectingProvider()
        self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)

    def test_provider_confirmed_deletion_requires_both_objects(self):
        self.register()
        record = self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        snapshot = self.service.snapshot(self.job)
        self.assertEqual(record.provider_asset_delete_state, "confirmed")
        self.assertEqual(record.provider_task_delete_state, "confirmed")
        self.assertTrue(snapshot["overallPrivacyDeletionComplete"])

    def test_provider_accepted_is_not_claimed_confirmed(self):
        self.provider.asset_receipt = "accepted"
        self.provider.task_receipt = "accepted"
        self.register()
        self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        snapshot = self.service.snapshot(self.job)
        self.assertFalse(snapshot["providerErasureComplete"])
        self.assertFalse(snapshot["overallPrivacyDeletionComplete"])

    def test_provider_without_delete_capability_is_truthfully_incomplete(self):
        service = PrivacyRetentionService(
            artifact_root=self.artifacts,
            registry_path=self.registry,
            provider=NoDeleteProvider(),
            now_epoch=lambda: self.now["value"],
        )
        service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=audioshake_documented_policy(),
            created_at_epoch=self.now["value"],
        )
        record = service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        self.assertEqual(record.provider_asset_delete_state, "unsupported_expiry_only")
        self.assertEqual(record.provider_task_delete_state, "unsupported_unknown_retention")
        self.assertFalse(service.snapshot(self.job)["overallPrivacyDeletionComplete"])

    def test_provider_error_never_becomes_confirmed(self):
        self.provider.raise_asset = True
        self.register()
        record = self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        self.assertEqual(record.provider_asset_delete_state, "unknown_after_error")
        self.assertFalse(self.service.snapshot(self.job)["overallPrivacyDeletionComplete"])

    def test_repeated_delete_is_idempotent_for_provider_calls(self):
        self.register()
        self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        self.assertEqual(self.provider.asset_calls, 1)
        self.assertEqual(self.provider.task_calls, 1)

    def test_wrong_provider_identifier_does_not_delete(self):
        self.register()
        record = self.service.request_delete(self.job, provider_asset_id="asset-wrong", provider_task_id=self.task_id)
        self.assertEqual(record.provider_asset_delete_state, "identifier_unavailable")
        self.assertEqual(self.provider.asset_calls, 0)

    def test_asset_expiry_is_visible_without_claiming_task_erasure(self):
        service = PrivacyRetentionService(
            artifact_root=self.artifacts,
            registry_path=self.registry,
            provider=NoDeleteProvider(),
            now_epoch=lambda: self.now["value"],
        )
        service.register(
            logical_job_id=self.job,
            provider_asset_id=self.asset_id,
            provider_task_id=self.task_id,
            policy=audioshake_documented_policy(),
            created_at_epoch=self.now["value"],
        )
        self.now["value"] += AUDIOSHAKE_ASSET_TTL_SECONDS + 1
        snapshot = service.snapshot(self.job)
        self.assertTrue(snapshot["vendorAssetExpiredByDocumentedTTL"])
        self.assertEqual(snapshot["providerAssetDeleteState"], "expired")
        self.assertFalse(snapshot["providerErasureComplete"])

    def test_output_link_expiry_is_visible_after_one_hour(self):
        self.register()
        self.now["value"] += AUDIOSHAKE_OUTPUT_LINK_TTL_SECONDS + 1
        self.assertTrue(self.service.snapshot(self.job)["vendorOutputLinksExpiredByDocumentedTTL"])

    def test_diagnostic_allowlist_accepts_non_content_operational_fields(self):
        self.register()
        record = self.service.record_diagnostic(
            self.job,
            {
                "state": "SEPARATING",
                "stable_error_code": "SEP_OK",
                "fraction_complete": 0.5,
                "retryable": True,
                "elapsed_ms": 1200,
                "source_bytes": 12345,
                "cost_units": 1.25,
            },
        )
        self.assertEqual(len(record.diagnostics), 1)

    def test_diagnostic_rejects_url_or_path_keys(self):
        self.register()
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_DIAGNOSTIC_KEY_FORBIDDEN"):
            self.service.record_diagnostic(self.job, {"output_url": "https://secret.example/x"})
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_DIAGNOSTIC_KEY_FORBIDDEN"):
            self.service.record_diagnostic(self.job, {"source_path": "/private/song.wav"})

    def test_diagnostic_rejects_content_like_free_text(self):
        self.register()
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_DIAGNOSTIC_KEY_FORBIDDEN"):
            self.service.record_diagnostic(self.job, {"message": "user filename and metadata"})

    def test_diagnostic_string_value_cannot_smuggle_url(self):
        self.register()
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_DIAGNOSTIC_VALUE_INVALID"):
            self.service.record_diagnostic(self.job, {"state": "https://secret.example"})

    def test_explicit_local_expiry_sweep_deletes_only_job_directory(self):
        policy = RetentionPolicy(None, None, "explicit_expiry", 60)
        directory = self.make_artifact()
        sibling = self.artifacts / ("b" * 32)
        sibling.mkdir(parents=True)
        (sibling / "keep.wav").write_bytes(b"keep")
        self.register(policy=policy)
        self.now["value"] += 61
        deleted = self.service.sweep_expired()
        self.assertEqual(deleted, (self.job,))
        self.assertFalse(directory.exists())
        self.assertTrue(sibling.exists())

    def test_until_project_delete_policy_is_not_swept(self):
        directory = self.make_artifact()
        self.register()
        self.now["value"] += 10_000_000
        self.assertEqual(self.service.sweep_expired(), ())
        self.assertTrue(directory.exists())

    def test_registry_survives_restart(self):
        self.register()
        restarted = PrivacyRetentionService(
            artifact_root=self.artifacts,
            registry_path=self.registry,
            provider=self.provider,
            now_epoch=lambda: self.now["value"],
        )
        self.assertEqual(restarted.snapshot(self.job)["logicalJobID"], self.job)

    def test_corrupt_registry_fails_closed(self):
        self.registry.parent.mkdir(parents=True, exist_ok=True)
        self.registry.write_text("{bad json", encoding="utf-8")
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_REGISTRY_CORRUPT"):
            self.service.snapshot(self.job)

    def test_invalid_policy_combinations_fail_closed(self):
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_LOCAL_TTL_REQUIRED"):
            RetentionPolicy(None, None, "explicit_expiry", None).validate()
        with self.assertRaisesRegex(PrivacyRetentionError, "SEP_PRIVACY_LOCAL_TTL_UNEXPECTED"):
            RetentionPolicy(None, None, "manual_delete", 60).validate()

    def test_invalid_provider_receipt_is_unknown_not_confirmed(self):
        self.provider.asset_receipt = "deleted-ish"
        self.register()
        record = self.service.request_delete(self.job, provider_asset_id=self.asset_id, provider_task_id=self.task_id)
        self.assertEqual(record.provider_asset_delete_state, "unknown_invalid_receipt")
        self.assertFalse(self.service.snapshot(self.job)["overallPrivacyDeletionComplete"])

    def test_snapshot_is_sanitized_and_contains_no_provider_ids(self):
        self.register()
        snapshot = self.service.snapshot(self.job)
        text = json.dumps(snapshot, sort_keys=True)
        self.assertNotIn(self.asset_id, text)
        self.assertNotIn(self.task_id, text)
        self.assertNotIn("http", text)


if __name__ == "__main__":
    unittest.main()
