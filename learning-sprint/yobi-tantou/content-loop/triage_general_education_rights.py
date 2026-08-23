#!/usr/bin/env python3
"""Fail-closed item-level rights triage for official general-education PDFs.

This script is intentionally NOT a copyright clearance engine. It only detects
signals that make manual rights review more urgent. Every item remains
reuseEligible=false until a human-verifiable item-level rights basis is recorded.

No official question text or excerpts are written to the output artifact.
"""

from __future__ import annotations

import io
import json
import re
import urllib.request
from collections import defaultdict
from pathlib import Path

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "official-general-education-rights-triage.v1.json"

EXAMS = {
    2024: {
        "url": "https://www.moj.go.jp/content/001421754.pdf",
        "expected": 42,
    },
    2025: {
        "url": "https://www.moj.go.jp/content/001443619.pdf",
        "expected": 44,
    },
    2026: {
        "url": "https://www.moj.go.jp/content/001466960.pdf",
        "expected": 44,
    },
}

QUESTION_HEADER = re.compile(r"〔\s*第\s*(\d+)\s*問\s*〕")
SHARED_HEADER = re.compile(
    r"〔\s*第\s*(\d+)\s*問\s*〕\s*(?:及び|・|、)\s*〔\s*第\s*(\d+)\s*問\s*〕"
)

SIGNALS: list[tuple[str, re.Pattern[str]]] = [
    ("explicit_source_or_attribution", re.compile(r"出典|出所|引用|出題に際して|原文を|一部変更|一部改変|参考文献")),
    ("named_author_or_work", re.compile(r"著者|著『|著「|訳者|訳『|訳「|\b[A-Z][A-Za-z.-]+\s+[A-Z][A-Za-z.-]+\b")),
    ("figure_table_photo", re.compile(r"写真|図\s*\d*|図表|グラフ|表\s*\d*|地図|模式図")),
    ("publication_or_web_source", re.compile(r"新聞|雑誌|論文|書籍|ウェブ|Web|WEB|ホームページ|サイト|URL|https?://|www\.")),
    ("copyright_marker", re.compile(r"©|Copyright|copyright|All rights reserved")),
]


def fetch_pdf(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (compatible; YobiTantouRightsAudit/1.0)"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read()
    if not data.startswith(b"%PDF"):
        raise RuntimeError(f"not a PDF: {url}")
    return data


def extract_text(data: bytes) -> str:
    reader = PdfReader(io.BytesIO(data))
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def question_blocks(text: str, expected: int) -> dict[int, str]:
    """Return one best individual block per official question number.

    Shared-passage headings can mention the same question numbers before the
    actual individual question headings. Selecting the final occurrence for a
    number reliably chooses the individual question block in the R6-R8 PDFs.
    """
    matches = list(QUESTION_HEADER.finditer(text))
    by_number: dict[int, list[re.Match[str]]] = defaultdict(list)
    for match in matches:
        number = int(match.group(1))
        if 1 <= number <= expected:
            by_number[number].append(match)

    missing = [number for number in range(1, expected + 1) if number not in by_number]
    if missing:
        raise RuntimeError(f"missing question headers: {missing}")

    selected = {number: occurrences[-1] for number, occurrences in by_number.items()}
    ordered = sorted(selected.items(), key=lambda item: item[1].start())
    blocks: dict[int, str] = {}
    for index, (number, match) in enumerate(ordered):
        end = ordered[index + 1][1].start() if index + 1 < len(ordered) else len(text)
        blocks[number] = text[match.start():end]
    return blocks


def shared_context_signals(text: str, expected: int) -> dict[int, set[str]]:
    propagated: dict[int, set[str]] = defaultdict(set)
    for shared in SHARED_HEADER.finditer(text):
        q1, q2 = int(shared.group(1)), int(shared.group(2))
        if not (1 <= q1 <= expected and 1 <= q2 <= expected):
            continue
        # Find the later individual q1 heading; content before it is the common
        # passage/instructions that apply to both questions.
        later = QUESTION_HEADER.search(text, shared.end())
        while later is not None and int(later.group(1)) not in {q1, q2}:
            later = QUESTION_HEADER.search(text, later.end())
        end = later.start() if later is not None else min(len(text), shared.end() + 12000)
        context = text[shared.start():end]
        for signal in detect_signals(context):
            propagated[q1].add(signal)
            propagated[q2].add(signal)
        if english_word_count(context) >= 80:
            propagated[q1].add("substantial_english_passage")
            propagated[q2].add("substantial_english_passage")
        propagated[q1].add("shared_source_passage")
        propagated[q2].add("shared_source_passage")
    return propagated


def detect_signals(block: str) -> list[str]:
    return [name for name, pattern in SIGNALS if pattern.search(block)]


def english_word_count(block: str) -> int:
    return len(re.findall(r"\b[A-Za-z]{2,}\b", block))


def classify(block: str, inherited: set[str]) -> list[str]:
    found = set(detect_signals(block)) | inherited
    if english_word_count(block) >= 80:
        found.add("substantial_english_passage")
    # A large item can contain a substantial quoted work even if extraction
    # loses explicit attribution markers. This is only a review-priority flag.
    if len(block) >= 7000:
        found.add("long_question_block")
    return sorted(found)


def build() -> dict:
    years: dict[str, dict] = {}
    for year, config in EXAMS.items():
        data = fetch_pdf(config["url"])
        text = extract_text(data)
        blocks = question_blocks(text, config["expected"])
        inherited = shared_context_signals(text, config["expected"])

        items = []
        for number in range(1, config["expected"] + 1):
            signals = classify(blocks[number], inherited.get(number, set()))
            items.append(
                {
                    "questionNumber": number,
                    "riskSignals": signals,
                    "riskSignalCount": len(signals),
                    "rightsReviewStatus": "manual_review_required",
                    "reuseEligible": False,
                    "clearanceBasis": None,
                }
            )

        if len(items) != config["expected"]:
            raise RuntimeError(f"{year}: expected {config['expected']} items, got {len(items)}")
        if any(item["reuseEligible"] for item in items):
            raise RuntimeError(f"{year}: fail-closed invariant violated")

        years[str(year)] = {
            "officialQuestionCount": config["expected"],
            "sourceURL": config["url"],
            "items": items,
        }
        flagged = sum(bool(item["riskSignals"]) for item in items)
        print(f"RIGHTS_TRIAGE {year}: items={len(items)} flagged={flagged} reuseEligible=0")

    result = {
        "schemaVersion": 1,
        "qualification": "司法試験予備試験・短答式",
        "scope": "一般教養科目",
        "generatedAt": "2026-08-13",
        "policy": {
            "automaticClearanceAllowed": False,
            "defaultReuseEligible": False,
            "note": "Risk signals only prioritize manual review; absence of a signal never establishes reuse permission.",
        },
        "years": years,
    }
    return result


def main() -> None:
    result = build()
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"WROTE {OUT} bytes={OUT.stat().st_size}")
    print("PASS: all R6-R8 general-education items remain fail-closed pending item-level rights review")


if __name__ == "__main__":
    main()
