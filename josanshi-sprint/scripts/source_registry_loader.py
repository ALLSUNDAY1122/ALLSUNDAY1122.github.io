#!/usr/bin/env python3
import json
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]


def registry_paths() -> Iterable[Path]:
    return sorted((ROOT / "data").glob("source-registry*.json"))


def load_sources() -> tuple[list[dict], list[Path]]:
    sources: list[dict] = []
    paths = list(registry_paths())
    if not paths:
        raise RuntimeError("No source-registry*.json files found")
    for path in paths:
        payload = json.loads(path.read_text(encoding="utf-8"))
        if payload.get("qualification") != "助産師国家試験":
            raise RuntimeError(f"{path.name}: qualification mismatch")
        batch = payload.get("sources")
        if not isinstance(batch, list):
            raise RuntimeError(f"{path.name}: sources must be an array")
        sources.extend(batch)
    ids = [source.get("id") for source in sources]
    if len(ids) != len(set(ids)):
        duplicates = sorted({sid for sid in ids if ids.count(sid) > 1})
        raise RuntimeError(f"Duplicate source IDs across registries: {duplicates}")
    return sources, paths


def load_source_map() -> dict[str, dict]:
    sources, _ = load_sources()
    return {source["id"]: source for source in sources}
