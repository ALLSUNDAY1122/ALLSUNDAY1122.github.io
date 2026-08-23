from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parents[1] / "Server"
if str(SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(SERVER_DIR))

from commercial_route_approval import ApprovalError, TERMS_KINDS, validate_manifest


def write_doc(root: Path, name: str, payload: bytes) -> tuple[str, str]:
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return name, hashlib.sha256(payload).hexdigest()


def valid_manifest(root: Path) -> dict:
    terms = {}
    for kind in TERMS_KINDS:
        path, digest = write_doc(root, f"docs/{kind}.bin", f"approved:{kind}".encode())
        terms[kind] = {
            "record_id": f"rec-{kind}-2026",
            "document_path": path,
            "sha256": digest,
            "effective_date": "2026-01-01",
            "expires_date": "2027-12-31",
        }
    cap_path, cap_sha = write_doc(root, "docs/capability-snapshot.json", b'{"models":"approved-live-snapshot"}')
    return {
        "schema_version": 1,
        "evidence_state": "NON_PARITY_EVIDENCE_ONLY",
        "approval_state": "APPROVED",
        "provider": {
            "provider_id": "AUDIOSHAKE",
            "provider_kind": "HOSTED_API",
            "account_tier": "PRODUCTION",
            "service_region": "US",
            "capability_snapshot": {
                "captured_at": "2026-08-24T00:00:00Z",
                "document_path": cap_path,
                "sha256": cap_sha,
                "models": [
                    {"model_name": "vocals", "model_version": "2026-08", "quality_profile": "standard", "canonical_roles": ["vocals", "instrumental"]},
                    {"model_name": "drums", "model_version": "2026-08", "quality_profile": "standard", "canonical_roles": ["drums"]},
                ],
            },
        },
        "credentials": {
            "environment_names": ["SEPARATION_PRODUCTION_API_KEY"],
            "server_side_only": True,
            "client_distribution_prohibited": True,
        },
        "terms": terms,
        "operational_terms": {
            "consumer_app_commercial_use_allowed": True,
            "input_confidential": True,
            "output_commercial_use_allowed": True,
            "output_export_to_end_user_allowed": True,
            "provider_training_on_user_content_allowed": False,
            "data_region": "US",
            "uploaded_asset_retention_seconds": 259200,
            "output_url_ttl_seconds": 3600,
            "delete_api_available": False,
            "delete_confirmation_semantics": "NOT_AVAILABLE",
            "pricing": {"currency": "USD", "billing_unit": "AUDIO_MINUTE", "unit_price": "0.125", "minimum_charge": "0"},
        },
    }


class CommercialRouteApprovalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.manifest = valid_manifest(self.root)
        self.today = date(2026, 8, 24)
        self.secret = "test-secret-value-123456"

    def tearDown(self):
        self.tmp.cleanup()

    def call(self, manifest=None, *, env=None, repo_root=None, require=True):
        return validate_manifest(
            manifest or self.manifest,
            self.root,
            env=env if env is not None else {"SEPARATION_PRODUCTION_API_KEY": self.secret},
            repo_root=repo_root,
            require_credentials=require,
            today=self.today,
        )

    def expect(self, code, mutate, **kwargs):
        value = copy.deepcopy(self.manifest)
        mutate(value)
        with self.assertRaises(ApprovalError) as ctx:
            self.call(value, **kwargs)
        self.assertEqual(code, ctx.exception.code)

    def test_01_valid_report_is_sanitized(self):
        report = self.call()
        blob = json.dumps(report, sort_keys=True)
        self.assertEqual("READY_FOR_LIVE_PROVIDER_GATE", report["result"])
        self.assertNotIn(self.secret, blob)
        self.assertNotIn("docs/commercial_use.bin", blob)
        self.assertNotIn("rec-commercial_use-2026", blob)
        self.assertFalse(report["credential_preflight"]["values_persisted"])
        self.assertFalse(report["operational_policy"]["pricing_values_persisted"])

    def test_02_missing_credential_is_external_pending(self):
        with self.assertRaises(ApprovalError) as ctx:
            self.call(env={})
        self.assertEqual("L1E01_CREDENTIAL_ENV_MISSING", ctx.exception.code)
        self.assertEqual("PENDING_EXTERNAL_CREDENTIAL", self.call(env={}, require=False)["result"])

    def test_03_document_sha_mismatch(self):
        self.expect("L1E01_DOCUMENT_SHA_MISMATCH", lambda m: m["terms"]["commercial_use"].__setitem__("sha256", "0" * 64))

    def test_04_document_missing(self):
        self.expect("L1E01_DOCUMENT_MISSING", lambda m: m["terms"]["pricing"].__setitem__("document_path", "docs/missing.bin"))

    def test_05_placeholder_terms_rejected(self):
        self.expect("L1E01_TERMS_PLACEHOLDER", lambda m: m["terms"]["pricing"].__setitem__("record_id", "REPLACE_WITH_TERMS"))

    def test_06_expired_terms_rejected(self):
        self.expect("L1E01_TERMS_EXPIRED", lambda m: m["terms"]["privacy_retention"].__setitem__("expires_date", "2026-01-01"))

    def test_07_future_terms_rejected(self):
        self.expect("L1E01_TERMS_NOT_EFFECTIVE", lambda m: m["terms"]["confidentiality"].__setitem__("effective_date", "2027-01-01"))

    def test_08_commercial_permission_false(self):
        self.expect("L1E01_COMMERCIAL_ROUTE_NOT_APPROVED", lambda m: m["operational_terms"].__setitem__("consumer_app_commercial_use_allowed", False))

    def test_09_output_export_permission_false(self):
        self.expect("L1E01_COMMERCIAL_ROUTE_NOT_APPROVED", lambda m: m["operational_terms"].__setitem__("output_export_to_end_user_allowed", False))

    def test_10_provider_training_true_rejected(self):
        self.expect("L1E01_PROVIDER_TRAINING_NOT_APPROVED", lambda m: m["operational_terms"].__setitem__("provider_training_on_user_content_allowed", True))

    def test_11_server_side_secret_required(self):
        self.expect("L1E01_SERVER_SIDE_SECRET_REQUIRED", lambda m: m["credentials"].__setitem__("server_side_only", False))

    def test_12_client_distribution_prohibited(self):
        self.expect("L1E01_CLIENT_SECRET_PROHIBITION_REQUIRED", lambda m: m["credentials"].__setitem__("client_distribution_prohibited", False))

    def test_13_duplicate_env_rejected(self):
        self.expect("L1E01_CREDENTIAL_ENV_DUPLICATE", lambda m: m["credentials"].__setitem__("environment_names", ["SEPARATION_PRODUCTION_API_KEY", "SEPARATION_PRODUCTION_API_KEY"]))

    def test_14_invalid_env_name_rejected(self):
        self.expect("L1E01_CREDENTIAL_ENV_INVALID", lambda m: m["credentials"].__setitem__("environment_names", ["bad-key"]))

    def test_15_capability_snapshot_sha_mismatch(self):
        self.expect("L1E01_CAPABILITY_SNAPSHOT_SHA_MISMATCH", lambda m: m["provider"]["capability_snapshot"].__setitem__("sha256", "0" * 64))

    def test_16_model_version_required(self):
        self.expect("L1E01_SCHEMA_REQUIRED", lambda m: m["provider"]["capability_snapshot"]["models"][0].__setitem__("model_version", ""))

    def test_17_duplicate_model_binding_rejected(self):
        def mutate(m):
            m["provider"]["capability_snapshot"]["models"].append(copy.deepcopy(m["provider"]["capability_snapshot"]["models"][0]))
        self.expect("L1E01_MODEL_BINDING_DUPLICATE", mutate)

    def test_18_duplicate_roles_rejected(self):
        self.expect("L1E01_MODEL_ROLES_DUPLICATE", lambda m: m["provider"]["capability_snapshot"]["models"][0].__setitem__("canonical_roles", ["vocals", "vocals"]))

    def test_19_delete_semantics_mismatch(self):
        self.expect("L1E01_DELETE_SEMANTICS_INVALID", lambda m: m["operational_terms"].__setitem__("delete_confirmation_semantics", "SYNC_CONFIRMED"))

    def test_20_bad_pricing_unit(self):
        self.expect("L1E01_PRICING_INVALID", lambda m: m["operational_terms"]["pricing"].__setitem__("billing_unit", "MYSTERY"))

    def test_21_bad_pricing_decimal(self):
        self.expect("L1E01_PRICING_INVALID", lambda m: m["operational_terms"]["pricing"].__setitem__("unit_price", "1e9"))

    def test_22_unknown_secret_field_rejected(self):
        self.expect("L1E01_SCHEMA_UNKNOWN_FIELD", lambda m: m.__setitem__("api_key", "must-not-be-accepted"))

    def test_23_path_traversal_rejected(self):
        self.expect("L1E01_PATH_UNSAFE", lambda m: m["terms"]["pricing"].__setitem__("document_path", "../secret.pdf"))

    def test_24_symlink_document_rejected(self):
        target = self.root / "outside.bin"
        target.write_bytes(b"x")
        link = self.root / "docs" / "link.bin"
        link.symlink_to(target)
        value = copy.deepcopy(self.manifest)
        value["terms"]["pricing"]["document_path"] = "docs/link.bin"
        value["terms"]["pricing"]["sha256"] = hashlib.sha256(b"x").hexdigest()
        with self.assertRaises(ApprovalError) as ctx:
            self.call(value)
        self.assertEqual("L1E01_PATH_SYMLINK", ctx.exception.code)

    def test_25_exact_secret_repository_scan_passes_without_secret(self):
        repo = self.root / "repo"
        repo.mkdir()
        (repo / "safe.txt").write_text("SEPARATION_PRODUCTION_API_KEY=from-environment-only")
        self.assertEqual("PASS", self.call(repo_root=repo)["credential_preflight"]["repository_exact_secret_scan"])

    def test_26_exact_secret_repository_scan_rejects_leak(self):
        repo = self.root / "repo"
        repo.mkdir()
        (repo / "bad.txt").write_text("prefix:" + self.secret + ":suffix")
        with self.assertRaises(ApprovalError) as ctx:
            self.call(repo_root=repo)
        self.assertEqual("L1E01_SECRET_FOUND_IN_REPOSITORY", ctx.exception.code)

    def test_27_secret_scan_across_chunk_boundary(self):
        repo = self.root / "repo"
        repo.mkdir()
        with (repo / "boundary.bin").open("wb") as handle:
            handle.write(b"a" * (1024 * 1024 - 5))
            handle.write(self.secret.encode())
        with self.assertRaises(ApprovalError) as ctx:
            self.call(repo_root=repo)
        self.assertEqual("L1E01_SECRET_FOUND_IN_REPOSITORY", ctx.exception.code)

    def test_28_short_credential_rejected_for_scan(self):
        repo = self.root / "repo"
        repo.mkdir()
        with self.assertRaises(ApprovalError) as ctx:
            self.call(env={"SEPARATION_PRODUCTION_API_KEY": "short"}, repo_root=repo)
        self.assertEqual("L1E01_CREDENTIAL_TOO_SHORT", ctx.exception.code)

    def test_29_model_order_does_not_change_identity(self):
        first = self.call()
        other = copy.deepcopy(self.manifest)
        other["provider"]["capability_snapshot"]["models"].reverse()
        second = self.call(other)
        self.assertEqual(first["approval_manifest_identity_sha256"], second["approval_manifest_identity_sha256"])

    def test_30_pricing_change_changes_hash_but_value_not_reported(self):
        first = self.call()
        other = copy.deepcopy(self.manifest)
        other["operational_terms"]["pricing"]["unit_price"] = "0.250"
        second = self.call(other)
        self.assertNotEqual(first["operational_policy"]["pricing_config_sha256"], second["operational_policy"]["pricing_config_sha256"])
        self.assertNotIn("0.250", json.dumps(second))


if __name__ == "__main__":
    unittest.main()
