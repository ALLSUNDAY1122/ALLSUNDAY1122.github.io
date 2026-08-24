import json
import tempfile
import unittest
from pathlib import Path

from generated_stem_retention import GeneratedStemRetentionCoordinator
from ai_stem_generation_retention_gateway import A24RetentionGateway, RetentionGatewayError

H = lambda c: c * 64


def variant(project=H("1"), role="guitar", generation=H("2"), index=0, artifact=H("a")):
    return {
        "schema_version": 1,
        "project_ref_hash": project,
        "role": role,
        "generation_ref_hash": generation,
        "variant_index": index,
        "artifact_sha256": artifact,
        "artifact_bytes": 1,
        "sample_rate": 48000,
        "channels": 2,
        "audio_format": 1,
        "bits_per_sample": 16,
        "frame_count": 4800,
        "mix_ready_receipt_sha256": H("b"),
    }


class RetentionGatewayTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "store"
        for d in ("objects", "manifests", "active"):
            (self.root / d).mkdir(parents=True, exist_ok=True)
        self.coordinator = GeneratedStemRetentionCoordinator(
            self.root, Path(self.tmp.name) / "delete-ledger.json"
        )
        self.gateway = A24RetentionGateway(self.coordinator)

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, raw, *, active=True):
        manifest = self.root / "manifests" / f"{raw['generation_ref_hash']}.v{raw['variant_index']}.json"
        manifest.write_text(json.dumps(raw, sort_keys=True, separators=(",", ":")))
        obj = self.root / "objects" / f"{raw['artifact_sha256']}.wav"
        obj.write_bytes(b"x")
        if active:
            pointer = self.root / "active" / f"{raw['project_ref_hash']}.{raw['role']}.json"
            pointer.write_text(json.dumps(raw, sort_keys=True, separators=(",", ":")))
        return manifest, obj

    def assertCode(self, code, fn):
        with self.assertRaises(RetentionGatewayError) as cm:
            fn()
        self.assertEqual(cm.exception.code, code)

    def test_register_variant_exposes_a25_surface(self):
        raw = variant(); self.put(raw)
        registration = self.gateway.register_variant(
            generation_ref_hash_value=raw["generation_ref_hash"], variant_index=0
        )
        self.assertEqual(registration.generation_ref_hash, raw["generation_ref_hash"])
        self.assertEqual(registration.artifact_sha256, raw["artifact_sha256"])
        self.assertEqual(len(self.gateway.retention_policy_sha256), 64)

    def test_register_requires_exact_active_pointer(self):
        raw = variant(); self.put(raw, active=False)
        self.assertCode(
            "GENRET_GATEWAY_ACTIVE_POINTER_MISSING",
            lambda: self.gateway.register_variant(generation_ref_hash_value=H("2"), variant_index=0),
        )

    def test_delete_maps_to_a24_and_returns_a25_association_receipt(self):
        raw = variant(); self.put(raw)
        snap = self.gateway.request_delete(
            generation_ref_hash_value=H("2"), variant_index=0, reason="USER_DELETE"
        )
        self.assertTrue(snap["association_delete_confirmed"])
        self.assertFalse(snap["refund_confirmed"])
        self.assertFalse(snap["runtime_erasure_confirmed"])

    def test_delete_replay_same_reason_is_idempotent(self):
        raw = variant(); self.put(raw)
        a = self.gateway.request_delete(generation_ref_hash_value=H("2"), variant_index=0, reason="USER_DELETE")
        b = self.gateway.request_delete(generation_ref_hash_value=H("2"), variant_index=0, reason="USER_DELETE")
        self.assertEqual(a["artifact_sha256"], b["artifact_sha256"])
        self.assertTrue(b["association_delete_confirmed"])

    def test_delete_reason_conflict_fails_closed(self):
        raw = variant(); self.put(raw)
        self.gateway.request_delete(generation_ref_hash_value=H("2"), variant_index=0, reason="USER_DELETE")
        self.assertCode(
            "GENRET_GATEWAY_DELETE_REASON_CONFLICT",
            lambda: self.gateway.request_delete(generation_ref_hash_value=H("2"), variant_index=0, reason="PROJECT_DELETE"),
        )

    def test_tombstone_blocks_re_registration(self):
        raw = variant(); self.put(raw)
        self.gateway.request_delete(generation_ref_hash_value=H("2"), variant_index=0, reason="USER_DELETE")
        # Reconstructing files cannot silently resurrect the deleted generation.
        self.put(raw)
        self.assertCode(
            "GENRET_GATEWAY_GENERATION_TOMBSTONED",
            lambda: self.gateway.register_variant(generation_ref_hash_value=H("2"), variant_index=0),
        )

    def binding(self, execution_id="exec-1", execution_hash=None):
        logical = "a" * 32
        execution_hash = execution_hash or __import__("hashlib").sha256(
            ("l1-a21-execution-v1:" + execution_id).encode()
        ).hexdigest()
        path = Path(self.tmp.name) / "bindings.json"
        path.write_text(json.dumps({
            "schema_version": 1,
            "records": {logical: {"execution_id": execution_id, "execution_ref_hash": execution_hash}},
        }))
        return path, __import__("hashlib").sha256(
            ("l1-a21-generation-ref-v1:" + logical).encode()
        ).hexdigest()

    def test_runtime_confirmed_receipt_is_authority_but_not_refund(self):
        path, gen = self.binding(); raw = variant(generation=gen); self.put(raw)
        snap = self.gateway.request_delete(
            generation_ref_hash_value=gen, variant_index=0, reason="USER_DELETE",
            runtime_delete=lambda _: "confirmed", binding_store_path=path,
        )
        self.assertTrue(snap["runtime_erasure_confirmed"])
        self.assertFalse(snap["refund_confirmed"])

    def test_runtime_accepted_is_only_pending(self):
        path, gen = self.binding(); raw = variant(generation=gen); self.put(raw)
        snap = self.gateway.request_delete(
            generation_ref_hash_value=gen, variant_index=0, reason="USER_DELETE",
            runtime_delete=lambda _: "accepted", binding_store_path=path,
        )
        self.assertEqual(snap["runtime_delete_state"], "pending")
        self.assertFalse(snap["runtime_erasure_confirmed"])

    def test_runtime_error_stays_unknown(self):
        path, gen = self.binding(); raw = variant(generation=gen); self.put(raw)
        def boom(_): raise RuntimeError("network")
        snap = self.gateway.request_delete(
            generation_ref_hash_value=gen, variant_index=0, reason="USER_DELETE",
            runtime_delete=boom, binding_store_path=path,
        )
        self.assertEqual(snap["runtime_delete_state"], "unknown")
        self.assertFalse(snap["runtime_erasure_confirmed"])

    def test_missing_binding_never_claims_erasure(self):
        raw = variant(); self.put(raw)
        snap = self.gateway.request_delete(
            generation_ref_hash_value=H("2"), variant_index=0, reason="USER_DELETE",
            runtime_delete=lambda _: "confirmed", binding_store_path=None,
        )
        self.assertEqual(snap["runtime_delete_state"], "unknown")
        self.assertFalse(snap["runtime_erasure_confirmed"])

    def test_binding_identity_mismatch_fails_closed(self):
        path, gen = self.binding(execution_hash=H("f")); raw = variant(generation=gen); self.put(raw)
        self.assertCode(
            "GENRET_GATEWAY_BINDING_IDENTITY_MISMATCH",
            lambda: self.gateway.request_delete(
                generation_ref_hash_value=gen, variant_index=0, reason="USER_DELETE",
                runtime_delete=lambda _: "confirmed", binding_store_path=path,
            ),
        )

    def test_snapshot_is_privacy_safe(self):
        raw = variant(); self.put(raw)
        snap = self.gateway.request_delete(generation_ref_hash_value=H("2"), variant_index=0, reason="USER_DELETE")
        encoded = json.dumps(snap)
        self.assertNotIn(str(self.root), encoded)
        self.assertFalse(snap["path_emitted"])
        self.assertFalse(snap["raw_audio_emitted"])
        self.assertFalse(snap["raw_runtime_id_emitted"])
        self.assertEqual(snap["parity_claim"], "NONE")


if __name__ == "__main__":
    unittest.main()
