import hashlib
import json
import types
import unittest

from account_processing_deletion import (
    AccountProcessingDeletionError,
    AccountProcessingDeletionService,
)

PROJECT = "12345678-1234-5678-9abc-def012345678"
OTHER = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"


def provider_hash(value):
    return None if value is None else hashlib.sha256(value.encode("utf-8")).hexdigest()


def job(
    hex_id,
    project_id=PROJECT,
    asset="asset-1",
    task="task-1",
    state="bound",
    proof_version=None,
    proof_asset_hash=None,
    proof_task_hash=None,
):
    return types.SimpleNamespace(
        logical_job_id=hex_id,
        project_id=project_id,
        provider_asset_id=asset,
        provider_task_id=task,
        state=state,
        deletion_identity_binding_version=proof_version,
        deleted_provider_asset_id_hash=proof_asset_hash,
        deleted_provider_task_id_hash=proof_task_hash,
    )


class DurableRegistry:
    def __init__(self, records):
        self.records = list(records)

    def list_records(self):
        return tuple(self.records)


class DurableService:
    def __init__(self, records):
        self.registry = DurableRegistry(records)
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
        for record in self.registry.records:
            if record.logical_job_id == logical_job_id:
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
                return
        raise RuntimeError("missing")


class PrivacyRegistry:
    def __init__(self):
        self.records = {}

    def get(self, logical_job_id):
        return self.records.get(logical_job_id)


class PrivacyService:
    def __init__(self, states=None, failures=None):
        self.registry = PrivacyRegistry()
        self.states = states or {}
        self.failures = failures or set()
        self.calls = []

    def request_delete(self, logical_job_id, **kwargs):
        self.calls.append((logical_job_id, kwargs))
        if logical_job_id in self.failures:
            raise RuntimeError("provider transport secret details")
        asset_state, task_state = self.states.get(logical_job_id, ("confirmed", "confirmed"))
        asset_id = kwargs.get("provider_asset_id")
        task_id = kwargs.get("provider_task_id")
        self.registry.records[logical_job_id] = types.SimpleNamespace(
            local_delete_confirmed=True,
            provider_asset_id_hash=provider_hash(asset_id),
            provider_task_id_hash=provider_hash(task_id),
            provider_asset_delete_state=asset_state if asset_id is not None else "not_applicable",
            provider_task_delete_state=task_state if task_id is not None else "not_applicable",
        )


class Reconciler:
    def __init__(self, privacy):
        self.privacy = privacy
        self.calls = []

    def resume_pending(self, logical_job_id):
        self.calls.append(logical_job_id)
        record = self.privacy.registry.records[logical_job_id]
        record.provider_asset_delete_state = "not_found"
        record.provider_task_delete_state = "confirmed"
        return {"state": "PASS"}


class AccountProcessingDeletionServiceTests(unittest.TestCase):
    def test_exact_project_filters_and_deletes_all_matching_jobs(self):
        j1 = job("1" * 32)
        j2 = job("2" * 32, project_id=PROJECT.upper(), asset="asset-2", task="task-2")
        other = job("3" * 32, project_id=OTHER)
        durable = DurableService([j1, j2, other])
        privacy = PrivacyService()
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT.upper())
        self.assertEqual(result["state"], "COMPLETE")
        self.assertEqual(result["matchedJobCount"], 2)
        self.assertEqual(result["completedJobCount"], 2)
        self.assertEqual(durable.marked, ["1" * 32, "2" * 32])
        self.assertEqual([call[0] for call in privacy.calls], ["1" * 32, "2" * 32])
        self.assertTrue(all(call[1]["reason"] == "account_delete" for call in privacy.calls))
        self.assertEqual(j1.deletion_identity_binding_version, 1)
        self.assertEqual(j1.deleted_provider_asset_id_hash, provider_hash("asset-1"))
        self.assertEqual(j1.deleted_provider_task_id_hash, provider_hash("task-1"))

    def test_unsupported_provider_erasure_keeps_durable_identity_for_reconciliation(self):
        logical = "4" * 32
        record = job(logical, asset="asset-private", task="task-private")
        durable = DurableService([record])
        privacy = PrivacyService(
            states={logical: ("unsupported_expiry_only", "unsupported_unknown_retention")}
        )
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(result["incompleteJobCount"], 1)
        self.assertEqual(durable.marked, [])
        self.assertEqual(record.provider_asset_id, "asset-private")
        self.assertEqual(record.provider_task_id, "task-private")
        self.assertEqual(
            result["jobs"][0]["stableErrorCode"],
            "SEP_ACCOUNT_DELETE_PROVIDER_ERASURE_INCOMPLETE",
        )

    def test_jobs_that_never_created_provider_objects_complete_after_local_delete(self):
        logical = "5" * 32
        record = job(logical, asset=None, task=None)
        durable = DurableService([record])
        privacy = PrivacyService()
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "COMPLETE")
        self.assertEqual(durable.marked, [logical])
        self.assertEqual(result["jobs"][0]["providerAssetState"], "not_applicable")
        self.assertEqual(result["jobs"][0]["providerTaskState"], "not_applicable")
        self.assertEqual(record.deletion_identity_binding_version, 1)
        self.assertIsNone(record.deleted_provider_asset_id_hash)
        self.assertIsNone(record.deleted_provider_task_id_hash)

    def test_one_job_failure_does_not_suppress_other_project_job_delete(self):
        bad = "6" * 32
        good = "7" * 32
        durable = DurableService([job(bad), job(good, asset="asset-7", task="task-7")])
        privacy = PrivacyService(failures={bad})
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(result["completedJobCount"], 1)
        self.assertEqual(result["incompleteJobCount"], 1)
        self.assertEqual([call[0] for call in privacy.calls], [bad, good])
        self.assertEqual(durable.marked, [good])

    def test_pending_authoritative_reconciliation_is_applied_before_completion_decision(self):
        logical = "8" * 32
        durable = DurableService([job(logical)])
        privacy = PrivacyService(states={logical: ("unknown_after_error", "unknown_after_error")})
        reconciler = Reconciler(privacy)
        result = AccountProcessingDeletionService(
            privacy_retention=privacy,
            durable_reconnect=durable,
            provider_reconciler=reconciler,
        ).delete_project(PROJECT)
        self.assertEqual(reconciler.calls, [logical])
        self.assertEqual(result["state"], "COMPLETE")
        self.assertEqual(durable.marked, [logical])

    def test_public_result_never_emits_project_job_or_provider_identifiers(self):
        logical = "9" * 32
        record = job(logical, asset="asset-SENSITIVE", task="task-SENSITIVE")
        durable = DurableService([record])
        privacy = PrivacyService()
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        encoded = json.dumps(result, sort_keys=True)
        self.assertNotIn(PROJECT, encoded)
        self.assertNotIn(logical, encoded)
        self.assertNotIn("asset-SENSITIVE", encoded)
        self.assertNotIn("task-SENSITIVE", encoded)
        self.assertEqual(len(result["projectRefHash"]), 64)
        self.assertEqual(len(result["jobs"][0]["jobRefHash"]), 64)
        self.assertEqual(result["parityClaim"], "NONE")

    def test_invalid_project_identity_fails_before_side_effects(self):
        durable = DurableService([job("a" * 32)])
        privacy = PrivacyService()
        service = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        )
        with self.assertRaises(AccountProcessingDeletionError) as caught:
            service.delete_project("not-a-project-uuid")
        self.assertEqual(caught.exception.code, "SEP_ACCOUNT_DELETE_PROJECT_ID_INVALID")
        self.assertEqual(privacy.calls, [])
        self.assertEqual(durable.marked, [])

    def test_existing_durable_tombstone_without_privacy_evidence_fails_closed(self):
        logical = "b" * 32
        durable = DurableService([job(logical, asset=None, task=None, state="deleted")])
        privacy = PrivacyService()
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(privacy.calls, [])
        self.assertEqual(
            result["jobs"][0]["stableErrorCode"],
            "SEP_ACCOUNT_DELETE_TOMBSTONE_PRIVACY_UNVERIFIED",
        )

    def test_legacy_tombstone_with_terminal_privacy_evidence_still_fails_without_identity_proof(self):
        logical = "c" * 32
        durable = DurableService([job(logical, asset=None, task=None, state="deleted")])
        privacy = PrivacyService()
        privacy.registry.records[logical] = types.SimpleNamespace(
            local_delete_confirmed=True,
            provider_asset_id_hash=provider_hash("asset-before-delete"),
            provider_task_id_hash=provider_hash("task-before-delete"),
            provider_asset_delete_state="not_found",
            provider_task_delete_state="confirmed",
        )
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(
            result["jobs"][0]["stableErrorCode"],
            "SEP_ACCOUNT_DELETE_TOMBSTONE_IDENTITY_PROOF_MISSING",
        )

    def test_existing_bound_tombstone_reverifies_matching_provider_proof(self):
        logical = "d" * 32
        asset_hash = provider_hash("asset-before-delete")
        task_hash = provider_hash("task-before-delete")
        durable = DurableService([
            job(
                logical,
                asset=None,
                task=None,
                state="deleted",
                proof_version=1,
                proof_asset_hash=asset_hash,
                proof_task_hash=task_hash,
            )
        ])
        privacy = PrivacyService()
        privacy.registry.records[logical] = types.SimpleNamespace(
            local_delete_confirmed=True,
            provider_asset_id_hash=asset_hash,
            provider_task_id_hash=task_hash,
            provider_asset_delete_state="not_found",
            provider_task_delete_state="confirmed",
        )
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "COMPLETE")
        self.assertTrue(result["jobs"][0]["durableTombstoned"])
        self.assertIsNone(result["jobs"][0]["stableErrorCode"])

    def test_existing_tombstone_provider_proof_mismatch_fails_closed(self):
        logical = "e" * 32
        durable = DurableService([
            job(
                logical,
                asset=None,
                task=None,
                state="deleted",
                proof_version=1,
                proof_asset_hash=provider_hash("asset-original"),
                proof_task_hash=provider_hash("task-original"),
            )
        ])
        privacy = PrivacyService()
        privacy.registry.records[logical] = types.SimpleNamespace(
            local_delete_confirmed=True,
            provider_asset_id_hash=provider_hash("asset-other"),
            provider_task_id_hash=provider_hash("task-original"),
            provider_asset_delete_state="confirmed",
            provider_task_delete_state="confirmed",
        )
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "INCOMPLETE")
        self.assertEqual(
            result["jobs"][0]["stableErrorCode"],
            "SEP_ACCOUNT_DELETE_TOMBSTONE_PROVIDER_IDENTITY_MISMATCH",
        )

    def test_bound_tombstone_without_provider_objects_requires_explicit_not_applicable(self):
        logical = "f" * 32
        durable = DurableService([
            job(
                logical,
                asset=None,
                task=None,
                state="deleted",
                proof_version=1,
                proof_asset_hash=None,
                proof_task_hash=None,
            )
        ])
        privacy = PrivacyService()
        privacy.registry.records[logical] = types.SimpleNamespace(
            local_delete_confirmed=True,
            provider_asset_id_hash=None,
            provider_task_id_hash=None,
            provider_asset_delete_state="not_applicable",
            provider_task_delete_state="not_applicable",
        )
        result = AccountProcessingDeletionService(
            privacy_retention=privacy, durable_reconnect=durable
        ).delete_project(PROJECT)
        self.assertEqual(result["state"], "COMPLETE")
        self.assertIsNone(result["jobs"][0]["stableErrorCode"])


if __name__ == "__main__":
    unittest.main()
