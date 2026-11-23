#!/usr/bin/env python3
"""Verify source transcription completeness and official answer-key vectors for FP3 2023."""
from __future__ import annotations
import json, pathlib, re, unicodedata

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = {
    "2023-05": {
        "question": ROOT / "sources/2023-05-g3-academic-question-source.txt",
        "answer": ROOT / "sources/2023-05-g3-academic-answer-source.txt",
        "tf": [2,1,2,1,2,2,1,2,1,2,2,1,1,2,2,2,2,1,1,2,1,2,1,2,1,1,1,1,2,1],
        "mc": [2,3,1,3,2,1,2,3,3,1,2,2,1,3,2,1,2,1,2,1,2,3,1,1,3,3,3,2,1,3],
        "date": "2023年5月28日",
    },
    "2023-09": {
        "question": ROOT / "sources/2023-09-g3-academic-question-source.txt",
        "answer": ROOT / "sources/2023-09-g3-academic-answer-source.txt",
        "tf": [1,2,2,1,1,2,1,2,1,1,2,2,1,2,1,2,2,2,2,2,1,2,1,2,1,2,1,2,1,1],
        "mc": [3,2,3,1,1,3,1,3,2,3,1,2,1,1,3,3,1,3,3,1,2,1,2,2,2,3,2,2,2,3],
        "date": "2023年9月10日",
    },
}

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

def main() -> int:
    report = {}
    for exam, item in SOURCES.items():
        qtext = unicodedata.normalize("NFKC", item["question"].read_text(encoding="utf-8"))
        atext = unicodedata.normalize("NFKC", item["answer"].read_text(encoding="utf-8"))
        nums = sorted({int(x) for x in re.findall(r"\((\d{1,2})\)", qtext) if 1 <= int(x) <= 60})
        if nums != list(range(1, 61)):
            fail(f"{exam}: question numbers incomplete: {nums}")
        if len(item["tf"]) != 30 or len(item["mc"]) != 30:
            fail(f"{exam}: answer vector length invalid")
        if any(x not in (1,2) for x in item["tf"]) or any(x not in (1,2,3) for x in item["mc"]):
            fail(f"{exam}: answer value out of range")
        if item["date"] not in atext:
            fail(f"{exam}: answer PDF date mismatch")
        if not all(f"問{x}" in atext for x in (1,10,20,30,31,40,50,60)):
            fail(f"{exam}: answer PDF question labels missing")
        lines = [line.strip() for line in atext.splitlines()]
        extracted = []
        for i, line in enumerate(lines):
            labels = re.findall("問 *([0-9]+)", line)
            if len(labels) == 10:
                j = i + 1
                while j < len(lines) and not lines[j]:
                    j += 1
                if j >= len(lines):
                    fail(f"{exam}: answer row missing after labels")
                values = [int(v) for v in re.findall("(?<![0-9])[123](?![0-9])", lines[j])]
                if len(values) != 10:
                    fail(f"{exam}: expected 10 answer values, got {values}")
                extracted.extend(values)
        expected = item["tf"] + item["mc"]
        if extracted != expected:
            fail(f"{exam}: extracted official answer vector mismatch: {extracted}")
        report[exam] = {"date": item["date"], "questions": 60, "true_false": 30,
                        "multiple_choice": 30, "answer_key_entries": 60,
                        "answer_key_source": item["answer"].name}
    print(json.dumps({"status":"PASS","exams":report,"total_questions":120}, ensure_ascii=False))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
