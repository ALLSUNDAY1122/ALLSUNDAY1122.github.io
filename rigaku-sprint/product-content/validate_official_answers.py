#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(name: str):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def slot_id(round_no: int, session: str, number: int) -> str:
    return f"RIGAKU-R{round_no}-{session}-{number:03d}"


def normalize_codes(value):
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return value
    raise TypeError(f"unsupported answer value: {value!r}")


def valid_response_code(code: str) -> bool:
    if not re.fullmatch(r"[1-5]{1,2}", code):
        return False
    return len(set(code)) == len(code)


def main() -> int:
    answers = load("official-answers.json")
    adjustments = load("scoring-adjustments.json")
    errors: list[str] = []

    expected_rounds = {"60", "59", "58"}
    if set(answers.get("answers", {})) != expected_rounds:
        errors.append("official answer rounds must be 60/59/58")

    normalized: dict[str, list[str]] = {}
    for round_text in sorted(expected_rounds, reverse=True):
        sessions = answers["answers"].get(round_text, {})
        if set(sessions) != {"AM", "PM"}:
            errors.append(f"R{round_text} sessions must be AM/PM")
            continue
        for session in ("AM", "PM"):
            values = sessions[session]
            if len(values) != 100:
                errors.append(f"R{round_text}-{session} answer count must be 100, got {len(values)}")
                continue
            for index, value in enumerate(values, start=1):
                sid = slot_id(int(round_text), session, index)
                try:
                    codes = normalize_codes(value)
                except TypeError as exc:
                    errors.append(f"{sid}: {exc}")
                    continue
                if len(codes) != len(set(codes)):
                    errors.append(f"{sid}: duplicate accepted response code")
                for code in codes:
                    if not valid_response_code(code):
                        errors.append(f"{sid}: invalid response code {code}")
                normalized[sid] = codes

    if len(normalized) != 600:
        errors.append(f"normalized official answer count must be 600, got {len(normalized)}")

    expected_adjustments: dict[str, dict] = {item["id"]: item for item in adjustments["adjustments"]}
    excluded_ids = {sid for sid, codes in normalized.items() if not codes}
    multiple_ids = {sid for sid, codes in normalized.items() if len(codes) > 1}

    expected_excluded = {
        sid for sid, item in expected_adjustments.items() if item["treatment"] == "excluded"
    }
    expected_multiple = {
        sid for sid, item in expected_adjustments.items() if item["treatment"] == "multiple_accepted"
    }

    if excluded_ids != expected_excluded:
        errors.append(
            f"excluded set mismatch: answers={sorted(excluded_ids)}, adjustments={sorted(expected_excluded)}"
        )
    if multiple_ids != expected_multiple:
        errors.append(
            f"multiple accepted set mismatch: answers={sorted(multiple_ids)}, adjustments={sorted(expected_multiple)}"
        )

    for sid in expected_multiple:
        official_codes = normalized.get(sid, [])
        adjustment_codes = expected_adjustments[sid]["acceptedResponseCodes"]
        if official_codes != adjustment_codes:
            errors.append(
                f"{sid}: accepted codes mismatch answers={official_codes}, adjustments={adjustment_codes}"
            )

    if answers.get("sourceRevision", {}).get("59") != "corrected_final":
        errors.append("R59 must use corrected_final answer revision")

    if errors:
        print("RIGAKU OFFICIAL ANSWERS: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RIGAKU OFFICIAL ANSWERS: PASS")
    print("official answers normalized: 600")
    print(f"excluded: {len(excluded_ids)}")
    print(f"multiple accepted: {len(multiple_ids)}")
    print("R59 revision: corrected_final")
    return 0


if __name__ == "__main__":
    sys.exit(main())
