#!/usr/bin/env python3
"""第115・114・113回 看護師国家試験 必修150問専用監査ゲート。

共通 validator は変更せず、required-150 配下の補正・隔離定義を含めて
必修だけを再監査する。一般・状況設定は読み取りのみで編集しない。
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
CONTENT = HERE.parent
RAW_DIR = CONTENT / "raw"
BATCH_DIR = CONTENT / "explanation-batches"
REPORT_PATH = HERE / "audit-report.json"

EXAMS = (115, 114, 113)
EXPECTED_PER_EXAM = 50
EXPECTED_TOTAL = 150
HIGH_SIM_THRESHOLD = 0.92


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


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


def apply_corrections(required: dict[str, dict], corrections: list[dict], errors: list[str]) -> set[str]:
    corrected_ids: set[str] = set()
    for row in corrections:
        qid = row.get("id")
        if qid not in required:
            errors.append(f"correction_out_of_scope:{qid}")
            continue
        for key in ("question", "choices"):
            if key in row:
                required[qid][key] = row[key]
        corrected_ids.add(qid)
    return corrected_ids


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    # 1) Rawから必修150問のみ抽出
    required: dict[str, dict] = {}
    exam_counts = Counter()
    raw_duplicate_ids: list[str] = []
    seen_all: set[str] = set()
    for exam, filename in ((115, "set1-raw.json"), (114, "set2-raw.json"), (113, "set3-raw.json")):
        data = load(RAW_DIR / filename)
        for q in data.get("questions", []):
            qid = q.get("id")
            if qid in seen_all:
                raw_duplicate_ids.append(qid)
            seen_all.add(qid)
            if q.get("sourceExam") == exam and q.get("category") == "必修":
                required[qid] = dict(q)
                exam_counts[exam] += 1

    if len(required) != EXPECTED_TOTAL:
        errors.append(f"required_count:{len(required)}!=150")
    for exam in EXAMS:
        if exam_counts[exam] != EXPECTED_PER_EXAM:
            errors.append(f"exam_{exam}_required_count:{exam_counts[exam]}!=50")
    if raw_duplicate_ids:
        errors.append(f"duplicate_raw_ids:{sorted(set(raw_duplicate_ids))}")

    # 2) 必修専用公式本文補正を適用（raw自体は変更しない）
    correction_doc = load(HERE / "text-corrections.json")
    corrections = correction_doc.get("corrections", [])
    correction_ids = [x.get("id") for x in corrections]
    if len(correction_ids) != len(set(correction_ids)):
        errors.append("duplicate_text_correction_ids")
    corrected_ids = apply_corrections(required, corrections, errors)

    # 3) 正答・公式採点取扱いの整合
    answer_mismatches: list[str] = []
    source_token_mismatches: list[str] = []
    scoring_special_raw: list[str] = []
    media_raw: list[str] = []
    for qid, q in required.items():
        status = q.get("officialScoringStatus")
        answer = q.get("answer")
        accepted = q.get("officialAcceptedAnswers") or []
        if status != "normal":
            scoring_special_raw.append(qid)
        if q.get("requiresMedia"):
            media_raw.append(qid)
        if status == "excluded":
            if answer is not None or accepted:
                answer_mismatches.append(qid)
        else:
            if answer is None or answer not in accepted:
                answer_mismatches.append(qid)
            tokens = {str(x).strip() for x in (q.get("sourceAnswerTokens") or [])}
            if answer is not None and tokens and str(answer + 1) not in tokens:
                source_token_mismatches.append(qid)
    if answer_mismatches:
        errors.append(f"answer_mismatch:{sorted(answer_mismatches)}")
    if source_token_mismatches:
        errors.append(f"source_answer_token_mismatch:{sorted(source_token_mismatches)}")

    # 4) 隔離台帳とrawの一致
    special = load(HERE / "special-cases.json")
    media_manifest = {x["id"] for x in special.get("mediaDependent", [])}
    scoring_manifest = {x["id"] for x in special.get("scoringSpecial", [])}
    expert_manifest = {x["id"] for x in special.get("expertReview", [])}
    if set(media_raw) != media_manifest:
        errors.append(f"media_manifest_mismatch:raw={sorted(media_raw)} manifest={sorted(media_manifest)}")
    if set(scoring_special_raw) != scoring_manifest:
        errors.append(f"scoring_manifest_mismatch:raw={sorted(scoring_special_raw)} manifest={sorted(scoring_manifest)}")
    if len(expert_manifest) != 2 or not expert_manifest.issubset(required):
        errors.append(f"expert_manifest_invalid:{sorted(expert_manifest)}")

    # 5) 通常解説バッチを集約。隔離10問は通常バッチへ混ぜない。
    expected_standard = set(required) - media_manifest - expert_manifest
    explanation_rows: dict[str, dict] = {}
    explanation_occurrences = Counter()
    batch_ids = Counter()
    out_of_scope_batch_items: list[str] = []
    for path in sorted(BATCH_DIR.glob("*.json")):
        data = load(path)
        batch_id = data.get("batchId")
        if batch_id:
            batch_ids[batch_id] += 1
        for row in data.get("items", []):
            qid = row.get("id")
            if qid in required:
                explanation_occurrences[qid] += 1
                explanation_rows[qid] = row
            elif path.name.startswith("REQ-"):
                out_of_scope_batch_items.append(qid)
    if out_of_scope_batch_items:
        errors.append(f"REQ_batch_out_of_scope:{sorted(out_of_scope_batch_items)}")
    duplicate_explanation_ids = sorted(qid for qid, n in explanation_occurrences.items() if n > 1)
    if duplicate_explanation_ids:
        errors.append(f"duplicate_explanation_ids:{duplicate_explanation_ids}")
    duplicate_batch_ids = sorted(x for x, n in batch_ids.items() if n > 1)
    if duplicate_batch_ids:
        errors.append(f"duplicate_batch_ids:{duplicate_batch_ids}")
    standard_missing = sorted(expected_standard - set(explanation_rows))
    standard_unexpected = sorted((set(explanation_rows) & (media_manifest | expert_manifest)))
    if standard_missing:
        errors.append(f"standard_explanation_missing:{standard_missing}")
    if standard_unexpected:
        errors.append(f"quarantined_in_standard_batches:{standard_unexpected}")

    # 6) 隔離10問にも解説・根拠・確認日を必須化
    special_explanations = load(HERE / "special-case-explanations.json")
    special_rows = {x.get("id"): x for x in special_explanations.get("items", [])}
    expected_special_explanation_ids = media_manifest | expert_manifest
    if set(special_rows) != expected_special_explanation_ids:
        errors.append(
            "special_explanation_manifest_mismatch:"
            f"expected={sorted(expected_special_explanation_ids)} actual={sorted(special_rows)}"
        )

    all_explanations = dict(explanation_rows)
    all_explanations.update(special_rows)
    explanation_missing: list[str] = []
    evidence_missing: list[str] = []
    evidence_date_missing: list[str] = []
    evidence_url_invalid: list[str] = []
    for qid in sorted(required):
        row = all_explanations.get(qid)
        if not row:
            explanation_missing.append(qid)
            continue
        if len((row.get("point") or "").strip()) < 8 or len((row.get("detail") or "").strip()) < 20:
            explanation_missing.append(qid)
        refs = row.get("explanationEvidenceRefs") or []
        if not refs:
            evidence_missing.append(qid)
        elif not all(valid_http_url(x) for x in refs):
            evidence_url_invalid.append(qid)
        if not (row.get("evidenceCheckedDate") or "").strip():
            evidence_date_missing.append(qid)
    if explanation_missing:
        errors.append(f"explanation_missing_or_short:{explanation_missing}")
    if evidence_missing:
        errors.append(f"evidence_missing:{evidence_missing}")
    if evidence_url_invalid:
        errors.append(f"evidence_url_invalid:{evidence_url_invalid}")
    if evidence_date_missing:
        errors.append(f"evidence_checked_date_missing:{evidence_date_missing}")

    # 7) 本文・選択肢の完全一致／高類似監査（補正後データで再実行）
    payloads = {qid: payload(q) for qid, q in required.items()}
    exact_groups = defaultdict(list)
    for qid, text in payloads.items():
        exact_groups[text].append(qid)
    exact_duplicates = sorted(sorted(ids) for text, ids in exact_groups.items() if text and len(ids) > 1)
    if exact_duplicates:
        errors.append(f"exact_duplicate_content:{exact_duplicates}")

    high_similarity: list[dict] = []
    ids = sorted(required)
    for i, a in enumerate(ids):
        pa = payloads[a]
        if len(pa) < 16:
            continue
        for b in ids[i + 1 :]:
            pb = payloads[b]
            if len(pb) < 16:
                continue
            # 長さ差が大きい組合せは高類似になり得ないため短絡。
            ratio_len = min(len(pa), len(pb)) / max(len(pa), len(pb))
            if ratio_len < HIGH_SIM_THRESHOLD:
                continue
            score = SequenceMatcher(None, pa, pb, autojunk=False).ratio()
            if score >= HIGH_SIM_THRESHOLD:
                high_similarity.append({"id1": a, "id2": b, "score": round(score, 4)})
    if high_similarity:
        errors.append(f"high_similarity_pairs:{high_similarity}")

    # 8) 製品解放対象を明示。図版・専門監査・採点特例は隔離。
    quarantine = media_manifest | expert_manifest | scoring_manifest
    release_eligible = sorted(set(required) - quarantine)
    if len(release_eligible) != 136:
        errors.append(f"release_eligible_count:{len(release_eligible)}!=136")

    report = {
        "schemaVersion": 1,
        "scope": "K115/K114/K113 required 150 only",
        "auditPolicy": "problem change -> required audit -> fix -> re-audit until PASS",
        "status": "PASS" if not errors else "FAIL",
        "counts": {
            "requiredTotal": len(required),
            "byExam": {str(x): exam_counts[x] for x in EXAMS},
            "textCorrections": len(corrected_ids),
            "standardExplanationExpected": len(expected_standard),
            "standardExplanationCovered": len(expected_standard & set(explanation_rows)),
            "specialExplanationExpected": len(expected_special_explanation_ids),
            "specialExplanationCovered": len(expected_special_explanation_ids & set(special_rows)),
            "mediaDependent": len(media_manifest),
            "scoringSpecial": len(scoring_manifest),
            "expertReview": len(expert_manifest),
            "releaseEligible": len(release_eligible),
            "quarantinedUnique": len(quarantine),
            "exactDuplicates": len(exact_duplicates),
            "highSimilarityPairs": len(high_similarity),
            "answerMismatches": len(answer_mismatches),
            "explanationMissing": len(explanation_missing),
            "evidenceMissing": len(evidence_missing),
            "evidenceDateMissing": len(evidence_date_missing)
        },
        "quarantine": {
            "media": sorted(media_manifest),
            "scoringSpecial": sorted(scoring_manifest),
            "expertReview": sorted(expert_manifest)
        },
        "releaseEligibleIds": release_eligible,
        "highSimilarity": high_similarity,
        "errors": errors,
        "warnings": warnings
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
