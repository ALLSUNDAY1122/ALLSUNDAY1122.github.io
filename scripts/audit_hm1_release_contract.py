#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CHECKLIST = ROOT / "ios/health-manager-1/RELEASE_CHECKLIST.md"
STATUS = ROOT / "ios/health-manager-1/RELEASE_STATUS.md"
SUBMIT = ROOT / "scripts/app2_005_hm1_prepare_submit.py"

checklist = CHECKLIST.read_text(encoding="utf-8")
status = STATUS.read_text(encoding="utf-8")
submit = SUBMIT.read_text(encoding="utf-8")
errors = []

required_contract = {
    "app id": 'APP_ID = "6799581662"',
    "bundle id": 'BUNDLE_ID = "jp.allsunday1122.healthmanager1"',
    "monthly id": 'MONTHLY_ID = "6804373671"',
    "lifetime id": 'LIFETIME_ID = "6799583540"',
    "264 questions": "独自に作成・監査した264問",
    "monthly 200": "月額200円",
    "lifetime 800": "買い切り800円",
}
for label, marker in required_contract.items():
    if marker not in submit:
        errors.append(f"submit contract missing {label}: {marker}")

for doc_name, text in (("checklist", checklist), ("status", status)):
    for marker in ("6799581662", "jp.allsunday1122.healthmanager1", "264問", "月額", "200円", "買い切り", "800円"):
        if marker not in text:
            errors.append(f"{doc_name} missing current marker: {marker}")

stale_active_patterns = [
    r"Status:\s*\*\*教材132問",
    r"残作業:\s*Apple Developer / App Store Connect / 署名付きIPA",
    r"買い切り980円相当",
    r"App Store ConnectにApp作成\s*$",
]
combined = checklist + "\n" + status
for pattern in stale_active_patterns:
    if re.search(pattern, combined, flags=re.MULTILINE):
        errors.append(f"stale active release assertion remains: {pattern}")

human_gate_markers = (
    "AI Preflight",
    "Visual Gate",
    "Submit for Review直前のユーザー最終承認",
    "TestFlightは開発QAに使用せず",
)
for marker in human_gate_markers:
    if marker not in combined:
        errors.append(f"release safety marker missing: {marker}")

if errors:
    print("FAIL: HM1 release contract drift")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PASS: HM1 release docs and submit automation agree on current 264-question / 200+800-yen contract")
