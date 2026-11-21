#!/usr/bin/env python3
"""HM2 submission preflight: read-only evidence verification, fail closed for submission."""
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "ios/health-manager-2"
BANK = BASE / "release-questions.json"
PIN = "8540991f1a75a9eaa640d695fe7ee1c54dc57861141c5d19514f43311f455fb0"
CSV_PIN = "a4404d36387f13c39ad13d06f30a437f78f4f5c763ddb1d5c2b31570fc5aed19"

def hashfile(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default="/tmp/hm2-submission-readiness.json")
    ap.add_argument("--enforce-submission", action="store_true")
    args = ap.parse_args()
    checks, errors, blockers = {}, [], []
    questions = json.loads(BANK.read_text(encoding="utf-8"))
    ids = [q["id"] for q in questions]
    shapes_ok = len(questions) == 300 and len(set(ids)) == 300 and all(
        len(q.get("choices", [])) == 5 and len(set(q["choices"])) == 5
        and type(q.get("correct_index")) is int and 0 <= q["correct_index"] < 5
        for q in questions
    )
    checks["300_question_structure"] = shapes_ok
    checks["reviewed_bank_sha256"] = hashfile(BANK)
    if not shapes_ok:
        errors.append("INVALID_QUESTION_STRUCTURE")
    if hashfile(BANK) != PIN:
        errors.append("UNREVIEWED_BANK_SHA")

    ledger = (BASE / "audit/FINAL_GATE_178_ID_EVIDENCE_MATRIX_20261112.md").read_text(encoding="utf-8")
    parts = ledger.split("## 178件個別照合の着手明細", 1)
    row_section = parts[1].split("## 今回の判断", 1)[0] if len(parts) == 2 else ""
    pending = re.findall(r"^\|\s*\x60(sm2-[^\x60]+)\x60", row_section, re.M)
    scope_ok = len(pending) == len(set(pending)) == 178 and set(pending) <= set(ids)
    checks["178_unique_review_scope"] = scope_ok
    if not scope_ok:
        errors.append("REVIEW_SCOPE_MISMATCH")

    swift = (BASE / "HealthManager2/StoreKitManager.swift").read_text(encoding="utf-8")
    pricing_ok = (swift.count("displayPrice") >= 2
                  and "monthlyJapanDisplayPrice" not in swift
                  and "lifetimeJapanDisplayPrice" not in swift
                  and "subscriptionPeriod.value == 1" in swift)
    checks["storekit_current_price"] = pricing_ok
    if not pricing_ok:
        errors.append("MISLEADING_STOREKIT_PRICE")
    privacy = plistlib.loads((BASE / "HealthManager2/PrivacyInfo.xcprivacy").read_bytes())
    checks["privacy_manifest"] = privacy.get("NSPrivacyTracking") is False and privacy.get("NSPrivacyCollectedDataTypes") == []
    if not checks["privacy_manifest"]:
        errors.append("PRIVACY_MANIFEST_MISMATCH")

    original = BANK.read_bytes()
    snapshot = subprocess.run(["node", str(BASE / "export-canonical-snapshot.cjs")],
                              cwd=ROOT, capture_output=True, text=True)
    snapshot_ok = snapshot.returncode == 0 and BANK.read_bytes() == original
    checks["canonical_snapshot_byte_identical"] = snapshot_ok
    if not snapshot_ok:
        errors.append("CANONICAL_REGENERATION_FAILED")

    strict = subprocess.run(["node", str(BASE / "export-audit-data.cjs")],
                            cwd=ROOT, capture_output=True, text=True)
    strict_message = strict.stdout + strict.stderr
    checks["strict_release_export"] = {
        "exit_code": strict.returncode,
        "blocked_by_review": "HM2_RELEASE_REVIEW_BLOCKED" in strict_message,
        "tail": strict_message[-900:],
    }
    if strict.returncode:
        if "HM2_RELEASE_REVIEW_BLOCKED" in strict_message:
            blockers.append("178_QUESTION_INDEPENDENT_REVIEW_PENDING")
        else:
            errors.append("STRICT_EXPORT_UNEXPECTED_FAILURE")

    # No evidence is inferred merely from a user report; these files must be
    # independently produced, reviewed and checked before submission.
    for relative, code in (
        ("ios/health-manager-2/audit/HM2_FINAL_EXPERT_APPROVALS_178.json", "EXPERT_APPROVAL_EVIDENCE_MISSING"),
        ("ios/health-manager-2/audit/HM2_RIGHTS_CLEARANCE_300.json", "RIGHTS_CLEARANCE_EVIDENCE_MISSING"),
        ("automation/asc-results/hm2-verified-release-candidate.json", "CURRENT_BUILD_ASC_READBACK_MISSING"),
    ):
        if not (ROOT / relative).is_file():
            blockers.append(code)
    csv = BASE / "audit/HM2_LAST_CONTENT_COMMIT_300.csv"
    if not csv.is_file():
        blockers.append("CLAUDE_300_ID_COMMIT_CSV_NOT_IMPORTED")
    elif hashfile(csv) != CSV_PIN:
        blockers.append("300_ID_COMMIT_CSV_HASH_MISMATCH")
    screens = ROOT / "automation/release-assets/hm2/manifest.json"
    if not screens.is_file():
        blockers.append("ACTUAL_APP_SCREENSHOTS_NOT_STORED")
    else:
        manifest = json.loads(screens.read_text(encoding="utf-8"))
        if manifest.get("source") != "hm2-review-screenshot.yml":
            blockers.append("APP_SCREENSHOTS_NOT_ACTUAL_SIMULATOR_CAPTURE")
        for item in manifest.get("files", []):
            p = screens.parent / str(item.get("name", ""))
            if not p.is_file() or hashfile(p) != item.get("sha256"):
                blockers.append("APP_SCREENSHOT_HASH_MISMATCH")
                break

    report = {
        "app": "第二種衛生管理者",
        "bundle_id": "jp.allsunday1122.healthmanager2",
        "app_store_connect_app_id": "6799751657",
        "bank_sha256": hashfile(BANK),
        "checks": checks,
        "technical_errors": errors,
        "submission_blockers": blockers,
        "submission_ready": not errors and not blockers,
        "note": "No expert approval, rights clearance, device test or ASC readback is inferred.",
    }
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"technical_errors": errors, "submission_blockers": blockers,
                      "submission_ready": report["submission_ready"]}, ensure_ascii=False))
    return 1 if errors or (args.enforce_submission and blockers) else 0

if __name__ == "__main__":
    raise SystemExit(main())
