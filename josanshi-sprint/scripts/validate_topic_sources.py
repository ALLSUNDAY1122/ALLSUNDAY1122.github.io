#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT = ROOT / "data" / "question-blueprint.json"
REGISTRY = ROOT / "data" / "source-registry.json"
TOPIC_MAP = ROOT / "data" / "topic-source-map.json"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


blueprint = json.loads(BLUEPRINT.read_text(encoding="utf-8"))
registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
topic_map = json.loads(TOPIC_MAP.read_text(encoding="utf-8"))

blueprint_topics = {t["topicId"]: t for t in blueprint["topics"]}
source_by_id = {s["id"]: s for s in registry["sources"]}
mapped = {t["topicId"]: t for t in topic_map["topics"]}

if len(blueprint_topics) != 66:
    fail(f"expected 66 blueprint topics, found {len(blueprint_topics)}")
if len(mapped) != len(topic_map["topics"]):
    fail("duplicate topicId in topic-source map")
if set(mapped) != set(blueprint_topics):
    missing = sorted(set(blueprint_topics) - set(mapped))
    extra = sorted(set(mapped) - set(blueprint_topics))
    fail(f"topic-source coverage mismatch; missing={missing}, extra={extra}")

allowed_risks = {"medium", "high", "critical"}
for topic_id, item in mapped.items():
    source_ids = item.get("sourceIds", [])
    if not source_ids:
        fail(f"{topic_id}: no evidence source")
    unknown = [sid for sid in source_ids if sid not in source_by_id]
    if unknown:
        fail(f"{topic_id}: unknown source IDs {unknown}")
    if item.get("risk") not in allowed_risks:
        fail(f"{topic_id}: invalid risk {item.get('risk')}")
    if not item.get("caseCluster"):
        fail(f"{topic_id}: caseCluster is required")
    if not isinstance(item.get("situationEligible"), bool):
        fail(f"{topic_id}: situationEligible must be boolean")

    # At least one primary anchor must explicitly cover the blueprint subject.
    # Additional supporting anchors may legitimately cross subject boundaries
    # (e.g. NCPR supporting BASIC newborn physiology).
    expected_subject = blueprint_topics[topic_id]["subject"]
    covered = False
    for sid in source_ids:
        domains = source_by_id[sid].get("domains", [])
        if "all" in domains or expected_subject in domains:
            covered = True
            break
    if not covered:
        fail(f"{topic_id}: no mapped source explicitly covers subject {expected_subject}")

# Safety-critical anchors that must not silently regress.
required_specific = {
    "BASIC-09": {"JSSTI-GUIDELINE-2026"},
    "BASIC-11": {"CFA-PRENATAL-INFO"},
    "BASIC-14": {"MHLW-DIETARY-2025"},
    "BASIC-20": {"NCCHD-PREG-LACT-MEDS"},
    "DIAGNOSIS-08": {"JSOG-OB-GUIDELINE-2026"},
    "DIAGNOSIS-16": {"MHLW-PERINATAL-SYSTEM"},
    "DIAGNOSIS-26": {"NCPR-GUIDELINE-2025"},
    "DIAGNOSIS-28": {"NCPR-GUIDELINE-2025"},
    "COMMUNITY-03": {"EGOV-MCH-ACT"},
    "MANAGEMENT-02": {"EGOV-PHN-MIDWIFE-NURSE-ACT", "EGOV-MEDICAL-CARE-ACT"},
    "MANAGEMENT-03": {"EGOV-MEDICAL-CARE-ACT"},
}
for topic_id, required in required_specific.items():
    actual = set(mapped[topic_id]["sourceIds"])
    if not required <= actual:
        fail(f"{topic_id}: missing safety-critical anchors {sorted(required - actual)}")

# Situation-setting cases are reserved for clinical diagnosis/support topics.
eligible = [tid for tid, item in mapped.items() if item["situationEligible"]]
if any(not tid.startswith("DIAGNOSIS-") for tid in eligible):
    fail("situationEligible may only be set on DIAGNOSIS topics in v1 mapping")
if len(eligible) < 20:
    fail(f"insufficient situation-setting topic pool: {len(eligible)}")

acceptable_roles = {
    "current_clinical_guideline",
    "current_neonatal_resuscitation_guideline",
    "midwifery_care_guideline",
    "midwifery_policy",
    "midwifery_operations_guideline",
    "current_nutrition_reference",
    "current_medication_reference",
    "current_public_health_hub",
    "current_postpartum_policy_guidance",
    "current_preconception_policy",
    "current_prenatal_testing_information",
    "current_infant_checkup_policy",
    "official_infant_growth_statistics",
    "current_perinatal_system_policy",
    "neonatal_professional_reference_hub",
    "current_pediatric_infection_vaccine_reference",
    "current_law",
    "supporting_guidance",
}
for topic_id, item in mapped.items():
    if item["risk"] in {"high", "critical"}:
        roles = {source_by_id[sid]["role"] for sid in item["sourceIds"]}
        if not roles & acceptable_roles:
            fail(f"{topic_id}: high-risk topic lacks an authoritative currentness anchor")

print("PASS: #14 topic-source coverage")
print(f"  blueprint topics: {len(blueprint_topics)}")
print(f"  mapped topics: {len(mapped)}")
print(f"  evidence sources available: {len(source_by_id)}")
print(f"  situation-setting eligible topics: {len(eligible)}")
print("  safety-critical topic anchors: PASS")
