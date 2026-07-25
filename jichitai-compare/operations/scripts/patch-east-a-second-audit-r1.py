from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKPOINT = ROOT / "operations/control/session-checkpoints/east-a.json"
AUDIT = ROOT / "operations/audits/east-a-quality-improvement-second-audit-20260725.json"
CHECKED_AT = "2026-07-25T10:55:00+09:00"


def load(relative: str) -> tuple[Path, dict]:
    path = ROOT / relative
    return path, json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def update_task(code: str, note: str) -> None:
    path, task = load(f"operations/tasks/{code}.json")
    task["lastCheckedAt"] = "2026-07-25"
    task["lastUpdatedAt"] = CHECKED_AT
    task["lastUpdatedBy"] = "東日本調査班A（品質改善第2監査）"
    if note not in task.setdefault("notes", []):
        task["notes"].append(note)
    save(path, task)


# 港区：病児・病後児保育の区内外料金を具体化。
path, minato = load("data/municipalities/13/13103.json")
svc = minato["services"]["sickChildCare"]
svc["details"]["fee"] = (
    "港区民は1人1日2,000円、港区外在住者は1人1日3,000円。"
    "生活保護受給世帯等は免除対象で、幼児教育・保育無償化の施設等利用費給付対象となる場合がある"
)
svc["source"]["checkedAt"] = "2026-07-25"
minato["updatedAt"] = "2026-07-25"
save(path, minato)
update_task(
    "13103",
    "品質改善第2監査で病児・病後児保育の料金を公式ページと再照合し、曖昧記載から港区民1日2,000円・区外1日3,000円へ具体化。",
)

# 前橋市：産後ケア3類型の料金を公式表どおり具体化。
path, maebashi = load("data/municipalities/10/10201.json")
svc = maebashi["services"]["postpartumCare"]
svc["details"]["types"] = "ショートステイ型、デイサービス型、アウトリーチ型"
svc["details"]["fee"] = (
    "ショートステイ型は1泊2日5,000円（以降1日ごと2,500円加算）、"
    "デイサービス型は1日1,600円、アウトリーチ型は無料。"
    "市民税非課税世帯・生活保護世帯は無料"
)
svc["details"]["limit"] = "3類型を合わせて7日間"
svc["source"]["checkedAt"] = "2026-07-25"
maebashi["updatedAt"] = "2026-07-25"
save(path, maebashi)
update_task(
    "10201",
    "品質改善第2監査で産後ケア料金を公式表と再照合し、宿泊1泊2日5,000円・通所1,600円・訪問無料、合計7日を具体化。",
)

checkpoint = json.loads(CHECKPOINT.read_text(encoding="utf-8"))
checkpoint["updatedAt"] = CHECKED_AT
checkpoint["blocked"] = [{
    "code": "20602",
    "name": "栄村",
    "reason": (
        "2026-07-25T10:38:00+09:00再確認でも公式サイトのトップページと既知の制度ページは502で取得不能。"
        "PR #3169・CI #7747で9制度すべてをunavailableとして安全公開済み。"
        "公式サイト復旧時のみ9制度を再調査し、それまでは推測せずIssue #2847を維持する。"
    ),
}]
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
    "sakaeServiceStatusAfter": {"verified": 0, "unavailable": 9, "needs_medium_review": 0},
    "publicationVerificationRunId": 30129853395,
    "status": "success",
}
checkpoint["qualityImprovementSecondAudit"] = {
    "status": "in_progress",
    "startedAt": "2026-07-25T10:38:00+09:00",
    "completedRounds": 2,
    "targetRounds": 4,
    "currentRound": "gunma_sample_completed",
    "sampledMunicipalities": [
        "13101", "13102", "13103", "13104", "13105",
        "10201", "10202", "10203", "10204", "10205",
    ],
    "confirmedDataErrors": 2,
    "confirmedStateRecordErrors": 1,
    "sakaeOfficialSiteStatus": "http_502",
    "nextAction": "山梨県の訂正対象外5自治体以上を重点監査する。",
}
if isinstance(checkpoint.get("verificationCampaign"), dict):
    checkpoint["verificationCampaign"]["nextAction"] = (
        "品質改善第2監査を継続する。栄村は9制度unavailable・Issue #2847維持。"
        "次は山梨県の訂正対象外5自治体以上を重点監査する。"
    )
save(CHECKPOINT, checkpoint)

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
        {
            "type": "fee_detail_omission",
            "municipalityCode": "10201",
            "municipalityName": "前橋市",
            "service": "postpartumCare",
            "before": "通所型1日1,600円の例示のみ",
            "after": "宿泊1泊2日5,000円・通所1日1,600円・訪問無料、3類型合計7日を明記",
            "officialSource": "https://www.city.maebashi.gunma.jp/kosodate_kyoiku/4/5/1/19801.html",
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
            "focus": ["年齢上限", "料金", "利用期間・回数", "住宅支援の分類", "一時預かりと乳児等通園支援事業の区別"],
            "result": "passed_after_correction",
            "confirmedErrors": 1,
            "correction": "港区の病児・病後児保育料金を区民1日2,000円・区外1日3,000円へ具体化",
        },
        {
            "round": 2,
            "scope": "群馬県・訂正対象外5市の重点抜き取り",
            "municipalities": [
                {"code": "10201", "name": "前橋市"},
                {"code": "10202", "name": "高崎市"},
                {"code": "10203", "name": "桐生市"},
                {"code": "10204", "name": "伊勢崎市"},
                {"code": "10205", "name": "太田市"},
            ],
            "focus": ["年齢上限", "料金", "利用期間・回数", "広域・市外利用", "住宅支援の分類"],
            "result": "passed_after_correction",
            "confirmedErrors": 1,
            "correction": "前橋市の産後ケア3類型の料金と合計利用日数を具体化",
            "notes": [
                "高崎市は施設別対象年齢・料金のため、市公式一覧と施設案内の組合せを確認",
                "桐生市・伊勢崎市・太田市は重点項目の現行公式情報と一致",
            ],
        },
    ],
    "publicEvidence": {
        "targetedSmokePullRequestNumber": 3173,
        "targetedSmokeRunId": 30129853395,
        "fullAuditPullRequestNumber": 3175,
        "fullAuditRunId": 30134336210,
    },
    "nextAction": "山梨県の訂正対象外5自治体以上を重点監査する。",
}
save(AUDIT, audit)
