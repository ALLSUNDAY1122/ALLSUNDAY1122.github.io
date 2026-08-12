#!/usr/bin/env python3
from __future__ import annotations

import glob
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN_PATH = ROOT / "content" / "question-plan.generated.json"
AUTHORED_GLOB = str(ROOT / "content" / "authored" / "*.json")
STRUCTURAL_FIELDS = [
    "round", "question_number", "subject", "question_type", "taxonomy",
    "scenario_id", "scenario_index", "scenario_total"
]
ID_RE = re.compile(r"^HOK-R([123])-([A-J])-(\d{2})$")


def main() -> int:
    if not PLAN_PATH.exists():
        print("FAIL: generated plan missing")
        return 1

    plan_rows = json.loads(PLAN_PATH.read_text(encoding="utf-8"))
    plan = {row["id"]: row for row in plan_rows}
    authored: list[dict] = []
    for filename in sorted(glob.glob(AUTHORED_GLOB)):
        authored.extend(json.loads(Path(filename).read_text(encoding="utf-8")))

    errors: list[str] = []
    slot_topics: dict[tuple[str, int], set[str]] = defaultdict(set)
    subject_topic_slots: dict[str, dict[int, str]] = defaultdict(dict)

    for row in authored:
        label = row.get("id", "unknown")
        planned = plan.get(label)
        if planned is None:
            errors.append(f"{label}: not present in canonical 330 structure")
            continue
        for field in STRUCTURAL_FIELDS:
            authored_value = row.get(field)
            planned_value = planned.get(field)
            if authored_value != planned_value:
                errors.append(
                    f"{label}: {field} mismatch authored={authored_value!r} planned={planned_value!r}"
                )

        match = ID_RE.match(label)
        if not match:
            errors.append(f"{label}: malformed ID")
            continue
        _, code, index_text = match.groups()
        slot = int(index_text)
        topic = str(row.get("topic", "")).strip()
        if not topic:
            errors.append(f"{label}: topic is blank")
            continue
        slot_topics[(code, slot)].add(topic)
        subject_topic_slots[row["subject"]][slot] = topic

    for (code, slot), topics in sorted(slot_topics.items()):
        if len(topics) > 1:
            errors.append(f"{code}-{slot:02d}: topic label drift across rounds {sorted(topics)}")

    # When all 11 slots of a subject have been authored at least once, require 11 distinct topics.
    for subject, slots in sorted(subject_topic_slots.items()):
        if len(slots) == 11 and len(set(slots.values())) != 11:
            errors.append(f"{subject}: 11 slots must have 11 distinct topic labels")

    authored_ids = {row.get("id") for row in authored}
    remaining = [row for row in plan_rows if row.get("id") not in authored_ids]
    subjects = Counter(row.get("subject") for row in authored)
    round_counts = Counter(row.get("round") for row in authored)
    type_counts = Counter(row.get("question_type") for row in authored)

    print("=== Hokenshi Authored Coverage v2 ===")
    print(f"authored={len(authored)}/330 remaining={len(remaining)}")
    print("rounds=" + ", ".join(f"R{k}:{round_counts[k]}" for k in sorted(round_counts)))
    print("types=" + ", ".join(f"{k}:{v}" for k, v in sorted(type_counts.items())))
    for subject in sorted(subjects):
        print(f"subject {subject}: {subjects[subject]}/33")

    if errors:
        print("FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("PASS: authored ID/exam/subject/type/taxonomy/scenario structure matches canonical 330 plan")
    print("PASS: topic labels are stable per content slot; authored wording may refine the initial planning label")
    if remaining:
        print("STATUS: coverage is incomplete; incomplete content remains blocked from release.")
    else:
        print("STATUS: 330/330 authored; proceed to evidence/content/release audits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
