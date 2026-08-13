#!/usr/bin/env python3
"""Editorial/structural release gate for independently authored practice items.

This gate does not re-decide the law. Legal source/date and answer correctness are
separate upstream gates. Here we require enough teaching value to justify a
formal learning-bank release: explicit difficulty, four unique choices, wrong-
choice rationales, substantive explanation, concise memory cue, evidence chain,
and no near-duplicate stems.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_INPUT = ROOT / "practice-release-staging.v1.json"
DEFAULT_REPORT = ROOT / "practice-release-quality-audit.v1.json"
DIFFICULTIES = {"foundation", "standard", "applied"}


class QualityError(ValueError):
    pass


def normalized(text: str) -> str:
    return re.sub(r"[\s、。・『』「」（）()\[\]]+", "", text or "")


def inspect_item(item: dict) -> list[str]:
    qid = item.get("id", "<no-id>")
    failures: list[str] = []

    if item.get("content_use") != "practice":
        failures.append("content_use_not_practice")
    if item.get("exam_year") is not None:
        failures.append("practice_has_official_exam_year")
    if item.get("audit_status") != "pending_release_audit":
        failures.append("not_pending_release_audit")
    if item.get("release_eligible") is not False:
        failures.append("already_release_eligible")
    if item.get("difficulty") not in DIFFICULTIES:
        failures.append("difficulty_missing_or_invalid")

    choices = item.get("choices")
    if not isinstance(choices, list) or len(choices) != 4:
        failures.append("exactly_four_choices_required")
        choices = choices if isinstance(choices, list) else []
    norm_choices = [normalized(str(choice)) for choice in choices]
    if len(norm_choices) != len(set(norm_choices)):
        failures.append("duplicate_choices")

    if item.get("answer_type") != "singleChoice":
        failures.append("current_practice_release_requires_singleChoice")
    answer = item.get("answer")
    if not isinstance(answer, int) or not 0 <= answer < len(choices):
        failures.append("answer_index_invalid")

    question = item.get("question", "")
    explanation = item.get("explanation", "")
    memory = item.get("memory", "")
    if len(normalized(question)) < 18:
        failures.append("question_too_short")
    if len(normalized(explanation)) < 70:
        failures.append("explanation_too_shallow")
    if not 8 <= len(normalized(memory)) <= 45:
        failures.append("memory_length_out_of_range")

    notes = item.get("distractor_notes")
    if not isinstance(notes, list) or len(notes) != len(choices):
        failures.append("distractor_notes_missing_or_wrong_count")
    elif isinstance(answer, int) and 0 <= answer < len(choices):
        for index, note in enumerate(notes):
            if index == answer:
                if note not in (None, ""):
                    failures.append("correct_choice_must_not_have_distractor_note")
            elif not isinstance(note, str) or len(normalized(note)) < 12:
                failures.append(f"distractor_note_too_shallow:{index}")

    for key in (
        "source_title", "source_url", "evidence_checked_date", "reference_date",
        "rights_basis", "staging_evidence",
    ):
        if not item.get(key):
            failures.append(f"missing_evidence:{key}")

    staging = item.get("staging_evidence") or {}
    if staging.get("answer_audit_verdict") != "PASS" or staging.get("answer_audit_risk") != "low":
        failures.append("upstream_answer_audit_not_low_risk_pass")

    return sorted(set(failures))


def build_report(items: list[dict]) -> dict:
    if not isinstance(items, list) or not items:
        raise QualityError("staging bank must be a non-empty list")
    ids = [item.get("id") for item in items]
    if any(not qid for qid in ids) or len(ids) != len(set(ids)):
        raise QualityError("missing or duplicate item IDs")

    results = []
    for item in items:
        failures = inspect_item(item)
        results.append({
            "id": item["id"],
            "subject": item.get("subject"),
            "difficulty": item.get("difficulty"),
            "verdict": "PASS" if not failures else "HOLD",
            "failures": failures,
        })

    near_duplicates = []
    for i, left in enumerate(items):
        for right in items[i + 1:]:
            ratio = difflib.SequenceMatcher(
                None, normalized(left.get("question", "")), normalized(right.get("question", ""))
            ).ratio()
            if ratio >= 0.84:
                pair = {"left": left["id"], "right": right["id"], "ratio": round(ratio, 3)}
                near_duplicates.append(pair)
                for result in results:
                    if result["id"] in {left["id"], right["id"]}:
                        result["verdict"] = "HOLD"
                        result["failures"] = sorted(set(result["failures"] + ["near_duplicate_question"]))

    passed = sum(result["verdict"] == "PASS" for result in results)
    return {
        "schemaVersion": 1,
        "checkedAt": "2026-08-13",
        "scope": "independently-authored practice staging",
        "policy": {
            "legalCorrectnessGate": "separate upstream e-Gov exact-date + answer audit",
            "automaticRelease": False,
            "requiredDifficulty": sorted(DIFFICULTIES),
            "requiredChoices": 4,
            "minimumExplanationNormalizedChars": 70,
            "minimumWrongChoiceRationaleNormalizedChars": 12,
            "nearDuplicateThreshold": 0.84,
        },
        "summary": {
            "total": len(results),
            "pass": passed,
            "hold": len(results) - passed,
            "nearDuplicatePairs": len(near_duplicates),
        },
        "nearDuplicates": near_duplicates,
        "items": results,
        "overallVerdict": "PASS" if passed == len(results) else "HOLD",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--require-pass", action="store_true")
    args = parser.parse_args()

    items = json.loads(args.input.read_text(encoding="utf-8"))
    report = build_report(items)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = report["summary"]
    print(f"QUALITY {report['overallVerdict']}: total={summary['total']} pass={summary['pass']} hold={summary['hold']} nearDuplicates={summary['nearDuplicatePairs']}")
    for item in report["items"]:
        if item["verdict"] != "PASS":
            print(f"HOLD {item['id']}: {','.join(item['failures'])}")
    print(f"WROTE {args.report}")
    if args.require_pass and report["overallVerdict"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
