#!/usr/bin/env python3
"""Fail-closed FP2 official-past-exam product gate; structural checks are NOT substantive auditing."""
import argparse
from collections import Counter
from datetime import date
from difflib import SequenceMatcher
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "official-source-catalog.json"

def _valid_https(url):
    if not isinstance(url, str):
        return False
    p = urlsplit(url)
    return p.scheme == "https" and bool(p.hostname) and not p.username and not p.password

def _norm(text):
    return re.sub(r"\s+", "", str(text or ""))

def audit(path: Path, catalog_path: Path = CATALOG) -> dict:
    errors = []
    def err(message):
        errors.append(message)
    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        rounds = catalog["rounds"]
        if not isinstance(rounds, list) or not rounds:
            raise ValueError("empty rounds")
        expected = {}
        for item in rounds:
            round_id = item["round"]
            date.fromisoformat(item["law_baseline_date"])
            if not re.fullmatch(r"\d{6}", round_id) or item["exam_types"].keys() != {"gakka", "jitsugi"}:
                raise ValueError("invalid round or subjects")
            for typ, spec in item["exam_types"].items():
                n = spec["count"]
                url = spec["question_url"]
                if type(n) is not int or n < 1 or n > 999 or not _valid_https(url) or urlsplit(url).hostname != "www.jafp.or.jp":
                    raise ValueError("invalid official count/source")
                for number in range(1, n + 1):
                    key = f"JAFP-FP2-{round_id}-{'ACA' if typ == 'gakka' else 'PRAC'}-{number:02d}"
                    if key in expected:
                        raise ValueError("duplicate catalog identity")
                    expected[key] = (item, typ, url, number)
        if not _valid_https(catalog.get("rights_policy_url")):
            raise ValueError("missing rights policy URL")
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as ex:
        return {"status": "FAIL", "release_ready": False, "errors": ["INVALID_OFFICIAL_CATALOG: " + str(ex)]}
    total = len(expected)
    if not path.is_file():
        return {"status": "FAIL", "release_ready": False, "expected_official_questions": total,
                "approved_questions": 0, "errors": ["PRODUCT_BANK_MISSING"]}
    try:
        bank = json.loads(path.read_text(encoding="utf-8"))
        questions = bank["questions"]
        if not isinstance(questions, list) or any(not isinstance(q, dict) for q in questions):
            raise ValueError("questions must be an array of objects")
    except (OSError, ValueError, TypeError, KeyError) as ex:
        return {"status": "FAIL", "release_ready": False, "expected_official_questions": total,
                "approved_questions": 0, "errors": ["INVALID_BANK_SCHEMA: " + str(ex)]}

    seen_ids = set()
    seen_sources = set()
    normalized = []
    approved_count = 0
    counts = Counter()
    for idx, q in enumerate(questions):
        label = q.get("id") or f"row-{idx+1}"
        if not isinstance(label, str) or not label.strip() or label in seen_ids:
            err(f"{label}: INVALID_OR_DUPLICATE_ID")
        seen_ids.add(label)
        source_id = q.get("sourceQuestionId")
        if not isinstance(source_id, str) or source_id not in expected:
            err(f"{label}: UNKNOWN_OFFICIAL_SOURCE_ID")
            ref = None
        else:
            ref = expected[source_id]
            if source_id in seen_sources:
                err(f"{label}: DUPLICATE_SOURCE_QUESTION_ID")
            seen_sources.add(source_id)
            counts[ref[1]] += 1
            item, typ, url, number = ref
            if q.get("examRound") != item["round"] or q.get("examType") != typ or q.get("originalQuestionNumber") != number:
                err(f"{label}: SOURCE_METADATA_MISMATCH")
            if q.get("sourceDocumentUrl") != url:
                err(f"{label}: SOURCE_DOCUMENT_URL_MISMATCH")
            if q.get("lawBaselineDate") != item["law_baseline_date"]:
                err(f"{label}: LEGAL_BASELINE_MISMATCH_OR_UNVERIFIED")
        if q.get("originType") != "official_past_exam":
            err(f"{label}: OFFICIAL_ORIGIN_REQUIRED")
        if q.get("auditStatus") == "approved":
            approved_count += 1
        else:
            err(f"{label}: UNAPPROVED_AUDIT_STATUS")
        for field in ("question", "topic", "point", "detail", "contentVersion"):
            if not isinstance(q.get(field), str) or not q[field].strip():
                err(f"{label}: MISSING_{field}")
        if q.get("transcriptionReviewStatus") != "verified":
            err(f"{label}: TRANSCRIPTION_NOT_VERIFIED")
        if q.get("answerReviewStatus") != "verified":
            err(f"{label}: ANSWER_NOT_VERIFIED")
        if q.get("explanationReviewStatus") != "verified":
            err(f"{label}: EXPLANATION_NOT_VERIFIED")
        if q.get("rightsReviewStatus") != "approved":
            err(f"{label}: RIGHTS_NOT_APPROVED")
        if q.get("thirdPartyRightsStatus") not in ("cleared", "not_applicable"):
            err(f"{label}: THIRD_PARTY_RIGHTS_UNRESOLVED")
        attribution = q.get("attributionText")
        if ref and (not isinstance(attribution, str) or "日本FP協会" not in attribution
                    or ref[0]["round"][:4] not in attribution
                    or ("学科" if ref[1] == "gakka" else "実技") not in attribution):
            err(f"{label}: SOURCE_ATTRIBUTION_MISSING_OR_WRONG")
        if q.get("modifiedFromOriginal") not in (True, False):
            err(f"{label}: MODIFICATION_FLAG_REQUIRED")
        elif q["modifiedFromOriginal"] and (not isinstance(q.get("modificationDisclosure"), str)
                                             or "加工" not in q["modificationDisclosure"]):
            err(f"{label}: MODIFICATION_DISCLOSURE_REQUIRED")
        if not q.get("rightsNoticeDisplayed") is True:
            err(f"{label}: RIGHTS_NOTICE_NOT_DISPLAYED")
        refs = q.get("sourceRefs")
        if not isinstance(refs, list) or not refs or any(not _valid_https(u) for u in refs):
            err(f"{label}: INVALID_PRIMARY_SOURCE_REFS")
        elif ref and ref[2] not in refs:
            err(f"{label}: OFFICIAL_SOURCE_NOT_IN_REFS")
        try:
            baseline = date.fromisoformat(q["lawBaselineDate"])
            if baseline > date.today():
                raise ValueError("future date")
        except (ValueError, KeyError, TypeError):
            err(f"{label}: INVALID_LEGAL_BASELINE")
        if q.get("answerType") == "singleChoice":
            choices = q.get("choices")
            answer = q.get("answerIndex")
            if not isinstance(choices, list) or len(choices) < 2 or any(not isinstance(c, str) or not c.strip() for c in choices) or type(answer) is not int or not 0 <= answer < len(choices):
                err(f"{label}: INVALID_SINGLE_CHOICE")
        elif q.get("answerType") == "numeric":
            if type(q.get("numericAnswer")) not in (float, int) or type(q.get("tolerance")) not in (float, int) or q["tolerance"] < 0 or not isinstance(q.get("unit"), str) or not q["unit"].strip():
                err(f"{label}: INVALID_NUMERIC_ANSWER")
        else:
            err(f"{label}: INVALID_ANSWER_TYPE")
        normalized.append((source_id, _norm(q.get("question"))))

    duplicate_pairs = []
    for i, (sid, sentence) in enumerate(normalized):
        if not sentence:
            continue
        for other_sid, other in normalized[:i]:
            if sentence == other or (min(len(sentence), len(other)) >= 20 and SequenceMatcher(None, sentence, other, autojunk=False).ratio() >= .9):
                duplicate_pairs.append([other_sid, sid])
    if duplicate_pairs:
        err("DUPLICATE_OR_NEAR_DUPLICATE_REVIEW_REQUIRED")
    missing = sorted(set(expected) - seen_sources)
    if missing:
        err(f"MISSING_OFFICIAL_SOURCE_IDS: {len(missing)}")
    if len(questions) != total:
        err(f"OFFICIAL_SOURCE_COUNT_MISMATCH: {len(questions)}/{total}")
    if approved_count != total:
        err(f"APPROVED_COUNT_MISMATCH: {approved_count}/{total}")
    return {
        "status": "FAIL" if errors else "PASS", "release_ready": not errors,
        "expected_official_questions": total, "product_questions": len(questions),
        "approved_questions": approved_count, "exam_type_counts": dict(counts),
        "missing_source_ids": missing, "duplicate_candidates": duplicate_pairs,
        "errors": errors,
        "scope": "Structural fail-closed verification only; flags/URLs/rights evidence must be independently audited."
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bank", type=Path, default=ROOT / "question_bank.json")
    parser.add_argument("--catalog", type=Path, default=CATALOG)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = audit(args.bank, args.catalog)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0 if result["release_ready"] else 1)

if __name__ == "__main__":
    main()
