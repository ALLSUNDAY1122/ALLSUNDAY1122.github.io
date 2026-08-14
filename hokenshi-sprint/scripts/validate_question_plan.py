#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "content" / "question-plan.generated.json"
EXPECTED_SUBJECTS = {
    "A": "公衆衛生看護学概論",
    "B": "公衆衛生看護方法論I",
    "C": "公衆衛生看護方法論II",
    "D": "対象別公衆衛生看護活動論",
    "E": "学校保健・産業保健",
    "F": "健康危機管理",
    "G": "公衆衛生看護管理論",
    "H": "疫学",
    "I": "保健統計",
    "J": "保健医療福祉行政論",
}
ALLOWED_GENERAL_TAXONOMY = {"I", "I-prime", "II"}
ALLOWED_SITUATIONAL_TAXONOMY = {"II", "III"}


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    if not PLAN.exists():
        print(f"FAIL: plan missing: {PLAN}")
        return 1

    rows = json.loads(PLAN.read_text(encoding="utf-8"))
    errors: list[str] = []

    if len(rows) != 330:
        fail(errors, f"total {len(rows)}/330")

    ids = [row.get("id") for row in rows]
    duplicates = [value for value, count in Counter(ids).items() if value and count > 1]
    if duplicates:
        fail(errors, f"duplicate ids: {duplicates}")

    for round_no in range(1, 4):
        round_rows = [row for row in rows if row.get("round") == round_no]
        if len(round_rows) != 110:
            fail(errors, f"round {round_no}: {len(round_rows)}/110")

        question_numbers = sorted(row.get("question_number") for row in round_rows)
        if question_numbers != list(range(1, 111)):
            fail(errors, f"round {round_no}: question numbers must be 1...110")

        type_counts = Counter(row.get("question_type") for row in round_rows)
        if type_counts.get("general", 0) != 75:
            fail(errors, f"round {round_no}: general {type_counts.get('general', 0)}/75")
        if type_counts.get("situational", 0) != 35:
            fail(errors, f"round {round_no}: situational {type_counts.get('situational', 0)}/35")

        for code, subject in EXPECTED_SUBJECTS.items():
            subject_rows = [row for row in round_rows if row.get("subject_code") == code]
            if len(subject_rows) != 11:
                fail(errors, f"round {round_no}/{code}: {len(subject_rows)}/11")
            if any(row.get("subject") != subject for row in subject_rows):
                fail(errors, f"round {round_no}/{code}: subject name mismatch")
            topics = [row.get("topic") for row in subject_rows]
            if len(set(topics)) != 11:
                fail(errors, f"round {round_no}/{code}: topic duplication")

        scenarios: dict[str, list[dict]] = defaultdict(list)
        for row in round_rows:
            question_type = row.get("question_type")
            tax = row.get("taxonomy")
            if question_type == "general":
                if tax not in ALLOWED_GENERAL_TAXONOMY:
                    fail(errors, f"{row.get('id')}: invalid general taxonomy {tax}")
                for field in ("scenario_id", "scenario_index", "scenario_total"):
                    if field in row:
                        fail(errors, f"{row.get('id')}: general question must not contain {field}")
            elif question_type == "situational":
                if tax not in ALLOWED_SITUATIONAL_TAXONOMY:
                    fail(errors, f"{row.get('id')}: invalid situational taxonomy {tax}")
                for field in ("scenario_id", "scenario_index", "scenario_total"):
                    if not row.get(field):
                        fail(errors, f"{row.get('id')}: missing {field}")
                scenarios[row.get("scenario_id")].append(row)
            else:
                fail(errors, f"{row.get('id')}: invalid question_type {question_type}")

            if not row.get("source_refs"):
                fail(errors, f"{row.get('id')}: source_refs missing")
            if row.get("audit_status") != "planned":
                fail(errors, f"{row.get('id')}: plan audit_status must be planned")

        sizes = sorted(len(group) for group in scenarios.values())
        if len(scenarios) != 12:
            fail(errors, f"round {round_no}: scenarios {len(scenarios)}/12")
        if sizes != [2] + [3] * 11:
            fail(errors, f"round {round_no}: scenario sizes {sizes}")

        for scenario_id, group in scenarios.items():
            totals = {row.get("scenario_total") for row in group}
            if totals != {len(group)}:
                fail(errors, f"{scenario_id}: scenario_total mismatch {totals} vs {len(group)}")
            indexes = sorted(row.get("scenario_index") for row in group)
            if indexes != list(range(1, len(group) + 1)):
                fail(errors, f"{scenario_id}: scenario_index mismatch {indexes}")

    if errors:
        print("=== Hokenshi 330 Question Plan ===")
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("=== Hokenshi 330 Question Plan ===")
    print("PASS: total=330 rounds=3x110 subjects=10x11 general=75 situational=35")
    print("PASS: each round scenarios=11x3 + 1x2")
    print("PASS: taxonomy/source-plan metadata complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
