#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "questions" / "original-mock.json"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    data = json.loads(PATH.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("dataset must be an array")

    before = collections.Counter(q.get("correct_index") for q in data)
    changed = 0
    for i, q in enumerate(data):
        choices = list(q["choices"])
        old = int(q["correct_index"])
        if not 0 <= old < len(choices):
            raise SystemExit(f"{q.get('id')}: invalid correct_index")
        correct_choice = choices[old]
        distractors = [c for j, c in enumerate(choices) if j != old]
        target = i % 4
        new_choices = distractors[:]
        new_choices.insert(target, correct_choice)
        if new_choices != choices or target != old:
            changed += 1
        q["choices"] = new_choices
        q["correct_index"] = target

    after = collections.Counter(q["correct_index"] for q in data)
    print(f"before={dict(sorted(before.items()))} after={dict(sorted(after.items()))} changed={changed}/{len(data)}")
    if args.apply:
        PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    elif changed:
        raise SystemExit("rebalancing required; rerun with --apply")


if __name__ == "__main__":
    main()
