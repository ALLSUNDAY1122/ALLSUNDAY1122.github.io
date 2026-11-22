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
PIN = "95e394dfa8f7d8b8dd23b763c168e61ab71e4e452fc519f87111011fc4c34eef"  # Exact current bank UTF-8 SHA-256; update only with reproducible 300-question snapshot
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

    # The Q0 user-approved alternative replaces named external expert approval.
    # This remains fail-closed: 178 independent double-checks, source references,
    # the in-app disclosure, and rights decisions for all 300 must be evidenced.
    # The validator checks completeness only; the substantive assertions still
    # require direct independent validation before final Q0 release sign-off.
    alternative = subprocess.run(
        ["python3", str(ROOT / "scripts/hm2_alternative_q0_gate.py"), "--enforce"],
        cwd=ROOT, capture_output=True, text=True
    )
    checks["alternative_q0_evidence"] = {
        "exit_code": alternative.returncode,
        "tail": (alternative.stdout + alternative.stderr)[-1200:],
    }
    if alternative.returncode != 0:
        blockers.append("ALTERNATIVE_Q0_178_DOUBLE_CHECK_AND_300_RIGHTS_PENDING")

    candidate = ROOT / "automation/asc-results/hm2-verified-release-candidate.json"
    if not candidate.is_file():
        blockers.append("CURRENT_BUILD_ASC_READBACK_MISSING")
    else:
        try:
            data = json.loads(candidate.read_text(encoding="utf-8"))
            valid = (
                str(data.get("app_id")) == "6799751657"
                and data.get("bundle_id") == "jp.allsunday1122.healthmanager2"
                and data.get("question_bank_sha256") == hashfile(BANK)
                and data.get("asc_processing_state") == "VALID"
                and data.get("app_store_eligible") is True
                and data.get("expired") is False
                and data.get("build_id") and data.get("build_number")
                and data.get("testflight_internal_verified") is True
                and data.get("device_test_pass") is True
                and data.get("iap_review_pass") is True
                and data.get("app_privacy_verified") is True
            )
            if not valid:
                blockers.append("CURRENT_BUILD_ASC_EVIDENCE_INVALID")
        except (OSError, ValueError):
            blockers.append("CURRENT_BUILD_ASC_EVIDENCE_UNREADABLE")
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
        if manifest.get("source") != "hm2-review-screenshot.yml" or manifest.get("question_bank_sha256") != hashfile(BANK):
            blockers.append("APP_SCREENSHOTS_NOT_CURRENT_SIMULATOR_CAPTURE")
        names = {f.get("name") for f in manifest.get("files", []) if isinstance(f, dict)}
        if not {"01-home.png", "02-premium.png"} <= names:
            blockers.append("REQUIRED_APP_SCREENSHOTS_MISSING")
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
        "note": "No independent Q0 completion, rights clearance, device test or ASC readback is inferred.",
    }
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"technical_errors": errors, "submission_blockers": blockers,
                      "submission_ready": report["submission_ready"]}, ensure_ascii=False))
    return 1 if errors or (args.enforce_submission and blockers) else 0

if __name__ == "__main__":
    raise SystemExit(main())
