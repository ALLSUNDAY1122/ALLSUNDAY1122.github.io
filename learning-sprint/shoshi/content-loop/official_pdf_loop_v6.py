#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys

import official_pdf_loop_v5 as v5

COMBO_END_RE = re.compile(r"^\s*1\s+.+?\s+2\s+.+?\s+3\s+.+?\s+4\s+.+?\s+5\s+.+\s*$")
SECTION_MARKER_RE = re.compile(
    r"^\s*(?:以下の試験問題について|なお[、,]|また[、,]|次の試験問題について|第\s*\d+\s*問以降について)",
)


def split_trailing_preamble(text: str) -> tuple[str, str]:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if COMBO_END_RE.fullmatch(line):
            head = "\n".join(lines[: i + 1]).strip()
            tail = "\n".join(lines[i + 1 :]).strip()
            return head, tail

    choice5_seen = False
    for i, line in enumerate(lines):
        if re.match(r"^\s*5(?:\s|　)", line):
            choice5_seen = True
            continue
        if choice5_seen and SECTION_MARKER_RE.match(line):
            head = "\n".join(lines[:i]).strip()
            tail = "\n".join(lines[i:]).strip()
            return head, tail
    return text.strip(), ""


def main() -> int:
    rc = v5.main()
    report = json.loads(v5.v4.v3.REPORT.read_text(encoding="utf-8"))
    questions = json.loads(v5.v4.v3.QUESTIONS.read_text(encoding="utf-8"))

    moved = []
    orphan = []
    for i, q in enumerate(questions):
        clean, tail = split_trailing_preamble(q.get("question", ""))
        if not tail:
            continue
        q["question"] = clean
        if i + 1 < len(questions):
            nxt = questions[i + 1]
            same_set = (
                nxt.get("source_year") == q.get("source_year")
                and nxt.get("session") == q.get("session")
                and nxt.get("source_question_no") == q.get("source_question_no") + 1
            )
            if same_set:
                nxt["section_preamble"] = tail
                moved.append({"from": q["id"], "to": nxt["id"], "chars": len(tail)})
            else:
                orphan.append({"from": q["id"], "tail": tail[:120]})
        else:
            orphan.append({"from": q["id"], "tail": tail[:120]})

    cross_contamination = []
    for q in questions:
        lines = q.get("question", "").splitlines()
        for i, line in enumerate(lines):
            if COMBO_END_RE.fullmatch(line) and any(x.strip() for x in lines[i + 1 :]):
                cross_contamination.append(q["id"])
                break

    report["cycle"] = 9
    report["cross_question_boundary_audit"] = {
        "moved_section_preambles": moved,
        "orphan_preambles": orphan,
        "remaining_cross_contamination": cross_contamination,
        "question_count": len(questions),
    }

    errors = list(report.get("errors", []))
    if len(questions) != 210:
        errors.append(f"question count {len(questions)}/210")
    if orphan:
        errors.append(f"orphan section preambles: {len(orphan)}")
    if cross_contamination:
        errors.append(f"cross-question contamination remains: {len(cross_contamination)}")

    report["errors"] = errors
    report["status"] = "PASS" if rc == 0 and not errors else "FAIL"

    v5.v4.v3.QUESTIONS.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding="utf-8")
    audit = json.loads(v5.v4.v3.CONFIG.read_text(encoding="utf-8"))
    by_id = {q["id"]: q for q in questions}
    for aq in audit.get("questions", []):
        src = by_id.get(aq.get("id"))
        if src:
            aq["question"] = src["question"]
            if src.get("section_preamble"):
                aq["section_preamble"] = src["section_preamble"]
            elif "section_preamble" in aq:
                aq.pop("section_preamble", None)
    v5.v4.v3.CONFIG.write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")
    v5.v4.v3.REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps({
        "cycle": 9,
        "status": report["status"],
        "moved_preambles": len(moved),
        "orphan_preambles": len(orphan),
        "remaining_cross_contamination": len(cross_contamination),
    }, ensure_ascii=False))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
