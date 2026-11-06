#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--notes", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    items = load(args.input)
    notes_doc = load(args.notes)
    notes = notes_doc.get("items") or {}
    ids = [item.get("id") for item in items]
    if set(ids) != set(notes):
        missing = sorted(set(ids) - set(notes))
        extra = sorted(set(notes) - set(ids))
        raise SystemExit(f"FAIL: distractor coverage mismatch missing={missing} extra={extra}")

    for item in items:
        qid = item["id"]
        row = notes[qid]
        choices = item.get("choices") or []
        answer = item.get("answer")
        if not isinstance(row, list) or len(row) != len(choices):
            raise SystemExit(f"FAIL: {qid}: distractor note count mismatch")
        for index, note in enumerate(row):
            if index == answer:
                if note not in (None, ""):
                    raise SystemExit(f"FAIL: {qid}: correct choice must have null distractor note")
            elif not isinstance(note, str) or len("".join(note.split())) < 12:
                raise SystemExit(f"FAIL: {qid}: shallow distractor note at {index}")
        item["distractor_notes"] = row
        item["distractor_evidence"] = {
            "version": notes_doc.get("version"),
            "checked_at": notes_doc.get("checkedAt"),
        }

    args.output.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: merged distractor rationales into {len(items)} staged items")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
