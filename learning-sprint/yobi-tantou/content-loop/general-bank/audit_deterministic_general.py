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


def signed_number_from_choice(text: str) -> float:
    value = abs(number_from_choice(text))
    raw = str(text)
    negative_markers = ("低下", "減少", "減", "マイナス", "-")
    positive_markers = ("上昇", "増加", "増", "プラス", "+")
    if any(marker in raw for marker in negative_markers):
        return -value
    if any(marker in raw for marker in positive_markers):
        return value
    return number_from_choice(text)


def close(a: float, b: float) -> bool:
    return math.isclose(float(a), float(b), rel_tol=1e-9, abs_tol=1e-9)


def unique_argmax(values: list[float]) -> int:
    maximum = max(values)
    indices = [i for i, value in enumerate(values) if close(value, maximum)]
    if len(indices) != 1:
        raise AuditError(f"argmax is not unique: {indices}")
    return indices[0]


def unique_argmin(values: list[float]) -> int:
    minimum = min(values)
    indices = [i for i, value in enumerate(values) if close(value, minimum)]
    if len(indices) != 1:
        raise AuditError(f"argmin is not unique: {indices}")
    return indices[0]


def compute_numeric(v: dict):
    kind = v.get("kind")
    if kind == "ratio_percent":
        return v["part"] / v["whole"] * 100
    if kind == "mean":
        return statistics.mean(v["values"])
    if kind == "weighted_mean":
        values, weights = v["values"], v["weights"]
        return sum(value * weight for value, weight in zip(values, weights)) / sum(weights)
    if kind == "increase_percent":
        return (v["after"] - v["before"]) / v["before"] * 100
    if kind == "ratio_share":
        return v["total"] * v["parts"][v["target_index"]] / sum(v["parts"])
    if kind == "divide":
        return v["numerator"] / v["denominator"]
    if kind == "unit_cost":
        return v["total_cost"] / v["count"]
    if kind == "difference":
        return v["a"] - v["b"]
    if kind == "median":
        return statistics.median(v["values"])
    if kind == "discount":
        return v["price"] * (100 - v["discount_percent"]) / 100
    if kind == "reverse_percent":
        return v["after"] / (v["percent"] / 100)
    if kind == "simple_interest":
        return v["principal"] * v["annual_rate_percent"] / 100 * v["years"]
    if kind == "solve_linear":
        return (v["c"] - v["b"]) / v["a"]
    if kind == "arithmetic_sequence":
        return v["first"] + (v["n"] - 1) * v["difference"]
    if kind == "percent_point_diff":
        return v["after_percent"] - v["before_percent"]
    if kind == "probability_complement_percent":
        return (1 - v["event_count"] / v["total_count"]) * 100
    if kind == "average_speed":
        return sum(v["distances"]) / sum(v["times"])
    if kind == "combination_count_2":
        n = v["n"]
        return n * (n - 1) / 2
    if kind == "rectangle_area":
        return v["width"] * v["height"]
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
    if kind == "share_of_sum":
        return v["values"][v["target_index"]] / sum(v["values"]) * 100
    if kind == "signed_difference":
        return v["after"] - v["before"]
    if kind == "compound_percent_factors":
        value = float(v["base"])
        for factor in v["factors"]:
            value *= factor
        return value
    raise AuditError(f"unsupported numeric verification kind: {kind}")


def compute_index(v: dict) -> int:
    kind = v.get("kind")
    if kind == "argmax_delta":
        return unique_argmax([end - start for start, end in v["pairs"]])
    if kind == "argmin_drop":
        return unique_argmin([start - end for start, end in v["pairs"]])
    if kind == "range_compare":
        ranges = [max(values) - min(values) for values in v["datasets"]]
        return unique_argmin(ranges)
    if kind == "compare_increase_percent":
        rates = [(end - start) / start * 100 for start, end in v["pairs"]]
        return unique_argmax(rates)
    if kind == "argmax":
        return unique_argmax(v["values"])
    if kind == "compare_ratio":
        rates = [part / whole for part, whole in v["pairs"]]
        return unique_argmax(rates)
    if kind == "priority":
        labels = v["labels"]
        return labels.index(v["priority"])
    raise AuditError(f"unsupported index verification kind: {kind}")


def compute_text(v: dict) -> str:
    kind = v.get("kind")
    if kind == "sequence":
        return "→".join(v["sequence"])
    if kind == "conditional_lookup":
        return str(v["mapping"][v["condition"]])
    if kind == "attribute_lookup":
        attribute, expected_value = v["query"]
        matches = [name for name, attrs in v["attributes"].items() if attrs.get(attribute) == expected_value]
        if len(matches) != 1:
            raise AuditError(f"attribute lookup is not unique: {matches}")
        return matches[0]
    if kind == "timeline_next":
        names = [event[1] for event in v["events"]]
        index = names.index(v["target"])
        if index + 1 >= len(names):
            raise AuditError("timeline target has no next event")
        return names[index + 1]
    if kind in {
        "explicit_cause", "exception", "all_requirements", "explicit_prohibition",
        "exception_application", "argmax_all", "threshold_all",
    }:
        return str(v["correct_text"])
    raise AuditError(f"unsupported text verification kind: {kind}")


def audit_item(item: dict) -> dict:
    qid = item.get("id", "<no-id>")
    verification = item.get("verification") or {}
    kind = verification.get("kind")
    choices = item.get("choices") or []
    answer = item.get("answer")
    if not isinstance(answer, int) or not 0 <= answer < len(choices):
        raise AuditError(f"{qid}: invalid answer index")

    numeric_kinds = {
        "ratio_percent", "mean", "weighted_mean", "increase_percent", "ratio_share", "divide",
        "unit_cost", "difference", "median", "discount", "reverse_percent", "simple_interest",
        "solve_linear", "arithmetic_sequence", "percent_point_diff", "probability_complement_percent",
        "average_speed", "combination_count_2", "rectangle_area", "multiply", "compound_percent", "sum",
        "remainder", "share_of_sum", "signed_difference", "compound_percent_factors",
    }
    index_kinds = {"argmax_delta", "argmin_drop", "range_compare", "compare_increase_percent", "argmax", "compare_ratio", "priority"}
    text_kinds = {"sequence", "conditional_lookup", "attribute_lookup", "timeline_next", "explicit_cause", "exception", "all_requirements", "explicit_prohibition", "exception_application", "argmax_all", "threshold_all"}

    if kind == "fraction":
        computed = str(verification["correct_text"])
        if str(choices[answer]).strip() != computed:
            raise AuditError(f"{qid}: fraction answer choice does not match fixture")
        if sum(str(choice).strip() == computed for choice in choices) != 1:
            raise AuditError(f"{qid}: fraction correct value is not unique")
    elif kind in numeric_kinds:
        computed = compute_numeric(verification)
        parser = signed_number_from_choice if kind in {"signed_difference", "percent_point_diff"} else number_from_choice
        selected = parser(choices[answer])
        if not close(selected, computed):
            raise AuditError(f"{qid}: selected choice {selected} != computed {computed}")
        numeric_matches = 0
        for choice in choices:
            try:
                if close(parser(choice), computed):
                    numeric_matches += 1
            except AuditError:
                pass
        if numeric_matches != 1:
            raise AuditError(f"{qid}: computed correct value is not unique among choices")
    elif kind in index_kinds:
        computed = compute_index(verification)
        if answer != computed:
            raise AuditError(f"{qid}: answer index {answer} != recomputed index {computed}")
    elif kind in text_kinds:
        computed = compute_text(verification)
        if str(choices[answer]).strip() != computed:
            raise AuditError(f"{qid}: selected text {choices[answer]!r} != computed {computed!r}")
        if sum(str(choice).strip() == computed for choice in choices) != 1:
            raise AuditError(f"{qid}: computed correct text is not unique")
        if kind == "argmax_all":
            values = verification["values"]
            max_value = max(values)
            computed_indices = [i for i, value in enumerate(values) if close(value, max_value)]
            if computed_indices != verification.get("correct_indices"):
                raise AuditError(f"{qid}: argmax_all indices mismatch")
        if kind == "threshold_all":
            thresholds = verification["thresholds"]
            computed_indices = [i for i, row in enumerate(verification["rows"]) if all(value >= threshold for value, threshold in zip(row, thresholds))]
            if computed_indices != verification.get("correct_indices"):
                raise AuditError(f"{qid}: threshold_all indices mismatch")
    else:
        raise AuditError(f"{qid}: unsupported verification kind {kind}")

    declared = verification.get("correct_value")
    if declared is not None and isinstance(computed, (int, float)) and not close(declared, computed):
        raise AuditError(f"{qid}: declared correct_value {declared} != recomputed {computed}")
    declared_index = verification.get("correct_index")
    if declared_index is not None and isinstance(computed, int) and declared_index != computed:
        raise AuditError(f"{qid}: declared correct_index {declared_index} != recomputed {computed}")

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
    except (AuditError, KeyError, ValueError, ZeroDivisionError) as error:
        print(f"FAIL: deterministic general answer audit: {error}")
        return 1

    report = {
        "schemaVersion": 2,
        "checkedAt": max(str(item.get("evidence_checked_date", "")) for item in items),
        "status": "PASS",
        "scope": args.bank.name,
        "policy": "設問内の自作fixtureから正答を再計算・再構成し、候補answer・選択肢と独立照合する。増減方向を含む選択肢は語義も符号として検証し、外部著作物の正答知識へ依存しない。",
        "items": results,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: deterministic general answer audit ({len(results)} items)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
