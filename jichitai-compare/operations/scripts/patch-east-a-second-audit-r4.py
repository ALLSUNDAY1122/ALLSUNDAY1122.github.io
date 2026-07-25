from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UPDATED_AT = "2026-07-25T12:16:00+09:00"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# 監査台帳を地域統合完了へ更新。
audit_path = ROOT / "operations" / "audits" / "east-a-quality-improvement-second-audit-20260725.json"
audit = read_json(audit_path)
latest = {
    "pullRequestNumber": 3276,
    "ciRunNumber": 8013,
    "ciRunId": 30141845500,
    "ciStatus": "success",
    "mergeSha": "844a011a5ef7107e069c251117e88d537df2bb63",
    "mergedTo": "region/east",
    "mergedAt": "2026-07-25T12:14:00+09:00"
}
history = audit.setdefault("regionalIntegrationHistory", [])
previous = audit.get("regionalIntegration")
if isinstance(previous, dict) and previous.get("pullRequestNumber"):
    if not any(item.get("pullRequestNumber") == previous.get("pullRequestNumber") for item in history):
        history.append(deepcopy(previous))
if not any(item.get("pullRequestNumber") == 3276 for item in history):
    history.append(deepcopy(latest))
audit["regionalIntegration"] = latest
audit["status"] = "completed_region_integrated"
audit["completedAt"] = UPDATED_AT
audit["nextAction"] = "全国統合・公開処理セッションでregion/eastの第2監査訂正をmainと公開ページへ同期し、公開表示を確認する。栄村Issue #2847は公式サイト復旧まで維持。"
audit["updatedAt"] = UPDATED_AT
write_json(audit_path, audit)

# checkpointを第2監査完了状態へ更新。
checkpoint_path = ROOT / "operations" / "control" / "session-checkpoints" / "east-a.json"
checkpoint = read_json(checkpoint_path)
checkpoint["updatedAt"] = UPDATED_AT
checkpoint["pullRequestNumber"] = 3276
checkpoint["ciStatus"] = "success"
q2 = checkpoint.setdefault("qualityImprovementSecondAudit", {})
q2.update({
    "status": "completed_region_integrated",
    "completedRounds": 4,
    "targetRounds": 4,
    "currentRound": "completed",
    "confirmedDataErrors": 12,
    "confirmedStateRecordErrors": 1,
    "sakaeOfficialSiteStatus": "http_502",
    "regionalPullRequestNumber": 3276,
    "regionalCiRunNumber": 8013,
    "regionalCiRunId": 30141845500,
    "regionalMergeSha": "844a011a5ef7107e069c251117e88d537df2bb63",
    "regionalIntegrationStatus": "success",
    "completedAt": UPDATED_AT,
    "nextAction": "全国統合・公開処理セッションでmain・公開ページへ同期確認する。栄村は9制度unavailable・Issue #2847維持。"
})
if isinstance(checkpoint.get("verificationCampaign"), dict):
    checkpoint["verificationCampaign"]["nextAction"] = "品質改善第2監査は4回完了しregion/east統合済み。全国統合・公開処理でmain・公開ページへ同期確認する。栄村Issue #2847は維持。"
write_json(checkpoint_path, checkpoint)
