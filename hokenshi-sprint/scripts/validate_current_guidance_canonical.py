#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "content" / "questions.canonical.json"
CURRENT_URL = "https://www.mhlw.go.jp/content/10900000/001707327.pdf"
OLD_URL_FRAGMENT = "dataId=00tb9310"
CHECKED_AT = "2026-08-13"


def is_phn_guidance_primary(row: dict) -> bool:
    title = str(row.get("source_title", ""))
    return "地域における保健師の保健活動" in title


def main() -> int:
    rows = json.loads(CANONICAL.read_text(encoding="utf-8"))
    linked = [row for row in rows if "S03" in row.get("source_refs", [])]
    primary = [row for row in linked if is_phn_guidance_primary(row)]
    supplemental = [row for row in linked if not is_phn_guidance_primary(row)]
    errors: list[str] = []

    for row in linked:
        label = row["id"]
        if row.get("source_checked_at") != CHECKED_AT:
            errors.append(f"{label}: S03-linked source_checked_at must be {CHECKED_AT}")
        if row.get("law_baseline_date") != CHECKED_AT:
            errors.append(f"{label}: S03-linked law_baseline_date must be {CHECKED_AT}")
        if OLD_URL_FRAGMENT in str(row.get("source_url", "")):
            errors.append(f"{label}: superseded 2013 PHN guidance URL remains in canonical source_url")

    for row in primary:
        if row.get("source_url") != CURRENT_URL:
            errors.append(f"{row['id']}: PHN guidance is primary but URL is not the 2026-05-15 notice")

    print("=== Current PHN Guidance Canonical Audit ===")
    print(f"S03-linked={len(linked)} primary={len(primary)} supplemental={len(supplemental)}")
    print(f"canonical_current_url={CURRENT_URL}")
    if errors:
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("PASS: S03 primary sources use the current notice; supplemental S03 references retain their own primary source and current recheck date; superseded URL absent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
