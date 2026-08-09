#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def main() -> int:
    base = Path(__file__).resolve().parent
    questions = json.loads((base / "data/questions.json").read_text(encoding="utf-8"))
    errors = []

    for q in questions:
        if not q.get("asset_required"):
            continue
        qid = q.get("id", "?")
        if q.get("asset_status") != "ready":
            errors.append(f"{qid}: asset_status={q.get('asset_status')}")
        if not q.get("asset_path"):
            errors.append(f"{qid}: asset_path missing")

    if errors:
        print("FAIL: AP figure/table asset audit")
        for error in errors:
            print(f"- {error}")
        return 1

    print("PASS: all required AP figure/table assets are ready")
    return 0


if __name__ == "__main__":
    sys.exit(main())
