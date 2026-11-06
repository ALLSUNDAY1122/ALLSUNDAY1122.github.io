#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent
BATCH_DIR = ROOT / "question-batches"


def load_questions() -> list[dict]:
    questions: list[dict] = []
    main = ROOT / "questions.json"
    if main.exists():
        data = json.loads(main.read_text(encoding="utf-8"))
        if isinstance(data, list):
            questions.extend(data)
    for path in sorted(BATCH_DIR.glob("questions-*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise ValueError(f"{path.name}: root must be an array")
        questions.extend(data)
    return questions


def is_search_or_discovery_url(url: str) -> bool:
    parsed = urlparse(url)
    host = parsed.netloc.lower()
    path = parsed.path.lower()
    query = parse_qs(parsed.query)

    if host == "pubmed.ncbi.nlm.nih.gov" and (path in {"", "/"}) and "term" in query:
        return True
    if host.endswith("google.com") and "/search" in path:
        return True
    if host.endswith("bing.com") and "/search" in path:
        return True
    return False


def main() -> int:
    errors: list[str] = []
    questions = load_questions()

    for question in questions:
        sid = str(question.get("id", "?"))
        refs = question.get("sourceRefs", [])
        if not isinstance(refs, list) or not refs:
            errors.append(f"{sid}: sourceRefs missing")
            continue
        weak = [str(url) for url in refs if is_search_or_discovery_url(str(url))]
        if weak:
            errors.append(f"{sid}: search/discovery URL cannot be final evidence: {weak}")

        embedded = question.get("contentAudit")
        if isinstance(embedded, dict):
            evidence = embedded.get("evidenceRefs", [])
            if isinstance(evidence, list):
                weak_embedded = [str(url) for url in evidence if is_search_or_discovery_url(str(url))]
                if weak_embedded:
                    errors.append(
                        f"{sid}: contentAudit uses search/discovery evidence: {weak_embedded}"
                    )

    if len(questions) != 600:
        errors.append(f"question count must be 600, got {len(questions)}")

    if errors:
        print("RIGAKU EVIDENCE QUALITY: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RIGAKU EVIDENCE QUALITY: PASS")
    print(f"specific evidence refs checked: {len(questions)} questions")
    print("generic PubMed/search-engine result URLs: 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
