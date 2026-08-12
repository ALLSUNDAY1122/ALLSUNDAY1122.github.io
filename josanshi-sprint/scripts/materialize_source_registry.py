#!/usr/bin/env python3
import json
from pathlib import Path

from source_registry_loader import load_sources

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "source-registry.json"

sources, paths = load_sources()
main = json.loads(OUTPUT.read_text(encoding="utf-8"))
payload = {
    "schemaVersion": "materialized-1.0",
    "qualification": "助産師国家試験",
    "checkedAt": "2026-08-13",
    "policy": main.get("policy", {}),
    "sources": sources,
    "materializedFrom": [path.name for path in paths],
    "openCoverage": main.get("openCoverage", {}),
}
OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"PASS: materialized {len(sources)} sources from {len(paths)} registry files")
