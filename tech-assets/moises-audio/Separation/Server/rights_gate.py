"""Fail-closed checkpoint rights gate for MOI-SEP-002 server inference.

This module does not grant legal rights. It only prevents a production separation service from
starting with a checkpoint whose project-side rights manifest is missing or inconsistent with the
verified MOI-SEP-LIC-001 policy.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ALLOWED_RIGHTS_BASES = {
    "PROJECT_OWNED_FROM_SCRATCH",
    "EXPLICIT_WRITTEN_COMMERCIAL_GRANT",
}

# Canonical policy currently excludes these lineages unless a new HQ-approved written grant
# supersedes MOI-SEP-LIC-001. Matching is case-insensitive and intentionally conservative.
PROHIBITED_MARKERS = {
    "official demucs",
    "official htdemucs",
    "facebookresearch/demucs pretrained",
    "musdb",
    "musdb18",
    "musdb18-hq",
    "medleydb",
    "spleeter pretrained",
    "open-unmix pretrained",
    "umxl",
    "umxhq",
    "umx pretrained",
}


class RightsGateError(RuntimeError):
    pass


@dataclass(frozen=True)
class ApprovedCheckpoint:
    model_id: str
    checkpoint_path: Path
    checkpoint_sha256: str
    architecture: str
    rights_basis: str
    rights_record_refs: tuple[str, ...]
    training_manifest_sha256: str | None


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise RightsGateError(message)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _normalized_text(value: Any) -> str:
    if isinstance(value, str):
        return value.lower()
    if isinstance(value, list):
        return " ".join(_normalized_text(item) for item in value)
    if isinstance(value, dict):
        return " ".join(f"{key} {_normalized_text(item)}" for key, item in value.items()).lower()
    return str(value).lower()


def validate_checkpoint_manifest(manifest_path: str | Path, checkpoint_path: str | Path) -> ApprovedCheckpoint:
    manifest_path = Path(manifest_path)
    checkpoint_path = Path(checkpoint_path)

    _require(manifest_path.is_file(), "SEP_RIGHTS_MANIFEST_MISSING")
    _require(checkpoint_path.is_file(), "SEP_CHECKPOINT_MISSING")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RightsGateError("SEP_RIGHTS_MANIFEST_INVALID_JSON") from exc

    _require(manifest.get("schema_version") == 1, "SEP_RIGHTS_SCHEMA_UNSUPPORTED")
    _require(manifest.get("commercial_inference_allowed") is True, "SEP_COMMERCIAL_INFERENCE_NOT_CLEARED")
    _require(manifest.get("rights_basis") in ALLOWED_RIGHTS_BASES, "SEP_RIGHTS_BASIS_NOT_CLEARED")
    _require(manifest.get("production_approved") is True, "SEP_CHECKPOINT_NOT_PRODUCTION_APPROVED")
    _require(manifest.get("contains_reference_outputs") is False, "SEP_REFERENCE_OUTPUT_CONTAMINATION")

    model_id = manifest.get("model_id")
    architecture = manifest.get("architecture")
    expected_hash = manifest.get("checkpoint_sha256")
    rights_refs = manifest.get("rights_record_refs")

    _require(isinstance(model_id, str) and model_id.strip(), "SEP_MODEL_ID_MISSING")
    _require(isinstance(architecture, str) and architecture.strip(), "SEP_ARCHITECTURE_MISSING")
    _require(isinstance(expected_hash, str) and len(expected_hash) == 64, "SEP_CHECKPOINT_HASH_MISSING")
    _require(isinstance(rights_refs, list) and rights_refs and all(isinstance(item, str) and item for item in rights_refs),
             "SEP_RIGHTS_RECORD_MISSING")

    rights_basis = manifest["rights_basis"]
    initializer = manifest.get("pretrained_initializer")
    training_manifest_hash = manifest.get("training_manifest_sha256")

    if rights_basis == "PROJECT_OWNED_FROM_SCRATCH":
        _require(initializer in (None, "NONE", "RANDOM_PROJECT_CONTROLLED"), "SEP_UNCLEARED_PRETRAINED_INITIALIZER")
        _require(isinstance(training_manifest_hash, str) and len(training_manifest_hash) == 64,
                 "SEP_TRAINING_MANIFEST_HASH_MISSING")

    policy_text = _normalized_text({
        "model_id": model_id,
        "architecture": architecture,
        "pretrained_initializer": initializer,
        "training_sources": manifest.get("training_sources", []),
        "notes": manifest.get("notes", ""),
    })
    prohibited = sorted(marker for marker in PROHIBITED_MARKERS if marker in policy_text)
    _require(not prohibited, "SEP_PROHIBITED_LINEAGE:" + ",".join(prohibited))

    actual_hash = _sha256(checkpoint_path)
    _require(actual_hash == expected_hash.lower(), "SEP_CHECKPOINT_HASH_MISMATCH")

    return ApprovedCheckpoint(
        model_id=model_id,
        checkpoint_path=checkpoint_path,
        checkpoint_sha256=actual_hash,
        architecture=architecture,
        rights_basis=rights_basis,
        rights_record_refs=tuple(rights_refs),
        training_manifest_sha256=training_manifest_hash,
    )
