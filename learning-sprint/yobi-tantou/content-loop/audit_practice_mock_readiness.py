#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CONFIG = ROOT / "practice-mock-config.v1.json"
OFFICIAL = ROOT / "official-exam-structure.v1.json"
RELEASE = ROOT.parent / "ios" / "Resources" / "questions.release.json"
DEFAULT_REPORT = ROOT / "practice-mock-readiness.v1.json"

DIFFICULTY_TO_MOCK = {
    "foundation": "practice-mock-1",
    "standard": "practice-mock-2",
    "applied": "practice-mock-3",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--require-complete", action="store_true")
    ap.add_argument("--report", default=str(DEFAULT_REPORT))
    args = ap.parse_args()

    config = load(CONFIG)
    official = load(OFFICIAL)
    questions = load(RELEASE)

    structure_year = str(config["basis"]["structureYear"])
    official_year = official["years"][structure_year]
    target = config["targetPerMock"]

    assert target["subjects"] == official_year["subjects"], "subject targets drift from official structure"
    assert target["legalQuestionTotal"] == official_year["legalQuestionTotal"] == 95
    assert target["generalEducation"] == official_year["generalEducation"]
    assert target["totalOfferedQuestionCount"] == 139
    assert config["completionGate"]["requiredTotalOfferedQuestions"] == 417

    ids = [q["id"] for q in questions]
    assert len(ids) == len(set(ids)), "duplicate release question id"

    per_mock = {m["id"]: defaultdict(int) for m in config["mocks"]}
    assigned_ids = defaultdict(list)
    structural_errors = []

    legal_subjects = set(target["subjects"])
    for q in questions:
        if not q.get("releaseEligible") or q.get("contentUse") != "practice":
            structural_errors.append(f"{q.get('id')}: non-release practice question in release bank")
            continue
        if q.get("examYear") is not None:
            structural_errors.append(f"{q['id']}: practice question must not claim official exam year")
        difficulty = q.get("difficulty")
        mock_id = DIFFICULTY_TO_MOCK.get(difficulty)
        if mock_id is None:
            structural_errors.append(f"{q['id']}: unsupported difficulty {difficulty!r}")
            continue
        subject = q.get("subject")
        if subject in legal_subjects:
            if q.get("lawBasisDate") != config["basis"]["lawBasisDate"]:
                structural_errors.append(f"{q['id']}: legal lawBasisDate mismatch")
            per_mock[mock_id][subject] += 1
            per_mock[mock_id]["legalQuestionTotal"] += 1
        elif subject == "一般教養":
            per_mock[mock_id]["一般教養"] += 1
        else:
            structural_errors.append(f"{q['id']}: unknown subject {subject!r}")
        assigned_ids[mock_id].append(q["id"])

    report_mocks = []
    total_filled = 0
    for mock in config["mocks"]:
        mock_id = mock["id"]
        counts = per_mock[mock_id]
        remaining_subjects = {
            subject: target_count - counts.get(subject, 0)
            for subject, target_count in target["subjects"].items()
        }
        general_filled = counts.get("一般教養", 0)
        general_remaining = target["generalEducation"]["offered"] - general_filled
        legal_filled = counts.get("legalQuestionTotal", 0)
        offered_filled = legal_filled + general_filled
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
                "legalQuestionTotal": target["legalQuestionTotal"] - legal_filled,
                "generalEducationOffered": general_remaining,
                "totalOfferedQuestionCount": target["totalOfferedQuestionCount"] - offered_filled,
            },
            "assignedQuestionIds": assigned_ids[mock_id],
            "complete": complete,
        })

    all_complete = all(m["complete"] for m in report_mocks)
    report = {
        "schemaVersion": 1,
        "checkedAt": "2026-08-14",
        "status": "PASS" if all_complete and not structural_errors else ("FAIL" if structural_errors else "HOLD"),
        "basis": {
            "structureYear": config["basis"]["structureYear"],
            "lawBasisDate": config["basis"]["lawBasisDate"],
        },
        "currentReleaseQuestionCount": len(questions),
        "currentAssignedOfferedQuestionCount": total_filled,
        "targetOfferedQuestionCount": config["completionGate"]["requiredTotalOfferedQuestions"],
        "remainingOfferedQuestionCount": config["completionGate"]["requiredTotalOfferedQuestions"] - total_filled,
        "difficultyCounts": dict(Counter(q.get("difficulty") for q in questions)),
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

    print(
        "HOLD: structure is valid but mock bank is incomplete; "
        f"filled={total_filled}/{config['completionGate']['requiredTotalOfferedQuestions']}"
    )
    if args.require_complete:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
