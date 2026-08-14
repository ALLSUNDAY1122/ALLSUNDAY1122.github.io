#!/usr/bin/env python3
"""Artifact-driven audit for the nurse-exam situation-setting specialist lane.

This validator deliberately derives progress from GitHub artifacts instead of a
manually maintained chat cursor.  It treats the 60 scenarios as the unit of
work and keeps release-only quarantines separate from content-authoring
completion.

Run from the repository root:
    python kangoshi-sprint/product-content/situation-audit/validate_situation_audit.py

Use --write to refresh situation-audit/report.json.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PRODUCT = ROOT / "kangoshi-sprint" / "product-content"
SUMMARY = PRODUCT / "classified" / "situation-group-summary.json"
BATCH_DIR = PRODUCT / "explanation-batches"
REPORT = PRODUCT / "situation-audit" / "report.json"

EXPECTED_SCENARIOS = 60
EXPECTED_QUESTIONS = 180
QUESTIONS_PER_SCENARIO = 3
REQUIRED_ITEM_FIELDS = ("point", "detail", "explanationEvidenceRefs", "evidenceCheckedDate")


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def normalized_items(batch: dict) -> list[dict]:
    items = batch.get("items")
    return items if isinstance(items, list) else []


def is_content_complete(item: dict) -> tuple[bool, list[str]]:
    missing: list[str] = []
    for field in REQUIRED_ITEM_FIELDS:
        value = item.get(field)
        if field == "explanationEvidenceRefs":
            if not isinstance(value, list) or not any(str(x).strip() for x in value):
                missing.append(field)
        elif not isinstance(value, str) or not value.strip():
            missing.append(field)
    return (not missing, missing)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="write report.json")
    args = ap.parse_args()

    summary = load_json(SUMMARY)
    groups = summary.get("groups", [])
    expected: dict[str, list[str]] = {}
    for group in groups:
        sid = group.get("scenarioId")
        qids = [q.get("id") for q in group.get("questions", []) if q.get("id")]
        if sid:
            expected[sid] = qids

    structural_errors: list[dict] = []
    if len(expected) != EXPECTED_SCENARIOS:
        structural_errors.append({"kind": "scenario_count", "expected": EXPECTED_SCENARIOS, "actual": len(expected)})
    expected_question_count = sum(len(v) for v in expected.values())
    if expected_question_count != EXPECTED_QUESTIONS:
        structural_errors.append({"kind": "question_count", "expected": EXPECTED_QUESTIONS, "actual": expected_question_count})
    for sid, qids in expected.items():
        if len(qids) != QUESTIONS_PER_SCENARIO or len(set(qids)) != QUESTIONS_PER_SCENARIO:
            structural_errors.append({"kind": "scenario_triplet", "scenarioId": sid, "questionIds": qids})

    # Only batches that explicitly declare scenarioId participate.  Generic
    # required/general batches are ignored, preventing duplicate accounting.
    candidates: dict[str, list[tuple[str, dict]]] = defaultdict(list)
    for path in sorted(BATCH_DIR.glob("*.json")):
        try:
            batch = load_json(path)
        except Exception as exc:  # keep one corrupt file from hiding all remaining work
            structural_errors.append({"kind": "batch_parse", "file": path.name, "error": str(exc)})
            continue
        sid = batch.get("scenarioId")
        if sid in expected:
            for item in normalized_items(batch):
                qid = item.get("id")
                if qid:
                    candidates[sid].append((path.name, item))

    completed: list[str] = []
    pending: list[dict] = []
    duplicate_conflicts: list[dict] = []
    split_batches: list[dict] = []

    for sid in sorted(expected):
        expected_ids = expected[sid]
        by_qid: dict[str, list[tuple[str, dict]]] = defaultdict(list)
        for filename, item in candidates.get(sid, []):
            by_qid[item["id"]].append((filename, item))

        files_used = sorted({filename for values in by_qid.values() for filename, _ in values})
        if len(files_used) > 1:
            split_batches.append({"scenarioId": sid, "files": files_used})

        missing_ids: list[str] = []
        incomplete_items: list[dict] = []
        unexpected_ids = sorted(set(by_qid) - set(expected_ids))

        for qid in expected_ids:
            versions = by_qid.get(qid, [])
            if not versions:
                missing_ids.append(qid)
                continue

            # Multiple files may represent the same question only if their
            # content-bearing fields are identical. Otherwise it is a conflict.
            fingerprints: dict[str, list[str]] = defaultdict(list)
            for filename, item in versions:
                fp_obj = {k: item.get(k) for k in REQUIRED_ITEM_FIELDS}
                fingerprint = json.dumps(fp_obj, ensure_ascii=False, sort_keys=True)
                fingerprints[fingerprint].append(filename)
            if len(fingerprints) > 1:
                duplicate_conflicts.append({
                    "scenarioId": sid,
                    "questionId": qid,
                    "files": sorted(filename for filename, _ in versions),
                })

            # At least one complete identical/current representation is enough
            # for authoring coverage; conflicts are still a canonical blocker.
            complete = False
            all_missing: set[str] = set()
            for filename, item in versions:
                ok, missing_fields = is_content_complete(item)
                if ok:
                    complete = True
                else:
                    all_missing.update(missing_fields)
            if not complete:
                incomplete_items.append({"questionId": qid, "missingFields": sorted(all_missing)})

        if not missing_ids and not incomplete_items and not unexpected_ids:
            completed.append(sid)
        else:
            pending.append({
                "scenarioId": sid,
                "questionIds": expected_ids,
                "missingQuestionIds": missing_ids,
                "incompleteItems": incomplete_items,
                "unexpectedQuestionIds": unexpected_ids,
            })

    completed_question_count = sum(len(expected[sid]) for sid in completed)
    report = {
        "schemaVersion": 2,
        "stateSource": "artifact-driven",
        "unit": "scenario",
        "expectedScenarioCount": EXPECTED_SCENARIOS,
        "expectedQuestionCount": EXPECTED_QUESTIONS,
        "contentCompleteScenarioCount": len(completed),
        "contentCompleteQuestionCount": completed_question_count,
        "contentPendingScenarioCount": len(pending),
        "contentPendingQuestionCount": EXPECTED_QUESTIONS - completed_question_count,
        "contentCompleteScenarioIds": completed,
        "contentPending": pending,
        "splitScenarioBatches": split_batches,
        "duplicateContentConflicts": duplicate_conflicts,
        "structuralErrors": structural_errors,
        "contentAuthoringPass": len(completed) == EXPECTED_SCENARIOS and not structural_errors and not duplicate_conflicts,
        "releasePolicy": {
            "expertMediaScoringConcernsBlockOnlyAffectedRelease": True,
            "expertReviewIsNotAContentAuthoringPrerequisite": True,
            "finalReleaseRequiresCanonicalIntegrationAndReleaseAudits": True,
        },
    }

    text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.write:
        REPORT.write_text(text, encoding="utf-8")
    else:
        print(text, end="")

    return 0 if not structural_errors and not duplicate_conflicts else 1


if __name__ == "__main__":
    sys.exit(main())
