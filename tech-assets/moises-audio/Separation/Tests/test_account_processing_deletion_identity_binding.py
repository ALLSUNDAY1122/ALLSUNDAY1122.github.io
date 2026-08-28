import hashlib
import types
import unittest

from account_processing_deletion import AccountProcessingDeletionService

PROJECT = "12345678-1234-5678-9abc-def012345678"
LOGICAL = "d" * 32


def provider_hash(value):
    return None if value is None else hashlib.sha256(value.encode("utf-8")).hexdigest()


def durable_record(*, asset="asset-current", task="task-current"):
    return types.SimpleNamespace(
        logical_job_id=LOGICAL,
        project_id=PROJECT,
        provider_asset_id=asset,
        provider_task_id=task,
        state="bound",
        deletion_identity_binding_version=None,
        deleted_provider_asset_id_hash=None,
        deleted_provider_task_id_hash=None,
    )


class DurableRegistry:
    def __init__(self, record):
        self.record = record

    def list_records(self):
        return (self.record,)


class DurableService:
    def __init__(self, record):
        self.registry = DurableRegistry(record)
        self.marked = []

    def mark_deleted(
        self,
        logical_job_id,
        *,
        bind_provider_identity=False,
        provider_asset_id_hash=None,
        provider_task_id_hash=None,
    ):
        self.marked.append(logical_job_id)
        record = self.registry.record
        record.state = "deleted"
        record.provider_asset_id = None
        record.provider_task_id = None
        record.deletion_identity_binding_version = 1 if bind_provider_identity else None
        record.deleted_provider_asset_id_hash = (
            provider_asset_id_hash if bind_provider_identity else None
        )
        record.deleted_provider_task_id_hash = (
            provider_task_id_hash if bind_provider_identity else None
        )


class PrivacyRegistry:
    def __init__(self, record):
        self.record = record

    def get(self, logical_job_id):
        return self.record if logical_job_id == LOGICAL else None


class PreexistingPrivacyService:
    """Models a retry where provider deletion was already reserved/completed earlier."""

    def __init__(self, record):
        self.registry = PrivacyRegistry(record)
        self.calls = []

    def request_delete(self, logical_job_id, **kwargs):
        self.calls.append((logical_job_id, kwargs))
        return self.registry.get(logical_job_id)


def privacy_record(*, asset_hash, task_hash, asset_state="confirmed", task_state="confirmed"):
    return types.SimpleNamespace(
        local_delete_confirmed=True,
        provider_asset_id_hash=asset_hash,
        provider_task_id_hash=task_hash,
        provider_asset_delete_state=asset_state,
        provider_task_delete_state=task_state,
    )


class AccountProcessingDeletionIdentityBindingTests(unittest.TestCase):
    def test_terminal_privacy_state_with_stale_provider_identity_fails_before_tombstone(self):
        durable = DurableService(durable_record())
        privacy = PreexistingPrivacyService(
            privacy_record(
                asset_hash=provider_hash("asset-stale"),
                task_hash=provider_hash("task-stale"),
            )
        )

        result = AccountProcessingDeletionService(
            privacy_retention=privacy,
            durable_reconnect=durable,
        ).delete_project(PROJECT)

        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(result["completedJobCount"], 0)
        self.assertEqual(result["incompleteJobCount"], 1)
        self.assertEqual(
            result["jobs"][0]["stableErrorCode"],
            "SEP_ACCOUNT_DELETE_PROVIDER_IDENTITY_MISMATCH",
        )
        self.assertEqual(durable.marked, [])

    def test_terminal_privacy_state_bound_to_current_provider_identity_allows_tombstone(self):
        asset = "asset-current"
        task = "task-current"
        durable = DurableService(durable_record(asset=asset, task=task))
        privacy = PreexistingPrivacyService(
            privacy_record(
                asset_hash=provider_hash(asset),
                task_hash=provider_hash(task),
                asset_state="not_found",
                task_state="confirmed",
            )
        )

        result = AccountProcessingDeletionService(
            privacy_retention=privacy,
            durable_reconnect=durable,
        ).delete_project(PROJECT)

        self.assertEqual(result["state"], "COMPLETE")
        self.assertEqual(durable.marked, [LOGICAL])
        record = durable.registry.record
        self.assertEqual(record.deletion_identity_binding_version, 1)
        self.assertEqual(record.deleted_provider_asset_id_hash, provider_hash(asset))
        self.assertEqual(record.deleted_provider_task_id_hash, provider_hash(task))
        self.assertIsNone(record.provider_asset_id)
        self.assertIsNone(record.provider_task_id)

    def test_absent_provider_identity_requires_not_applicable_state(self):
        durable = DurableService(durable_record(asset=None, task=None))
        privacy = PreexistingPrivacyService(
            privacy_record(
                asset_hash=None,
                task_hash=None,
                asset_state="not_requested",
                task_state="not_requested",
            )
        )

        result = AccountProcessingDeletionService(
            privacy_retention=privacy,
            durable_reconnect=durable,
        ).delete_project(PROJECT)

        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(
            result["jobs"][0]["stableErrorCode"],
            "SEP_ACCOUNT_DELETE_PROVIDER_ERASURE_INCOMPLETE",
        )
        self.assertEqual(durable.marked, [])

    def test_malformed_privacy_identity_hash_fails_closed(self):
        durable = DurableService(durable_record())
        privacy = PreexistingPrivacyService(
            privacy_record(asset_hash="not-a-sha256", task_hash=provider_hash("task-current"))
        )

        result = AccountProcessingDeletionService(
            privacy_retention=privacy,
            durable_reconnect=durable,
        ).delete_project(PROJECT)

        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(
            result["jobs"][0]["stableErrorCode"],
            "SEP_ACCOUNT_DELETE_PROVIDER_IDENTITY_MISMATCH",
        )
        self.assertEqual(durable.marked, [])


if __name__ == "__main__":
    unittest.main()
