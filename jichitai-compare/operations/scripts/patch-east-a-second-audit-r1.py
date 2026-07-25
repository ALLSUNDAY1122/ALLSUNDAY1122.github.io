from __future__ import annotations

import json
from pathlib import Path

# Temporary idempotent patcher for the first round of the second quality audit.
ROOT = Path(__file__).resolve().parents[2]
CHECKPOINT = ROOT / "operations/control/session-checkpoints/east-a.json"
AUDIT = ROOT / "operations/audits/east-a-quality-improvement-second-audit-20260725.json"
MINATO = ROOT / "data/municipalities/13/13103.json"
MINATO_TASK = ROOT / "operations/tasks/13103.json"

checked_at = "2026-07-25T10:47:00+09:00"

municipality = json.loads(MINATO.read_text(encoding="utf-8"))
service = municipality["services"]["sickChildCare"]
service["details"]["fee"] = (
    "港区民は1人1日2,000円、港区外在住者は1人1日3,000円。"
    "生活保護受給世帯等は免除対象で、幼児教育・保育無償化の施設等利用費給付対象となる場合がある"
)
service["source"]["checkedAt"] = "2026-07-25"
municipality["updatedAt"] = "2026-07-25"
MINATO.write_text(json.dumps(municipality, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

task = json.loads(MINATO_TASK.read_text(encoding="utf-8"))
task["lastCheckedAt"] = "2026-07-25"
task["lastUpdatedAt"] = checked_at
task["lastUpdatedBy"] = "東日本調査班A（品質改善第2監査）"
note = (
    "品質改善第2監査で病児・病後児保育の料金を公式ページと再照合し、"
    "曖昧記載から港区民1日2,000円・区外1日3,000円へ具体化。"
)
if note not in task.setdefault("notes", []):
    task["notes"].append(note)
MINATO_TASK.write_text(json.dumps(task, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

checkpoint = json.loads(CHECKPOINT.read_text(encoding="utf-8"))
checkpoint["updatedAt"] = checked_at
checkpoint["blocked"] = [
    {
        "code": "20602",
        "name": "栄村",
        "reason": (
            "2026-07-25T10:38:00+09:00再確認でも公式サイトのトップページと既知の制度ページは"
            "502で取得不能。PR #3169・CI #7747で9制度すべてをunavailableとして安全公開済み。"
            "公式サイト復旧時のみ9制度を再調査し、それまでは推測せずIssue #2847を維持する。"
        ),
    }
]
checkpoint["postCompletionResolution"] = {
    "trackingIssueNumber": 3166,
    "trackingIssueStatus": "closed",
    "pullRequestNumber": 3169,
    "ciRunNumber": 7747,
    "resolvedMunicipalityCount": 20,
    "resolvedServiceCount": 30,
    "verifiedServiceCount": 23,
    "unavailableServiceCount": 7,
    "needsMediumReviewServicesAfter": 0,
    "sakaeServiceStatusAfter": {
        "verified": 0,
        "unavailable": 9,
        "needs_medium_review": 0,
    },
    "publicationVerificationRunId": 30129853395,
    "status": "success",
}
checkpoint["qualityImprovementSecondAudit"] = {
    "status": "in_progress",
    "startedAt": "2026-07-25T10:38:00+09:00",
    "completedRounds": 1,
    "targetRounds": 4,
    "currentRound": "tokyo_sample_and_state_consistency",
    "sampledMunicipalities": ["13101", "13102", "13103", "13104", "13105"],
    "confirmedDataErrors": 1,
    "confirmedStateRecordErrors": 1,
    "sakaeOfficialSiteStatus": "http_502",
    "nextAction": "群馬県の訂正対象外5自治体以上を重点監査する。",
}
if isinstance(checkpoint.get("verificationCampaign"), dict):
    checkpoint["verificationCampaign"]["nextAction"] = (
        "品質改善第2監査を継続する。栄村は9制度unavailable・Issue #2847維持。"
        "次は群馬県の訂正対象外5自治体以上を重点監査する。"
    )
CHECKPOINT.write_text(json.dumps(checkpoint, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

audit = {
    "schemaVersion": "1.0.0",
    "auditId": "east-a-quality-improvement-second-audit-20260725",
    "sessionId": "east-a",
    "status": "in_progress",
    "startedAt": "2026-07-25T10:38:00+09:00",
    "restoredBaseline": {
        "verificationCampaignRounds": 10,
        "auditedMunicipalities": 201,
        "nationwidePullRequestNumber": 3130,
        "finalCiRunNumber": 7654,
        "verifiedPageCount": 49,
        "naganoResolutionPullRequestNumber": 3169,
        "naganoResolutionCiRunNumber": 7747,
        "naganoResolvedMunicipalities": 20,
        "naganoResolvedServices": 30,
        "naganoVerifiedServices": 23,
        "naganoUnavailableServices": 7,
        "needsMediumReviewServicesAfter": 0,
        "fullNorthEastPublicationAuditPullRequestNumber": 3175,
        "fullNorthEastPublicationAuditRunId": 30134336210,
    },
    "confirmedCorrections": [
        {
            "type": "checkpoint_state_mismatch",
            "path": "jichitai-compare/operations/control/session-checkpoints/east-a.json",
            "before": "栄村7制度needs_medium_review・2制度unavailable",
            "after": "栄村9制度unavailable・needs_medium_review 0",
            "basis": "PR #3169・CI #7747・公開確認run 30129853395",
        },
        {
            "type": "fee_detail_omission",
            "municipalityCode": "13103",
            "municipalityName": "港区",
            "service": "sickChildCare",
            "before": "施設利用料が必要とのみ記載",
            "after": "港区民1日2,000円・港区外在住者1日3,000円、免除・無償化対象を明記",
            "officialSource": "https://www.city.minato.tokyo.jp/kodomo/kodomo/kodomo/hoikuen/service/byoji7.html",
        },
    ],
    "sakae": {
        "code": "20602",
        "officialTopPage": "https://www.vill.sakae.nagano.jp/",
        "knownOfficialServicePage": "https://www.vill.sakae.nagano.jp/docs/2263.html",
        "checkedAt": "2026-07-25T10:38:00+09:00",
        "result": "both_http_502",
        "action": "9制度を再調査せず、全件unavailableとIssue #2847を維持",
    },
    "rounds": [
        {
            "round": 1,
            "scope": "東京都・訂正対象外5区の重点抜き取り",
            "municipalities": [
                {"code": "13101", "name": "千代田区"},
                {"code": "13102", "name": "中央区"},
                {"code": "13103", "name": "港区"},
                {"code": "13104", "name": "新宿区"},
                {"code": "13105", "name": "文京区"},
            ],
            "focus": [
                "年齢上限",
                "料金",
                "利用期間・回数",
                "住宅支援の分類",
                "一時預かりと乳児等通園支援事業の区別",
            ],
            "officialSourceResult": "passed_after_correction",
            "sourceJsonResult": "corrected",
            "publicEvidence": {
                "targetedSmokePullRequestNumber": 3173,
                "targetedSmokeRunId": 30129853395,
                "fullAuditPullRequestNumber": 3175,
                "fullAuditRunId": 30134336210,
            },
            "confirmedErrors": 1,
            "notes": [
                "千代田区の令和8年7月住宅助成増額、年齢上限、最長8年を再確認",
                "中央区の病児保育年齢・日額、家賃債務保証助成、一時預かり年齢・時間額を再確認",
                "港区の病児・病後児保育料金を港区民1日2,000円・区外1日3,000円へ具体化",
                "港区の住宅取得補助、産後ケア回数・負担上限を再確認",
                "新宿区の病児預かり年齢・時間額、転居助成、乳児等通園支援の期間・頻度・無償を再確認",
                "文京区の病児保育年齢・日額・連続日数、ひとり親転居助成、産後ケア日数、乳児等通園支援を再確認",
            ],
        }
    ],
    "nextAction": "群馬県の訂正対象外5自治体以上を重点監査する。",
}
AUDIT.parent.mkdir(parents=True, exist_ok=True)
AUDIT.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
