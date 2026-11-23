#!/usr/bin/env python3
"""Stage IPA published IT Passport PDF questions. Never grant release PASS.

Usage: python3 stage-ipa-pdf.py YEAR OFFICIAL_QS_PDF OFFICIAL_ANS_PDF
Requires pdftotext -layout and pdfinfo (poppler). Official binary sources only.
Records SHA-256, page-level evidence, and one raw draft per detected question.
All questions remain HOLD until source/figure/answer are independently verified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "questions" / "ipa-staging"
QUESTION_START = re.compile(r"(?m)^[\u0020\t\u3000]*問[\u0020\t\u3000]*(\d{1,3})(?=[\u0020\t\u3000\n]|[^\d])")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_pdf(path: Path) -> list[str]:
    binary = path.read_bytes()
    if not binary.startswith(b"%PDF"):
        raise ValueError(f"Not a PDF: {path}")
    # Each form-feed marks an official PDF page. Preserve original text.
    result = subprocess.run(
        ["pdftotext", "-layout", str(path), "-"],
        capture_output=True, check=True,
    )
    return result.stdout.decode("utf-8").split("\f")


def stage(year: int, question_pdf: Path, answer_pdf: Path) -> dict:
    if not 2022 <= year <= 2026:
        raise ValueError(f"Unexpected IPA release year: {year}")
    pages = read_pdf(question_pdf)
    answer_pages = read_pdf(answer_pdf)
    # Collect precise page locations and unmodified text segment boundaries.
    found = []
    for page_number, page in enumerate(pages, 1):
        matches = list(QUESTION_START.finditer(page))
        for i, match in enumerate(matches):
            number = int(match.group(1))
            if not 1 <= number <= 100:
                continue
            end = matches[i + 1].start() if i + 1 < len(matches) else len(page)
            fragment = page[match.start():end].strip()
            if len(fragment) < 15:
                continue
            found.append({
                "question_number": number,
                "source_page": page_number,
                "raw_text_segment": fragment,
                "verbatim_visual_audit": "HOLD",
                "official_answer_audit": "HOLD",
                "figure_audit": "HOLD",
                "release_eligible": False,
            })
    seen = {}
    for item in found:
        seen.setdefault(item["question_number"], []).append(item)
    unique = sorted(n for n in seen if len(seen[n]) == 1)
    missing = sorted(set(range(1, 101)) - set(unique))
    # Do not silently choose duplicate segments or invent diagrams / answers.
    drafts = [seen[n][0] for n in unique]
    evidence = {
        "year": year,
        "question_pdf_sha256": sha256(question_pdf),
        "answer_pdf_sha256": sha256(answer_pdf),
        "question_pdf_bytes": question_pdf.stat().st_size,
        "answer_pdf_bytes": answer_pdf.stat().st_size,
        "pdf_page_count": len([p for p in pages if p.strip()]),
        "answer_page_count": len([p for p in answer_pages if p.strip()]),
        "detected_unique_questions": len(drafts),
        "missing_or_duplicate_questions": missing,
        "raw_drafts": drafts,
        "answer_source_text": "\n\f\n".join(answer_pages),
        "status": "STAGED_UNVERIFIED_ONLY",
        "canonical_questions_promoted": 0,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{year}-unverified-drafts.json"
    dest.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"year": year, "drafts": len(drafts), "missing": missing, "path": str(dest)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("year", type=int)
    parser.add_argument("question_pdf", type=Path)
    parser.add_argument("answer_pdf", type=Path)
    args = parser.parse_args()
    print(json.dumps(stage(args.year, args.question_pdf, args.answer_pdf), ensure_ascii=False))


if __name__ == "__main__":
    main()
