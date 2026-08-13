#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "questions.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    payload = f"blob {len(data)}\0".encode("utf-8") + data
    return hashlib.sha1(payload).hexdigest()


bank = json.loads(BANK.read_text(encoding="utf-8"))
questions = bank.get("questions", [])
by_intent = {q.get("intentId"): q for q in questions}
if len(by_intent) != len(questions):
    fail("materialized bank contains duplicate intentId")

approval_files = sorted((ROOT / "data").glob("audit-approvals*.json"))
if not approval_files:
    fail("no audit approval ledgers found")

approvals = {}
bound_ledgers = 0
legacy_ledgers = 0
for path in approval_files:
    doc = json.loads(path.read_text(encoding="utf-8"))
    if doc.get("qualification") != "助産師国家試験":
        fail(f"{path.name}: qualification mismatch")

    batch_path_value = doc.get("batchPath")
    batch_blob_sha = doc.get("batchBlobSha")
    if bool(batch_path_value) != bool(batch_blob_sha):
        fail(f"{path.name}: batchPath and batchBlobSha must be supplied together")
    if batch_path_value:
        batch_path = ROOT / batch_path_value
        if not batch_path.is_file():
            fail(f"{path.name}: audited batch not found: {batch_path_value}")
        actual_blob = git_blob_sha(batch_path)
        if actual_blob != batch_blob_sha:
            fail(
                f"{path.name}: audited batch changed after approval "
                f"(expected {batch_blob_sha}, actual {actual_blob}); re-audit required"
            )
        bound_ledgers += 1
    else:
        # Historical ledgers remain valid during migration. New approvals must be blob-bound.
        legacy_ledgers += 1

    for approval in doc.get("approvals", []):
        intent_id = approval.get("intentId")
        if not intent_id:
            fail(f"{path.name}: approval without intentId")
        if intent_id in approvals:
            fail(f"duplicate approval across ledgers: {intent_id}")
        approvals[intent_id] = {**approval, "approvalLedger": path.name}

applied = 0
for intent_id, question in by_intent.items():
    approval = approvals.get(intent_id)
    if approval is None:
        continue
    audit_record = ROOT / approval.get("auditRecord", "")
    if not audit_record.is_file():
        fail(f"{intent_id}: audit record not found: {audit_record}")
    if question.get("auditStatus") not in {"content-reviewed", "pass"}:
        fail(f"{intent_id}: question is not content-reviewed before independent approval")
    question["auditStatus"] = "pass"
    question["independentAuditDate"] = approval.get("auditDate")
    question["independentAuditRecord"] = approval.get("auditRecord")
    question["approvalLedger"] = approval.get("approvalLedger")
    applied += 1

BANK.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(
    "PASS: "
    f"approval ledgers={len(approval_files)}, approvals={len(approvals)}, applied={applied}, "
    f"blob-bound={bound_ledgers}, legacy={legacy_ledgers}"
)
