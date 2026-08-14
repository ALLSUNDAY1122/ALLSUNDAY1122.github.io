#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN_PATH = ROOT / "content" / "question-plan.generated.json"
CANONICAL_PATH = ROOT / "content" / "questions.canonical.json"

REQUIRED = [
    "id", "round", "question_number", "subject", "topic", "question_type",
    "taxonomy", "answer_type", "question", "choices", "correct_indices",
    "explanation", "memory_point", "source_title", "source_url", "source_refs",
    "source_checked_at", "law_baseline_date", "content_version", "rights_basis",
    "origin_type", "audit_status", "premium"
]
# The 2026-08-13 initial topic plan was a generation scaffold. After primary-source
# review, topic labels and per-ID placement changed in several subjects. Keep only
# immutable identity fields tied to the 3x110 shell here; validate actual question
# type/taxonomy/scenario integrity independently below.
MATCH_FIELDS = ["round", "question_number", "subject"]


def normalize(text: str) -> str:
    text = str(text).lower()
    text = re.sub(r"\s+", "", text)
    return re.sub(r"[、。,.!?！？・:：;；（）()\[\]{}『』「」\-ー〜~]", "", text)


def main() -> int:
    rows = json.loads(CANONICAL_PATH.read_text(encoding="utf-8"))
    plan_rows = json.loads(PLAN_PATH.read_text(encoding="utf-8"))
    plan = {row["id"]: row for row in plan_rows}
    errors: list[str] = []
    warnings: list[str] = []

    if len(rows) != 330:
        errors.append(f"total must be 330, got {len(rows)}")

    ids = [row.get("id") for row in rows]
    duplicates = [value for value, count in Counter(ids).items() if value and count > 1]
    if duplicates:
        errors.append(f"duplicate ids: {duplicates}")

    for row in rows:
        label = row.get("id", "unknown")
        planned = plan.get(label)
        if planned is None:
            errors.append(f"{label}: missing from structural plan")
            continue
        for field in MATCH_FIELDS:
            if row.get(field) != planned.get(field):
                errors.append(f"{label}: {field} mismatch canonical={row.get(field)!r} planned={planned.get(field)!r}")

        for field in REQUIRED:
            value = row.get(field)
            if field == "premium" and value is False:
                continue
            if value in (None, "", []):
                errors.append(f"{label}: missing {field}")

        if row.get("origin_type") != "original_from_primary_source":
            errors.append(f"{label}: origin_type must be original_from_primary_source")
        if row.get("question_type") == "general":
            if any(row.get(key) is not None for key in ("scenario_id", "scenario_index", "scenario_total")):
                errors.append(f"{label}: general question has scenario metadata")
            if row.get("taxonomy") not in {"I", "I-prime", "II"}:
                errors.append(f"{label}: invalid general taxonomy {row.get('taxonomy')}")
        elif row.get("question_type") == "situational":
            if row.get("taxonomy") not in {"II", "III"}:
                errors.append(f"{label}: invalid situational taxonomy {row.get('taxonomy')}")
            for field in ("scenario_id", "scenario_index", "scenario_total"):
                if row.get(field) in (None, ""):
                    errors.append(f"{label}: missing {field}")
        else:
            errors.append(f"{label}: invalid question_type")

        answer_type = row.get("answer_type")
        choices = row.get("choices")
        indices = row.get("correct_indices")
        if answer_type == "singleChoice":
            if not isinstance(choices, list) or len(choices) < 2:
                errors.append(f"{label}: invalid choices")
            if not isinstance(indices, list) or len(indices) != 1:
                errors.append(f"{label}: singleChoice requires one correct index")
            elif isinstance(choices, list) and not (0 <= indices[0] < len(choices)):
                errors.append(f"{label}: correct index out of range")
        elif answer_type == "multiChoice":
            if not isinstance(indices, list) or len(indices) < 2 or len(indices) != len(set(indices)):
                errors.append(f"{label}: multiChoice indices invalid")
        elif answer_type == "numeric":
            if not isinstance(row.get("correct_number"), (int, float)):
                errors.append(f"{label}: numeric answer missing")
        else:
            errors.append(f"{label}: unsupported answer_type {answer_type}")

        if not str(row.get("source_url", "")).startswith("https://"):
            errors.append(f"{label}: source_url must use https")
        if len(str(row.get("explanation", ""))) < 30:
            errors.append(f"{label}: explanation too short")
        if len(str(row.get("memory_point", ""))) < 10:
            errors.append(f"{label}: memory_point too short")

    round_counts = Counter(row.get("round") for row in rows)
    for round_no in (1, 2, 3):
        round_rows = [row for row in rows if row.get("round") == round_no]
        if len(round_rows) != 110:
            errors.append(f"round {round_no}: expected 110 got {len(round_rows)}")
        general = sum(row.get("question_type") == "general" for row in round_rows)
        situational = sum(row.get("question_type") == "situational" for row in round_rows)
        if (general, situational) != (75, 35):
            errors.append(f"round {round_no}: expected general/situational 75/35 got {general}/{situational}")

    subject_counts = Counter(row.get("subject") for row in rows)
    for subject, count in sorted(subject_counts.items()):
        if count != 33:
            errors.append(f"subject {subject}: expected 33 got {count}")
    if len(subject_counts) != 10:
        errors.append(f"expected 10 subjects, got {len(subject_counts)}")

    scenarios: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        if row.get("question_type") == "situational":
            scenarios[row["scenario_id"]].append(row)
    for scenario_id, group in scenarios.items():
        totals = {row.get("scenario_total") for row in group}
        if len(totals) != 1:
            errors.append(f"{scenario_id}: inconsistent scenario_total")
            continue
        total = next(iter(totals))
        indexes = sorted(row.get("scenario_index") for row in group)
        if total not in {2, 3}:
            errors.append(f"{scenario_id}: scenario_total must be 2 or 3, got {total}")
        if len(group) != total or indexes != list(range(1, total + 1)):
            errors.append(f"{scenario_id}: broken scenario chain count={len(group)} total={total} indexes={indexes}")

    normalized = [(row["id"], normalize(row["question"])) for row in rows]
    for i, (id_a, text_a) in enumerate(normalized):
        for id_b, text_b in normalized[i + 1:]:
            if text_a == text_b:
                errors.append(f"exact duplicate: {id_a} <-> {id_b}")
                continue
            ratio = SequenceMatcher(None, text_a, text_b).ratio()
            if ratio >= 0.88:
                errors.append(f"high similarity {ratio:.2f}: {id_a} <-> {id_b}")
            elif ratio >= 0.78:
                warnings.append(f"similarity review {ratio:.2f}: {id_a} <-> {id_b}")

    print("=== Hokenshi Canonical 330 Audit ===")
    print(f"questions={len(rows)} rounds={dict(sorted(round_counts.items()))} subjects={len(subject_counts)} scenarios={len(scenarios)}")
    if warnings:
        print("WARNINGS")
        for warning in warnings:
            print(f"- {warning}")
    if errors:
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("PASS: 330 structure / 10x33 subjects / 75+35 per round / answers / evidence metadata / scenario chains / duplicate-high-similarity gate")
    return 0


if __name__ == "__main__":
    sys.exit(main())
