#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import date
from difflib import SequenceMatcher
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
REQUIRED_DIR = ROOT / "required-150"
CANONICAL_ROOT = ROOT / "questions"
EXAMS = (115, 114, 113)
EXPECTED_PER_EXAM = 50
EXPECTED_TOTAL = 150
HIGH_SIM_THRESHOLD = 0.92


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def valid_http_url(value: object) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    p = urlparse(value)
    return p.scheme in {"http", "https"} and bool(p.netloc)


def norm_text(value: str) -> str:
    value = unicodedata.normalize("NFKC", value or "").lower()
    return re.sub(r"[^0-9a-zぁ-んァ-ヶ一-龠々〆ヵヶ]+", "", value)


def payload(q: dict) -> str:
    return norm_text((q.get("question") or "") + "|" + "|".join(q.get("choices") or []))


def answer_is_official(q: dict) -> bool:
    status = q.get("officialScoringStatus")
    answer = q.get("answer")
    accepted = q.get("officialAcceptedAnswers") or []
    if status == "excluded":
        return answer is None and not accepted
    if answer is None:
        return False
    if isinstance(answer, list):
        if accepted and all(isinstance(x, int) for x in accepted):
            return sorted(answer) == sorted(accepted)
        normalized = [sorted(x) if isinstance(x, list) else [x] for x in accepted]
        return sorted(answer) in normalized
    return answer in accepted


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    questions: dict[str, dict] = {}
    exam_counts = Counter()

    for exam in EXAMS:
        path = CANONICAL_ROOT / f"exam-{exam}" / "required.json"
        if not path.exists():
            errors.append(f"canonical_file_missing:{path.relative_to(ROOT)}")
            continue
        doc = load(path)
        if doc.get("sourceExam") != exam:
            errors.append(f"canonical_source_exam_mismatch:{exam}:{doc.get('sourceExam')}")
        if doc.get("category") != "必修":
            errors.append(f"canonical_category_mismatch:{exam}:{doc.get('category')}")
        rows = doc.get("questions") or []
        if len(rows) != EXPECTED_PER_EXAM:
            errors.append(f"exam_{exam}_question_count:{len(rows)}!=50")
        for q in rows:
            qid = q.get("id")
            if qid in questions:
                errors.append(f"duplicate_question_id:{qid}")
                continue
            questions[qid] = q
            exam_counts[exam] += 1

    if len(questions) != EXPECTED_TOTAL:
        errors.append(f"canonical_required_total:{len(questions)}!=150")

    answer_mismatches: list[str] = []
    source_token_mismatches: list[str] = []
    explanation_missing: list[str] = []
    evidence_missing: list[str] = []
    evidence_date_missing: list[str] = []
    rights_missing: list[str] = []
    source_missing: list[str] = []
    classification_missing: list[str] = []
    dynamic_pending: list[str] = []
    release_policy_errors: list[str] = []

    media_ids: set[str] = set()
    scoring_ids: set[str] = set()
    expert_ids: set[str] = set()
    release_ids: set[str] = set()

    for qid, q in questions.items():
        if q.get("category") != "必修":
            errors.append(f"non_required_category:{qid}:{q.get('category')}")
        if not q.get("majorSubject") or not q.get("subject"):
            classification_missing.append(qid)
        if not (q.get("question") or "").strip():
            errors.append(f"question_missing:{qid}")
        choices = q.get("choices") or []
        if q.get("answerType") in {"singleChoice", "multiChoice"} and not choices:
            errors.append(f"choices_missing:{qid}")

        if not answer_is_official(q):
            answer_mismatches.append(qid)
        answer = q.get("answer")
        tokens = {str(x).strip() for x in (q.get("sourceAnswerTokens") or [])}
        if isinstance(answer, int) and tokens and str(answer + 1) not in tokens:
            source_token_mismatches.append(qid)

        if len((q.get("point") or "").strip()) < 8 or len((q.get("detail") or "").strip()) < 20:
            explanation_missing.append(qid)
        refs = q.get("explanationEvidenceRefs") or []
        if not refs or not all(valid_http_url(x) for x in refs):
            evidence_missing.append(qid)
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(q.get("evidenceCheckedDate") or "")):
            evidence_date_missing.append(qid)

        if not q.get("rightsStatus") or not q.get("copyrightBasis"):
            rights_missing.append(qid)
        if not q.get("sourceAttribution") or not (q.get("sourceRefs") or []):
            source_missing.append(qid)
        if q.get("originType") != "licensed_official":
            errors.append(f"origin_type_invalid:{qid}:{q.get('originType')}")

        if q.get("dynamicEvidenceRequired") and q.get("dynamicEvidenceStatus") not in {"verified", "expert_review_required"}:
            dynamic_pending.append(qid)

        reasons = q.get("specialistQuarantineReasons") or []
        kinds = {x.get("kind") for x in reasons}
        if "mediaDependent" in kinds:
            media_ids.add(qid)
        if "scoringSpecial" in kinds:
            scoring_ids.add(qid)
        if "expertReview" in kinds:
            expert_ids.add(qid)

        quarantined = bool(kinds)
        if quarantined and q.get("releaseEligible") is not False:
            release_policy_errors.append(qid)
        if not quarantined and q.get("releaseEligible") is not True:
            release_policy_errors.append(qid)
        if q.get("releaseEligible") is True:
            release_ids.add(qid)

    for label, rows in (
        ("answer_mismatch", answer_mismatches),
        ("source_answer_token_mismatch", source_token_mismatches),
        ("explanation_missing", explanation_missing),
        ("evidence_missing", evidence_missing),
        ("evidence_checked_date_missing", evidence_date_missing),
        ("rights_basis_missing", rights_missing),
        ("source_attribution_missing", source_missing),
        ("classification_missing", classification_missing),
        ("dynamic_evidence_pending", dynamic_pending),
        ("release_policy_error", release_policy_errors),
    ):
        if rows:
            errors.append(f"{label}:{sorted(set(rows))}")

    quarantine = media_ids | scoring_ids | expert_ids
    if len(media_ids) != 8:
        errors.append(f"media_count:{len(media_ids)}!=8")
    if len(scoring_ids) != 6:
        errors.append(f"scoring_special_count:{len(scoring_ids)}!=6")
    if len(expert_ids) != 2:
        errors.append(f"expert_review_count:{len(expert_ids)}!=2")
    if len(quarantine) != 14:
        errors.append(f"quarantine_union_count:{len(quarantine)}!=14")
    if len(release_ids) != 136:
        errors.append(f"release_eligible_count:{len(release_ids)}!=136")

    payloads = {qid: payload(q) for qid, q in questions.items()}
    exact_groups = defaultdict(list)
    for qid, text in payloads.items():
        exact_groups[text].append(qid)
    exact_duplicates = [sorted(ids) for text, ids in exact_groups.items() if text and len(ids) > 1]
    if exact_duplicates:
        errors.append(f"exact_duplicate_content:{exact_duplicates}")

    high_similarity: list[dict] = []
    ids = sorted(questions)
    for i, a in enumerate(ids):
        pa = payloads[a]
        if len(pa) < 16:
            continue
        for b in ids[i + 1:]:
            pb = payloads[b]
            if len(pb) < 16:
                continue
            length_ratio = min(len(pa), len(pb)) / max(len(pa), len(pb))
            if length_ratio < HIGH_SIM_THRESHOLD:
                continue
            score = SequenceMatcher(None, pa, pb, autojunk=False).ratio()
            if score >= HIGH_SIM_THRESHOLD:
                high_similarity.append({"id1": a, "id2": b, "score": round(score, 4)})
    if high_similarity:
        errors.append(f"high_similarity_pairs:{high_similarity}")

    report = {
        "schemaVersion": 1,
        "scope": "K115/K114/K113 required canonical 150",
        "auditDate": date.today().isoformat(),
        "status": "PASS" if not errors else "FAIL",
        "policy": "canonical JSON is final specialist source; batch-level PASS is not reused as final PASS",
        "counts": {
            "requiredTotal": len(questions),
            "byExam": {str(exam): exam_counts[exam] for exam in EXAMS},
            "answerMismatches": len(set(answer_mismatches)),
            "sourceAnswerTokenMismatches": len(set(source_token_mismatches)),
            "explanationMissing": len(set(explanation_missing)),
            "evidenceMissing": len(set(evidence_missing)),
            "evidenceCheckedDateMissing": len(set(evidence_date_missing)),
            "rightsBasisMissing": len(set(rights_missing)),
            "sourceAttributionMissing": len(set(source_missing)),
            "classificationMissing": len(set(classification_missing)),
            "dynamicEvidencePending": len(set(dynamic_pending)),
            "exactDuplicateContent": len(exact_duplicates),
            "highSimilarityPairs": len(high_similarity),
            "mediaDependent": len(media_ids),
            "scoringSpecial": len(scoring_ids),
            "expertReview": len(expert_ids),
            "quarantinedUnique": len(quarantine),
            "releaseEligible": len(release_ids),
        },
        "quarantine": {
            "media": sorted(media_ids),
            "scoringSpecial": sorted(scoring_ids),
            "expertReview": sorted(expert_ids),
        },
        "highSimilarity": high_similarity,
        "errors": errors,
        "warnings": warnings,
    }
    dump(REQUIRED_DIR / "canonical-audit.json", report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
