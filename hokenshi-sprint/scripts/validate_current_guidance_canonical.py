#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "content" / "questions.canonical.json"
CURRENT_URL = "https://www.mhlw.go.jp/content/10900000/001707327.pdf"
CHECKED_AT = "2026-08-13"


def main() -> int:
    rows = json.loads(CANONICAL.read_text(encoding="utf-8"))
    linked = [row for row in rows if "S03" in row.get("source_refs", [])]
    errors: list[str] = []
    for row in linked:
        label = row["id"]
        if row.get("source_url") != CURRENT_URL:
            errors.append(f"{label}: S03-linked question does not point to current 2026-05-15 guidance")
        if row.get("source_checked_at") != CHECKED_AT:
            errors.append(f"{label}: source_checked_at must be {CHECKED_AT}")
        if row.get("law_baseline_date") != CHECKED_AT:
            errors.append(f"{label}: law_baseline_date must be {CHECKED_AT}")

    print("=== Current PHN Guidance Canonical Audit ===")
    print(f"S03-linked canonical questions={len(linked)}")
    if errors:
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("PASS: every S03-linked canonical question uses the 2026-05-15 MHLW guidance and current check date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
