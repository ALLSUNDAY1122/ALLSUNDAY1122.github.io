from __future__ import annotations

from pathlib import Path
import sys
import unittest

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
sys.path.insert(0, str(SERVER_DIR))

from production_transport_gateway import (
    ProductionTransportAuthorizationGateway,
    ProductionTransportGatewayError,
)

PROJECT_A = "11111111-1111-4111-8111-111111111111"
ASSET_A = "33333333-3333-4333-8333-333333333333"


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
    def snapshot(self, logical_job_id):
        raise AssertionError("unused")

    def result(self, logical_job_id):
        raise AssertionError("unused")

    def request_cancel(self, logical_job_id):
        raise AssertionError("unused")

    def request_delete(self, logical_job_id, *, reason):
        raise AssertionError("unused")


class FakeAccountDeletion:
    def delete_project(self, project_id):
        raise AssertionError("unused")


class FakeProjectResolver:
    def project_id_for_job(self, logical_job_id):
        raise AssertionError("unused")


class StartFailure(RuntimeError):
    def __init__(self, code, *, retryable=False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


class RecordingStartService:
    def __init__(self, error=None):
        self.error = error
        self.calls = []

    def start(self, **kwargs):
        self.calls.append(kwargs)
        if self.error is not None:
            raise self.error
        return {"logical_job_id": "a" * 32}


class ProductionTransportStartGatewayTests(unittest.TestCase):
    def make_gateway(self, *, authorizer=None, start_service=None):
        self.authorizer = authorizer or FakeAuthorizer()
        self.start_service = start_service
        return ProductionTransportAuthorizationGateway(
            safety_facade=FakeSafetyFacade(),
            account_deletion=FakeAccountDeletion(),
            authorizer=self.authorizer,
            project_resolver=FakeProjectResolver(),
            start_service=start_service,
        )

    def valid_start(self, gateway, **overrides):
        values = {
            "principal_id": "user:123",
            "project_id": PROJECT_A,
            "source_path": Path("/server-owned/upload.bin"),
            "asset_id": ASSET_A,
            "canonical_roles": ("bass", "drums", "vocals"),
            "quality_profile": "hifi",
            "idempotency_key": "idem-123",
        }
        values.update(overrides)
        return gateway.start_processing(**values)

    def test_authorized_start_preserves_exact_contract(self):
        service = RecordingStartService()
        gateway = self.make_gateway(start_service=service)

        result = self.valid_start(gateway)

        self.assertEqual(result, {"logical_job_id": "a" * 32})
        self.assertEqual(
            self.authorizer.calls,
            [{
                "principal_id": "user:123",
                "project_id": PROJECT_A,
                "operation": "processing_start",
            }],
        )
        self.assertEqual(
            service.calls,
            [{
                "source_path": Path("/server-owned/upload.bin"),
                "project_id": PROJECT_A,
                "asset_id": ASSET_A,
                "canonical_roles": ("bass", "drums", "vocals"),
                "quality_profile": "hifi",
                "idempotency_key": "idem-123",
            }],
        )

    def test_denied_start_stops_before_service(self):
        service = RecordingStartService()
        gateway = self.make_gateway(authorizer=FakeAuthorizer(result=False), start_service=service)

        with self.assertRaisesRegex(ProductionTransportGatewayError, "SEP_TRANSPORT_FORBIDDEN"):
            self.valid_start(gateway)

        self.assertEqual(service.calls, [])

    def test_missing_start_service_fails_closed(self):
        gateway = self.make_gateway(start_service=None)

        with self.assertRaisesRegex(
            ProductionTransportGatewayError, "SEP_TRANSPORT_START_SURFACE_MISSING"
        ):
            self.valid_start(gateway)

        self.assertEqual(self.authorizer.calls[0]["operation"], "processing_start")

    def test_roles_must_be_unique_sorted_and_canonical(self):
        service = RecordingStartService()
        gateway = self.make_gateway(start_service=service)

        for roles in (
            ("vocals", "bass"),
            ("bass", "bass"),
            ("Bass", "vocals"),
            (),
            "bass,vocals",
        ):
            with self.subTest(roles=roles):
                with self.assertRaises(ProductionTransportGatewayError):
                    self.valid_start(gateway, canonical_roles=roles)

        self.assertEqual(service.calls, [])

    def test_asset_quality_and_idempotency_are_fail_closed(self):
        service = RecordingStartService()
        gateway = self.make_gateway(start_service=service)

        invalid = (
            {"asset_id": "not-a-uuid"},
            {"quality_profile": " hifi"},
            {"quality_profile": "hifi\nunsafe"},
            {"idempotency_key": " idem"},
            {"idempotency_key": "idem\r\nunsafe"},
        )
        for override in invalid:
            with self.subTest(override=override):
                with self.assertRaises(ProductionTransportGatewayError):
                    self.valid_start(gateway, **override)

        self.assertEqual(service.calls, [])

    def test_safe_service_error_is_preserved_and_unknown_error_is_sanitized(self):
        gateway = self.make_gateway(
            start_service=RecordingStartService(
                StartFailure("SEP_PROFILE_ENTITLEMENT_REQUIRED", retryable=False)
            )
        )
        with self.assertRaises(ProductionTransportGatewayError) as caught:
            self.valid_start(gateway)
        self.assertEqual(caught.exception.code, "SEP_PROFILE_ENTITLEMENT_REQUIRED")
        self.assertFalse(caught.exception.retryable)

        gateway = self.make_gateway(start_service=RecordingStartService(RuntimeError("secret detail")))
        with self.assertRaises(ProductionTransportGatewayError) as caught:
            self.valid_start(gateway)
        self.assertEqual(caught.exception.code, "SEP_TRANSPORT_START_FAILED")
        self.assertFalse(caught.exception.retryable)
        self.assertNotIn("secret detail", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
