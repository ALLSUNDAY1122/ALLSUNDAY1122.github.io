#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

ALLOWED_FIELDS = {"question", "explanation", "memory"}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--overrides", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    items = load(args.input)
    doc = load(args.overrides)
    overrides = doc.get("items") or {}
    if not isinstance(items, list) or not items:
        raise SystemExit("FAIL: editorial input must be a non-empty JSON array")
    if not isinstance(overrides, dict) or not overrides:
        raise SystemExit("FAIL: editorial overrides must contain non-empty items object")

    by_id = {item.get("id"): item for item in items}
    unknown = sorted(set(overrides) - set(by_id))
    if unknown:
        raise SystemExit(f"FAIL: editorial overrides reference unknown IDs: {unknown}")

    for qid, changes in overrides.items():
        if not isinstance(changes, dict) or not changes:
            raise SystemExit(f"FAIL: {qid}: override must be non-empty object")
        illegal = sorted(set(changes) - ALLOWED_FIELDS)
        if illegal:
            raise SystemExit(f"FAIL: {qid}: editorial override cannot change {illegal}")
        item = by_id[qid]
        for field, value in changes.items():
            if not isinstance(value, str) or not value.strip():
                raise SystemExit(f"FAIL: {qid}: {field} override must be non-empty string")
            item[field] = value.strip()
        item["editorial_evidence"] = {
            "version": doc.get("version"),
            "checked_at": doc.get("checkedAt"),
            "reason": doc.get("reason"),
            "changed_fields": sorted(changes),
        }

    args.output.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: applied audited editorial overrides to {len(overrides)} items")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
