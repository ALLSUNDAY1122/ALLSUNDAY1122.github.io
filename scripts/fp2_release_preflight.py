#!/usr/bin/env python3
"""Fail-closed FP2 canonical bank + source-web-shell gate. Does not certify an iOS binary."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "fp2-manabi-sprint"
BANK = APP / "questions/canonical/approved-questions-20261123.json"
LOCK = APP / "release/bundle-lock-20261123.json"


def git_blob_sha(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=("content", "release"), default="content")
    ap.add_argument("--output")
    args = ap.parse_args()
    errors, warnings = [], []
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    questions = bank.get("questions", [])
    expected_count = bank.get("content_approved_questions")
    if len(questions) != expected_count:
        errors.append(f"bank count mismatch: {len(questions)} != {expected_count}")
    if len(questions) != lock.get("content_review_pass"):
        errors.append("source lock content count mismatch")
    ids = [q.get("id") for q in questions]
    if len(ids) != len(set(ids)):
        errors.append("duplicate question IDs")
    selected = [q for q in questions if q.get("release_selected") is True]
    reserve = [q for q in questions if q.get("release_selected") is False]
    if len(selected) != 298 or len(reserve) != 12 or bank.get("release_candidate_questions") != 298 or bank.get("reserve_content_pass_questions") != 12:
        errors.append(f"release scope mismatch: selected={len(selected)}, reserves={len(reserve)}")
    domain_counts = {}
    for q in selected:
        d = q.get("domain")
        domain_counts[d] = domain_counts.get(d, 0) + 1
    if len(domain_counts) != 6 or sorted(domain_counts.values()) != [48, 50, 50, 50, 50, 50]:
        errors.append("release scope must be 48+50*5=298 official only")
    if bank.get("recovered_pass_count") != 180 or bank.get("recovered_fail_count") != 0 or bank.get("recovered_hold_count") != 0:
        errors.append("independent corrected re-audit 180/0/0 mismatch")
    if (bank.get("expansion_audit_pass_count"), bank.get("expansion_audit_fail_count"), bank.get("expansion_audit_hold_count")) != (118, 2, 0):
        errors.append("verbatim independent audit PASS118 FAIL2 HOLD0 (2024 rounds; total five PASS298) mismatch")
    sessions = {}
    for q in selected:
        session = q.get("exam_year_month") or q.get("examDate") or "independently-authored"
        sessions[session] = sessions.get(session, 0) + 1
    if sessions != {"2024-05":59,"2024-09":59,"2025-01":60,"2025-05":60,"2026-05":60}:
        errors.append("session distribution invalid: 298 official PASS and no replacements")
    if len(questions) != 310:
        errors.append("310 canonical PASS expected (298 official +12 original reserves)")
    reaudited_pass = {
       "fp2-2025-05-gakka-036", "fp2-2025-05-gakka-039",
       "fp2-2025-01-gakka-017", "fp2-2025-01-gakka-013"
    }
    q20 = "fp2-2025-01-gakka-020"
    q20_entries = [q for q in questions if q.get("id") == q20]
    if len(q20_entries) != 1 or q20_entries[0].get("release_selected") is not True or q20_entries[0].get("independent_audit_status") != "PASS" or q20_entries[0].get("audit_evidence_path") != "fp2-manabi-sprint/audit/FP2_2025_01_Q20_SECOND_CORRECTION_REAUDIT_PASS_20261123.md":
        errors.append("Q20: second independent re-audit PASS evidence must exist and join 298 selection")
    for ident in reaudited_pass:
        matches = [q for q in questions if q.get("id") == ident]
        if len(matches) != 1 or matches[0].get("release_selected") is not True or matches[0].get("audit_evidence_path") != "fp2-manabi-sprint/audit/FP2_FAIL5_CORRECTED_INDEPENDENT_REAUDIT_20261123.md" or matches[0].get("independent_audit_status") != "PASS":
            errors.append(f"{ident}: corrected PASS must be independently evidenced in 298 selection")
    if any((q.get("modification_verification", "").startswith("PROVISIONAL") or "PENDING" in q.get("modification_verification", "")) for q in selected):
        warnings.append("release selection has provisionally classified modified flags; NOT release ready")
    independent_paths = set()
    for q in questions:
        ident = q.get("id", "UNKNOWN")
        choices = q.get("choices", [])
        stem = q.get("stem") or q.get("question")
        explanation = q.get("explanation")
        a = q.get("answer_index")
        if not isinstance(stem, str) or not stem.strip() or not isinstance(choices, list) or len(choices) != 4 or any(not isinstance(c, str) or not c.strip() for c in choices) or not isinstance(explanation, str) or not explanation.strip() or not isinstance(a, int) or a not in (0, 1, 2, 3):
            errors.append(f"{ident}: invalid question structure")
        if q.get("approved_for_content_bank") is not True or q.get("independent_audit_status") != "PASS":
            errors.append(f"{ident}: content independent PASS missing")
        if not isinstance(q.get("modified"), bool) or not isinstance(q.get("modification_note"), str) or not q.get("modification_note").strip():
            errors.append(f"{ident}: modification classification/note missing")
        src = q.get("source_original_question_url") or q.get("source_question_url") or q.get("source_url") or q.get("sourceUrl") or q.get("primary_law_url")
        if not isinstance(src, str) or not src.startswith("https://"):
            errors.append(f"{ident}: primary source URL missing")
        if q.get("publishable") is not False:
            errors.append(f"{ident}: unsafe publication flag")
        audit_path = q.get("audit_evidence_path")
        if not isinstance(audit_path, str) or not audit_path.startswith("fp2-manabi-sprint/audit/"):
            errors.append(f"{ident}: independent evidence path missing")
        else:
            independent_paths.add(audit_path)
            if not (ROOT / audit_path).is_file():
                errors.append(f"{ident}: evidence file absent")
    for audit_path in independent_paths:
        data = (ROOT / audit_path).read_bytes() if (ROOT / audit_path).exists() else b""
        found = git_blob_sha(data)
        for q in questions:
            if q.get("audit_evidence_path") == audit_path and q.get("audit_evidence_blob_sha") != found:
                errors.append(f"{q['id']}: evidence blob SHA mismatch")
    for path, rec in lock.get("assets", {}).items():
        f = ROOT / path
        if not f.is_file():
            errors.append(f"asset missing: {path}")
        elif git_blob_sha(f.read_bytes()) != rec.get("blob_sha"):
            errors.append(f"asset drift: {path}")
    html = (APP / "index.html").read_text(encoding="utf-8")
    js = (APP / "fp2-approved-bank.js").read_text(encoding="utf-8")
    sw = (APP / "service-worker.js").read_text(encoding="utf-8")
    for tag, ok in [
        ("adapter linked", 'src="fp2-approved-bank.js"' in html),
        ("canonical bank single-source linked", lock["adapter_bank_path"] in js),
        ("service worker linked", "serviceWorker.register" in html),
        ("offline same-bank precache", lock["service_worker_precache_bank_path"] in sw),
        ("4/8/16 goal UI", all(f'data-goal="{n}"' in html for n in (4, 8, 16))),
        ("82px ring", '<svg width="82" height="82"' in html),
        ("4-tab navigation", all(f'data-screen="{name}"' in html for name in ("home", "mock", "history", "settings"))),
        ("source and modified display", "modification_note" in html and "source_section" in html),
        ("offline manifest", 'href="./manifest.webmanifest"' in html),
        ("privacy page", (APP / "privacy.html").is_file()),
        ("support page", (APP / "support.html").is_file()),
    ]:
        if not ok:
            errors.append("web shell: " + tag)
    if re.search(r"const\s+QUESTIONS\s*=\s*\[", html):
        errors.append("legacy embedded sample bank still present")
    if "600問監査後" in html:
        errors.append("obsolete 600 fixed bank placeholder")
    if any(token in html.lower() for token in ("firebase", "crashlytics", "google-analytics", "mixpanel", "revenuecat")):
        warnings.append("possible SDK reference in HTML: inspect App Privacy")
    release_blockers = [
        "Q0: final operator-rights and independent all-choices 2026-04-01 legal-application signoff not recorded",
        "Q1: release-candidate difficulty/curriculum/reproducible official source review not finalized",
        "Q2: learner usability test and real learning-loop validation not performed",
        "Q3: golden-master screenshot fidelity, actual browser/iPhone, recovery/offline E2E not proven",
        "Q4: genuinely independent E2E and learner acceptance missing",
        "Q5: native iOS bundle, App Store Connect current version/build/IAP, privacy, screenshots/TestFlight evidence missing",
    ]
    if args.mode == "release":
        errors.extend(release_blockers)
    result = {
        "gate": "FP2 source and content static gate",
        "mode": args.mode,
        "content_questions": len(questions),
        "selected_release_candidates": len(selected),
        "reserve_content_pass": len(reserve),
        "selected_domain_counts": domain_counts,
        "verified_independent_evidence_files": sorted(independent_paths),
        "source_asset_count": len(lock.get("assets", {})),
        "ios_ipa_bundle_verified": False,
        "web_runtime_e2e_verified": False,
        "selected_original_pdf_verification_all_done": not any((q.get("modification_verification", "").startswith("PROVISIONAL") or "PENDING" in q.get("modification_verification", "")) for q in selected),
        "app_privacy_final_verified": False,
        "release_blockers": release_blockers,
        "errors": errors,
        "warnings": warnings,
        "status": "PASS" if not errors else "FAIL",
    }
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
