import hashlib
import json
import tempfile
import unittest
from pathlib import Path
import importlib.util


MODULE_PATH = Path(__file__).resolve().parents[1] / "Server" / "rights_gate.py"
spec = importlib.util.spec_from_file_location("rights_gate", MODULE_PATH)
rights_gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(rights_gate)


class RightsGateTests(unittest.TestCase):
    def make_checkpoint(self, root: Path, data: bytes = b"checkpoint") -> tuple[Path, str]:
        checkpoint = root / "model.pt"
        checkpoint.write_bytes(data)
        return checkpoint, hashlib.sha256(data).hexdigest()

    def write_manifest(self, root: Path, checkpoint_hash: str, **overrides) -> Path:
        manifest = {
            "schema_version": 1,
            "model_id": "project-owned-htdemucs-v1",
            "architecture": "HTDemucs-class project implementation",
            "checkpoint_sha256": checkpoint_hash,
            "rights_basis": "PROJECT_OWNED_FROM_SCRATCH",
            "commercial_inference_allowed": True,
            "production_approved": True,
            "contains_reference_outputs": False,
            "rights_record_refs": ["RIGHTS-001"],
            "pretrained_initializer": "RANDOM_PROJECT_CONTROLLED",
            "training_manifest_sha256": "a" * 64,
            "training_sources": ["PROJECT_COMMISSIONED_REAL_MULTITRACKS"],
        }
        manifest.update(overrides)
        path = root / "manifest.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    def test_accepts_project_owned_checkpoint_with_matching_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint, digest = self.make_checkpoint(root)
            manifest = self.write_manifest(root, digest)
            approved = rights_gate.validate_checkpoint_manifest(manifest, checkpoint)
            self.assertEqual(approved.checkpoint_sha256, digest)
            self.assertEqual(approved.rights_basis, "PROJECT_OWNED_FROM_SCRATCH")

    def test_rejects_hash_mismatch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint, _ = self.make_checkpoint(root)
            manifest = self.write_manifest(root, "b" * 64)
            with self.assertRaisesRegex(rights_gate.RightsGateError, "SEP_CHECKPOINT_HASH_MISMATCH"):
                rights_gate.validate_checkpoint_manifest(manifest, checkpoint)

    def test_rejects_noncommercial_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint, digest = self.make_checkpoint(root)
            manifest = self.write_manifest(root, digest, commercial_inference_allowed=False)
            with self.assertRaisesRegex(rights_gate.RightsGateError, "SEP_COMMERCIAL_INFERENCE_NOT_CLEARED"):
                rights_gate.validate_checkpoint_manifest(manifest, checkpoint)

    def test_rejects_official_demucs_or_musdb_lineage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint, digest = self.make_checkpoint(root)
            manifest = self.write_manifest(
                root,
                digest,
                notes="initialized from official Demucs weights",
                training_sources=["MUSDB18-HQ"],
            )
            with self.assertRaisesRegex(rights_gate.RightsGateError, "SEP_PROHIBITED_LINEAGE"):
                rights_gate.validate_checkpoint_manifest(manifest, checkpoint)

    def test_rejects_missing_training_manifest_for_from_scratch_path(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint, digest = self.make_checkpoint(root)
            manifest = self.write_manifest(root, digest, training_manifest_sha256=None)
            with self.assertRaisesRegex(rights_gate.RightsGateError, "SEP_TRAINING_MANIFEST_HASH_MISSING"):
                rights_gate.validate_checkpoint_manifest(manifest, checkpoint)

    def test_written_commercial_grant_path_does_not_require_training_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint, digest = self.make_checkpoint(root)
            manifest = self.write_manifest(
                root,
                digest,
                rights_basis="EXPLICIT_WRITTEN_COMMERCIAL_GRANT",
                pretrained_initializer="VENDOR_GRANTED_MODEL",
                training_manifest_sha256=None,
                training_sources=[],
                notes="vendor model under explicit written grant",
            )
            approved = rights_gate.validate_checkpoint_manifest(manifest, checkpoint)
            self.assertEqual(approved.rights_basis, "EXPLICIT_WRITTEN_COMMERCIAL_GRANT")


if __name__ == "__main__":
    unittest.main()
