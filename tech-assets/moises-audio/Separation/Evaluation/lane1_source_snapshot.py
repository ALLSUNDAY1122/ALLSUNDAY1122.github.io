#!/usr/bin/env python3
"""Deterministic Lane 1 owned-source snapshot for L1-A26 audit provenance.

Engineering evidence only. This does not make or promote a PARITY claim.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
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


def _verify_git_owned_tree_binding(audio_root: Path, entries: list[dict]) -> None:
    """Fail closed when a git-backed Lane snapshot is not the exact HEAD-owned tree.

    `git rev-parse HEAD` alone proves only the ref, not that the working tree bytes
    match that commit. This check binds the durable Separation/Processing file set
    and tracked content state to HEAD. A non-git standalone snapshot remains valid;
    the full A26 runner separately requires git HEAD availability.
    """
    root = audio_root.resolve()
    try:
        repo_root = root.parents[1]
    except IndexError:
        return

    probe = subprocess.run(
        ["git", "-C", str(repo_root), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if probe.returncode != 0:
        return
    try:
        if Path((probe.stdout or "").strip()).resolve() != repo_root.resolve():
            raise SourceSnapshotError("L1A26_GIT_TREE_BINDING_UNAVAILABLE")
        audio_rel = root.relative_to(repo_root.resolve()).as_posix()
    except (OSError, ValueError) as exc:
        raise SourceSnapshotError("L1A26_GIT_TREE_BINDING_UNAVAILABLE") from exc

    scopes = [f"{audio_rel}/Separation", f"{audio_rel}/Processing"]
    try:
        status = subprocess.run(
            [
                "git",
                "-C",
                str(repo_root),
                "status",
                "--porcelain=v1",
                "--untracked-files=no",
                "--",
                *scopes,
            ],
            capture_output=True,
            text=True,
            timeout=20,
        )
        tree = subprocess.run(
            [
                "git",
                "-C",
                str(repo_root),
                "ls-tree",
                "-r",
                "--name-only",
                "HEAD",
                "--",
                *scopes,
            ],
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SourceSnapshotError("L1A26_GIT_TREE_BINDING_UNAVAILABLE") from exc

    if status.returncode != 0 or tree.returncode != 0:
        raise SourceSnapshotError("L1A26_GIT_TREE_BINDING_UNAVAILABLE")
    if (status.stdout or "").strip():
        raise SourceSnapshotError("L1A26_OWNED_WORKTREE_DIRTY")

    expected_paths = {
        line.strip()
        for line in (tree.stdout or "").splitlines()
        if line.strip()
    }
    actual_paths = {
        f"{audio_rel}/{entry['path']}"
        for entry in entries
    }
    if expected_paths != actual_paths:
        raise SourceSnapshotError("L1A26_OWNED_TREE_MISMATCH")


def build_source_snapshot(audio_root: Path, *, excludes: Iterable[Path] | None = None) -> dict:
    """Hash all durable regular files in Worker 1 owned Separation/Processing scopes.

    Symlinks fail closed because a snapshot must bind repository bytes, not an external target.
    Runtime-generated cache/temp/lock files are excluded. Explicit excludes are intended for
    an audit report output path when that output is placed below the Lane root.

    When the supplied Lane root belongs to a git checkout, the snapshot additionally fails
    closed unless tracked Separation/Processing files are clean and the durable on-disk file
    set exactly matches the files tracked at HEAD. This prevents a correct HEAD ref from
    masking modified, missing, untracked, or ignored durable owned files.
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

    _verify_git_owned_tree_binding(root, entries)

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
