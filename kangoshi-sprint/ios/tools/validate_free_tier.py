#!/usr/bin/env python3
"""Prove the kangoshi free-tier payload without an iOS build.

Reads the same release drafts + quarantine used by prepare_native_content.py
and asserts the 8+8+8 exam-115 free sample contract. Does not write GeneratedResources.
"""
from __future__ import annotations
import json, sys
from collections import Counter
from pathlib import Path

CATEGORIES = ("必修", "一般", "状況設定")
PER_CATEGORY = 8
EXAM = 115

def repo_root() -> Path:
    here = Path(__file__).resolve()
    for candidate in [here.parents[2], Path("/workspace/kangoshi-work"), Path.cwd()]:
        if (candidate / "kangoshi-sprint/product-content/release-quarantine-20261125.json").exists():
            return candidate
    raise SystemExit("kangoshi-sprint/product-content not found")

def release_questions(root: Path):
    content = root / "kangoshi-sprint/product-content"
    quarantine = json.loads((content / "release-quarantine-20261125.json").read_text(encoding="utf-8"))
    quarantined = {x["id"] for x in quarantine.get("items") or []}
    questions = []
    for sid in ("set1", "set2", "set3"):
        rows = json.loads((content / "enriched-draft" / f"{sid}-draft.json").read_text(encoding="utf-8")).get("questions") or []
        for q in rows:
            if q["id"] in quarantined or q.get("releaseQuarantineStatus") == "quarantined":
                continue
            questions.append({
                "id": q["id"],
                "sourceExam": int(q["sourceExam"]),
                "category": q.get("category") or "",
            })
    expected = quarantine["releaseEligibleCount"]
    if len(questions) != expected:
        raise SystemExit(f"release-eligible count {len(questions)} != {expected}")
    return questions, quarantine

def free_ids(questions):
    ids = []
    for category in CATEGORIES:
        part = [q["id"] for q in questions if q["sourceExam"] == EXAM and q["category"] == category][:PER_CATEGORY]
        ids.extend(part)
    return ids

def main() -> int:
    root = repo_root()
    questions, quarantine = release_questions(root)
    ids = free_ids(questions)
    by_id = {q["id"]: q for q in questions}
    errors = []
    if len(ids) != 24:
        errors.append(f"expected 24 free IDs, got {len(ids)}")
    if len(set(ids)) != len(ids):
        errors.append("free IDs are not unique")
    missing = [i for i in ids if i not in by_id]
    if missing:
        errors.append(f"unresolved IDs: {missing}")
    counts = Counter(by_id[i]["category"] for i in ids if i in by_id)
    for category in CATEGORIES:
        if counts[category] != PER_CATEGORY:
            errors.append(f"{category}: {counts[category]} != {PER_CATEGORY}")
    exams = {by_id[i]["sourceExam"] for i in ids if i in by_id}
    if exams and exams != {EXAM}:
        errors.append(f"free IDs must all be exam {EXAM}, got {exams}")

    report = {
        "pass": not errors,
        "releaseEligible": len(questions),
        "canonicalTotal": 720,
        "quarantined": quarantine.get("releaseQuarantinedCount") or len(quarantine.get("items") or []),
        "freeSampleQuestionIds": ids,
        "freeSampleCount": len(ids),
        "byCategory": dict(counts),
        "errors": errors,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1

if __name__ == "__main__":
    sys.exit(main())
