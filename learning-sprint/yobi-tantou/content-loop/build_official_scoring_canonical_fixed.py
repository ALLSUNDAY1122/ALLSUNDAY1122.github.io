#!/usr/bin/env python3
"""Build R6/R7 official scoring canonical data with table-cell note binding.

The underlying answer/point extraction remains coordinate based because it reliably
recovers every No./answer and question/point pair.  Only scoring annotations such
as partial-credit thresholds and unordered groups are rebound here using the
compact table-cell structure, avoiding nearest-neighbour drift across merged PDF
cells.
"""

import importlib.util
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "build_official_scoring_canonical.py"

spec = importlib.util.spec_from_file_location("yobi_scoring_base", BASE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"cannot load {BASE_PATH}")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

original_parse_answer_page = base.parse_answer_page


def _number(text):
    if text is None:
        return None
    value = str(text).translate(base.DIGITS).strip()
    if not re.fullmatch(r"[0-9]+", value):
        return None
    return int(value)


def _main_note_table(page):
    """Return the compact table whose columns repeat 問/No/解答/配点/備考."""
    for table in page.get("tables", []):
        rows = table.get("rows") or []
        if not rows:
            continue
        header = rows[0]
        if len(header) < 5 or len(header) % 5 != 0:
            continue
        if not any(cell == "問" for cell in header):
            continue
        if not any(cell in ("No", "Ｎｏ.") for cell in header):
            continue
        return rows
    return []


def table_bound_notes(page):
    """Map official notes to the question number in the same merged table panel."""
    rows = _main_note_table(page)
    if not rows:
        return {}, set()

    panel_count = len(rows[0]) // 5
    current_question = [None] * panel_count
    notes = {}
    unordered = set()

    for row in rows[1:]:
        padded = list(row) + [None] * max(0, panel_count * 5 - len(row))
        for panel in range(panel_count):
            q_cell, _, _, _, note_cell = padded[panel * 5:(panel + 1) * 5]
            q = _number(q_cell)
            if q is not None:
                current_question[panel] = q
            q = current_question[panel]
            if q is None or not note_cell:
                continue
            note = " ".join(str(note_cell).split())
            if not note:
                continue
            existing = notes.get(q, "")
            notes[q] = (existing + " " + note).strip() if existing else note
            if "順" in note:
                unordered.add(q)

    return notes, unordered


def fixed_parse_answer_page(document_key, page):
    no_answers, q_points, _, _ = original_parse_answer_page(document_key, page)
    notes, unordered = table_bound_notes(page)
    return no_answers, q_points, notes, unordered


def validate_special_rules(result):
    """Fail closed on every partial-credit/unordered shape observed in R6/R7 PDFs."""
    expected = {
        2024: {
            ("憲法", 1): (3, 3, 2, 1, False),
            ("憲法", 2): (3, 3, 2, 1, False),
            ("憲法", 5): (3, 3, 2, 1, False),
            ("憲法", 7): (3, 3, 2, 1, False),
            ("憲法", 9): (3, 3, 2, 1, False),
            ("憲法", 11): (3, 3, 2, 1, False),
            ("行政法", 15): (4, 3, 3, 2, False),
            ("行政法", 16): (4, 3, 3, 2, False),
            ("行政法", 17): (4, 3, 3, 2, False),
            ("行政法", 20): (4, 3, 3, 2, False),
            ("行政法", 21): (4, 3, 3, 2, False),
            ("行政法", 22): (4, 3, 3, 2, False),
            ("民事訴訟法", 32): (2, 2, 1, 1, True),
            ("民事訴訟法", 34): (2, 2, 1, 1, True),
            ("民事訴訟法", 36): (2, 2, 1, 1, True),
            ("民事訴訟法", 45): (2, 2, 1, 1, True),
            ("刑法", 1): (2, 3, None, None, True),
            ("刑法", 7): (2, 3, None, None, True),
            ("刑法", 13): (5, 4, 4, 2, False),
            ("刑事訴訟法", 17): (5, 3, 4, 2, False),
            ("刑事訴訟法", 20): (5, 3, 4, 2, False),
        },
        2025: {
            ("憲法", 1): (3, 3, 2, 1, False),
            ("憲法", 4): (3, 3, 2, 1, False),
            ("憲法", 6): (3, 3, 2, 1, False),
            ("憲法", 7): (3, 3, 2, 1, False),
            ("憲法", 8): (3, 3, 2, 1, False),
            ("憲法", 9): (3, 3, 2, 1, False),
            ("行政法", 13): (4, 3, 3, 2, False),
            ("行政法", 15): (4, 3, 3, 2, False),
            ("行政法", 17): (4, 3, 3, 2, False),
            ("行政法", 20): (4, 3, 3, 2, False),
            ("行政法", 21): (4, 3, 3, 2, False),
            ("行政法", 23): (4, 3, 3, 2, False),
            ("民事訴訟法", 41): (2, 2, None, None, True),
            ("刑法", 4): (2, 3, None, None, True),
            ("刑法", 10): (2, 3, None, None, True),
            ("刑法", 13): (5, 4, 4, 2, False),
            ("刑事訴訟法", 15): (5, 3, 4, 2, False),
            ("刑事訴訟法", 26): (5, 3, 4, 2, False),
        },
    }

    for year, rules in expected.items():
        questions = result["years"][str(year)]["legal"]["questions"]
        by_key = {(q["subject"], q["questionNumber"]): q for q in questions}
        for key, (slot_count, max_points, partial_threshold, partial_points, unordered) in rules.items():
            q = by_key.get(key)
            if q is None:
                raise ValueError(f"{year} missing special-rule question {key}")
            group = q["responseGroups"][0]
            if len(group["slotIDs"]) != slot_count:
                raise ValueError(f"{year} {key}: slot count mismatch")
            if q["maxPoints"] != max_points:
                raise ValueError(f"{year} {key}: max points mismatch")
            if group["orderSensitive"] == unordered:
                raise ValueError(f"{year} {key}: unordered/orderSensitive mismatch")
            bands = {(b["minimumCorrect"], b["points"]) for b in q["scoreBands"]}
            if partial_threshold is None:
                if len(bands) != 1:
                    raise ValueError(f"{year} {key}: unexpected partial credit {bands}")
            elif (partial_threshold, partial_points) not in bands:
                raise ValueError(f"{year} {key}: missing partial-credit band {partial_threshold}->{partial_points}")


def main():
    if not base.TABLES.exists() or not base.SHAPES.exists():
        print("BLOCKED: generated source summaries are missing")
        return 2

    base.parse_answer_page = fixed_parse_answer_page
    result = base.build()
    if result is None:
        return 1

    validate_special_rules(result)
    base.OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    for year, year_data in result["years"].items():
        print(
            f"PASS {year}: legal={year_data['legal']['questionCount']} questions/"
            f"{year_data['legal']['maxPoints']} points, general="
            f"{year_data['generalEducation']['offered']} offered -> 20/60 points, "
            f"total=270, pass={year_data['officialPassScore']}"
        )
    print(f"PASS: special scoring rules validated from official table cells")
    print(f"WROTE {base.OUT} bytes={base.OUT.stat().st_size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
