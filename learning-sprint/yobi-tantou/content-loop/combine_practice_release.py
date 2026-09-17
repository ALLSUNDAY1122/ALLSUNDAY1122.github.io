#!/usr/bin/env python3
"""Combine independently audited practice tiers into one formal practice bank.

Every input tier must already be release_passed. This combiner refuses official
mock content, exam-year labels, duplicate IDs, missing/unknown difficulty, or a
tier whose declared difficulty does not match its items.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

DIFFICULTIES = {"foundation", "standard", "applied"}


class CombineError(ValueError):
    pass


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def combine(tiers: list[tuple[str, list[dict]]]) -> list[dict]:
    if not tiers:
        raise CombineError("at least one practice tier is required")

    combined: list[dict] = []
    seen_ids: set[str] = set()
    seen_difficulties: set[str] = set()

    for declared_difficulty, items in tiers:
        if declared_difficulty not in DIFFICULTIES:
            raise CombineError(f"unknown declared difficulty: {declared_difficulty}")
        if not isinstance(items, list) or not items:
            raise CombineError(f"{declared_difficulty}: release tier must be non-empty")
        if declared_difficulty in seen_difficulties:
            raise CombineError(f"duplicate tier: {declared_difficulty}")
        seen_difficulties.add(declared_difficulty)

        for item in items:
            qid = item.get("id")
            if not qid:
                raise CombineError(f"{declared_difficulty}: missing id")
            if qid in seen_ids:
                raise CombineError(f"duplicate question id across tiers: {qid}")
            seen_ids.add(qid)

            if item.get("difficulty") != declared_difficulty:
                raise CombineError(f"{qid}: difficulty does not match declared tier")
            if item.get("audit_status") != "release_passed" or item.get("release_eligible") is not True:
                raise CombineError(f"{qid}: only release_passed items may be combined")
            if item.get("content_use") != "practice":
                raise CombineError(f"{qid}: only practice content may enter combined bank")
            if item.get("exam_year") is not None:
                raise CombineError(f"{qid}: practice item cannot carry official exam year")
            if item.get("origin_type") == "official_exam_reproduced":
                raise CombineError(f"{qid}: official exam reproduction cannot enter practice bank")
            combined.append(item)

    if len(combined) != len(seen_ids):
        raise CombineError("combined count invariant violated")
    return combined


def fixture(qid: str, difficulty: str) -> dict:
    return {
        "id": qid,
        "difficulty": difficulty,
        "audit_status": "release_passed",
        "release_eligible": True,
        "content_use": "practice",
        "origin_type": "original_from_primary_source",
    }


def self_test() -> None:
    result = combine([
        ("foundation", [fixture("F1", "foundation")]),
        ("standard", [fixture("S1", "standard")]),
    ])
    assert [item["id"] for item in result] == ["F1", "S1"]

    duplicate = fixture("F1", "standard")
    try:
        combine([("foundation", [fixture("F1", "foundation")]), ("standard", [duplicate])])
    except CombineError:
        pass
    else:
        raise AssertionError("duplicate ID crossed tier boundary")

    official = fixture("O1", "standard")
    official["content_use"] = "official_mock"
    official["exam_year"] = 2025
    try:
        combine([("standard", [official])])
    except CombineError:
        pass
    else:
        raise AssertionError("official mock entered practice bank")

    mismatch = fixture("M1", "foundation")
    try:
        combine([("standard", [mismatch])])
    except CombineError:
        pass
    else:
        raise AssertionError("difficulty mismatch was accepted")

    print("SELFTEST PASS: tier isolation, release gate, duplicate IDs, official mock exclusion")


def parse_tier(value: str) -> tuple[str, Path]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("tier must be DIFFICULTY=PATH")
    difficulty, raw_path = value.split("=", 1)
    if difficulty not in DIFFICULTIES or not raw_path:
        raise argparse.ArgumentTypeError("tier difficulty/path invalid")
    return difficulty, Path(raw_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tier", action="append", type=parse_tier, default=[])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return
    if not args.tier or not args.output:
        parser.error("--tier DIFFICULTY=PATH and --output are required")

    result = combine([(difficulty, load(path)) for difficulty, path in args.tier])
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts = {difficulty: sum(item["difficulty"] == difficulty for item in result) for difficulty in DIFFICULTIES}
    print(f"PASS: combined practice release {len(result)} items; difficulty={counts}")
    print(f"WROTE {args.output}")


if __name__ == "__main__":
    main()
