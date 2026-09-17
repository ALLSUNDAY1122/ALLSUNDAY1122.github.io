#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def normalized(text: str) -> str:
    return re.sub(r"\s+", "", text or "")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--overrides", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    items = json.loads(args.input.read_text(encoding="utf-8"))
    doc = json.loads(args.overrides.read_text(encoding="utf-8"))
    patches = doc.get("items") or {}
    if not isinstance(items, list) or not items:
        raise SystemExit("FAIL: input must be non-empty list")
    if not isinstance(patches, dict) or not patches:
        raise SystemExit("FAIL: overrides.items must be non-empty object")

    by_id = {item.get("id"): item for item in items}
    unknown = sorted(set(patches) - set(by_id))
    if unknown:
        raise SystemExit(f"FAIL: unknown override IDs: {unknown}")

    for qid, rows in patches.items():
        item = by_id[qid]
        notes = item.get("distractor_notes")
        choices = item.get("choices") or []
        answer = item.get("answer")
        if not isinstance(notes, list) or len(notes) != len(choices):
            raise SystemExit(f"FAIL: {qid}: current distractor note structure invalid")
        if not isinstance(rows, dict) or not rows:
            raise SystemExit(f"FAIL: {qid}: override rows must be non-empty object")
        changed = []
        for raw_index, replacement in rows.items():
            index = int(raw_index)
            if not 0 <= index < len(choices):
                raise SystemExit(f"FAIL: {qid}: override index out of range {index}")
            if index == answer:
                raise SystemExit(f"FAIL: {qid}: cannot override correct-choice note")
            if not isinstance(replacement, str) or len(normalized(replacement)) < 12:
                raise SystemExit(f"FAIL: {qid}: replacement note too shallow at {index}")
            notes[index] = replacement.strip()
            changed.append(index)
        item["distractor_notes"] = notes
        item["distractor_override_evidence"] = {
            "version": doc.get("version"),
            "checked_at": doc.get("checkedAt"),
            "reason": doc.get("reason"),
            "changed_indices": sorted(changed),
        }

    args.output.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: applied distractor-note overrides to {len(patches)} items")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
