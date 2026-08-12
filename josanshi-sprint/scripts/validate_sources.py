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
if not sources:
    fail("source registry is empty")

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
    "NCPR-GUIDELINE-2025",
}
actual = set(ids)
if not required_anchor_ids <= actual:
    fail(f"missing canonical anchors: {sorted(required_anchor_ids - actual)}")

restricted = {
    source["id"] for source in sources
    if "permission" in source["reuse"].lower()
    or "転載" in source["reuse"]
    or source["directReproduction"].lower().startswith("no")
}
if "JSOG-OB-GUIDELINE-2026" not in restricted:
    fail("JSOG 2026 guideline must be explicitly marked restricted for direct reproduction")
if "NCPR-GUIDELINE-2025" not in restricted:
    fail("NCPR 2025 algorithm must be explicitly marked restricted for direct reproduction")

print("PASS: #14 source registry")
print(f"  sources: {len(sources)}")
print(f"  restricted/direct-reproduction guarded: {len(restricted)}")
print("  current legal/clinical anchor set present")
