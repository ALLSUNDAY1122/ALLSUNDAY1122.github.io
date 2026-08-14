#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import re
import statistics
from pathlib import Path


class AuditError(ValueError):
    pass


def number_from_choice(text: str) -> float:
    cleaned = str(text).replace(",", "")
    match = re.search(r"-?\d+(?:\.\d+)?", cleaned)
    if not match:
        raise AuditError(f"numeric choice expected: {text}")
    return float(match.group(0))


def close(a: float, b: float) -> bool:
    return math.isclose(float(a), float(b), rel_tol=1e-9, abs_tol=1e-9)


def compute(v: dict):
    kind = v.get("kind")
    if kind == "ratio_percent":
        return v["part"] / v["whole"] * 100
    if kind == "mean":
        return statistics.mean(v["values"])
    if kind == "increase_percent":
        return (v["after"] - v["before"]) / v["before"] * 100
    if kind == "ratio_share":
        return v["total"] * v["parts"][v["target_index"]] / sum(v["parts"])
    if kind == "divide":
        return v["numerator"] / v["denominator"]
    if kind == "difference":
        return v["a"] - v["b"]
    if kind == "median":
        return statistics.median(v["values"])
    if kind == "discount":
        return v["price"] * (100 - v["discount_percent"]) / 100
    if kind == "multiply":
        return v["a"] * v["b"]
    if kind == "compound_percent":
        value = float(v["base"])
        for percent in v["percents"]:
            value *= percent / 100
        return value
    if kind == "sum":
        return sum(v["values"])
    if kind == "remainder":
        return v["total"] - sum(v["parts"])
    raise AuditError(f"unsupported deterministic verification kind: {kind}")


def audit_item(item: dict) -> dict:
    qid = item.get("id", "<no-id>")
    verification = item.get("verification") or {}
    kind = verification.get("kind")
    choices = item.get("choices") or []
    answer = item.get("answer")
    if not isinstance(answer, int) or not 0 <= answer < len(choices):
        raise AuditError(f"{qid}: invalid answer index")

    if kind == "fraction":
        expected = str(verification["correct_text"])
        if str(choices[answer]).strip() != expected:
            raise AuditError(f"{qid}: fraction answer choice does not match computed fixture")
        if sum(str(choice).strip() == expected for choice in choices) != 1:
            raise AuditError(f"{qid}: fraction correct value is not unique")
        computed = expected
    else:
        computed = compute(verification)
        selected = number_from_choice(choices[answer])
        if not close(selected, computed):
            raise AuditError(f"{qid}: selected choice {selected} != computed {computed}")
        numeric_matches = 0
        for choice in choices:
            try:
                if close(number_from_choice(choice), computed):
                    numeric_matches += 1
            except AuditError:
                pass
        if numeric_matches != 1:
            raise AuditError(f"{qid}: computed correct value is not unique among choices")

    declared = verification.get("correct_value")
    if declared is not None and isinstance(computed, (int, float)) and not close(declared, computed):
        raise AuditError(f"{qid}: declared correct_value {declared} != recomputed {computed}")

    return {
        "id": qid,
        "expectedAnswer": answer,
        "verdict": "PASS",
        "risk": "low",
        "verificationKind": kind,
        "computed": computed,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bank", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    items = json.loads(args.bank.read_text(encoding="utf-8"))
    if not isinstance(items, list) or not items:
        print("FAIL: deterministic general audit requires non-empty list")
        return 1
    results = []
    try:
        for item in items:
            results.append(audit_item(item))
    except (AuditError, KeyError, ZeroDivisionError) as error:
        print(f"FAIL: deterministic general answer audit: {error}")
        return 1

    report = {
        "schemaVersion": 1,
        "checkedAt": max(str(item.get("evidence_checked_date", "")) for item in items),
        "status": "PASS",
        "scope": args.bank.name,
        "policy": "設問内の自作数値fixtureから正答を再計算し、候補answer・選択肢と独立照合する。外部著作物の正答知識へ依存しない。",
        "items": results,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: deterministic general answer audit ({len(results)} items)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
