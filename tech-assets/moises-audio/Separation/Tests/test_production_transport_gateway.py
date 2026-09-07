from __future__ import annotations

import ast
import unittest
from dataclasses import dataclass
from pathlib import Path
import sys

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from production_transport_gateway import (
    DurableReconnectProjectResolver,
    ProductionTransportAuthorizationGateway,
    ProductionTransportGatewayError,
)


PROJECT_A = "11111111-1111-4111-8111-111111111111"
PROJECT_B = "22222222-2222-4222-8222-222222222222"
JOB_A = "a" * 32


@dataclass
class DurableRecord:
    project_id: str


class FakeRegistry:
    def __init__(self, records=None):
        self.records = dict(records or {})
        self.calls = []

    def get(self, logical_job_id: str):
        self.calls.append(logical_job_id)
        return self.records.get(logical_job_id)


class FakeReconnect:
    def __init__(self, records=None):
        self.registry = FakeRegistry(records)


class FakeAuthorizer:
    def __init__(self, result=True, error=None):
        self.result = result
        self.error = error
        self.calls = []

    def authorize(self, **kwargs):
        self.calls.append(kwargs)
        if self.error is not None:
            raise self.error
        return self.result


class FakeSafetyFacade:
    def __init__(self):
        self.calls = []

    def snapshot(self, logical_job_id):
        self.calls.append(("snapshot", logical_job_id, None))
        return {"phase": "ready"}

    def result(self, logical_job_id):
        self.calls.append(("result", logical_job_id, None))
        return ["safe-output"]

    def request_cancel(self, logical_job_id):
        self.calls.append(("cancel", logical_job_id, None))
        return {"cancel": "requested"}

    def request_delete(self, logical_job_id, *, reason):
        self.calls.append(("delete", logical_job_id, reason))
        return {"delete": "requested"}


class FakeAccountDeletion:
    def __init__(self):
        self.calls = []

    def delete_project(self, project_id):
        self.calls.append(project_id)
        return {"project_id": project_id, "complete": True}


class RecordingResolver:
    def __init__(self, project_id=PROJECT_A, error=None):
        self.project_id = project_id
        self.error = error
        self.calls = []

    def project_id_for_job(self, logical_job_id):
        self.calls.append(logical_job_id)
        if self.error is not None:
            raise self.error
        return self.project_id


class ProductionTransportGatewayTests(unittest.TestCase):
    def make_gateway(self, *, authorizer=None, resolver=None):
        self.safety = FakeSafetyFacade()
        self.account = FakeAccountDeletion()
        self.authorizer = authorizer or FakeAuthorizer()
        self.resolver = resolver or RecordingResolver()
        return ProductionTransportAuthorizationGateway(
            safety_facade=self.safety,
            account_deletion=self.account,
            authorizer=self.authorizer,
            project_resolver=self.resolver,
        )

    def test_durable_resolver_binds_exact_registered_project(self):
        reconnect = FakeReconnect({JOB_A: DurableRecord(project_id=PROJECT_A)})
        resolver = DurableReconnectProjectResolver(reconnect)
        self.assertEqual(resolver.project_id_for_job(JOB_A), PROJECT_A)
        self.assertEqual(reconnect.registry.calls, [JOB_A])
        with self.assertRaisesRegex(ProductionTransportGatewayError, "SEP_TRANSPORT_JOB_NOT_REGISTERED"):
            resolver.project_id_for_job("b" * 32)

    def test_authorized_processing_operations_route_only_to_safety_facade(self):
        gateway = self.make_gateway()
        self.assertEqual(
            gateway.snapshot(principal_id="user:123", project_id=PROJECT_A, logical_job_id=JOB_A),
            {"phase": "ready"},
        )
        self.assertEqual(
            gateway.result(principal_id="user:123", project_id=PROJECT_A, logical_job_id=JOB_A),
            ["safe-output"],
        )
        self.assertEqual(
            gateway.cancel(principal_id="user:123", project_id=PROJECT_A, logical_job_id=JOB_A),
            {"cancel": "requested"},
        )
        self.assertEqual(
            gateway.delete_processing_job(
                principal_id="user:123", project_id=PROJECT_A, logical_job_id=JOB_A
            ),
            {"delete": "requested"},
        )
        self.assertEqual(
            self.safety.calls,
            [
                ("snapshot", JOB_A, None),
                ("result", JOB_A, None),
                ("cancel", JOB_A, None),
                ("delete", JOB_A, "user_delete"),
            ],
        )
        self.assertEqual(self.resolver.calls, [JOB_A, JOB_A, JOB_A, JOB_A])
        self.assertEqual(
            [call["operation"] for call in self.authorizer.calls],
            [
                "processing_snapshot",
                "processing_result",
                "processing_cancel",
                "processing_delete",
            ],
        )

    def test_denied_authorization_stops_before_job_resolution_or_side_effect(self):
        gateway = self.make_gateway(authorizer=FakeAuthorizer(result=False))
        with self.assertRaisesRegex(ProductionTransportGatewayError, "SEP_TRANSPORT_FORBIDDEN"):
            gateway.result(principal_id="user:denied", project_id=PROJECT_A, logical_job_id=JOB_A)
        self.assertEqual(self.resolver.calls, [])
        self.assertEqual(self.safety.calls, [])
        self.assertEqual(self.account.calls, [])

    def test_truthy_non_boolean_authorization_is_rejected(self):
        gateway = self.make_gateway(authorizer=FakeAuthorizer(result="yes"))
        with self.assertRaisesRegex(ProductionTransportGatewayError, "SEP_TRANSPORT_FORBIDDEN"):
            gateway.snapshot(principal_id="user:123", project_id=PROJECT_A, logical_job_id=JOB_A)
        self.assertEqual(self.resolver.calls, [])
        self.assertEqual(self.safety.calls, [])

    def test_job_project_mismatch_stops_before_safety_side_effect(self):
        gateway = self.make_gateway(resolver=RecordingResolver(project_id=PROJECT_B))
        with self.assertRaisesRegex(
            ProductionTransportGatewayError, "SEP_TRANSPORT_JOB_PROJECT_MISMATCH"
        ):
            gateway.cancel(principal_id="user:123", project_id=PROJECT_A, logical_job_id=JOB_A)
        self.assertEqual(self.safety.calls, [])
        self.assertEqual(self.resolver.calls, [JOB_A])

    def test_account_project_delete_is_authorized_then_delegated_to_account_service(self):
        gateway = self.make_gateway()
        result = gateway.delete_account_project(principal_id="user:123", project_id=PROJECT_A)
        self.assertTrue(result["complete"])
        self.assertEqual(self.account.calls, [PROJECT_A])
        self.assertEqual(self.resolver.calls, [])
        self.assertEqual(self.safety.calls, [])
        self.assertEqual(self.authorizer.calls[0]["operation"], "account_project_delete")

    def test_authorizer_failure_is_fail_closed_and_retryable(self):
        gateway = self.make_gateway(authorizer=FakeAuthorizer(error=RuntimeError("auth down")))
        with self.assertRaises(ProductionTransportGatewayError) as caught:
            gateway.delete_account_project(principal_id="user:123", project_id=PROJECT_A)
        self.assertEqual(caught.exception.code, "SEP_TRANSPORT_AUTHORIZATION_UNAVAILABLE")
        self.assertTrue(caught.exception.retryable)
        self.assertEqual(self.account.calls, [])

    def test_malformed_public_identity_is_rejected_before_dependencies(self):
        gateway = self.make_gateway()
        with self.assertRaisesRegex(
            ProductionTransportGatewayError, "SEP_TRANSPORT_PRINCIPAL_ID_INVALID"
        ):
            gateway.snapshot(principal_id="bad principal", project_id=PROJECT_A, logical_job_id=JOB_A)
        with self.assertRaisesRegex(
            ProductionTransportGatewayError, "SEP_TRANSPORT_PROJECT_ID_INVALID"
        ):
            gateway.snapshot(principal_id="user:123", project_id="not-a-uuid", logical_job_id=JOB_A)
        with self.assertRaisesRegex(
            ProductionTransportGatewayError, "SEP_TRANSPORT_LOGICAL_JOB_ID_INVALID"
        ):
            gateway.snapshot(principal_id="user:123", project_id=PROJECT_A, logical_job_id="bad")
        self.assertEqual(self.safety.calls, [])
        self.assertEqual(self.account.calls, [])

    def test_gateway_source_has_no_raw_backend_processing_surface(self):
        path = SERVER_DIR / "production_transport_gateway.py"
        tree = ast.parse(path.read_text(encoding="utf-8"))
        gateway_class = next(
            node
            for node in tree.body
            if isinstance(node, ast.ClassDef)
            and node.name == "ProductionTransportAuthorizationGateway"
        )
        rendered = ast.unparse(gateway_class)
        self.assertNotIn("self._backend", rendered)
        self.assertNotIn("collect_ready_outputs", rendered)
        self.assertNotIn(".observe(", rendered)
        self.assertIn("self._safety.result", rendered)
        self.assertIn("self._account_deletion.delete_project", rendered)


if __name__ == "__main__":
    unittest.main()
