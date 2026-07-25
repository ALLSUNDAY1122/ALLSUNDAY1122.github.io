from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKPOINT = ROOT / "operations/control/session-checkpoints/east-a.json"
AUDIT = ROOT / "operations/audits/east-a-quality-improvement-second-audit-20260725.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


checkpoint = load(CHECKPOINT)
checkpoint["updatedAt"] = "2026-07-25T11:04:00+09:00"
checkpoint["pullRequestNumber"] = 3210
checkpoint["ciStatus"] = "success"
entries = checkpoint.setdefault("completedSinceSplit", [])
new_entries = [
    {
        "code": "13103",
        "name": "港区（品質改善第2監査・病児保育料金訂正）",
        "pullRequestNumber": 3210,
        "ciRunNumber": 7824,
    },
    {
        "code": "10201",
        "name": "前橋市（品質改善第2監査・産後ケア料金訂正）",
        "pullRequestNumber": 3210,
        "ciRunNumber": 7824,
    },
]
for entry in new_entries:
    if not any(
        item.get("code") == entry["code"]
        and item.get("pullRequestNumber") == entry["pullRequestNumber"]
        and item.get("name") == entry["name"]
        for item in entries
    ):
        entries.append(entry)
second = checkpoint.setdefault("qualityImprovementSecondAudit", {})
second.update({
    "regionalPullRequestNumber": 3210,
    "regionalCiRunNumber": 7824,
    "regionalCiRunId": 30139529573,
    "regionalMergeSha": "665c9721d28c5cd0417252a2fdeffe9885417024",
    "regionalIntegrationStatus": "success",
})
save(CHECKPOINT, checkpoint)

audit = load(AUDIT)
audit["regionalIntegration"] = {
    "pullRequestNumber": 3210,
    "ciRunNumber": 7824,
    "ciRunId": 30139529573,
    "ciStatus": "success",
    "mergeSha": "665c9721d28c5cd0417252a2fdeffe9885417024",
    "mergedTo": "region/east",
    "mergedAt": "2026-07-25T11:01:00+09:00",
}
audit["updatedAt"] = "2026-07-25T11:04:00+09:00"
save(AUDIT, audit)
