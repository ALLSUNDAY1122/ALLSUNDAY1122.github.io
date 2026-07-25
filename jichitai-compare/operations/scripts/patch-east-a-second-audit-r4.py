from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKED_DATE = "2026-07-25"
CHECKED_AT = "2026-07-25T12:14:00+09:00"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def municipality_path(code: str) -> Path:
    return ROOT / "data" / "municipalities" / code[:2] / f"{code}.json"


def task_path(code: str) -> Path:
    return ROOT / "operations" / "tasks" / f"{code}.json"


def update_task(code: str, note: str) -> None:
    path = task_path(code)
    task = read_json(path)
    task["lastCheckedAt"] = CHECKED_DATE
    task["lastUpdatedAt"] = CHECKED_AT
    task["lastUpdatedBy"] = "東日本調査班A"
    notes = task.setdefault("notes", [])
    if note not in notes:
        notes.append(note)
    write_json(path, task)


# 20201 長野市: 市内4施設の連続利用期間と施設別料金を具体化。
path = municipality_path("20201")
data = read_json(path)
data["updatedAt"] = CHECKED_DATE
service = data["services"]["sickChildCare"]
service["summary"] = "長野地域連携中枢都市圏内で相互利用でき、市内4施設は1回につき連続7日まで"
service["details"]["fee"] = "長野赤十字病院ゆりかごは1日2,200円（昼食込）、長野松代総合病院バオバブは2,000円、篠ノ井総合病院あいあいは2,000円（昼食込）、長野市民病院たんぽぽは2,000円（昼食・おやつ込）"
service["details"]["limit"] = "長野市内4施設はいずれも1回の利用につき連続7日まで（休日を含む）"
service["source"]["checkedAt"] = CHECKED_DATE
write_json(path, data)
update_task("20201", "品質改善第2監査第4回で、病児・病後児保育の市内4施設別料金と連続7日以内の利用上限を公式ページへ同期。年齢上限・広域相互利用・住宅支援分類は不一致なし。")

# 20202 松本市: 連続5日上限と市外在住・市内在勤者料金を追記。
path = municipality_path("20202")
data = read_json(path)
data["updatedAt"] = CHECKED_DATE
service = data["services"]["sickChildCare"]
service["summary"] = "生後5か月から小学3年生までを4施設で預かり、1疾病につき連続5日以内"
service["details"]["fee"] = "松本市在住で保育施設在園児は認定時間内無料。市内在住の未就園児・小学生は4時間以内650円、8時間以内1,300円、延長30分100円。市外在住かつ市内在勤は4時間以内1,300円、8時間以内2,600円、延長30分200円"
service["details"]["limit"] = "1回の疾病につき4施設を合わせて連続5日以内"
service["details"]["wideArea"] = "松本市・塩尻市・山形村・朝日村・木祖村在住、または保護者が松本市内勤務する児童が対象"
service["source"]["checkedAt"] = CHECKED_DATE
write_json(path, data)
update_task("20202", "品質改善第2監査第4回で、病児保育の1疾病あたり連続5日上限と、市外在住・市内在勤者の4時間1,300円／8時間2,600円料金を追記。住宅支援の一般制度分類・上限30万円は不一致なし。")

# 20203 上田市: 病児保育料金を1日1,000円へ具体化。
path = municipality_path("20203")
data = read_json(path)
data["updatedAt"] = CHECKED_DATE
service = data["services"]["sickChildCare"]
service["summary"] = "生後6か月または1歳から小学3年生までを市内2施設で1日1,000円で預かる"
service["details"]["fee"] = "1人1日1,000円。医師の診療費は別途。午後5時までに迎えがない場合は延長料金が発生"
service["details"]["hours"] = "月曜日から金曜日の午前8時から午後5時まで（延長は午後6時まで）"
service["details"]["capacity"] = "各センター1日6人"
service["source"]["checkedAt"] = CHECKED_DATE
write_json(path, data)
update_task("20203", "品質改善第2監査第4回で、病児保育の利用料を1日1,000円、各施設定員6人、延長18時までと具体化。対象年齢・広域対象・空き家改修補助の上限20万円／移住者50万円は不一致なし。")

# 20204 岡谷市: 住宅改修補助が現在受付一時中止であることを明記。
path = municipality_path("20204")
data = read_json(path)
data["updatedAt"] = CHECKED_DATE
service = data["services"]["housingSupport"]
service["summary"] = "空き家バンク購入住宅の改修費を2分の1、最大80万円補助（現在は受付一時中止）"
service["details"]["applicationStatus"] = "2026年4月1日更新の公式ページでは、申請多数のため受付を一時中止"
service["details"]["deadline"] = "空き家購入日から6か月以内かつ工事契約・着手前に申請。受付再開状況を都市計画課へ確認"
service["source"]["checkedAt"] = CHECKED_DATE
write_json(path, data)
update_task("20204", "品質改善第2監査第4回で、空き家バンク住宅改修補助が申請多数により現在受付一時中止であることを明記。補助率2分の1・上限80万円、病児保育の広域年齢・料金・連続7日上限は不一致なし。")

# 20205 飯田市: 世帯区分別料金、給食実費、連続利用期間を具体化。
path = municipality_path("20205")
data = read_json(path)
data["updatedAt"] = CHECKED_DATE
service = data["services"]["sickChildCare"]
service["summary"] = "生後6か月から小学6年生までを下伊那広域で受け入れ、一般世帯は5時間以内1,000円・5時間超2,000円"
service["details"]["fee"] = "生活保護世帯と市民税非課税のひとり親・障がい世帯は無料。市民税非課税世帯は5時間以内500円・5時間超1,000円。その他世帯は5時間以内1,000円・5時間超2,000円。給食希望時は実費400円"
service["details"]["limit"] = "原則として連続7日以内（休業日を除く）"
service["details"]["hours"] = "月曜日から金曜日の午前8時から午後6時まで。延長保育なし"
service["details"]["capacity"] = "1日6人"
service["source"]["checkedAt"] = CHECKED_DATE
write_json(path, data)
update_task("20205", "品質改善第2監査第4回で、病児保育の世帯区分別料金、給食実費400円、連続7日上限、定員6人を公式ページへ同期。対象年齢・下伊那広域利用・住宅改修補助上限30万円／指定地区50万円は不一致なし。")

# 監査記録を第4回完了状態へ更新。
audit_path = ROOT / "operations" / "audits" / "east-a-quality-improvement-second-audit-20260725.json"
audit = read_json(audit_path)
corrections = audit.setdefault("confirmedCorrections", [])
new_corrections = [
    {
        "type": "usage_period_and_fee_detail_omission",
        "municipalityCode": "20201",
        "municipalityName": "長野市",
        "service": "sickChildCare",
        "before": "市内施設の料金を2,000～2,200円等とのみ記載し、連続利用上限を未記録",
        "after": "市内4施設別料金と1回連続7日上限を明記",
        "officialSource": "https://www.city.nagano.nagano.jp/n117000/kosodate/p001489.html"
    },
    {
        "type": "wide_area_fee_and_period_omission",
        "municipalityCode": "20202",
        "municipalityName": "松本市",
        "service": "sickChildCare",
        "before": "市内在住者料金のみで、市外在住・市内在勤料金と連続利用上限を未記録",
        "after": "市外在住・市内在勤の4時間1,300円・8時間2,600円と連続5日上限を明記",
        "officialSource": "https://www.city.matsumoto.nagano.jp/site/kosodate/198321.html"
    },
    {
        "type": "fee_detail_omission",
        "municipalityCode": "20203",
        "municipalityName": "上田市",
        "service": "sickChildCare",
        "before": "施設ごとの利用料を支払うとのみ記載",
        "after": "1人1日1,000円、延長料金・定員・利用時間を明記",
        "officialSource": "https://www.city.ueda.nagano.jp/soshiki/kosodate-k/2730.html"
    },
    {
        "type": "application_status_omission",
        "municipalityCode": "20204",
        "municipalityName": "岡谷市",
        "service": "housingSupport",
        "before": "補助率・上限額のみ記載",
        "after": "申請多数により現在受付一時中止であることを明記",
        "officialSource": "https://www.city.okaya.lg.jp/soshikikarasagasu/toshikeikakuka/633/1/16377.html"
    },
    {
        "type": "fee_and_period_detail_omission",
        "municipalityCode": "20205",
        "municipalityName": "飯田市",
        "service": "sickChildCare",
        "before": "料金は住所地・世帯区分により異なるとのみ記載",
        "after": "世帯区分別0～2,000円、給食400円、連続7日上限を明記",
        "officialSource": "https://www.city.iida.lg.jp/soshiki/12/iida-ohisamaharuru.html"
    }
]
existing_keys = {(item.get("municipalityCode"), item.get("service"), item.get("type")) for item in corrections}
for item in new_corrections:
    key = (item["municipalityCode"], item["service"], item["type"])
    if key not in existing_keys:
        corrections.append(item)

round4 = {
    "round": 4,
    "scope": "長野県・PR #3169再判定対象外5市の重点抜き取り",
    "municipalities": [
        {"code": "20201", "name": "長野市"},
        {"code": "20202", "name": "松本市"},
        {"code": "20203", "name": "上田市"},
        {"code": "20204", "name": "岡谷市"},
        {"code": "20205", "name": "飯田市"}
    ],
    "focus": ["年齢上限", "料金", "利用期間・回数", "広域利用", "住宅支援の分類・受付状況"],
    "result": "passed_after_corrections",
    "confirmedErrors": 5,
    "corrections": [
        "長野市・松本市・上田市・飯田市の病児保育料金・期間条件を具体化",
        "岡谷市の空き家改修補助が現在受付一時中止であることを追記"
    ],
    "notes": [
        "長野市・松本市・上田市・岡谷市・飯田市の住宅支援制度の対象区分、補助率、上限額は公式情報と一致",
        "5市の年齢上限、広域利用対象、こども誰でも通園制度の対象月齢に追加不一致なし"
    ]
}
rounds = [item for item in audit.setdefault("rounds", []) if item.get("round") != 4]
rounds.append(round4)
audit["rounds"] = rounds
audit["status"] = "completed_pending_regional_integration"
audit["nextAction"] = "第4回訂正をPR・CIで検証し、region/eastへ統合後に第2監査の完了記録を確定する。栄村Issue #2847は維持。"
audit["updatedAt"] = CHECKED_AT
write_json(audit_path, audit)

# checkpointを第4回監査完了・地域統合待ちへ更新。
checkpoint_path = ROOT / "operations" / "control" / "session-checkpoints" / "east-a.json"
checkpoint = read_json(checkpoint_path)
checkpoint["updatedAt"] = CHECKED_AT
q2 = checkpoint.setdefault("qualityImprovementSecondAudit", {})
q2.update({
    "status": "completed_pending_regional_integration",
    "completedRounds": 4,
    "targetRounds": 4,
    "currentRound": "nagano_sample_completed",
    "confirmedDataErrors": 12,
    "confirmedStateRecordErrors": 1,
    "sakaeOfficialSiteStatus": "http_502",
    "nextAction": "第4回訂正をPR・CIで検証しregion/eastへ統合後、完了記録を確定する。栄村は9制度unavailable・Issue #2847維持。"
})
sampled = q2.setdefault("sampledMunicipalities", [])
for code in ["20201", "20202", "20203", "20204", "20205"]:
    if code not in sampled:
        sampled.append(code)
if isinstance(checkpoint.get("verificationCampaign"), dict):
    checkpoint["verificationCampaign"]["nextAction"] = "品質改善第2監査4回を完了。第4回訂正のPR・CI・region/east統合と完了記録を確定する。栄村は9制度unavailable・Issue #2847維持。"
write_json(checkpoint_path, checkpoint)
