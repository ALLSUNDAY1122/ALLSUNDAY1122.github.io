#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CLASSIFIED = ROOT / "classified"
BATCH_DIR = ROOT / "explanation-batches"
REQUIRED_DIR = ROOT / "required-150"
CANONICAL_ROOT = ROOT / "questions"

SET_MAP = {
    115: CLASSIFIED / "set1-classified.json",
    114: CLASSIFIED / "set2-classified.json",
    113: CLASSIFIED / "set3-classified.json",
}
EXPECTED_PER_EXAM = 50
EXPECTED_TOTAL = 150

DYNAMIC_PATTERNS = [
    r"法律", r"法に基づ", r"制度", r"保険", r"給付", r"届出", r"人口動態", r"患者調査",
    r"国民.*調査", r"食事摂取基準", r"平均寿命", r"健康寿命", r"死亡率", r"出生率",
    r"受療率", r"有訴者率", r"自殺.*状況", r"将来推計人口", r"最新",
    r"令和\s*\d+\s*年", r"平成\s*\d+\s*年", r"20\d{2}\s*年",
]
DYNAMIC_RE = re.compile("|".join(DYNAMIC_PATTERNS), re.I)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def dynamic_required(q: dict) -> bool:
    text = " ".join([
        str(q.get("question") or ""),
        str(q.get("scenario") or ""),
        " ".join(q.get("choices") or []),
    ])
    return bool(DYNAMIC_RE.search(re.sub(r"\s+", "", text)))


def main() -> int:
    errors: list[str] = []
    required: dict[str, dict] = {}
    exam_counts = Counter()

    for exam, path in SET_MAP.items():
        data = load(path)
        for row in data.get("questions", []):
            if row.get("sourceExam") == exam and row.get("category") == "必修":
                qid = row.get("id")
                if qid in required:
                    errors.append(f"duplicate_required_id:{qid}")
                    continue
                required[qid] = dict(row)
                exam_counts[exam] += 1

    if len(required) != EXPECTED_TOTAL:
        errors.append(f"required_count:{len(required)}!=150")
    for exam in SET_MAP:
        if exam_counts[exam] != EXPECTED_PER_EXAM:
            errors.append(f"exam_{exam}_required_count:{exam_counts[exam]}!=50")

    correction_doc = load(REQUIRED_DIR / "text-corrections.json")
    corrections = correction_doc.get("corrections", [])
    correction_ids: set[str] = set()
    for row in corrections:
        qid = row.get("id")
        if qid in correction_ids:
            errors.append(f"duplicate_correction_id:{qid}")
            continue
        correction_ids.add(qid)
        q = required.get(qid)
        if not q:
            errors.append(f"correction_out_of_scope:{qid}")
            continue
        if "question" in row:
            q["question"] = row["question"]
        if "choices" in row:
            q["choices"] = row["choices"]
        q["textCorrectionStatus"] = "official_overlay_verified"
        q["textCorrectionEvidenceRefs"] = correction_doc.get("sourceRefs") or []
        q["textCorrectionCheckedDate"] = correction_doc.get("checkedDate")

    special_doc = load(REQUIRED_DIR / "special-cases.json")
    media_ids = {x["id"] for x in special_doc.get("mediaDependent", [])}
    scoring_ids = {x["id"] for x in special_doc.get("scoringSpecial", [])}
    expert_ids = {x["id"] for x in special_doc.get("expertReview", [])}
    quarantine_ids = media_ids | scoring_ids | expert_ids

    special_explanation_doc = load(REQUIRED_DIR / "special-case-explanations.json")
    special_explanations = {row.get("id"): row for row in special_explanation_doc.get("items", [])}

    explanation_rows: dict[str, dict] = {}
    explanation_sources: dict[str, str] = {}
    occurrences = Counter()

    for path in sorted(BATCH_DIR.glob("*.json")):
        doc = load(path)
        for row in doc.get("items", []):
            qid = row.get("id")
            if qid not in required:
                continue
            occurrences[qid] += 1
            explanation_rows[qid] = row
            explanation_sources[qid] = path.name

    for qid, row in special_explanations.items():
        if qid not in required:
            errors.append(f"special_explanation_out_of_scope:{qid}")
            continue
        if qid in explanation_rows:
            errors.append(f"special_explanation_duplicate_with_batch:{qid}:{explanation_sources[qid]}")
            continue
        explanation_rows[qid] = row
        explanation_sources[qid] = "required-150/special-case-explanations.json"

    duplicate_explanations = sorted(qid for qid, n in occurrences.items() if n > 1)
    if duplicate_explanations:
        errors.append(f"duplicate_required_explanation_rows:{duplicate_explanations}")

    missing_explanations = sorted(set(required) - set(explanation_rows))
    if missing_explanations:
        errors.append(f"missing_required_explanations:{missing_explanations}")

    special_reason_map: dict[str, list[dict]] = {}
    for kind, rows in (
        ("mediaDependent", special_doc.get("mediaDependent", [])),
        ("scoringSpecial", special_doc.get("scoringSpecial", [])),
        ("expertReview", special_doc.get("expertReview", [])),
    ):
        for row in rows or []:
            qid = row.get("id")
            if qid not in required:
                errors.append(f"special_case_out_of_scope:{kind}:{qid}")
                continue
            special_reason_map.setdefault(qid, []).append({
                "kind": kind,
                "status": row.get("status"),
                "reason": row.get("reason") or row.get("issue") or row.get("note"),
            })

    canonical_by_exam: dict[int, list[dict]] = {115: [], 114: [], 113: []}

    for qid in sorted(required):
        q = required[qid]
        expl = explanation_rows.get(qid)
        if expl:
            q["point"] = str(expl.get("point") or "").strip()
            q["detail"] = str(expl.get("detail") or "").strip()
            q["explanationEvidenceRefs"] = expl.get("explanationEvidenceRefs") or []
            q["evidenceCheckedDate"] = str(expl.get("evidenceCheckedDate") or "").strip()
            q["explanationSource"] = explanation_sources.get(qid)
            q["explanationStatus"] = "audited"
            dyn = dynamic_required(q)
            q["dynamicEvidenceRequired"] = dyn
            q["dynamicEvidenceStatus"] = expl.get("dynamicEvidenceStatus", "pending") if dyn else "not_required"

        q["answerEvidenceRefs"] = list(dict.fromkeys(q.get("sourceRefs") or []))
        q["originType"] = "licensed_official"
        q["copyrightBasis"] = q.get("rightsStatus")
        q["canonicalCategory"] = "required"
        q["specialistQuarantineStatus"] = "quarantined" if qid in quarantine_ids else "clear"
        q["specialistQuarantineReasons"] = special_reason_map.get(qid, [])
        q["releaseEligible"] = qid not in quarantine_ids
        q["canonicalStatus"] = "audited_quarantined" if qid in quarantine_ids else "audited_release_candidate"
        canonical_by_exam[q["sourceExam"]].append(q)

    if errors:
        report = {
            "schemaVersion": 1,
            "status": "FAIL",
            "auditDate": date.today().isoformat(),
            "errors": errors,
            "counts": {
                "requiredTotal": len(required),
                "textCorrections": len(correction_ids),
                "explanationsResolved": len(explanation_rows),
            },
        }
        dump(REQUIRED_DIR / "canonical-build-report.json", report)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 1

    for exam, questions in canonical_by_exam.items():
        questions.sort(key=lambda q: (q.get("session") or "", q.get("questionNo") or 0))
        out = {
            "schemaVersion": 1,
            "canonicalType": "learning-sprint-required",
            "sourceExam": exam,
            "category": "必修",
            "questionCount": len(questions),
            "sourceOfTruth": "GitHub canonical after specialist audit",
            "generatedFrom": {
                "classified": SET_MAP[exam].name,
                "textCorrections": "required-150/text-corrections.json",
                "explanationBatches": "product-content/explanation-batches/*.json",
                "specialCases": "required-150/special-cases.json",
                "specialExplanations": "required-150/special-case-explanations.json",
            },
            "releasePolicy": "canonical JSON is audited content; releaseEligible=false stays excluded until quarantine is resolved",
            "questions": questions,
        }
        dump(CANONICAL_ROOT / f"exam-{exam}" / "required.json", out)

    report = {
        "schemaVersion": 1,
        "status": "PASS",
        "auditDate": date.today().isoformat(),
        "counts": {
            "requiredTotal": len(required),
            "byExam": {str(exam): len(canonical_by_exam[exam]) for exam in SET_MAP},
            "textCorrections": len(correction_ids),
            "explanationsResolved": len(explanation_rows),
            "mediaDependent": len(media_ids),
            "scoringSpecial": len(scoring_ids),
            "expertReview": len(expert_ids),
            "quarantinedUnique": len(quarantine_ids),
            "releaseEligible": len(required) - len(quarantine_ids),
        },
        "outputs": [
            "questions/exam-115/required.json",
            "questions/exam-114/required.json",
            "questions/exam-113/required.json",
        ],
        "errors": [],
    }
    dump(REQUIRED_DIR / "canonical-build-report.json", report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
