#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "data" / "source-registry.json"
REQUIRED_FIELDS = {
    "id", "title", "publisher", "url", "domains", "role",
    "currentness", "reuse", "directReproduction"
}


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


data = json.loads(REGISTRY.read_text(encoding="utf-8"))
sources = data.get("sources", [])
if len(sources) < 20:
    fail(f"expanded source registry unexpectedly small: {len(sources)}")

ids = [source.get("id") for source in sources]
if len(ids) != len(set(ids)):
    fail("source IDs must be unique")

for source in sources:
    missing = REQUIRED_FIELDS - set(source)
    if missing:
        fail(f"{source.get('id', '<unknown>')}: missing fields {sorted(missing)}")
    if not source["url"].startswith("https://"):
        fail(f"{source['id']}: source URL must be HTTPS")
    if not source["domains"]:
        fail(f"{source['id']}: at least one coverage domain is required")
    if not source["currentness"].strip():
        fail(f"{source['id']}: currentness note is required")
    if not source["reuse"].strip() or not source["directReproduction"].strip():
        fail(f"{source['id']}: reuse and direct-reproduction policy are required")

required_anchor_ids = {
    "MHLW-EXAM-R5-STANDARD",
    "MHLW-EXAM-109",
    "EGOV-MCH-ACT",
    "EGOV-PHN-MIDWIFE-NURSE-ACT",
    "EGOV-MEDICAL-CARE-ACT",
    "EGOV-MATERNAL-PROTECTION-ACT",
    "JSOG-OB-GUIDELINE-2026",
    "JSOG-GYN-GUIDELINE-2026",
    "JSSTI-GUIDELINE-2026",
    "NCPR-GUIDELINE-2025",
    "JAM-MIDWIFERY-GUIDELINE-2024",
    "MHLW-DIETARY-2025",
    "NCCHD-PREG-LACT-MEDS",
    "CFA-MATERNAL-CHILD-HEALTH",
    "CFA-POSTPARTUM-CARE-2026",
    "CFA-PRECON-5YEAR",
    "CFA-PRENATAL-INFO",
    "CFA-INFANT-CHECKUPS",
    "CFA-INFANT-GROWTH-2023",
    "MHLW-PERINATAL-SYSTEM",
    "MHLW-MIDWIFE-POLICY",
    "JMA-MIDWIFE-OPERATIONS-2024",
    "JPS-NEONATAL",
    "JPS-VACCINE-INFECTION-2026",
}
actual = set(ids)
if not required_anchor_ids <= actual:
    fail(f"missing canonical anchors: {sorted(required_anchor_ids - actual)}")

restricted = {
    source["id"] for source in sources
    if "permission" in source["reuse"].lower()
    or "prohibit" in source["reuse"].lower()
    or "copyright" in source["reuse"].lower()
    or "転載" in source["reuse"]
    or source["directReproduction"].lower().startswith("no")
}
required_restricted = {
    "JSOG-OB-GUIDELINE-2026",
    "JSOG-GYN-GUIDELINE-2026",
    "JSSTI-GUIDELINE-2026",
    "NCPR-GUIDELINE-2025",
    "JAM-MIDWIFERY-GUIDELINE-2024",
    "JMA-MIDWIFE-OPERATIONS-2024",
    "NCCHD-PREG-LACT-MEDS",
}
if not required_restricted <= restricted:
    fail(f"restricted-source guard missing: {sorted(required_restricted - restricted)}")

if data.get("checkedAt") != "2026-08-13":
    fail("source registry must record the current evidence audit date 2026-08-13")

print("PASS: #14 source registry")
print(f"  sources: {len(sources)}")
print(f"  restricted/direct-reproduction guarded: {len(restricted)}")
print("  current legal/clinical/public-health anchor set present")
