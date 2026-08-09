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
PDF_TAIL_RE = re.compile(r"(?:受験地|受験番号|十の位|一の位)")
DANGLING_PREAMBLE_RE = re.compile(r"(?:また[、,]|なお[、,]|及び|又は)\s*$")
BOOKLET_INSTRUCTION_RE = re.compile(r"(?:答案用紙|試験時間|試験問題のホチキス|注\s*意)")


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


def strip_booklet_instructions(q: dict) -> dict | None:
    if q.get("session") != "PM" or q.get("source_question_no") != 1:
        return None
    text = q.get("question", "")
    own = re.compile(r"第\s*1\s*問")
    matches = list(own.finditer(text))
    if not matches:
        return None
    # Use the last early Q1 heading; any preceding exam administration text is not a question.
    candidates = [m for m in matches if m.start() < 5000]
    if not candidates:
        return None
    m = candidates[-1]
    prefix = text[:m.start()].strip()
    body = text[m.end():].strip()
    if not prefix or not BOOKLET_INSTRUCTION_RE.search(prefix) or len(body) < 40:
        return None
    q["question"] = body
    return {"id": q["id"], "discarded_chars": len(prefix), "marker": "booklet_instructions"}


def promote_false_heading_prefix(q: dict) -> dict | None:
    qn = int(q.get("source_question_no") or 0)
    text = q.get("question", "")
    own = re.compile(fr"第\s*{qn}\s*問")
    matches = list(own.finditer(text))
    if not matches:
        return None

    m = matches[0]
    if m.start() == 0 and len(matches) > 1:
        m = matches[1]
    if m.start() <= 0 or m.start() > 700:
        return None

    prefix = text[:m.start()].strip()
    if not ("試験問題" in prefix and ("解答" in prefix or "適用" in prefix or prefix.startswith("から"))):
        return None

    body = text[m.end():].strip()
    if len(body) < 40:
        return None

    existing = (q.get("section_preamble") or "").strip()
    q["section_preamble"] = "\n".join(x for x in [existing, prefix] if x).strip()
    q["question"] = body
    return {"id": q["id"], "prefix_chars": len(prefix), "preamble_chars": len(q["section_preamble"])}


def main() -> int:
    rc = v5.main()
    report = json.loads(v5.v4.v3.REPORT.read_text(encoding="utf-8"))
    questions = json.loads(v5.v4.v3.QUESTIONS.read_text(encoding="utf-8"))

    moved = []
    orphan = []
    discarded_pdf_tail = []
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
                continue

        if q.get("source_question_no") == 35 and q.get("session") == "AM" and PDF_TAIL_RE.search(tail):
            discarded_pdf_tail.append({"from": q["id"], "chars": len(tail), "marker": "answer_sheet"})
        else:
            orphan.append({"from": q["id"], "tail": tail[:120]})

    discarded_booklet_instructions = []
    for q in questions:
        fixed = strip_booklet_instructions(q)
        if fixed:
            discarded_booklet_instructions.append(fixed)

    promoted_prefixes = []
    for q in questions:
        fixed = promote_false_heading_prefix(q)
        if fixed:
            promoted_prefixes.append(fixed)

    cross_contamination = []
    suspicious_leading_continuation = []
    dangling_preambles = []
    booklet_instruction_residue = []
    for q in questions:
        lines = q.get("question", "").splitlines()
        for i, line in enumerate(lines):
            if COMBO_END_RE.fullmatch(line) and any(x.strip() for x in lines[i + 1 :]):
                cross_contamination.append(q["id"])
                break
        if re.match(r"^\s*から\s*第?\s*\d+\s*問", q.get("question", "")):
            suspicious_leading_continuation.append(q["id"])
        if q.get("source_question_no") == 1 and BOOKLET_INSTRUCTION_RE.search(q.get("question", "")[:1200]):
            booklet_instruction_residue.append(q["id"])
        pre = (q.get("section_preamble") or "").strip()
        if pre and DANGLING_PREAMBLE_RE.search(pre):
            dangling_preambles.append(q["id"])

    report["cycle"] = 12
    report["cross_question_boundary_audit"] = {
        "moved_section_preambles": moved,
        "promoted_false_heading_prefixes": promoted_prefixes,
        "discarded_pdf_tail_artifacts": discarded_pdf_tail,
        "discarded_booklet_instructions": discarded_booklet_instructions,
        "orphan_preambles": orphan,
        "remaining_cross_contamination": cross_contamination,
        "suspicious_leading_continuation": suspicious_leading_continuation,
        "booklet_instruction_residue": booklet_instruction_residue,
        "dangling_preambles": dangling_preambles,
        "question_count": len(questions),
    }

    errors = list(report.get("errors", []))
    if len(questions) != 210:
        errors.append(f"question count {len(questions)}/210")
    if orphan:
        errors.append(f"orphan section preambles: {len(orphan)}")
    if cross_contamination:
        errors.append(f"cross-question contamination remains: {len(cross_contamination)}")
    if suspicious_leading_continuation:
        errors.append(f"leading continuation remains: {len(suspicious_leading_continuation)}")
    if booklet_instruction_residue:
        errors.append(f"booklet instructions remain: {len(booklet_instruction_residue)}")
    if dangling_preambles:
        errors.append(f"dangling section preambles: {len(dangling_preambles)}")

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
        "cycle": 12,
        "status": report["status"],
        "moved_preambles": len(moved),
        "promoted_prefixes": len(promoted_prefixes),
        "discarded_pdf_tail_artifacts": len(discarded_pdf_tail),
        "discarded_booklet_instructions": len(discarded_booklet_instructions),
        "orphan_preambles": len(orphan),
        "remaining_cross_contamination": len(cross_contamination),
        "booklet_instruction_residue": len(booklet_instruction_residue),
        "dangling_preambles": len(dangling_preambles),
    }, ensure_ascii=False))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
