#!/usr/bin/env python3
"""Fail-closed release gate for five complete IPA IT Passport public exam sets."""
from __future__ import annotations

import collections
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QDIR = ROOT / "questions"
EXPECTED_YEARS = (2022, 2023, 2024, 2025, 2026)
EXPECTED_TOTAL = 500
SHA256 = re.compile(r"^[a-f0-9]{64}$")


def read_json(path: Path):
    if not path.exists():
        raise ValueError(f"MISSING: {path.relative_to(ROOT)}")
    return json.loads(path.read_text(encoding="utf-8"))


def check():
    m = read_json(QDIR / "manifest.json")
    led = read_json(QDIR / "official-source-ledger.json")
    qbank = read_json(QDIR / "official-verbatim.json")
    status = read_json(ROOT / "release-status.json")
    assert isinstance(qbank, list), "official-verbatim.json must be an array"
    official = m["canonical"]["official"]
    assert tuple(official["release_years"]) == EXPECTED_YEARS, "wrong official exam years"
    assert official["release_target"] == EXPECTED_TOTAL, "release target must be 500"
    assert official["current"] == len(qbank), "manifest/count mismatch"
    assert len(qbank) == EXPECTED_TOTAL, f"OFFICIAL_NOT_READY: {len(qbank)}/500 verified questions"
    assert status["requirements"]["official_release_target"] == 500
    sources = {int(s["year"]): s for s in led["years"]}
    assert set(sources) == set(EXPECTED_YEARS), "source ledger year mismatch"
    counts = collections.Counter()
    seen = set()
    for index, item in enumerate(qbank, 1):
        assert isinstance(item, dict), f"item {index}: not object"
        year = item.get("year")
        number = item.get("question_number")
        assert year in sources and type(number) is int and 1 <= number <= 100, f"item {index}: year/number invalid"
        pair = (year, number)
        assert pair not in seen, f"duplicate IPA question: {pair}"
        seen.add(pair)
        counts[year] += 1
        origin = item.get("origin_type")
        assert origin == "ipa_published_verbatim", f"{pair}: original/rewritten problem forbidden"
        source = sources[year]
        assert source.get("question_pdf"), f"{year}: official PDF source not verified"
        assert source.get("answer_pdf"), f"{year}: official answer PDF not verified"
        assert item.get("source_url") == source["question_pdf"], f"{pair}: incorrect source URL"
        assert item.get("answer_source_url") == source["answer_pdf"], f"{pair}: incorrect official answer source"
        assert isinstance(item.get("source_page"), int) and item["source_page"] >= 1, f"{pair}: PDF page missing"
        assert item.get("source_label") == f"出典：令和{year - 2018}年度 ITパスポート試験 公開問題 問{number}", f"{pair}: source label missing"
        assert item.get("modified") is False, f"{pair}: modified question cannot be advertised as verbatim"
        assert item.get("verbatim_visual_audit") == "PASS", f"{pair}: visual audit not PASS"
        assert item.get("official_answer_audit") == "PASS", f"{pair}: answer audit not PASS"
        assert isinstance(item.get("question"), str) and item["question"].strip(), f"{pair}: text missing"
        choices = item.get("choices")
        assert isinstance(choices, list) and len(choices) == 4 and all(isinstance(c, str) and c.strip() for c in choices), f"{pair}: four source choices required"
        assert type(item.get("correct_index")) is int and 0 <= item["correct_index"] < 4, f"{pair}: answer index invalid"
        assert SHA256.fullmatch(str(item.get("source_question_sha256", ""))), f"{pair}: source content audit hash missing"
        assert item.get("figure_audit") in {"PASS", "NOT_REQUIRED"}, f"{pair}: figure audit missing"
        assert item.get("syllabus_version") and item.get("basis_date"), f"{pair}: syllabus/basis date missing"
    assert all(counts[y] == 100 for y in EXPECTED_YEARS), f"year distributions invalid: {dict(counts)}"
    assert all(s.get("release_ready") and s.get("verbatim_transcribed") == 100 and s.get("correct_answers_audited") == 100 for s in sources.values()), "year-level independent audit not complete"
    print("PASS: five complete IPA public exam sets / official source / attribution / answer and visual audit")


if __name__ == "__main__":
    try:
        check()
    except (AssertionError, ValueError, KeyError, TypeError) as exc:
        print(f"BLOCKED: {exc}", file=sys.stderr)
        sys.exit(1)
