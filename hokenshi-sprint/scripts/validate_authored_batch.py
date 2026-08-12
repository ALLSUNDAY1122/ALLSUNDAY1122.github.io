#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path

REQUIRED = [
    "id", "round", "question_number", "subject", "topic", "question_type",
    "taxonomy", "answer_type", "question", "choices", "correct_indices",
    "explanation", "memory_point", "source_title", "source_url", "source_refs",
    "source_checked_at", "law_baseline_date", "content_version", "rights_basis",
    "origin_type", "audit_status", "premium"
]


def normalize(text: str) -> str:
    text = str(text).lower()
    text = re.sub(r"\s+", "", text)
    return re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", text)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def validate_file(path: Path) -> int:
    rows = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    warnings: list[str] = []

    if not isinstance(rows, list) or not rows:
        print(f"FAIL {path}: non-empty JSON array required")
        return 1

    ids = [row.get("id") for row in rows]
    duplicates = [value for value, count in Counter(ids).items() if value and count > 1]
    if duplicates:
        fail(errors, f"duplicate ids {duplicates}")

    for row in rows:
        label = row.get("id", "unknown")
        for field in REQUIRED:
            if field not in row or row[field] in (None, "", []):
                if field == "premium" and row.get(field) is False:
                    continue
                fail(errors, f"{label}: missing {field}")

        if row.get("origin_type") != "original_from_primary_source":
            fail(errors, f"{label}: origin_type must be original_from_primary_source")
        if row.get("audit_status") not in {"drafted", "structure_passed", "evidence_passed", "content_passed", "release_ready"}:
            fail(errors, f"{label}: invalid audit_status {row.get('audit_status')}")
        if row.get("question_type") not in {"general", "situational"}:
            fail(errors, f"{label}: invalid question_type")
        if row.get("question_type") == "general":
            if any(key in row for key in ("scenario_id", "scenario_index", "scenario_total")):
                fail(errors, f"{label}: general question contains scenario metadata")
            if row.get("taxonomy") not in {"I", "I-prime", "II"}:
                fail(errors, f"{label}: invalid general taxonomy {row.get('taxonomy')}")
        else:
            if row.get("taxonomy") not in {"II", "III"}:
                fail(errors, f"{label}: invalid situational taxonomy {row.get('taxonomy')}")
            for field in ("scenario_id", "scenario_index", "scenario_total"):
                if not row.get(field):
                    fail(errors, f"{label}: missing {field}")

        answer_type = row.get("answer_type")
        choices = row.get("choices")
        indices = row.get("correct_indices")
        if answer_type == "singleChoice":
            if not isinstance(choices, list) or len(choices) < 2:
                fail(errors, f"{label}: choices invalid")
            if not isinstance(indices, list) or len(indices) != 1:
                fail(errors, f"{label}: singleChoice requires one correct index")
            elif isinstance(choices, list) and not (0 <= indices[0] < len(choices)):
                fail(errors, f"{label}: correct index out of range")
        elif answer_type == "multiChoice":
            if not isinstance(indices, list) or len(indices) < 2 or len(set(indices)) != len(indices):
                fail(errors, f"{label}: multiChoice indices invalid")
        elif answer_type == "numeric":
            if not isinstance(row.get("correct_number"), (int, float)):
                fail(errors, f"{label}: numeric answer missing")
        else:
            fail(errors, f"{label}: unsupported answer_type {answer_type}")

        if not str(row.get("source_url", "")).startswith("https://"):
            fail(errors, f"{label}: source_url must be https")
        if not str(row.get("rights_basis", "")).strip():
            fail(errors, f"{label}: rights_basis missing")
        if len(str(row.get("explanation", ""))) < 30:
            fail(errors, f"{label}: explanation too short")
        if len(str(row.get("memory_point", ""))) < 10:
            fail(errors, f"{label}: memory_point too short")

    normalized = [(row.get("id"), normalize(row.get("question", ""))) for row in rows]
    for i, (id_a, text_a) in enumerate(normalized):
        for id_b, text_b in normalized[i + 1:]:
            if text_a == text_b:
                fail(errors, f"exact duplicate: {id_a} <-> {id_b}")
                continue
            ratio = SequenceMatcher(None, text_a, text_b).ratio()
            if ratio >= 0.88:
                fail(errors, f"high similarity {ratio:.2f}: {id_a} <-> {id_b}")
            elif ratio >= 0.78:
                warnings.append(f"similarity review {ratio:.2f}: {id_a} <-> {id_b}")

    print(f"=== Authored Batch Audit: {path.name} ===")
    print(f"questions={len(rows)}")
    if warnings:
        print("WARNINGS")
        for warning in warnings:
            print(f"- {warning}")
    if errors:
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("PASS: schema / answer shape / evidence metadata / originality gate")
    print("NOTE: medical-policy correctness requires separate primary-source review before release_ready.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    status = 0
    for path in args.paths:
        status |= validate_file(path)
    return status


if __name__ == "__main__":
    sys.exit(main())
