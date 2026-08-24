#!/usr/bin/env python3
"""Deterministic Lane 1 owned-source snapshot for L1-A26 audit provenance.

Engineering evidence only. This does not make or promote a PARITY claim.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Iterable

TOOL_VERSION = "L1-A26-SOURCE-SNAPSHOT-v1"
EVIDENCE_STATE = "NON_PARITY_EVIDENCE_ONLY"
_EXCLUDED_DIR_NAMES = {"__pycache__", ".pytest_cache", ".mypy_cache"}
_EXCLUDED_FILE_NAMES = {".DS_Store"}
_EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".tmp", ".lock"}


class SourceSnapshotError(RuntimeError):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


def _canonical_bytes(value) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                h.update(chunk)
    except OSError as exc:
        raise SourceSnapshotError("L1A26_SOURCE_FILE_UNREADABLE") from exc
    return h.hexdigest()


def _normalize_excludes(audio_root: Path, excludes: Iterable[Path] | None) -> set[Path]:
    root = audio_root.resolve()
    out: set[Path] = set()
    for path in excludes or ():
        try:
            resolved = Path(path).resolve()
            resolved.relative_to(root)
        except (OSError, ValueError) as exc:
            raise SourceSnapshotError("L1A26_SOURCE_EXCLUDE_OUTSIDE_ROOT") from exc
        out.add(resolved)
    return out


def _eligible(path: Path) -> bool:
    if path.name in _EXCLUDED_FILE_NAMES or path.suffix.lower() in _EXCLUDED_SUFFIXES:
        return False
    return not any(part in _EXCLUDED_DIR_NAMES for part in path.parts)


def build_source_snapshot(audio_root: Path, *, excludes: Iterable[Path] | None = None) -> dict:
    """Hash all durable regular files in Worker 1 owned Separation/Processing scopes.

    Symlinks fail closed because a snapshot must bind repository bytes, not an external target.
    Runtime-generated cache/temp/lock files are excluded. Explicit excludes are intended for
    an audit report output path when that output is placed below the Lane root.
    """
    root = Path(audio_root).resolve()
    if not root.is_dir():
        raise SourceSnapshotError("L1A26_AUDIO_ROOT_MISSING")
    excluded = _normalize_excludes(root, excludes)
    entries: list[dict] = []
    for scope_name in ("Separation", "Processing"):
        scope = root / scope_name
        if not scope.is_dir():
            raise SourceSnapshotError("L1A26_OWNED_SCOPE_MISSING")
        for path in sorted(scope.rglob("*"), key=lambda p: p.as_posix()):
            if not _eligible(path):
                continue
            if path.is_symlink():
                raise SourceSnapshotError("L1A26_SOURCE_SYMLINK_FORBIDDEN")
            if not path.is_file():
                continue
            resolved = path.resolve()
            try:
                rel = resolved.relative_to(root).as_posix()
            except ValueError as exc:
                raise SourceSnapshotError("L1A26_SOURCE_PATH_OUTSIDE_ROOT") from exc
            if resolved in excluded:
                continue
            try:
                size = resolved.stat().st_size
            except OSError as exc:
                raise SourceSnapshotError("L1A26_SOURCE_FILE_STAT_FAILED") from exc
            entries.append({"path": rel, "bytes": size, "sha256": _sha256_file(resolved)})
    if not entries:
        raise SourceSnapshotError("L1A26_SOURCE_SNAPSHOT_EMPTY")
    semantic = {
        "domain": "l1-a26-owned-source-snapshot-v1",
        "files": entries,
    }
    return {
        "schema_version": 1,
        "tool_version": TOOL_VERSION,
        "evidence_state": EVIDENCE_STATE,
        "scope": ["Separation/**", "Processing/**"],
        "file_count": len(entries),
        "files": entries,
        "source_snapshot_sha256": hashlib.sha256(_canonical_bytes(semantic)).hexdigest(),
        "parity_claim": "NONE",
    }


def verify_expected_snapshot(snapshot: dict, expected_sha256: str | None) -> dict:
    actual = snapshot.get("source_snapshot_sha256")
    if expected_sha256 is None:
        return {"state": "NOT_REQUESTED", "expected": None, "actual": actual}
    if not isinstance(expected_sha256, str) or len(expected_sha256) != 64:
        raise SourceSnapshotError("L1A26_EXPECTED_SOURCE_SNAPSHOT_INVALID")
    try:
        int(expected_sha256, 16)
    except ValueError as exc:
        raise SourceSnapshotError("L1A26_EXPECTED_SOURCE_SNAPSHOT_INVALID") from exc
    expected = expected_sha256.lower()
    return {
        "state": "PASS" if actual == expected else "FAIL",
        "expected": expected,
        "actual": actual,
    }
