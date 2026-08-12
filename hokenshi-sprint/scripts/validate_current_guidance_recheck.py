#!/usr/bin/env python3
from __future__ import annotations

import glob
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT_GLOB = str(ROOT / "content" / "audits" / "phn-guidance-2026-05-15-recheck*.json")
AUTHORED_GLOB = str(ROOT / "content" / "authored" / "*.json")
CURRENT_URL = "https://www.mhlw.go.jp/content/10900000/001707327.pdf"


def main() -> int:
    errors: list[str] = []
    audit_records: list[dict] = []
    audit_files = sorted(glob.glob(AUDIT_GLOB))
    if not audit_files:
        print("FAIL: current-guidance audit manifest missing")
        return 1

    for filename in audit_files:
        audit = json.loads(Path(filename).read_text(encoding="utf-8"))
        if audit.get("result") != "pass":
            errors.append(f"{Path(filename).name}: audit result must be pass")
        if audit.get("canonical_source_url") != CURRENT_URL:
            errors.append(f"{Path(filename).name}: canonical S03 source URL is not current")
        if audit.get("checked_at") != "2026-08-13":
            errors.append(f"{Path(filename).name}: checked_at mismatch")
        for record in audit.get("records", []):
            if record.get("decision") != "pass":
                errors.append(f"{record.get('id')}: decision must be pass")
            if not record.get("basis"):
                errors.append(f"{record.get('id')}: basis missing")
            audit_records.append(record)

    audit_id_counts = Counter(record.get("id") for record in audit_records)
    duplicate_audit_ids = sorted(key for key, count in audit_id_counts.items() if key and count > 1)
    if duplicate_audit_ids:
        errors.append(f"duplicate audit IDs across manifests: {duplicate_audit_ids}")

    authored: list[dict] = []
    for filename in sorted(glob.glob(AUTHORED_GLOB)):
        authored.extend(json.loads(Path(filename).read_text(encoding="utf-8")))

    s03_ids = {row["id"] for row in authored if "S03" in row.get("source_refs", [])}
    audited_ids = {row.get("id") for row in audit_records if row.get("decision") == "pass"}

    missing = sorted(s03_ids - audited_ids)
    extra = sorted(audited_ids - s03_ids)
    if missing:
        errors.append(f"S03 authored questions not rechecked: {missing}")
    if extra:
        errors.append(f"audit contains unknown/non-S03 IDs: {extra}")

    print("=== Current PHN Guidance Recheck ===")
    print(f"audit_manifests={len(audit_files)}")
    print(f"S03-linked authored={len(s03_ids)} audited={len(audited_ids)}")
    print(f"canonical={CURRENT_URL}")
    if errors:
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("PASS: all currently authored S03-linked questions are explicitly rechecked against 2026-05-15 guidance")
    print("NOTE: this does not promote drafted questions to release_ready.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
