from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

SERVER = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER))

from advanced_capabilities import (
    AdvancedCapabilityError,
    AdvancedRole,
    AdvancedRoleCatalog,
    parse_audioshake_models,
)
from audioshake_task_contract import (
    AUDIOSHAKE_TASK_MAX_TARGETS,
    build_contract_bound_audioshake_capabilities,
    effective_audioshake_max_targets,
)
from budgeted_production_orchestrator import BudgetedProductionSeparationOrchestrator
from canonical_advanced_provider import CanonicalAdvancedAudioShakeAdapter
from production_orchestrator import OrchestratorError


def synthetic_catalog(count: int) -> AdvancedRoleCatalog:
    roles = {
        f"role{index}": AdvancedRole(
            canonical_role=f"role{index}",
            reference_state="UNVERIFIED_CURRENT_IPHONE",
            audioshake_model=f"model{index}",
            family="synthetic",
            notes="A44 contract-bound regression role.",
        )
        for index in range(count)
    }
    return AdvancedRoleCatalog(
        schema_version=1,
        captured_at="2026-08-27",
        parity_state="NON_PARITY_EVIDENCE_ONLY",
        roles=roles,
        incompatible_role_sets=(),
        unknowns=(),
    )


def model_payload(count: int):
    return {
        "models": [
            {
                "id": f"model{index}",
                "category": "instrumentStemSeparation",
                "access": "enabled",
                "outputFormats": ["wav"],
                "creditsPerMinute": 1,
            }
            for index in range(count)
        ]
    }


class FakeClient:
    def __init__(self, count: int):
        self.payload = model_payload(count)
        self.requests = []
        self.upload_calls = 0

    def _json_request(self, method, path, body=None):
        self.requests.append((method, path, body))
        if path == "/models":
            return self.payload
        if path == "/tasks":
            return {"id": "task-a44"}
        raise AssertionError(path)

    def upload_asset(self, source_path):
        self.upload_calls += 1
        return "asset-a44"

    def get_task_state(self, task_id):
        raise AssertionError("not used")

    def find_tasks_by_metadata(self, metadata):
        return ()


class A44AudioShakeTaskContractTests(unittest.TestCase):
    def test_documented_task_cap_is_twenty(self):
        self.assertEqual(AUDIOSHAKE_TASK_MAX_TARGETS, 20)
        self.assertEqual(effective_audioshake_max_targets(), 20)

    def test_deployment_policy_may_narrow_provider_cap(self):
        self.assertEqual(effective_audioshake_max_targets(8), 8)

    def test_deployment_policy_cannot_widen_provider_cap(self):
        self.assertEqual(effective_audioshake_max_targets(40), 20)

    def test_invalid_configured_cap_fails_closed(self):
        for value in (0, -1, True):
            with self.subTest(value=value):
                with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_MAX_TARGETS_INVALID"):
                    effective_audioshake_max_targets(value)

    def test_contract_bound_capability_always_exposes_twenty_without_override(self):
        catalog = synthetic_catalog(1)
        snapshot = parse_audioshake_models(model_payload(1))
        caps = build_contract_bound_audioshake_capabilities(snapshot, catalog=catalog)
        self.assertEqual(caps.max_targets, 20)

    def test_exactly_twenty_canonical_targets_pass_preflight(self):
        catalog = synthetic_catalog(20)
        client = FakeClient(20)
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=catalog)
        roles = tuple(catalog.roles)
        self.assertEqual(adapter.preflight_separation(roles), roles)
        self.assertEqual([path for _, path, _ in client.requests], ["/models"])
        self.assertEqual(client.upload_calls, 0)

    def test_twenty_one_targets_fail_before_discovery_upload_or_post(self):
        catalog = synthetic_catalog(21)
        client = FakeClient(21)
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_TARGET_LIMIT_EXCEEDED"):
            adapter.preflight_separation(tuple(catalog.roles))
        self.assertEqual(client.requests, [])
        self.assertEqual(client.upload_calls, 0)

    def test_create_task_rechecks_contract_before_post(self):
        catalog = synthetic_catalog(21)
        client = FakeClient(21)
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_TARGET_LIMIT_EXCEEDED"):
            adapter.create_separation_task("asset-a44", tuple(catalog.roles))
        self.assertFalse(any(path == "/tasks" for _, path, _ in client.requests))
        self.assertEqual(client.upload_calls, 0)

    def test_disabled_model_fails_media_free_preflight(self):
        catalog = synthetic_catalog(1)
        client = FakeClient(1)
        client.payload["models"][0]["access"] = "request_access"
        adapter = CanonicalAdvancedAudioShakeAdapter(client, catalog=catalog)
        with self.assertRaisesRegex(AdvancedCapabilityError, "SEP_ADV_NO_ENABLED_INSTRUMENT_MODELS"):
            adapter.preflight_separation(("role0",))
        self.assertEqual(client.upload_calls, 0)
        self.assertFalse(any(path == "/tasks" for _, path, _ in client.requests))

    def test_budgeted_entrypoint_runs_provider_preflight_before_source_io_and_cost(self):
        class RejectingProvider:
            def __init__(self):
                self.preflight_calls = 0
                self.upload_calls = 0

            def preflight_separation(self, models):
                self.preflight_calls += 1
                raise AdvancedCapabilityError("SEP_ADV_TARGET_LIMIT_EXCEEDED")

            def upload_asset(self, source_path):
                self.upload_calls += 1
                raise AssertionError("upload must not run")

        class CostGuardMustNotRun:
            def __getattr__(self, name):
                raise AssertionError(f"cost guard must not run: {name}")

        provider = RejectingProvider()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            orchestrator = BudgetedProductionSeparationOrchestrator(
                provider=provider,
                cost_guard=CostGuardMustNotRun(),
                source_root=root / "sources",
                artifact_root=root / "artifacts",
                registry_path=root / "state" / "jobs.json",
                duration_resolver=lambda _: (_ for _ in ()).throw(AssertionError("duration must not run")),
            )
            # Deliberately missing source: A44 provider preflight must win before containment/stat/hash.
            with self.assertRaises(OrchestratorError) as caught:
                orchestrator.start(
                    source_path=root / "sources" / "missing.wav",
                    project_id="project-a44",
                    asset_id="asset-a44",
                    models=("role0",),
                    idempotency_key="a44-preflight-order",
                )
        self.assertEqual(caught.exception.code, "SEP_ADV_TARGET_LIMIT_EXCEEDED")
        self.assertFalse(caught.exception.retryable)
        self.assertEqual(provider.preflight_calls, 1)
        self.assertEqual(provider.upload_calls, 0)


if __name__ == "__main__":
    unittest.main()
