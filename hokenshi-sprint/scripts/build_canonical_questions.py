#!/usr/bin/env python3
from __future__ import annotations

import glob
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTHORED_GLOB = str(ROOT / "content" / "authored" / "*.json")
OVERRIDE_GLOB = str(ROOT / "content" / "overrides" / "*.json")
PLAN_PATH = ROOT / "content" / "question-plan.generated.json"
OUT = ROOT / "content" / "questions.canonical.json"
CURRENT_PHN_URL = "https://www.mhlw.go.jp/content/10900000/001707327.pdf"
CURRENT_PHN_TITLE = "地域における保健師の保健活動について（令和8年5月15日健生発0515第1号）"
OLD_PHN_URL_FRAGMENT = "dataId=00tb9310"


def load_many(pattern: str) -> list[tuple[str, dict]]:
    rows: list[tuple[str, dict]] = []
    for filename in sorted(glob.glob(pattern)):
        for row in json.loads(Path(filename).read_text(encoding="utf-8")):
            rows.append((filename, row))
    return rows


def normalize_superseded_source_metadata(row: dict) -> dict:
    normalized = dict(row)
    title = str(normalized.get("source_title", ""))
    source_url = str(normalized.get("source_url", ""))
    if "地域における保健師の保健活動" in title and OLD_PHN_URL_FRAGMENT in source_url:
        normalized["source_title"] = CURRENT_PHN_TITLE
        normalized["source_url"] = CURRENT_PHN_URL
    return normalized


def main() -> None:
    plan = json.loads(PLAN_PATH.read_text(encoding="utf-8"))
    plan_ids = {row["id"] for row in plan}

    authored_pairs = load_many(AUTHORED_GLOB)
    canonical: dict[str, dict] = {}
    duplicate_authored: set[str] = set()
    authored_ids: set[str] = set()
    for _, source_row in authored_pairs:
        row = normalize_superseded_source_metadata(source_row)
        row_id = row["id"]
        if row_id in canonical:
            duplicate_authored.add(row_id)
        canonical[row_id] = row
        authored_ids.add(row_id)

    override_pairs = load_many(OVERRIDE_GLOB)
    override_ids: set[str] = set()
    layered: list[str] = []
    for filename, source_row in override_pairs:
        row = normalize_superseded_source_metadata(source_row)
        row_id = row["id"]
        if row_id not in plan_ids:
            raise RuntimeError(f"override id not in 330 plan: {row_id}")
        if row_id in override_ids:
            layered.append(f"{row_id} <- {Path(filename).name}")
        override_ids.add(row_id)
        canonical[row_id] = row

    missing = sorted(plan_ids - canonical.keys())
    extra = sorted(canonical.keys() - plan_ids)
    if missing or extra:
        raise RuntimeError(f"canonical coverage mismatch missing={missing} extra={extra}")

    ordered = sorted(canonical.values(), key=lambda row: (row["round"], row["question_number"], row["id"]))
    if len(ordered) != 330:
        raise RuntimeError(f"expected 330 canonical questions, got {len(ordered)}")

    OUT.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    normalized_count = sum(
        row.get("source_title") == CURRENT_PHN_TITLE and row.get("source_url") == CURRENT_PHN_URL
        for row in ordered
    )
    print(f"authored_fragments={len(authored_pairs)} override_records={len(override_pairs)} canonical={len(ordered)}")
    print(f"replaced_existing={len(override_ids & authored_ids)} added_missing={len(override_ids - authored_ids)}")
    print(f"current_phn_primary_records={normalized_count}")
    if duplicate_authored:
        print(f"note: duplicate authored fragment ids were superseded deterministically: {sorted(duplicate_authored)}")
    if layered:
        print("layered overrides (later filename wins):")
        for value in layered:
            print(f"- {value}")
    print(f"wrote={OUT}")


if __name__ == "__main__":
    main()
