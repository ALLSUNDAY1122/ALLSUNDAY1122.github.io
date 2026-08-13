#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "content" / "questions.canonical.json"
RELEASE = ROOT / "content" / "questions.release-ready.json"
BUNDLED = ROOT / "NativePackage" / "Sources" / "HokenshiSprintFeature" / "Resources" / "questions.json"
MANIFEST = ROOT / "content" / "release-manifest.json"
BASELINE = "2026-08-13"


def compact_hash(rows: list[dict]) -> str:
    payload = json.dumps(rows, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def main() -> None:
    rows = json.loads(CANONICAL.read_text(encoding="utf-8"))
    if len(rows) != 330:
        raise RuntimeError(f"release requires 330 canonical questions, got {len(rows)}")

    ids: set[str] = set()
    release_rows: list[dict] = []
    for row in rows:
        label = row.get("id", "unknown")
        if label in ids:
            raise RuntimeError(f"duplicate id at promotion: {label}")
        ids.add(label)
        if row.get("origin_type") != "original_from_primary_source":
            raise RuntimeError(f"{label}: non-original content cannot be promoted")
        if not str(row.get("rights_basis", "")).strip():
            raise RuntimeError(f"{label}: rights_basis missing")
        if not str(row.get("source_url", "")).startswith("https://"):
            raise RuntimeError(f"{label}: primary source URL must be https")
        if row.get("source_checked_at") != BASELINE:
            raise RuntimeError(f"{label}: source_checked_at must be {BASELINE}")
        if row.get("law_baseline_date") != BASELINE:
            raise RuntimeError(f"{label}: law_baseline_date must be {BASELINE}")
        promoted = dict(row)
        promoted["audit_status"] = "release_ready"
        release_rows.append(promoted)

    digest = compact_hash(release_rows)
    RELEASE.parent.mkdir(parents=True, exist_ok=True)
    BUNDLED.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(release_rows, ensure_ascii=False, indent=2) + "\n"
    RELEASE.write_text(payload, encoding="utf-8")
    BUNDLED.write_text(payload, encoding="utf-8")
    MANIFEST.write_text(
        json.dumps(
            {
                "app_key": "hokenshi-sprint",
                "generated_at": BASELINE,
                "question_count": 330,
                "rounds": 3,
                "questions_per_round": 110,
                "audit_status": "release_ready",
                "sha256": digest,
                "source": "questions.canonical.json after canonical/current-guidance gates",
            },
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print(f"PASS: promoted={len(release_rows)} sha256={digest}")
    print(f"release={RELEASE}")
    print(f"bundled={BUNDLED}")


if __name__ == "__main__":
    main()
