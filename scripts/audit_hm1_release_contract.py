#!/usr/bin/env python3
from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "ios/health-manager-1"
CHECKLIST = BASE / "RELEASE_CHECKLIST.md"
STATUS = BASE / "RELEASE_STATUS.md"
METADATA = BASE / "APP_STORE_METADATA_JA.md"
ASC_INPUT = BASE / "APP_STORE_CONNECT_INPUT_JA.md"
PREPARE = BASE / "prepare-ios.sh"
READINESS = ROOT / "automation/hm1-testflight-readiness.json"
SUBMIT = ROOT / "scripts/app2_005_hm1_prepare_submit.py"
METADATA_WORKFLOW = ROOT / ".github/workflows/app2-005-hm1-prepare-metadata.yml"

texts = {
    "checklist": CHECKLIST.read_text(encoding="utf-8"),
    "status": STATUS.read_text(encoding="utf-8"),
    "metadata": METADATA.read_text(encoding="utf-8"),
    "asc_input": ASC_INPUT.read_text(encoding="utf-8"),
}
submit = SUBMIT.read_text(encoding="utf-8")
prepare = PREPARE.read_text(encoding="utf-8")
metadata_workflow = METADATA_WORKFLOW.read_text(encoding="utf-8")
readiness = json.loads(READINESS.read_text(encoding="utf-8"))
errors = []

required_submit = {
    "app id": 'APP_ID = "6799581662"',
    "bundle id": 'BUNDLE_ID = "jp.allsunday1122.healthmanager1"',
    "monthly id": 'MONTHLY_ID = "6804373671"',
    "lifetime id": 'LIFETIME_ID = "6799583540"',
    "264 questions": "独自に作成・監査した264問",
    "monthly 200": "月額200円",
    "lifetime 800": "買い切り800円",
}
for label, marker in required_submit.items():
    if marker not in submit:
        errors.append(f"submit contract missing {label}: {marker}")

for doc_name, text in texts.items():
    for marker in ("264問", "月額", "200円", "買い切り", "800円"):
        if marker not in text:
            errors.append(f"{doc_name} missing current marker: {marker}")

for doc_name in ("checklist", "status"):
    text = texts[doc_name]
    for marker in ("6799581662", "jp.allsunday1122.healthmanager1"):
        if marker not in text:
            errors.append(f"{doc_name} missing release identity: {marker}")

stale_active_patterns = [
    r"Status:\s*\*\*教材132問",
    r"残作業:\s*Apple Developer / App Store Connect / 署名付きIPA",
    r"買い切り980円相当",
    r"Non-Consumable\s*/\s*980円相当",
    r"購入後は全132問",
    r"説明候補:\s*全132問",
]
combined_docs = "\n".join(texts.values())
for pattern in stale_active_patterns:
    if re.search(pattern, combined_docs, flags=re.MULTILINE):
        errors.append(f"stale active release assertion remains: {pattern}")

# Raw web source may still carry the historic display fallback, but release
# preparation must deterministically replace it and assert that no 980-yen text
# or 132-question claim can survive into the bundled app.
prepare_markers = (
    "audit_hm1_release_contract.py",
    "hm1-testflight-readiness.json",
    "HM1 TestFlight blocked: readiness gate is not PASS",
    '${HM1_PRODUCT_ONLY:-0}',
    "HM1 product-only materialization; TestFlight readiness intentionally not consumed",
    "monthlyPrice:'¥200',lifetimePrice:'¥800'",
    "assert '980円' not in updated",
    "assert '全132問' not in updated",
    "assert len(questions)==264",
)
for marker in prepare_markers:
    if marker not in prepare:
        errors.append(f"release preparation safety marker missing: {marker}")

# Metadata and Visual Gate preparation must be executable before TestFlight
# readiness is true. Conversely, the normal release path must still fail closed.
# This prevents the circular dependency where screenshots/metadata cannot be
# generated until a gate that itself depends on those screenshots is already PASS.
metadata_markers = (
    "HM1_PRODUCT_ONLY: '1'",
    "bash ios/health-manager-1/prepare-ios.sh",
    "Upload metadata and review screenshots without submission",
    "Safety violation: metadata workflow must not select a build or submit for review",
)
for marker in metadata_markers:
    if marker not in metadata_workflow:
        errors.append(f"metadata-only workflow safety marker missing: {marker}")
if "submit_to_testflight: true" in metadata_workflow or "submit_to_app_store: true" in metadata_workflow:
    errors.append("metadata-only workflow must never publish a TestFlight/App Store build")

required_readiness = {
    "release_contract",
    "learning_acceptance",
    "storekit_regression",
    "visual_gate",
    "release_drift",
    "fresh_asc_release_readback",
}
actual_required = set(readiness.get("required") or [])
if actual_required != required_readiness:
    errors.append(f"TestFlight readiness requirements drifted: {sorted(actual_required)}")
if readiness.get("ready") not in (True, False):
    errors.append("TestFlight readiness must be an explicit boolean")

human_gate_markers = (
    "AI Preflight",
    "Visual Gate",
    "Submit for Review直前のユーザー最終承認",
    "TestFlightは開発QAに使用せず",
)
for marker in human_gate_markers:
    if marker not in combined_docs:
        errors.append(f"release safety marker missing: {marker}")

if errors:
    print("FAIL: HM1 release contract drift")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print(
    "PASS: HM1 release docs, submit automation, metadata-only Visual path, "
    "build preparation and TestFlight readiness agree on the current "
    "264-question / 200+800-yen contract"
)
