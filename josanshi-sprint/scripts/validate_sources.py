#!/usr/bin/env python3
from source_registry_loader import load_sources

REQUIRED_FIELDS = {
    "id", "title", "publisher", "url", "domains", "role",
    "currentness", "reuse", "directReproduction"
}


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


try:
    sources, paths = load_sources()
except RuntimeError as error:
    fail(str(error))

if len(sources) < 30:
    fail(f"expanded source registry unexpectedly small: {len(sources)}")

ids = [source.get("id") for source in sources]
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
    "MHLW-VITAL-STATISTICS",
    "MHLW-VITAL-RATES",
    "MHLW-TFR-DEFINITION",
    "MHLW-OPEN-SEMI-OPEN",
    "MHLW-MATERNAL-SUPPORT-2026",
    "MHLW-BIRTH-ALLOWANCE",
    "MHLW-HEALTH-JAPAN21-3",
    "CFA-KODOMO-KATEI-CENTER",
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

print("PASS: #14 modular source registry")
print(f"  files: {[path.name for path in paths]}")
print(f"  sources: {len(sources)}")
print(f"  restricted/direct-reproduction guarded: {len(restricted)}")
print("  legal/clinical/public-health/statistical anchor set present")
