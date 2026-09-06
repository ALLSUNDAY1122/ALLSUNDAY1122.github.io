"""Lane 1 E02 rights-cleared real-audio intake readiness gate.

This gate does not prove that waveform content is genuinely human-recorded. It binds
A19-validated media to private rights/provenance records and fails closed when the
grant, fixture manifest, or source-document bytes disagree.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any, Mapping, Sequence

from evaluation_core import EvaluationError, load_json, normalize_sha256, sha256_file
from golden_corpus_intake import validate_golden_corpus_files

SCHEMA_VERSION = 1
TOOL_VERSION = "L1-E02-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
GROUPS = {"G1", "G2"}
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")


class RightsIntakeError(EvaluationError):
    pass


def err(code: str, message: str = "rights intake validation failed") -> RightsIntakeError:
    return RightsIntakeError(code, message)


def obj(value: Any, field: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise err("L1E02_SCHEMA_TYPE", f"{field} must be object")
    return value


def arr(value: Any, field: str) -> list[Any]:
    if not isinstance(value, list):
        raise err("L1E02_SCHEMA_TYPE", f"{field} must be array")
    return value


def text(value: Any, field: str, *, ident: bool = False) -> str:
    if not isinstance(value, str) or not value.strip():
        raise err("L1E02_SCHEMA_REQUIRED", f"{field} must be non-empty string")
    out = value.strip()
    if ident and not SAFE_ID.fullmatch(out):
        raise err("L1E02_ID_INVALID", field)
    return out


def boolean(value: Any, field: str) -> bool:
    if not isinstance(value, bool):
        raise err("L1E02_SCHEMA_TYPE", f"{field} must be boolean")
    return value


def exact(mapping: Mapping[str, Any], allowed: set[str], required: set[str], field: str) -> None:
    missing = required - set(mapping)
    extra = set(mapping) - allowed
    if missing:
        raise err("L1E02_SCHEMA_REQUIRED", f"{field} missing {sorted(missing)}")
    if extra:
        raise err("L1E02_SCHEMA_UNKNOWN_FIELD", f"{field} has {sorted(extra)}")


def normalize_sha(value: Any, field: str) -> str:
    try:
        out = normalize_sha256(value, field)
    except EvaluationError as exc:
        raise err("L1E02_SHA256_INVALID", field) from exc
    if not SHA_RE.fullmatch(out):
        raise err("L1E02_SHA256_INVALID", field)
    return out


def canonical_sha(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def hashed_ref(namespace: str, value: str) -> str:
    return hashlib.sha256((f"lane1-e02-{namespace}-v1\0" + value).encode("utf-8")).hexdigest()


def iso_date(value: Any, field: str) -> str:
    out = text(value, field)
    try:
        date.fromisoformat(out)
    except ValueError as exc:
        raise err("L1E02_DATE_INVALID", field) from exc
    return out


def no_symlink(root: Path, rel: Path, field: str) -> None:
    cursor = root.resolve()
    for part in rel.parts:
        cursor /= part
        if cursor.is_symlink():
            raise err("L1E02_PATH_SYMLINK", field)


def safe_file(root: Path, value: Any, field: str, missing_code: str) -> Path:
    raw = text(value, field)
    rel = Path(raw)
    if rel.is_absolute() or ".." in rel.parts:
        raise err("L1E02_PATH_UNSAFE", field)
    no_symlink(root, rel, field)
    base = root.resolve()
    path = (base / rel).resolve()
    try:
        path.relative_to(base)
    except ValueError as exc:
        raise err("L1E02_PATH_OUTSIDE_ROOT", field) from exc
    if not path.is_file():
        raise err(missing_code, field)
    return path


def validate_rights_index(raw: Any) -> dict[str, Any]:
    index = obj(raw, "rights_index")
    keys = {"schema_version", "evidence_state", "corpus_id", "corpus_revision", "records"}
    exact(index, keys, keys, "rights_index")
    if index["schema_version"] != SCHEMA_VERSION:
        raise err("L1E02_INDEX_SCHEMA")
    if index["evidence_state"] != EVIDENCE_STATE:
        raise err("L1E02_EVIDENCE_STATE")
    records: list[dict[str, str]] = []
    seen: set[str] = set()
    record_keys = {
        "fixture_id", "expected_group", "fixture_manifest_path", "fixture_manifest_sha256",
        "grant_record_path", "grant_record_sha256",
    }
    for i, raw_record in enumerate(arr(index["records"], "records")):
        record = obj(raw_record, f"records[{i}]")
        exact(record, record_keys, record_keys, f"records[{i}]")
        fixture_id = text(record["fixture_id"], f"records[{i}].fixture_id", ident=True)
        if fixture_id in seen:
            raise err("L1E02_FIXTURE_DUPLICATE", fixture_id)
        seen.add(fixture_id)
        group = text(record["expected_group"], f"records[{i}].expected_group")
        if group not in GROUPS:
            raise err("L1E02_GROUP_INVALID", fixture_id)
        records.append({
            "fixture_id": fixture_id,
            "expected_group": group,
            "fixture_manifest_path": text(record["fixture_manifest_path"], "fixture_manifest_path"),
            "fixture_manifest_sha256": normalize_sha(record["fixture_manifest_sha256"], "fixture_manifest_sha256"),
            "grant_record_path": text(record["grant_record_path"], "grant_record_path"),
            "grant_record_sha256": normalize_sha(record["grant_record_sha256"], "grant_record_sha256"),
        })
    if not records:
        raise err("L1E02_INDEX_EMPTY")
    return {
        "corpus_id": text(index["corpus_id"], "corpus_id", ident=True),
        "corpus_revision": text(index["corpus_revision"], "corpus_revision", ident=True),
        "records": records,
    }


def validate_grant(raw: Any, *, fixture_id: str, expected_group: str, rights_root: Path, today: date) -> dict[str, Any]:
    grant = obj(raw, "grant")
    keys = {
        "schema_version", "rights_record_id", "fixture_id", "grant_state",
        "authority_reviewed", "revoked", "effective_date", "expires_date",
        "source_document", "provenance", "permissions",
    }
    exact(grant, keys, keys, "grant")
    if grant["schema_version"] != SCHEMA_VERSION:
        raise err("L1E02_GRANT_SCHEMA")
    rights_record_id = text(grant["rights_record_id"], "rights_record_id", ident=True)
    if grant["fixture_id"] != fixture_id:
        raise err("L1E02_GRANT_FIXTURE_MISMATCH", fixture_id)
    if text(grant["grant_state"], "grant_state").upper() != "VERIFIED":
        raise err("L1E02_GRANT_NOT_VERIFIED", fixture_id)
    if not boolean(grant["authority_reviewed"], "authority_reviewed"):
        raise err("L1E02_AUTHORITY_UNVERIFIED", fixture_id)
    if boolean(grant["revoked"], "revoked"):
        raise err("L1E02_GRANT_REVOKED", fixture_id)
    effective = iso_date(grant["effective_date"], "effective_date")
    if date.fromisoformat(effective) > today:
        raise err("L1E02_GRANT_NOT_EFFECTIVE", fixture_id)
    expires = None
    if grant["expires_date"] is not None:
        expires = iso_date(grant["expires_date"], "expires_date")
        if date.fromisoformat(expires) < today:
            raise err("L1E02_GRANT_EXPIRED", fixture_id)

    source = obj(grant["source_document"], "source_document")
    exact(source, {"path", "sha256"}, {"path", "sha256"}, "source_document")
    source_path = safe_file(rights_root, source["path"], "source_document.path", "L1E02_SOURCE_DOCUMENT_MISSING")
    source_sha = normalize_sha(source["sha256"], "source_document.sha256")
    if sha256_file(source_path) != source_sha:
        raise err("L1E02_SOURCE_DOCUMENT_SHA_MISMATCH", fixture_id)

    provenance = obj(grant["provenance"], "provenance")
    pkeys = {"real_recorded_music_attested", "synthetic_or_generated", "origin_record_id"}
    exact(provenance, pkeys, pkeys, "provenance")
    if not boolean(provenance["real_recorded_music_attested"], "real_recorded_music_attested"):
        raise err("L1E02_REAL_RECORDING_NOT_ATTESTED", fixture_id)
    if boolean(provenance["synthetic_or_generated"], "synthetic_or_generated"):
        raise err("L1E02_SYNTHETIC_OR_GENERATED_FORBIDDEN", fixture_id)
    origin_record_id = text(provenance["origin_record_id"], "origin_record_id", ident=True)

    permissions = obj(grant["permissions"], "permissions")
    perm_keys = {
        "commercial_engineering_use", "project_processing_submission",
        "reference_service_submission", "isolated_source_evaluation",
        "internal_stem_evaluation", "redistribution_allowed",
    }
    exact(permissions, perm_keys, perm_keys, "permissions")
    normalized_permissions = {key: boolean(permissions[key], f"permissions.{key}") for key in perm_keys}
    if not normalized_permissions["commercial_engineering_use"]:
        raise err("L1E02_COMMERCIAL_ENGINEERING_DENIED", fixture_id)
    if not normalized_permissions["project_processing_submission"]:
        raise err("L1E02_PROJECT_SUBMISSION_DENIED", fixture_id)
    if expected_group == "G1":
        if not normalized_permissions["isolated_source_evaluation"] or not normalized_permissions["internal_stem_evaluation"]:
            raise err("L1E02_G1_ISOLATED_SOURCE_RIGHTS_REQUIRED", fixture_id)
    elif expected_group == "G2":
        if not normalized_permissions["reference_service_submission"]:
            raise err("L1E02_G2_REFERENCE_SUBMISSION_REQUIRED", fixture_id)

    permission_profile = {
        "commercial_engineering_use": normalized_permissions["commercial_engineering_use"],
        "project_processing_submission": normalized_permissions["project_processing_submission"],
        "reference_service_submission": normalized_permissions["reference_service_submission"],
        "isolated_source_evaluation": normalized_permissions["isolated_source_evaluation"],
        "internal_stem_evaluation": normalized_permissions["internal_stem_evaluation"],
        "redistribution_allowed": normalized_permissions["redistribution_allowed"],
    }
    return {
        "rights_record_id": rights_record_id,
        "rights_record_ref_hash": hashlib.sha256(("lane1-golden-rights-ref-v1\0" + rights_record_id).encode("utf-8")).hexdigest(),
        "origin_record_ref_hash": hashed_ref("origin-record", origin_record_id),
        "source_document_sha256": source_sha,
        "effective_date": effective,
        "expires_date": expires,
        "permission_profile": permission_profile,
        "permission_profile_sha256": canonical_sha(permission_profile),
    }


def validate_rights_packet_from_report(*, corpus_root: Path | str, rights_root: Path | str, golden_report: Mapping[str, Any], rights_index: Mapping[str, Any], today: date | None = None) -> dict[str, Any]:
    corpus_root = Path(corpus_root).resolve()
    rights_root = Path(rights_root).resolve()
    if not corpus_root.is_dir():
        raise err("L1E02_CORPUS_ROOT_INVALID")
    if not rights_root.is_dir():
        raise err("L1E02_RIGHTS_ROOT_INVALID")
    if golden_report.get("intake_state") != "READY_FOR_HQ_GOLDEN_GATE":
        raise err("L1E02_A19_NOT_READY")
    if golden_report.get("parity_state") != "NON_PARITY_EVIDENCE_ONLY":
        raise err("L1E02_A19_PARITY_STATE_INVALID")
    corpus_lock = normalize_sha(golden_report.get("corpus_lock_sha256"), "golden_report.corpus_lock_sha256")
    index = validate_rights_index(rights_index)
    if index["corpus_id"] != golden_report.get("corpus_id") or index["corpus_revision"] != golden_report.get("corpus_revision"):
        raise err("L1E02_CORPUS_IDENTITY_MISMATCH")

    golden_rows = golden_report.get("fixtures")
    if not isinstance(golden_rows, list) or not golden_rows:
        raise err("L1E02_A19_FIXTURES_MISSING")
    golden_by_id = {str(row.get("fixture_id")): row for row in golden_rows if isinstance(row, Mapping)}
    if len(golden_by_id) != len(golden_rows):
        raise err("L1E02_A19_FIXTURE_ID_INVALID")
    rights_ids = {record["fixture_id"] for record in index["records"]}
    if rights_ids != set(golden_by_id):
        raise err("L1E02_RIGHTS_COVERAGE_MISMATCH")

    current = today or date.today()
    evidence_rows: list[dict[str, Any]] = []
    for record in sorted(index["records"], key=lambda item: item["fixture_id"]):
        fixture_id = record["fixture_id"]
        golden = obj(golden_by_id[fixture_id], f"golden.fixtures.{fixture_id}")
        if golden.get("group") != record["expected_group"]:
            raise err("L1E02_GROUP_MISMATCH", fixture_id)
        if golden.get("manifest_sha256") != record["fixture_manifest_sha256"]:
            raise err("L1E02_A19_MANIFEST_BINDING_MISMATCH", fixture_id)

        manifest_path = safe_file(corpus_root, record["fixture_manifest_path"], "fixture_manifest_path", "L1E02_FIXTURE_MANIFEST_MISSING")
        if sha256_file(manifest_path) != record["fixture_manifest_sha256"]:
            raise err("L1E02_FIXTURE_MANIFEST_SHA_MISMATCH", fixture_id)
        manifest = obj(load_json(manifest_path), f"fixture_manifest.{fixture_id}")
        if manifest.get("fixture_id") != fixture_id:
            raise err("L1E02_FIXTURE_ID_MISMATCH", fixture_id)
        if manifest.get("rights_status") != "VERIFIED":
            raise err("L1E02_MANIFEST_RIGHTS_NOT_VERIFIED", fixture_id)
        if manifest.get("real_recorded_music") is not True or manifest.get("synthetic") is not False:
            raise err("L1E02_MANIFEST_REAL_AUDIO_REQUIRED", fixture_id)
        if manifest.get("commercial_engineering_use_allowed") is not True:
            raise err("L1E02_MANIFEST_COMMERCIAL_DENIED", fixture_id)

        grant_path = safe_file(rights_root, record["grant_record_path"], "grant_record_path", "L1E02_GRANT_RECORD_MISSING")
        if sha256_file(grant_path) != record["grant_record_sha256"]:
            raise err("L1E02_GRANT_RECORD_SHA_MISMATCH", fixture_id)
        grant = validate_grant(load_json(grant_path), fixture_id=fixture_id, expected_group=record["expected_group"], rights_root=rights_root, today=current)
        raw_rights_id = text(manifest.get("rights_record_id"), "manifest.rights_record_id", ident=True)
        if raw_rights_id != grant["rights_record_id"]:
            raise err("L1E02_RIGHTS_RECORD_ID_MISMATCH", fixture_id)
        if grant["rights_record_ref_hash"] != golden.get("rights_record_ref_hash"):
            raise err("L1E02_A19_RIGHTS_REF_MISMATCH", fixture_id)
        if manifest.get("reference_service_submission_allowed") is True and not grant["permission_profile"]["reference_service_submission"]:
            raise err("L1E02_MANIFEST_REFERENCE_RIGHT_OVERCLAIM", fixture_id)
        if record["expected_group"] == "G2" and manifest.get("reference_service_submission_allowed") is not True:
            raise err("L1E02_G2_MANIFEST_REFERENCE_RIGHT_REQUIRED", fixture_id)

        evidence_rows.append({
            "fixture_id": fixture_id,
            "group": record["expected_group"],
            "manifest_sha256": record["fixture_manifest_sha256"],
            "mixture_sha256": golden.get("mixture_sha256"),
            "reference_sha256_by_role": dict(sorted(obj(golden.get("reference_sha256_by_role", {}), "reference_sha256_by_role").items())),
            "grant_record_sha256": record["grant_record_sha256"],
            "rights_record_ref_hash": grant["rights_record_ref_hash"],
            "origin_record_ref_hash": grant["origin_record_ref_hash"],
            "source_document_sha256": grant["source_document_sha256"],
            "effective_date": grant["effective_date"],
            "expires_date": grant["expires_date"],
            "permission_profile_sha256": grant["permission_profile_sha256"],
        })

    intake_lock = hashlib.sha256((
        "lane1-e02-rights-intake-v1\0" + corpus_lock + "\0" +
        json.dumps(evidence_rows, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)
    ).encode("utf-8")).hexdigest()
    return {
        "schema_version": 1,
        "tool_version": TOOL_VERSION,
        "evidence_kind": "RIGHTS_CLEARED_REAL_AUDIO_INTAKE",
        "evidence_state": EVIDENCE_STATE,
        "intake_state": "READY_FOR_HQ_LIVE_AUDIO_GATE",
        "parity_state": "NON_PARITY_EVIDENCE_ONLY",
        "corpus_id": index["corpus_id"],
        "corpus_revision": index["corpus_revision"],
        "a19_corpus_lock_sha256": corpus_lock,
        "e02_rights_intake_lock_sha256": intake_lock,
        "fixtures": evidence_rows,
        "privacy": {
            "raw_rights_record_ids_emitted": False,
            "raw_origin_record_ids_emitted": False,
            "contract_paths_emitted": False,
            "contract_text_emitted": False,
            "media_paths_emitted": False,
            "media_titles_emitted": False,
            "raw_audio_emitted": False,
        },
        "limitations": {
            "waveform_proves_human_recording": False,
            "provenance_requires_verified_private_attestation": True,
            "hq_final_rights_judgment_required": True,
        },
        "parity_reason": "E02 binds A19-validated real-audio candidates to private rights/provenance evidence; live provider, reference differential, human review, device evidence and HQ PARITY remain separate gates.",
    }


def validate_e02_files(*, corpus_root: Path | str, a19_index_path: Path | str, a19_policy_path: Path | str, rights_root: Path | str, rights_index_path: Path | str) -> dict[str, Any]:
    corpus_root = Path(corpus_root).resolve()
    rights_root = Path(rights_root).resolve()
    golden = validate_golden_corpus_files(root=corpus_root, index_path=a19_index_path, policy_path=a19_policy_path)
    rights_index_file = safe_file(rights_root, rights_index_path, "rights_index_path", "L1E02_RIGHTS_INDEX_MISSING")
    return validate_rights_packet_from_report(
        corpus_root=corpus_root,
        rights_root=rights_root,
        golden_report=golden,
        rights_index=obj(load_json(rights_index_file), "rights_index"),
    )


def atomic_dump(path: Path | str, payload: Mapping[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name("." + target.name + ".tmp")
    try:
        with tmp.open("w", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, target)
    except OSError as exc:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        raise err("L1E02_REPORT_WRITE_FAILED") from exc


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Lane 1 E02 rights-cleared real-audio intake")
    parser.add_argument("--corpus-root", required=True)
    parser.add_argument("--a19-index", required=True)
    parser.add_argument("--a19-policy", required=True)
    parser.add_argument("--rights-root", required=True)
    parser.add_argument("--rights-index", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)
    try:
        report = validate_e02_files(
            corpus_root=args.corpus_root,
            a19_index_path=args.a19_index,
            a19_policy_path=args.a19_policy,
            rights_root=args.rights_root,
            rights_index_path=args.rights_index,
        )
        atomic_dump(args.out, report)
    except EvaluationError as exc:
        print(exc.code, file=sys.stderr)
        return 2
    print(report["e02_rights_intake_lock_sha256"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
