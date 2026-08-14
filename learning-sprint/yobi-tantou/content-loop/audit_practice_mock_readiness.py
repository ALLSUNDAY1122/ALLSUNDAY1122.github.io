#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CONFIG = ROOT / "practice-mock-config.v1.json"
OFFICIAL = ROOT / "official-exam-structure.v1.json"
RELEASE = ROOT.parent / "ios" / "Resources" / "questions.release.json"
MOCK_BANK = ROOT / "mock-bank"
DEFAULT_REPORT = ROOT / "practice-mock-readiness.v1.json"

DIFFICULTY_TO_MOCK = {
    "foundation": "practice-mock-1",
    "standard": "practice-mock-2",
    "applied": "practice-mock-3",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def add_count(per_mock, assigned_ids, qid, mock_id, subject, legal_subjects):
    if subject in legal_subjects:
        per_mock[mock_id][subject] += 1
        per_mock[mock_id]["legalQuestionTotal"] += 1
    elif subject == "一般教養":
        per_mock[mock_id]["一般教養"] += 1
    assigned_ids[mock_id].append(qid)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--require-complete", action="store_true")
    ap.add_argument("--report", default=str(DEFAULT_REPORT))
    args = ap.parse_args()

    config = load(CONFIG)
    official = load(OFFICIAL)
    native_questions = load(RELEASE)
    expansion_files = sorted(MOCK_BANK.glob("*.release.json"))

    structure_year = str(config["basis"]["structureYear"])
    official_year = official["years"][structure_year]
    target = config["targetPerMock"]
    valid_mock_ids = {m["id"] for m in config["mocks"]}

    assert target["subjects"] == official_year["subjects"], "subject targets drift from official structure"
    assert target["legalQuestionTotal"] == official_year["legalQuestionTotal"] == 95
    assert target["generalEducation"] == official_year["generalEducation"]
    assert target["totalOfferedQuestionCount"] == 139
    assert config["completionGate"]["requiredTotalOfferedQuestions"] == 417

    per_mock = {m["id"]: defaultdict(int) for m in config["mocks"]}
    assigned_ids = defaultdict(list)
    structural_errors = []
    all_ids = set()
    legal_subjects = set(target["subjects"])

    native_ids = [q.get("id") for q in native_questions]
    if any(not qid for qid in native_ids) or len(native_ids) != len(set(native_ids)):
        structural_errors.append("native release bank has missing or duplicate IDs")

    for q in native_questions:
        qid = q.get("id") or "<no-id>"
        if qid in all_ids:
            structural_errors.append(f"{qid}: duplicate across formal banks")
        all_ids.add(qid)
        if not q.get("releaseEligible") or q.get("contentUse") != "practice":
            structural_errors.append(f"{qid}: non-release practice question in native release bank")
            continue
        if q.get("examYear") is not None:
            structural_errors.append(f"{qid}: practice question must not claim official exam year")
        difficulty = q.get("difficulty")
        mock_id = DIFFICULTY_TO_MOCK.get(difficulty)
        if mock_id is None:
            structural_errors.append(f"{qid}: unsupported difficulty {difficulty!r}")
            continue
        subject = q.get("subject")
        if subject in legal_subjects and q.get("lawBasisDate") != config["basis"]["lawBasisDate"]:
            structural_errors.append(f"{qid}: legal lawBasisDate mismatch")
        if subject not in legal_subjects and subject != "一般教養":
            structural_errors.append(f"{qid}: unknown subject {subject!r}")
            continue
        add_count(per_mock, assigned_ids, qid, mock_id, subject, legal_subjects)

    expansion_count = 0
    expansion_file_summary = []
    for path in expansion_files:
        items = load(path)
        if not isinstance(items, list) or not items:
            structural_errors.append(f"{path.name}: promoted mock batch must be non-empty JSON array")
            continue
        file_count = 0
        for q in items:
            qid = q.get("id") or "<no-id>"
            if qid in all_ids:
                structural_errors.append(f"{qid}: duplicate across native/mock release banks")
            all_ids.add(qid)
            mock_id = q.get("practice_mock_id")
            if mock_id not in valid_mock_ids:
                structural_errors.append(f"{qid}: invalid practice_mock_id {mock_id!r}")
                continue
            if q.get("audit_status") != "release_passed" or q.get("release_eligible") is not True:
                structural_errors.append(f"{qid}: mock expansion is not release_passed/release_eligible")
            if q.get("content_use") != "practice" or q.get("exam_year") is not None:
                structural_errors.append(f"{qid}: mock expansion must be practice with no official exam year")
            subject = q.get("subject")
            if subject in legal_subjects:
                if q.get("reference_date") != config["basis"]["lawBasisDate"]:
                    structural_errors.append(f"{qid}: legal reference_date mismatch")
            elif subject != "一般教養":
                structural_errors.append(f"{qid}: unknown subject {subject!r}")
                continue
            add_count(per_mock, assigned_ids, qid, mock_id, subject, legal_subjects)
            expansion_count += 1
            file_count += 1
        expansion_file_summary.append({"file": path.name, "count": file_count})

    report_mocks = []
    total_filled = 0
    for mock in config["mocks"]:
        mock_id = mock["id"]
        counts = per_mock[mock_id]
        remaining_subjects = {}
        for subject, target_count in target["subjects"].items():
            filled = counts.get(subject, 0)
            remaining = target_count - filled
            if remaining < 0:
                structural_errors.append(f"{mock_id}/{subject}: exceeds target {filled}>{target_count}")
            remaining_subjects[subject] = max(0, remaining)

        general_filled = counts.get("一般教養", 0)
        general_remaining_raw = target["generalEducation"]["offered"] - general_filled
        if general_remaining_raw < 0:
            structural_errors.append(
                f"{mock_id}/一般教養: exceeds target {general_filled}>{target['generalEducation']['offered']}"
            )
        general_remaining = max(0, general_remaining_raw)
        legal_filled = counts.get("legalQuestionTotal", 0)
        if legal_filled > target["legalQuestionTotal"]:
            structural_errors.append(
                f"{mock_id}/legalQuestionTotal: exceeds target {legal_filled}>{target['legalQuestionTotal']}"
            )
        offered_filled = legal_filled + general_filled
        if offered_filled > target["totalOfferedQuestionCount"]:
            structural_errors.append(
                f"{mock_id}/totalOffered: exceeds target {offered_filled}>{target['totalOfferedQuestionCount']}"
            )
        total_filled += offered_filled
        complete = (
            all(v == 0 for v in remaining_subjects.values())
            and general_remaining == 0
            and offered_filled == target["totalOfferedQuestionCount"]
        )
        report_mocks.append({
            "id": mock_id,
            "displayName": mock["displayName"],
            "seedDifficulty": mock["seedDifficulty"],
            "filled": {
                "subjects": {s: counts.get(s, 0) for s in target["subjects"]},
                "legalQuestionTotal": legal_filled,
                "generalEducationOffered": general_filled,
                "totalOfferedQuestionCount": offered_filled,
            },
            "remaining": {
                "subjects": remaining_subjects,
                "legalQuestionTotal": max(0, target["legalQuestionTotal"] - legal_filled),
                "generalEducationOffered": general_remaining,
                "totalOfferedQuestionCount": max(0, target["totalOfferedQuestionCount"] - offered_filled),
            },
            "assignedQuestionIds": assigned_ids[mock_id],
            "complete": complete,
        })

    all_complete = all(m["complete"] for m in report_mocks)
    target_total = config["completionGate"]["requiredTotalOfferedQuestions"]
    if total_filled > target_total:
        structural_errors.append(f"global offered total exceeds target {total_filled}>{target_total}")

    report = {
        "schemaVersion": 2,
        "checkedAt": "2026-08-14",
        "status": "PASS" if all_complete and not structural_errors else ("FAIL" if structural_errors else "HOLD"),
        "basis": {
            "structureYear": config["basis"]["structureYear"],
            "lawBasisDate": config["basis"]["lawBasisDate"],
        },
        "nativeSeedQuestionCount": len(native_questions),
        "promotedMockExpansionQuestionCount": expansion_count,
        "promotedMockExpansionFiles": expansion_file_summary,
        "currentFormalQuestionCount": len(native_questions) + expansion_count,
        "currentAssignedOfferedQuestionCount": total_filled,
        "targetOfferedQuestionCount": target_total,
        "remainingOfferedQuestionCount": max(0, target_total - total_filled),
        "seedDifficultyCounts": dict(Counter(q.get("difficulty") for q in native_questions)),
        "structuralErrors": structural_errors,
        "mocks": report_mocks,
    }

    out = Path(args.report)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if structural_errors:
        print("FAIL: practice mock readiness structural errors")
        for error in structural_errors:
            print(f"- {error}")
        return 1

    if all_complete:
        print("PASS: three original practice mocks meet all current-format slot counts")
        return 0

    print(f"HOLD: structure valid; formal={total_filled}/{target_total}; remaining={target_total - total_filled}")
    if args.require_complete:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
