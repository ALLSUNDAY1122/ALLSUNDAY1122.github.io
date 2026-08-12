#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"
APPROVALS = ROOT / "data" / "audit-approvals.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


bank = json.loads(BANK.read_text(encoding="utf-8"))
approval_doc = json.loads(APPROVALS.read_text(encoding="utf-8"))
questions = bank.get("questions", [])
by_intent = {q.get("intentId"): q for q in questions}
if len(by_intent) != len(questions):
    fail("materialized bank contains duplicate intentId")

seen = set()
applied = 0
for approval in approval_doc.get("approvals", []):
    intent_id = approval.get("intentId")
    if not intent_id or intent_id in seen:
        fail(f"invalid/duplicate approval intentId: {intent_id}")
    seen.add(intent_id)
    audit_record = ROOT / approval.get("auditRecord", "")
    if not audit_record.is_file():
        fail(f"{intent_id}: audit record not found: {audit_record}")
    question = by_intent.get(intent_id)
    if question is None:
        # Approvals may be landed before the authored batch; do not fabricate content.
        continue
    if question.get("auditStatus") not in {"content-reviewed", "pass"}:
        fail(f"{intent_id}: question is not content-reviewed before independent approval")
    question["auditStatus"] = "pass"
    question["independentAuditDate"] = approval.get("auditDate")
    question["independentAuditRecord"] = approval.get("auditRecord")
    applied += 1

BANK.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"PASS: independent audit approvals applied: {applied}")
