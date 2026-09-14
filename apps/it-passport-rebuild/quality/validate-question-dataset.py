#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import re
import unicodedata
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
QUESTIONS_DIR = ROOT / "questions"
QUALITY_DIR = ROOT / "quality"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def valid_http_url(value: str) -> bool:
    try:
        u = urlparse(value)
        return u.scheme in {"http", "https"} and bool(u.netloc)
    except Exception:
        return False


def normalize_text(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).lower()
    return re.sub(r"\s+", "", value)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", action="store_true", help="enforce complete canonical release pool")
    args = ap.parse_args()

    manifest = load_json(QUESTIONS_DIR / "manifest.json")
    config = load_json(QUALITY_DIR / "exam-config.json")
    questions = load_json(QUESTIONS_DIR / "original-mock.json")

    require(isinstance(questions, list), "original-mock.json must be a JSON array")
    required = list(config["required_fields"])
    allowed_subjects = set(config["subjects"])
    live_syllabus = str(manifest["current_syllabus_version"])
    draft_syllabus = str((manifest.get("next_system") or {}).get("draft_syllabus_version") or "")
    block_draft = bool((manifest.get("release_guards") or {}).get("block_draft_questions_from_live_pool"))

    seen_ids = set()
    seen_questions = set()
    round_subject = collections.defaultdict(collections.Counter)
    round_counts = collections.Counter()

    for i, q in enumerate(questions, 1):
        where = f"question[{i}]"
        require(isinstance(q, dict), f"{where} must be an object")
        missing = [k for k in required if k not in q]
        require(not missing, f"{where} missing fields: {missing}")

        qid = str(q["id"]).strip()
        require(qid, f"{where}.id empty")
        require(qid not in seen_ids, f"duplicate id: {qid}")
        seen_ids.add(qid)

        question = str(q["question"]).strip()
        require(question, f"{qid}: question empty")
        nq = normalize_text(question)
        require(nq not in seen_questions, f"{qid}: duplicate normalized question text")
        seen_questions.add(nq)

        subject = str(q["subject"]).strip()
        require(subject in allowed_subjects, f"{qid}: invalid subject {subject!r}")
        choices = q["choices"]
        require(isinstance(choices, list) and len(choices) == 4, f"{qid}: choices must contain exactly 4 items")
        require(all(isinstance(x, str) and x.strip() for x in choices), f"{qid}: choices must be non-empty strings")
        normalized_choices = [normalize_text(x) for x in choices]
        require(len(set(normalized_choices)) == 4, f"{qid}: choices must be distinct")
        correct = q["correct_index"]
        require(isinstance(correct, int) and 0 <= correct < 4, f"{qid}: correct_index must be 0..3")
        require(isinstance(q["explanation"], str) and q["explanation"].strip(), f"{qid}: explanation empty")
        require(isinstance(q["topic"], str) and q["topic"].strip(), f"{qid}: topic empty")

        version = str(q["syllabus_version"]).strip()
        require(version, f"{qid}: syllabus_version empty")
        if block_draft and draft_syllabus:
            require(version != draft_syllabus, f"{qid}: draft syllabus {draft_syllabus} cannot enter live pool")
        require(version == live_syllabus, f"{qid}: live pool requires syllabus {live_syllabus}, got {version}")

        source_url = str(q["source_url"]).strip()
        require(valid_http_url(source_url), f"{qid}: invalid source_url")
        require(str(q["reference_date"]).strip(), f"{qid}: reference_date empty")
        require(str(q["origin_type"]).strip(), f"{qid}: origin_type empty")
        require(str(q["rights_basis"]).strip(), f"{qid}: rights_basis empty")

        rnd_raw = q["round"]
        require(isinstance(rnd_raw, int), f"{qid}: round must be an integer")
        rnd = rnd_raw
        require(1 <= rnd <= int(config["rounds"]), f"{qid}: round out of range: {rnd}")
        round_counts[rnd] += 1
        round_subject[rnd][subject] += 1

    canonical = manifest["canonical"]["original_mock"]
    target = int(canonical["target"])
    configured_rounds = int(config["rounds"])
    per_round = sum(int(v) for v in config["subjects"].values())
    require(target == configured_rounds * per_round, "manifest target must equal rounds × per-round distribution")
    require(int(canonical.get("current", -1)) == len(questions), "manifest canonical.current must match actual count")
    require(len(questions) <= target, f"dataset exceeds target {target}")
    for rnd, count in round_counts.items():
        require(count <= per_round, f"round {rnd}: exceeds {per_round} questions")
        for subject, actual in round_subject[rnd].items():
            expected = int(config["subjects"][subject])
            require(actual <= expected, f"round {rnd} {subject}: exceeds target {expected}")

    if args.release:
        require(len(questions) == target, f"release requires {target} questions, found {len(questions)}")
        require(len(round_counts) == configured_rounds, f"release requires {configured_rounds} rounds, found {len(round_counts)}")
        for rnd in range(1, configured_rounds + 1):
            count = round_counts[rnd]
            require(count == per_round, f"round {rnd}: expected {per_round} questions, found {count}")
            for subject, expected in config["subjects"].items():
                actual = round_subject[rnd][subject]
                require(actual == int(expected), f"round {rnd} {subject}: expected {expected}, found {actual}")
        print(f"PASS: IT Passport release dataset {len(questions)} questions / {configured_rounds} rounds / syllabus {live_syllabus}")
    else:
        progress = 100.0 * len(questions) / target if target else 0.0
        print(f"PASS: IT Passport development dataset schema valid; current={len(questions)} target={target} progress={progress:.1f}% live_syllabus={live_syllabus}")
        if len(questions) < target:
            print(f"INFO: release intentionally incomplete by {target - len(questions)} questions")


if __name__ == "__main__":
    main()
