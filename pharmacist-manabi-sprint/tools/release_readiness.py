#!/usr/bin/env python3
"""Evidence-based pharmacist content release readiness.

Structural product audit PASS is not rights, clinical accuracy or legal-version approval.
This report never upgrades a pending review to PASS. --strict is intended for
a future release handoff once all independent evidence has been recorded.
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
AUDIT = ROOT.parent / "automation" / "pharmacist-q0-q1-audit"
VERIFIED_CONTENT = {"verified_pass", "independent_review_pass", "expert_review_pass"}
VERIFIED_RIGHTS = {"RIGHTS_VERIFIED_PASS"}
VERIFIED_LAW = {"LAW_VERSION_VERIFIED_PASS"}
VERIFIED_IMAGE = {"visually_verified_pass"}
GENERIC_MARKERS = (
    "図表・構造式・装置図では、設問で指定された特徴を順に照合",
    "出典表示付き画像で確認し、選択肢",
    "図や表を参照して正しい選択肢",
)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="Fail unless content, law, rights and visual review are complete")
    parser.add_argument("--out", type=Path, help="Optional sanitized JSON report")
    args = parser.parse_args()

    source = load(CONTENT / "source-manifest.json")
    questions = load(CONTENT / "product" / "questions.json")["questions"]
    media = load(CONTENT / "media" / "media-manifest.json")
    law = load(AUDIT / "legal-review-queue-v1.json")["items"]
    rights = load(AUDIT / "third-party-rights-review-queue-v1.json")["items"]
    external = load(CONTENT / "third-party-source-citations.json").get("items", {})

    review_status = Counter(str(q.get("reviewStatus") or "NOT_VERIFIED") for q in questions)
    not_reviewed = [q["id"] for q in questions if str(q.get("reviewStatus") or "") not in VERIFIED_CONTENT]
    media_pending = [qid for qid, x in media.items() if x.get("releaseStatus") not in VERIFIED_IMAGE]
    legal_pending = [x["id"] for x in law if x.get("status") not in VERIFIED_LAW]
    rights_pending = [x["id"] for x in rights if x.get("status") not in VERIFIED_RIGHTS]
    generic = [q["id"] for q in questions if any(m in (q.get("explanation") or "") for m in GENERIC_MARKERS)]
    missing_provenance = [x["id"] for x in rights if
                          x["id"] not in external or
                          not external[x["id"]].get("title") or
                          not external[x["id"]].get("url", "").startswith("https://")]
    source_done = source.get("audit", {}).get("fullProblemAuditComplete") is True
    counts_ok = (len(questions), len(media), len(law), len(rights)) == (1035, 154, 107, 4)

    blockers = []
    if not counts_ok: blockers.append("SCOPE_COUNT_MISMATCH")
    if not source_done: blockers.append("CONTENT_MANIFEST_INCOMPLETE")
    if not_reviewed: blockers.append("QUESTION_CONTENT_INDEPENDENT_REVIEW_PENDING")
    if media_pending: blockers.append("MEDIA_VISUAL_REVIEW_PENDING")
    if legal_pending: blockers.append("EXAM_DATE_LEGAL_VERSION_REVIEW_PENDING")
    if rights_pending: blockers.append("THIRD_PARTY_RIGHTS_REVIEW_PENDING")
    if generic: blockers.append("GENERIC_EXPLANATIONS_PRESENT")
    if missing_provenance: blockers.append("THIRD_PARTY_ORIGINAL_CITATION_MISSING")

    report = {
        "app": "薬剤師国家試験｜学びスプリント",
        "schemaVersion": 1,
        "contentReleaseGate": "BLOCKED" if blockers else "CONTENT_GATES_PASSED_AWAITING_NATIVE_ACCEPTANCE",
        "structuralAuditPassIsNotContentApproval": True,
        "Q0": "BLOCKED" if legal_pending or rights_pending or missing_provenance else "SOURCE_RIGHTS_CHECKS_PASSED",
        "Q1": "FAIL" if not source_done or not_reviewed or media_pending or not counts_ok else "CONTENT_CHECKS_PASSED",
        "Q2": "FAIL" if generic else "NO_GENERIC_MARKERS_DETECTED_NOT_SEMANTIC_PROOF",
        "Q3": "NOT_TESTED_BY_THIS_SCRIPT",
        "Q4": "INDEPENDENT_HUMAN_DEVICE_ACCEPTANCE_NOT_VERIFIED_BY_THIS_SCRIPT",
        "Q5": "NOT_SUBMITTED",
        "counts": {
            "questions": len(questions), "questionContentReviewPending": len(not_reviewed),
            "images": len(media), "imageVisualReviewPending": len(media_pending),
            "legalCandidates": len(law), "legalReviewPending": len(legal_pending),
            "thirdPartyItems": len(rights), "thirdPartyRightsPending": len(rights_pending),
            "missingThirdPartyProvenance": len(missing_provenance),
            "genericExplanations": len(generic),
        },
        "reviewStatusCounts": dict(review_status),
        "blockers": blockers,
        "examples": {
            "pendingQuestions": not_reviewed[:12],
            "pendingImages": media_pending[:12],
            "pendingLaws": legal_pending[:12],
            "pendingThirdPartyRights": rights_pending,
            "genericExplanations": generic[:15],
        },
    }
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output, encoding="utf-8")
    print(output)
    return 1 if args.strict and blockers else 0


if __name__ == "__main__":
    raise SystemExit(main())
