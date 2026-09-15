#!/usr/bin/env python3
"""Audit LS16 OT question-bank difficulty *profile* against exam structure.

This deliberately does not pretend to know psychometric item difficulty.  The
public MHLW material gives us an objective exam structure (general/practical),
not per-item p-values.  We therefore gate the things we can verify reliably:

* every shipped item is licensed_official MHLW material;
* every 200-question round keeps the official 160 general / 40 practical frame;
* text-only filtering must not create a materially different mix of clinical
  vignettes, multi-select items, or short-recall proxies between rounds;
* a 16-question practice sample can be stratified to 13 general / 3 practical
  instead of accidentally becoming general-only.

The proxy labels are audit metadata only.  They are never presented as an
official MHLW difficulty classification.
"""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path

ROUND_NAMES = ("R1", "R2", "R3")
EXPECTED_PER_ROUND = 200
EXPECTED_GENERAL = 160
EXPECTED_PRACTICAL = 40
EXPECTED_TOTAL = 600
MAX_ROUND_PROFILE_SPREAD = 0.12

CASE_RE = re.compile(
    r"(?:\d{1,3}\s*歳|患者|男性|女性|男児|女児|入院|退院|発症|診断|受診|既往|"
    r"麻痺|骨折|脳梗塞|脳出血|統合失調症|認知症|心不全|Parkinson|パーキンソン)",
    re.IGNORECASE,
)


def norm(value: object) -> str:
    return unicodedata.normalize("NFKC", str(value or "")).strip()


def qtext(q: dict) -> str:
    return norm(q.get("text") or q.get("question"))


def is_clinical_vignette(q: dict) -> bool:
    return bool(CASE_RE.search(qtext(q)))


def is_multi_select(q: dict) -> bool:
    if q.get("answer_type") == "multiChoice":
        return True
    answer = q.get("answer")
    return isinstance(answer, list) and len(answer) > 1


def is_short_recall_proxy(q: dict) -> bool:
    """Conservative proxy for a short one-step recall item, not 'easy'."""
    if q.get("question_type") != "general" or is_multi_select(q) or is_clinical_vignette(q):
        return False
    text = re.sub(r"\s+", "", qtext(q))
    return len(text) <= 46


def ratio(count: int, total: int) -> float:
    return round(count / total, 4) if total else 0.0


def profile(items: list[dict]) -> dict:
    n = len(items)
    practical = [q for q in items if q.get("question_type") == "practical"]
    general = [q for q in items if q.get("question_type") == "general"]
    clinical = [q for q in items if is_clinical_vignette(q)]
    multi = [q for q in items if is_multi_select(q)]
    short = [q for q in items if is_short_recall_proxy(q)]
    return {
        "total": n,
        "general": len(general),
        "practical": len(practical),
        "clinical_vignette_proxy": len(clinical),
        "clinical_vignette_ratio": ratio(len(clinical), n),
        "practical_clinical_vignette_proxy": sum(is_clinical_vignette(q) for q in practical),
        "practical_clinical_vignette_ratio": ratio(sum(is_clinical_vignette(q) for q in practical), len(practical)),
        "multi_select": len(multi),
        "multi_select_ratio": ratio(len(multi), n),
        "short_recall_proxy": len(short),
        "short_recall_proxy_ratio": ratio(len(short), len(general)),
    }


def spread(round_profiles: dict[str, dict], key: str) -> float:
    values = [round_profiles[r][key] for r in ROUND_NAMES]
    return round(max(values) - min(values), 4)


def load_questions(paths: list[str]) -> list[dict]:
    out: list[dict] = []
    for path in paths:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
        if not isinstance(payload, list):
            raise ValueError(f"{path}: expected JSON array")
        out.extend(payload)
    return out


def audit(items: list[dict]) -> dict:
    errors: list[str] = []
    warnings: list[str] = []

    if len(items) != EXPECTED_TOTAL:
        errors.append(f"total={len(items)} expected={EXPECTED_TOTAL}")

    ids = [norm(q.get("id")) for q in items]
    if len(ids) != len(set(ids)):
        errors.append("duplicate_ids")

    non_official = [q.get("id") for q in items if q.get("origin_type") != "licensed_official"]
    if non_official:
        errors.append(f"non_official_items={len(non_official)} first={non_official[:10]}")

    round_profiles: dict[str, dict] = {}
    for r in ROUND_NAMES:
        rr = [q for q in items if q.get("round") == r]
        p = profile(rr)
        round_profiles[r] = p
        if p["total"] != EXPECTED_PER_ROUND:
            errors.append(f"{r}_total={p['total']} expected={EXPECTED_PER_ROUND}")
        if p["general"] != EXPECTED_GENERAL or p["practical"] != EXPECTED_PRACTICAL:
            errors.append(
                f"{r}_exam_mix=general:{p['general']},practical:{p['practical']} "
                f"expected={EXPECTED_GENERAL}/{EXPECTED_PRACTICAL}"
            )

    # Text-only rights filtering is allowed, but one round must not become much
    # more recall-heavy or much less clinical than another round.
    profile_spreads = {
        "clinical_vignette_ratio": spread(round_profiles, "clinical_vignette_ratio"),
        "practical_clinical_vignette_ratio": spread(round_profiles, "practical_clinical_vignette_ratio"),
        "multi_select_ratio": spread(round_profiles, "multi_select_ratio"),
        "short_recall_proxy_ratio": spread(round_profiles, "short_recall_proxy_ratio"),
    }
    for key, value in profile_spreads.items():
        if value > MAX_ROUND_PROFILE_SPREAD:
            errors.append(f"round_profile_spread:{key}={value:.4f}>{MAX_ROUND_PROFILE_SPREAD:.2f}")

    # This is a deliberately conservative warning rather than a fabricated
    # psychometric fail threshold.  Practical questions already carry the
    # objective 20% slot gate above.
    overall = profile(items)
    if overall["clinical_vignette_proxy"] == 0:
        errors.append("clinical_vignette_proxy_zero")
    if overall["short_recall_proxy"] > overall["general"] // 2:
        warnings.append("more_than_half_of_general_items_match_short_recall_proxy")

    practice_16_contract = {
        "sample_size": 16,
        "general": 13,
        "practical": 3,
        "note": "closest integer stratification to the official 160/40 frame; sampling contract for LS16-005",
    }

    return {
        "task": "LS16-004",
        "audit": "difficulty-profile-v1",
        "status": "PASS" if not errors else "FAIL",
        "method": {
            "principle": "match verifiable national-exam structure; do not invent psychometric difficulty labels",
            "official_origin_required": True,
            "round_mix": {"general": EXPECTED_GENERAL, "practical": EXPECTED_PRACTICAL},
            "profile_spread_limit": MAX_ROUND_PROFILE_SPREAD,
            "proxy_fields": [
                "clinical_vignette_proxy",
                "practical_clinical_vignette_proxy",
                "multi_select",
                "short_recall_proxy",
            ],
        },
        "overall": overall,
        "rounds": round_profiles,
        "round_profile_spreads": profile_spreads,
        "practice_16_contract": practice_16_contract,
        "errors": errors,
        "warnings": warnings,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("questions", nargs="+")
    ap.add_argument("--out", default="sagyo-ryohoshi-sprint/audit/difficulty-audit.json")
    args = ap.parse_args()
    report = audit(load_questions(args.questions))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["status"] == "PASS" else 1)


if __name__ == "__main__":
    main()
