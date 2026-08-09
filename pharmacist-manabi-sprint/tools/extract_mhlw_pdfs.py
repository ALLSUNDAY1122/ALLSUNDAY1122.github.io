#!/usr/bin/env python3
"""Extract question blocks from the official MHLW pharmacist exam PDFs.

This script is intentionally source-only: it does not generate answers or explanations.
It downloads the official PDFs, extracts their text layer with PyMuPDF, splits only
within the expected question-number range for each PDF, and writes one JSON record
per official question. The generated files are audit inputs, not release-ready data.
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path

import fitz  # PyMuPDF

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "content" / "extracted"
CACHE_DIR = ROOT / ".pdf-cache"

SOURCES = {
    111: [
        ("mandatory", 1, 90, "https://www.mhlw.go.jp/content/001677927.pdf"),
        ("theory-a", 91, 150, "https://www.mhlw.go.jp/content/001677928.pdf"),
        ("theory-b", 151, 195, "https://www.mhlw.go.jp/content/001677929.pdf"),
        ("practical-a", 196, 245, "https://www.mhlw.go.jp/content/001677930.pdf"),
        ("practical-b", 246, 285, "https://www.mhlw.go.jp/content/001677931.pdf"),
        ("practical-c", 286, 345, "https://www.mhlw.go.jp/content/001677932.pdf"),
    ],
    110: [
        ("mandatory", 1, 90, "https://www.mhlw.go.jp/content/001455149.pdf"),
        ("theory-a", 91, 150, "https://www.mhlw.go.jp/content/001455152.pdf"),
        ("theory-b", 151, 195, "https://www.mhlw.go.jp/content/001455159.pdf"),
        ("practical-a", 196, 245, "https://www.mhlw.go.jp/content/001455160.pdf"),
        ("practical-b", 246, 285, "https://www.mhlw.go.jp/content/001455161.pdf"),
        ("practical-c", 286, 345, "https://www.mhlw.go.jp/content/001455162.pdf"),
    ],
    109: [
        ("mandatory", 1, 90, "https://www.mhlw.go.jp/content/001226759.pdf"),
        ("theory-a", 91, 150, "https://www.mhlw.go.jp/content/001226760.pdf"),
        ("theory-b", 151, 195, "https://www.mhlw.go.jp/content/001226761.pdf"),
        ("practical-a", 196, 245, "https://www.mhlw.go.jp/content/001226762.pdf"),
        ("practical-b", 246, 285, "https://www.mhlw.go.jp/content/001226763.pdf"),
        ("practical-c", 286, 345, "https://www.mhlw.go.jp/content/001226764.pdf"),
    ],
}


def download(url: str, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and dst.stat().st_size > 1000:
        return
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 learning-sprint-audit/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r, dst.open("wb") as f:
        f.write(r.read())


def pdf_text(path: Path) -> str:
    doc = fitz.open(path)
    pages = []
    for page_no, page in enumerate(doc, 1):
        text = page.get_text("text", sort=True)
        pages.append(f"\n[[PAGE:{page_no}]]\n{text}")
    return "\n".join(pages)


def normalize_source_text(text: str) -> str:
    text = text.replace("\u3000", " ").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def question_markers(text: str, start: int, end: int):
    # Official PDF text generally places 問NN at the beginning of a line. Keep the
    # boundary strict to avoid references to another question inside body text.
    pat = re.compile(r"(?m)^\s*問\s*([0-9]{1,3})\s*(?:\n|$)")
    markers = []
    for m in pat.finditer(text):
        n = int(m.group(1))
        if start <= n <= end:
            markers.append((n, m.start(), m.end()))
    # Some PDFs extract `問 123  ...` on one line rather than line-breaking.
    if len({n for n, _, _ in markers}) < (end - start + 1):
        pat2 = re.compile(r"(?m)^\s*問\s*([0-9]{1,3})\s+")
        for m in pat2.finditer(text):
            n = int(m.group(1))
            if start <= n <= end:
                markers.append((n, m.start(), m.end()))
    # De-duplicate identical question/start pairs, then keep the earliest marker per q.
    earliest = {}
    for n, a, b in sorted(markers, key=lambda x: x[1]):
        earliest.setdefault(n, (a, b))
    return [(n, *earliest[n]) for n in sorted(earliest)]


def split_questions(text: str, start: int, end: int):
    markers = question_markers(text, start, end)
    by_pos = sorted(markers, key=lambda x: x[1])
    records = {}
    for i, (n, a, b) in enumerate(by_pos):
        next_a = by_pos[i + 1][1] if i + 1 < len(by_pos) else len(text)
        block = text[b:next_a].strip()
        # Remove page sentinel lines while preserving a list of source pages.
        pages = sorted({int(x) for x in re.findall(r"\[\[PAGE:(\d+)\]\]", block)})
        block = re.sub(r"\n?\[\[PAGE:\d+\]\]\n?", "\n", block).strip()
        records[n] = {"questionNo": n, "sourcePages": pages, "rawText": block}
    missing = [n for n in range(start, end + 1) if n not in records]
    extras = [n for n in records if not (start <= n <= end)]
    return records, missing, extras


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    overall = []
    failures = []

    for exam, parts in SOURCES.items():
        exam_records = {}
        source_files = []
        for part, start, end, url in parts:
            pdf_path = CACHE_DIR / f"{exam}-{part}.pdf"
            print(f"download {exam} {part}: {url}")
            download(url, pdf_path)
            text = normalize_source_text(pdf_text(pdf_path))
            records, missing, extras = split_questions(text, start, end)
            source_files.append({
                "part": part,
                "range": [start, end],
                "url": url,
                "detected": len(records),
                "missing": missing,
                "extras": extras,
            })
            if missing or extras or len(records) != end - start + 1:
                failures.append({"exam": exam, "part": part, "missing": missing, "extras": extras, "detected": len(records)})
            for n, rec in records.items():
                rec.update({"exam": exam, "part": part, "sourceUrl": url})
                exam_records[n] = rec

        ordered = [exam_records[n] for n in sorted(exam_records)]
        out = {
            "schemaVersion": 1,
            "exam": exam,
            "expectedQuestionCount": 345,
            "detectedQuestionCount": len(ordered),
            "sources": source_files,
            "questions": ordered,
        }
        (OUT_DIR / f"exam-{exam}-raw.json").write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
        overall.append({"exam": exam, "detected": len(ordered), "expected": 345, "sources": source_files})

    report = {"schemaVersion": 1, "totalExpected": 1035, "totalDetected": sum(x["detected"] for x in overall), "exams": overall, "failures": failures}
    (OUT_DIR / "extraction-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if failures or report["totalDetected"] != report["totalExpected"]:
        print("Extraction incomplete; refusing PASS.", file=sys.stderr)
        return 1
    print("PASS: all 1,035 official question blocks extracted")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
