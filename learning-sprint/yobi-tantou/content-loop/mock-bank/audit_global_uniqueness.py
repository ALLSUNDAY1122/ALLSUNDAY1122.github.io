#!/usr/bin/env python3
import argparse
import difflib
import json
import re
from pathlib import Path


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def normalized(text: str) -> str:
    return re.sub(r"[\s、。・『』「」（）()\[\]!?！？:：;；]+", "", text or "")


def stem(item: dict) -> str:
    return str(item.get("question") or item.get("stem") or "")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--expansion", type=Path, required=True)
    parser.add_argument("--threshold", type=float, default=0.84)
    args = parser.parse_args()

    base = load(args.base)
    expansion = load(args.expansion)
    if not isinstance(base, list) or not isinstance(expansion, list) or not expansion:
        raise SystemExit("FAIL: base and expansion must be JSON arrays; expansion non-empty")

    base_ids = {item.get("id") for item in base}
    expansion_ids = [item.get("id") for item in expansion]
    if any(not qid for qid in expansion_ids) or len(expansion_ids) != len(set(expansion_ids)):
        raise SystemExit("FAIL: expansion has missing or duplicate IDs")
    overlap = sorted(base_ids & set(expansion_ids))
    if overlap:
        raise SystemExit(f"FAIL: ID overlap with release bank: {overlap}")

    failures = []
    pairs = []
    for new in expansion:
        new_text = normalized(stem(new))
        if not new_text:
            failures.append(f"{new.get('id')}: empty question text")
            continue
        for old in base:
            old_text = normalized(stem(old))
            if not old_text:
                continue
            ratio = difflib.SequenceMatcher(None, new_text, old_text).ratio()
            if ratio >= args.threshold:
                pairs.append({"new": new["id"], "old": old.get("id"), "ratio": round(ratio, 3)})
                failures.append(f"near duplicate {ratio:.3f}: {new['id']} <-> {old.get('id')}")

    if failures:
        print("FAIL: global uniqueness audit")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"PASS: expansion {len(expansion)} items has no ID overlap or >= {args.threshold:.2f} stem similarity against base {len(base)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
