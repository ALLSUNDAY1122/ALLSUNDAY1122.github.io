#!/usr/bin/env python3
import io
import json
import re
import urllib.request
from pathlib import Path

import pdfplumber

UA = "Mozilla/5.0 (compatible; LearningSprintOfficialQuestionShapeSummary/1.0)"
HERE = Path(__file__).resolve().parent
OUT = HERE / "official-question-shapes-summary.json"

QUESTION_PDFS = {
    "2024-憲法・行政法": "https://www.moj.go.jp/content/001421751.pdf",
    "2024-民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001421752.pdf",
    "2024-刑法・刑事訴訟法": "https://www.moj.go.jp/content/001421753.pdf",
    "2024-一般教養科目": "https://www.moj.go.jp/content/001421754.pdf",
    "2025-憲法・行政法": "https://www.moj.go.jp/content/001443616.pdf",
    "2025-民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001443617.pdf",
    "2025-刑法・刑事訴訟法": "https://www.moj.go.jp/content/001443618.pdf",
    "2025-一般教養科目": "https://www.moj.go.jp/content/001443619.pdf",
    "2026-憲法・行政法": "https://www.moj.go.jp/content/001466957.pdf",
    "2026-民法・商法・民事訴訟法": "https://www.moj.go.jp/content/001466958.pdf",
    "2026-刑法・刑事訴訟法": "https://www.moj.go.jp/content/001466959.pdf",
    "2026-一般教養科目": "https://www.moj.go.jp/content/001466960.pdf",
}

GROUP_SUBJECT_RANGES = {
    "憲法・行政法": [(1, 12, "憲法"), (13, 24, "行政法")],
    "民法・商法・民事訴訟法": [(1, 15, "民法"), (16, 30, "商法"), (31, 45, "民事訴訟法")],
    "刑法・刑事訴訟法": [(1, 13, "刑法"), (14, 26, "刑事訴訟法")],
}

DIGIT_MAP = str.maketrans("０１２３４５６７８９", "0123456789")
QUESTION_RE = re.compile(r"〔\s*第\s*([0-9０-９]+)\s*問\s*〕")
NO_PATTERNS = [
    re.compile(r"[［\[]\s*(?:No\.?|NO\.?|Ｎｏ\.?|№)\s*([0-9０-９]+)\s*[］\]]", re.I),
    re.compile(r"(?:No\.?|NO\.?|Ｎｏ\.?|№)\s*([0-9０-９]+)", re.I),
]
POINT_RE = re.compile(r"配点\s*[：:]?\s*([0-9０-９]+)")


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/pdf"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()


def fwint(value: str) -> int:
    return int(value.translate(DIGIT_MAP))


def normalize(text: str) -> str:
    return (text or "").replace("\u3000", " ")


def subject_for(group: str, question_number: int) -> str:
    if group == "一般教養科目":
        return "一般教養科目"
    for start, end, subject in GROUP_SUBJECT_RANGES[group]:
        if start <= question_number <= end:
            return subject
    raise ValueError(f"question outside subject range: {group} q{question_number}")


def extract_slots(block: str):
    slots = set()
    for pattern in NO_PATTERNS:
        for match in pattern.finditer(block):
            slots.add(fwint(match.group(1)))
    return sorted(slots)


def extract_document(key: str, url: str):
    year_text, group = key.split("-", 1)
    year = int(year_text)
    raw = fetch(url)
    page_texts = []
    with pdfplumber.open(io.BytesIO(raw)) as pdf:
        for page in pdf.pages:
            # layout=True keeps answer-box labels close to their source question.
            text = page.extract_text(layout=True, x_tolerance=2, y_tolerance=2) or ""
            page_texts.append(normalize(text))
    joined = "\n<<<PAGE_BREAK>>>\n".join(page_texts)
    matches = list(QUESTION_RE.finditer(joined))
    by_question = {}
    for index, match in enumerate(matches):
        qno = fwint(match.group(1))
        end = matches[index + 1].start() if index + 1 < len(matches) else len(joined)
        block = joined[match.start():end]
        slots = extract_slots(block)
        point_match = POINT_RE.search(block[:700])
        points = fwint(point_match.group(1)) if point_match else None
        item = {
            "questionNumber": qno,
            "subject": subject_for(group, qno),
            "slots": slots,
            "pointsFromQuestionPDF": points,
            "blockSnippet": re.sub(r"\s+", " ", block[:800]).strip(),
        }
        # Shared passages can repeat headings. Prefer the occurrence with more slot evidence.
        previous = by_question.get(qno)
        if previous is None or len(item["slots"]) > len(previous["slots"]):
            by_question[qno] = item

    expected_questions = 42 if key == "2024-一般教養科目" else 44 if group == "一般教養科目" else 24 if group == "憲法・行政法" else 45 if group == "民法・商法・民事訴訟法" else 26
    missing_questions = sorted(set(range(1, expected_questions + 1)) - set(by_question))
    slotless = [q for q, item in sorted(by_question.items()) if not item["slots"]]
    return {
        "url": url,
        "bytes": len(raw),
        "expectedQuestions": expected_questions,
        "questions": [by_question[q] for q in sorted(by_question)],
        "missingQuestions": missing_questions,
        "slotlessQuestions": slotless,
    }


def main():
    result = {"schemaVersion": 1, "documents": {}}
    failures = []
    for key, url in QUESTION_PDFS.items():
        doc = extract_document(key, url)
        result["documents"][key] = doc
        print(f"SHAPES {key}: questions={len(doc['questions'])}/{doc['expectedQuestions']} missing={doc['missingQuestions']} slotless={doc['slotlessQuestions']}")
        if doc["missingQuestions"]:
            failures.append(f"{key}: missing question headings {doc['missingQuestions']}")
        # General education has one answer box per question and legal questions must have >=1.
        if doc["slotlessQuestions"]:
            failures.append(f"{key}: slotless questions {doc['slotlessQuestions']}")

    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"WROTE {OUT} bytes={OUT.stat().st_size}")
    if failures:
        for failure in failures:
            print("FAILURE", failure)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
