#!/usr/bin/env python3
"""HM2 alternative Q0 evidence verifier. Read-only; fails closed.

This validates evidence *structure*, not the truth of legal/rights assertions.
Never use it alone to claim Q0 approval.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "ios/health-manager-2"
BANK = BASE / "release-questions.json"
LEDGER = BASE / "audit/FINAL_GATE_178_ID_EVIDENCE_MATRIX_20261112.md"
EVIDENCE = BASE / "audit/HM2_INDEPENDENT_DOUBLE_CHECK_178.json"
RIGHTS = BASE / "audit/HM2_RIGHTS_CLEARANCE_300.json"
DISCLOSURE = {
    "in_app": ROOT / "apps/sanitary-manager-2/gm4.js",
    "support": ROOT / "health-manager-2/support.html",
    "store": BASE / "APP_STORE_METADATA_JA.md",
}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def nonblank(x):
    return isinstance(x, str) and bool(x.strip())


def load_json(path, failures, label):
    if not path.is_file():
        failures.append(label + "_MISSING")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        failures.append(label + "_UNREADABLE")
        return None


def validate(root=ROOT, evidence=EVIDENCE, rights=RIGHTS):
    # Paths below follow the actual repository, never inferred from supplied files.
    bank_path = root / "ios/health-manager-2/release-questions.json"
    ledger_path = root / "ios/health-manager-2/audit/FINAL_GATE_178_ID_EVIDENCE_MATRIX_20261112.md"
    failures = []
    questions = load_json(bank_path, failures, "BANK")
    if not isinstance(questions, list):
        return {"pass": False, "failures": failures + ["BANK_NOT_ARRAY"]}
    ids = [q.get("id") for q in questions if isinstance(q, dict)]
    if any(not isinstance(q, dict) for q in questions):
        failures.append("BANK_ROW_SCHEMA_INVALID")
    if len(questions) != 300 or len(ids) != 300 or len(set(ids)) != 300:
        failures.append("BANK_NOT_300_UNIQUE")
    bank_hash = sha256(bank_path)
    if not ledger_path.is_file():
        return {"pass": False, "failures": failures + ["SCOPE_LEDGER_MISSING"]}
    ledger = ledger_path.read_text(encoding="utf-8")
    segments = ledger.split("## 178件個別照合の着手明細", 1)
    section = segments[1].split("## 今回の判断", 1)[0] if len(segments) == 2 else ""
    scope = re.findall(r"^\|\s*`(sm2-[^`]+)`", section, re.M)
    if len(scope) != 178 or len(set(scope)) != 178 or not set(scope).issubset(ids):
        failures.append("SCOPE_NOT_178_UNIQUE")
    by_question = {q["id"]: q for q in questions if isinstance(q, dict) and nonblank(q.get("id"))}
    if any(not isinstance(q.get("choices"), list) or len(q["choices"]) != 5 or type(q.get("correct_index")) is not int or not 0 <= q["correct_index"] <= 4 for q in questions if isinstance(q, dict)):
        failures.append("BANK_CHOICE_SHAPE_INVALID")
    payload = load_json(evidence, failures, "DOUBLE_CHECK")
    if payload is not None and not isinstance(payload, dict):
        failures.append("DOUBLE_CHECK_SCHEMA_INVALID")
    if isinstance(payload, dict):
        rows = payload.get("reviews")
        if payload.get("question_bank_sha256") != bank_hash:
            failures.append("DOUBLE_CHECK_BANK_SHA_MISMATCH")
        if not isinstance(rows, list) or len(rows) != 178:
            failures.append("DOUBLE_CHECK_COUNT")
        else:
            by_id = {r.get("id"): r for r in rows if isinstance(r, dict)}
            if any(not isinstance(r, dict) for r in rows):
                failures.append("DOUBLE_CHECK_ROW_SCHEMA_INVALID")
            if len(by_id) != 178 or set(by_id) != set(scope):
                failures.append("DOUBLE_CHECK_SCOPE")
            for id_, row in by_id.items():
                if id_ not in by_question:
                    continue
                q = by_question[id_]
                passes = row.get("passes")
                if not isinstance(passes, list) or len(passes) != 2:
                    failures.append(f"{id_}:TWO_PASSES_REQUIRED")
                    continue
                reviewer_ids = []
                for i, p in enumerate(passes):
                    if not isinstance(p, dict):
                        failures.append(f"{id_}:PASS{i+1}_INVALID")
                        continue
                    reviewer_ids.append(p.get("reviewer_id"))
                    if not all(nonblank(p.get(k)) for k in
                               ("reviewer_id", "reviewed_at", "method", "primary_source_url",
                                "source_section", "applicable_on", "reasoning")):
                        failures.append(f"{id_}:PASS{i+1}_EVIDENCE_INCOMPLETE")
                    if p.get("question_bank_sha256") != bank_hash:
                        failures.append(f"{id_}:PASS{i+1}_STALE_SHA")
                    judgments = p.get("choices")
                    if not isinstance(judgments, list) or len(judgments) != 5:
                        failures.append(f"{id_}:PASS{i+1}_FIVE_CHOICES_REQUIRED")
                        continue
                    for j, choice in enumerate(judgments):
                        if (not isinstance(choice, dict)
                                or choice.get("text") != q["choices"][j]
                                or type(choice.get("correct")) is not bool
                                or not nonblank(choice.get("reason"))
                                or not nonblank(choice.get("source_section"))):
                            failures.append(f"{id_}:PASS{i+1}_CHOICE{j+1}_INCOMPLETE")
                    if all(isinstance(x, dict) and type(x.get("correct")) is bool for x in judgments):
                        truth = [i for i, x in enumerate(judgments) if x["correct"]]
                        if truth != [q["correct_index"]]:
                            failures.append(f"{id_}:PASS{i+1}_ANSWER_CONFLICT")
                if len(reviewer_ids) != 2 or not all(map(nonblank, reviewer_ids)) or reviewer_ids[0] == reviewer_ids[1]:
                    failures.append(f"{id_}:INDEPENDENCE_UNPROVEN")
                if row.get("final_disposition") != "approved_after_reconciliation":
                    failures.append(f"{id_}:RECONCILIATION_REQUIRED")
    rights_doc = load_json(rights, failures, "RIGHTS")
    if rights_doc is not None and not isinstance(rights_doc, dict):
        failures.append("RIGHTS_SCHEMA_INVALID")
    if isinstance(rights_doc, dict):
        rows = rights_doc.get("decisions")
        if rights_doc.get("question_bank_sha256") != bank_hash:
            failures.append("RIGHTS_BANK_SHA_MISMATCH")
        if not isinstance(rows, list) or len(rows) != 300:
            failures.append("RIGHTS_COUNT")
        else:
            by_id = {r.get("id"): r for r in rows if isinstance(r, dict)}
            if any(not isinstance(r, dict) for r in rows):
                failures.append("RIGHTS_ROW_SCHEMA_INVALID")
            if len(by_id) != 300 or set(by_id) != set(ids):
                failures.append("RIGHTS_SCOPE")
            for id_, row in by_id.items():
                if not (row.get("cleared") is True
                        and all(nonblank(row.get(k)) for k in
                        ("source_url", "rights_holder", "license_or_exception",
                         "originality_comparison", "decision_rationale",
                         "reviewer_id", "reviewed_at"))):
                    failures.append(f"{id_}:RIGHTS_INCOMPLETE")
    for label, relative in (("IN_APP", "apps/sanitary-manager-2/gm4.js"),
                            ("SUPPORT", "health-manager-2/support.html"),
                            ("STORE", "ios/health-manager-2/APP_STORE_METADATA_JA.md")):
        path = root / relative
        s = path.read_text(encoding="utf-8") if path.is_file() else ""
        # Do not mistake positive official/supervised claims for a disclaimer.
        unofficial = any(x in s for x in ("非公式", "公式アプリではなく", "公式教材ではなく", "公式アプリではありません"))
        unsupervised = any(x in s for x in (
            "監修なし", "監修・承認を受けていません",
            "監修・承認を受けた教材ではありません", "専門家監修を受けていません"
        ))
        if not (unofficial and unsupervised):
            failures.append(f"{label}_DISCLAIMER_MISSING")
    return {"pass": not failures, "question_bank_sha256": bank_hash,
            "scope_count": len(scope), "failures": failures[:40],
            "failure_count": len(failures),
            "note": "Evidence structure only. Human/legal source validity is not proven by this script."}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument("--output")
    args = parser.parse_args()
    result = validate()
    raw = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(raw, encoding="utf-8")
    print(raw, end="")
    return 1 if args.enforce and not result["pass"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
