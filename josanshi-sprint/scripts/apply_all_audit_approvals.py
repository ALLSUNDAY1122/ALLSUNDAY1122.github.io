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


def register_question_approval(approvals: dict, path: Path, approval: dict) -> None:
    intent_id = approval.get("intentId")
    if not intent_id:
        fail(f"{path.name}: question approval without intentId")
    if intent_id in approvals:
        fail(f"duplicate question approval across ledgers: {intent_id}")
    approvals[intent_id] = {**approval, "approvalLedger": path.name}


def register_scenario_approval(scenario_approvals: dict, path: Path, approval: dict) -> None:
    scenario_id = approval.get("scenarioId")
    if not scenario_id:
        fail(f"{path.name}: scenario approval without scenarioId")
    if scenario_id in scenario_approvals:
        fail(f"duplicate scenario approval across ledgers: {scenario_id}")
    scenario_approvals[scenario_id] = {**approval, "approvalLedger": path.name}


bank = json.loads(BANK.read_text(encoding="utf-8"))
questions = bank.get("questions", [])
scenarios = bank.get("scenarios", [])
by_intent = {q.get("intentId"): q for q in questions}
by_scenario = {s.get("scenarioId"): s for s in scenarios}
if len(by_intent) != len(questions):
    fail("materialized bank contains duplicate intentId")
if len(by_scenario) != len(scenarios):
    fail("materialized bank contains duplicate scenarioId")

approval_files = sorted((ROOT / "data").glob("audit-approvals*.json"))
if not approval_files:
    fail("no audit approval ledgers found")

approvals = {}
scenario_approvals = {}
bound_ledgers = 0
legacy_ledgers = 0
full_batch_ledgers = 0
for path in approval_files:
    doc = json.loads(path.read_text(encoding="utf-8"))
    if doc.get("qualification") != "助産師国家試験":
        fail(f"{path.name}: qualification mismatch")

    batch_path_value = doc.get("batchPath")
    batch_blob_sha = doc.get("batchBlobSha")
    if bool(batch_path_value) != bool(batch_blob_sha):
        fail(f"{path.name}: batchPath and batchBlobSha must be supplied together")

    batch_path = None
    batch_doc = None
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
        batch_doc = json.loads(batch_path.read_text(encoding="utf-8"))
        bound_ledgers += 1
    else:
        legacy_ledgers += 1

    full_batch = doc.get("fullBatchApproval")
    if full_batch is not None:
        if not isinstance(full_batch, dict):
            fail(f"{path.name}: fullBatchApproval must be an object")
        if batch_path is None or batch_doc is None:
            fail(f"{path.name}: fullBatchApproval requires blob-bound batchPath")

        audit_date = full_batch.get("auditDate")
        audit_record_value = full_batch.get("auditRecord")
        approve_questions = full_batch.get("questions") is True
        approve_scenarios = full_batch.get("scenarios") is True
        if not audit_date or not audit_record_value:
            fail(f"{path.name}: fullBatchApproval requires auditDate and auditRecord")
        if not approve_questions and not approve_scenarios:
            fail(f"{path.name}: fullBatchApproval must approve questions and/or scenarios")

        audit_record = ROOT / audit_record_value
        if not audit_record.is_file():
            fail(f"{path.name}: full-batch audit record not found: {audit_record_value}")
        audit_text = audit_record.read_text(encoding="utf-8")
        if "PASS" not in audit_text:
            fail(f"{path.name}: full-batch audit record does not contain explicit PASS")
        if batch_path.name not in audit_text and batch_path_value not in audit_text:
            fail(f"{path.name}: audit record does not identify audited batch {batch_path.name}")

        batch_questions = batch_doc.get("questions", [])
        batch_scenarios = batch_doc.get("scenarios", [])
        if approve_questions:
            if not isinstance(batch_questions, list) or not batch_questions:
                fail(f"{path.name}: question-wide approval requested for empty/non-array batch")
            for question in batch_questions:
                register_question_approval(
                    approvals,
                    path,
                    {
                        "intentId": question.get("intentId"),
                        "auditDate": audit_date,
                        "auditRecord": audit_record_value,
                    },
                )
        if approve_scenarios:
            if not isinstance(batch_scenarios, list) or not batch_scenarios:
                fail(f"{path.name}: scenario-wide approval requested for empty/non-array batch")
            for scenario in batch_scenarios:
                register_scenario_approval(
                    scenario_approvals,
                    path,
                    {
                        "scenarioId": scenario.get("scenarioId"),
                        "auditDate": audit_date,
                        "auditRecord": audit_record_value,
                    },
                )
        full_batch_ledgers += 1

    for approval in doc.get("approvals", []):
        register_question_approval(approvals, path, approval)

    for approval in doc.get("scenarioApprovals", []):
        register_scenario_approval(scenario_approvals, path, approval)

question_applied = 0
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
    question_applied += 1

scenario_applied = 0
for scenario_id, scenario in by_scenario.items():
    approval = scenario_approvals.get(scenario_id)
    if approval is None:
        continue
    audit_record = ROOT / approval.get("auditRecord", "")
    if not audit_record.is_file():
        fail(f"{scenario_id}: scenario audit record not found: {audit_record}")
    if scenario.get("auditStatus") not in {"content-reviewed", "pass"}:
        fail(f"{scenario_id}: scenario is not content-reviewed before independent approval")
    scenario["auditStatus"] = "pass"
    scenario["independentAuditDate"] = approval.get("auditDate")
    scenario["independentAuditRecord"] = approval.get("auditRecord")
    scenario["approvalLedger"] = approval.get("approvalLedger")
    scenario_applied += 1

BANK.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(
    "PASS: "
    f"approval ledgers={len(approval_files)}, question approvals={len(approvals)}, "
    f"question applied={question_applied}, scenario approvals={len(scenario_approvals)}, "
    f"scenario applied={scenario_applied}, blob-bound={bound_ledgers}, "
    f"full-batch={full_batch_ledgers}, legacy={legacy_ledgers}"
)
