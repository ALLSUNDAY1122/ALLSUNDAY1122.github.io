from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKED_DATE = "2026-07-25"
CHECKED_AT = "2026-07-25T11:38:00+09:00"
BRANCH = "audit/east-a-second-quality-20260725-r3"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def municipality_path(code: str) -> Path:
    return ROOT / "data" / "municipalities" / code[:2] / f"{code}.json"


def task_path(code: str) -> Path:
    return ROOT / "operations" / "tasks" / f"{code}.json"


def update_task(code: str, note: str, replace_source: tuple[str, str] | None = None, add_source: str | None = None) -> None:
    path = task_path(code)
    task = read_json(path)
    task["lastCheckedAt"] = CHECKED_DATE
    task["lastUpdatedAt"] = CHECKED_AT
    task["lastUpdatedBy"] = "東日本調査班A"
    notes = task.setdefault("notes", [])
    if note not in notes:
        notes.append(note)
    sources = task.setdefault("officialSources", [])
    if replace_source:
        old, new = replace_source
        sources = [new if url == old else url for url in sources]
        if new not in sources:
            sources.append(new)
        task["officialSources"] = sources
    if add_source and add_source not in sources:
        sources.append(add_source)
    write_json(path, task)


# 19201 甲府市: 一般の住居確保給付金から、現行の子育て世帯住宅取得支援へ差し替え。
kofu_path = municipality_path("19201")
kofu = read_json(kofu_path)
kofu["updatedAt"] = CHECKED_DATE
kofu["services"]["housingSupport"] = {
    "status": "verified",
    "summary": "18歳以下の子を養育する新婚・子育て世帯に住宅取得・改修・引越費用を最大90万円補助",
    "eligibility": {"minAgeMonths": 0, "maxAgeYears": 18},
    "details": {
        "target": "令和8年度に18歳年度末までの子（妊娠中を含む）を養育し、婚姻時に夫婦とも39歳以下、夫婦合計所得500万円未満等の要件を満たす新婚世帯または婚姻後5年以内の子育て世帯",
        "costs": "令和8年4月1日から令和9年3月31日までに支払った住宅購入費（土地代を除く）、リフォーム費用、引越業者・運送業者への引越費用",
        "amount": "新築住宅は上限30万円（夫婦とも29歳以下は60万円）、既存住宅取得・リフォームは上限60万円（夫婦とも29歳以下は90万円）",
        "conditions": "申請住宅に夫婦・子が住民登録し、10年以上の市内居住意思、市税滞納なし、公的家賃補助との重複なし等",
        "period": "令和8年度の申請期限は令和9年3月31日。予算状況により早期終了する場合あり"
    },
    "source": {
        "url": "https://www.city.kofu.yamanashi.jp/ijuuteijuu/kosodatesetaizyuutakusyutoku.html",
        "checkedAt": CHECKED_DATE
    }
}
write_json(kofu_path, kofu)
update_task(
    "19201",
    "品質改善第2監査第3回で、一般の住居確保給付金ではなく令和8年度子育て世帯住宅取得支援事業をhousingSupportへ登録。対象年齢・費用・上限額・申請期限を現行公式ページへ同期。",
    replace_source=(
        "https://www.city.kofu.yamanashi.jp/sekatsufukushi/machi/sumai/jose/kinkyu.html",
        "https://www.city.kofu.yamanashi.jp/ijuuteijuu/kosodatesetaizyuutakusyutoku.html",
    ),
)

# 19202 富士吉田市: KAITEKI住宅は子どもの養育要件がない一般住宅支援として年齢上限を正規化。
fujiyoshida_path = municipality_path("19202")
fujiyoshida = read_json(fujiyoshida_path)
fujiyoshida["updatedAt"] = CHECKED_DATE
housing = fujiyoshida["services"]["housingSupport"]
housing["summary"] = "子どもの有無を問わず、やまなしKAITEKI住宅の建築・取得費用を最大120万円補助"
housing["eligibility"] = {"minAgeMonths": 0, "maxAgeYears": 120}
housing["details"]["target"] = "市内のやまなしKAITEKI住宅認定住宅を自ら居住する目的で建築または取得し、所在地へ住民登録した方。子どもの養育・年齢要件はない"
housing["details"]["classification"] = "一般住宅支援（子育て世帯限定制度ではない）"
housing["source"]["checkedAt"] = CHECKED_DATE
sick = fujiyoshida["services"]["sickChildCare"]
sick["details"]["target"] = "山梨県内在住で、病気中または回復期にあり保護者の就労等で家庭保育が困難な生後6か月から小学校6年生までの子ども"
sick["details"]["fee"] = "市立病後児保育室は市内在住1日1,000円、市外在住1日1,500円に給食費300円を加算。生活保護・市町村民税非課税世帯は減免あり。民間の病児・病後児対応型施設は施設設定"
sick["details"]["wideArea"] = "市立病後児保育室は山梨県内在住者が利用可能"
sick["source"]["checkedAt"] = CHECKED_DATE
additional = sick.setdefault("additionalSources", [])
detail_url = "https://www.city.fujiyoshida.yamanashi.jp/site/kosodate/2732.html"
if not any(item.get("url") == detail_url for item in additional):
    additional.append({"url": detail_url, "checkedAt": CHECKED_DATE})
else:
    for item in additional:
        if item.get("url") == detail_url:
            item["checkedAt"] = CHECKED_DATE
write_json(fujiyoshida_path, fujiyoshida)
update_task(
    "19202",
    "品質改善第2監査第3回で、KAITEKI住宅補助に子どもの養育要件がないことからhousingSupport年齢上限を120歳へ正規化。市立病後児保育室の県内広域対象と市内1,000円・市外1,500円＋給食費を追記。",
    add_source=detail_url,
)

# 19205 山梨市: 県内広域利用時の料金を明記。
yamanashi_path = municipality_path("19205")
yamanashi = read_json(yamanashi_path)
yamanashi["updatedAt"] = CHECKED_DATE
sick = yamanashi["services"]["sickChildCare"]
sick["details"]["fee"] = "山梨市内在住は日額2,000円、県内の市外在住は日額2,500円。生活保護・前年度住民税非課税世帯は無料。昼食代300円は別途"
sick["details"]["wideArea"] = "山梨県内全域の生後6か月から小学校6年生までが利用対象"
sick["source"]["checkedAt"] = CHECKED_DATE
write_json(yamanashi_path, yamanashi)
update_task(
    "19205",
    "品質改善第2監査第3回で、病児・病後児保育の県内広域利用料金（市内2,000円・県内市外2,500円）と昼食代300円を明記。",
)

# 19206 大月市: 市外・県外利用料金を明記。
otsuki_path = municipality_path("19206")
otsuki = read_json(otsuki_path)
otsuki["updatedAt"] = CHECKED_DATE
sick = otsuki["services"]["sickChildCare"]
sick["details"]["fee"] = "大月市内在住は日額1,000円（生活保護・市町村民税非課税世帯は全額免除）、山梨県内の市外在住は日額1,500円、山梨県外在住は日額4,000円。昼食代等は別途"
sick["details"]["wideArea"] = "市内在住・市内勤務世帯に加え、県内広域利用等の市外利用者にも料金区分を設定"
sick["source"]["checkedAt"] = CHECKED_DATE
write_json(otsuki_path, otsuki)
update_task(
    "19206",
    "品質改善第2監査第3回で、病児・病後児保育の市内1,000円・県内市外1,500円・県外4,000円の料金区分を明記。",
)

# 19204 都留市: 訂正なし。監査実施記録のみ更新。
update_task(
    "19204",
    "品質改善第2監査第3回で、年齢上限・料金・連続利用日数・県内広域利用・子育て世帯住宅取得支援の分類を再確認し、現行公式情報との不一致なし。",
)

# 監査記録。
audit_path = ROOT / "operations" / "audits" / "east-a-quality-improvement-second-audit-20260725.json"
audit = read_json(audit_path)
corrections = audit.setdefault("confirmedCorrections", [])
new_corrections = [
    {
        "type": "housing_program_misclassification",
        "municipalityCode": "19201",
        "municipalityName": "甲府市",
        "service": "housingSupport",
        "before": "一般の生活困窮者住居確保給付金を登録",
        "after": "令和8年度子育て世帯住宅取得支援事業（最大90万円）へ差し替え",
        "officialSource": "https://www.city.kofu.yamanashi.jp/ijuuteijuu/kosodatesetaizyuutakusyutoku.html"
    },
    {
        "type": "housing_age_classification_error",
        "municipalityCode": "19202",
        "municipalityName": "富士吉田市",
        "service": "housingSupport",
        "before": "子どもの養育要件がないKAITEKI住宅補助を18歳上限として登録",
        "after": "一般住宅支援として年齢上限120歳へ正規化",
        "officialSource": "https://www.city.fujiyoshida.yamanashi.jp/page/11949.html"
    },
    {
        "type": "wide_area_fee_omission",
        "municipalityCode": "19202",
        "municipalityName": "富士吉田市",
        "service": "sickChildCare",
        "before": "市内料金のみ記載",
        "after": "市内1,000円・市外1,500円＋給食費300円と県内広域対象を明記",
        "officialSource": "https://www.city.fujiyoshida.yamanashi.jp/site/kosodate/2732.html"
    },
    {
        "type": "wide_area_fee_omission",
        "municipalityCode": "19205",
        "municipalityName": "山梨市",
        "service": "sickChildCare",
        "before": "市内料金のみ記載",
        "after": "市内2,000円・県内市外2,500円・昼食代300円を明記",
        "officialSource": "https://www.city.yamanashi.yamanashi.jp/site/kosodate/1456.html"
    },
    {
        "type": "wide_area_fee_omission",
        "municipalityCode": "19206",
        "municipalityName": "大月市",
        "service": "sickChildCare",
        "before": "市内料金のみ記載",
        "after": "市内1,000円・県内市外1,500円・県外4,000円を明記",
        "officialSource": "https://www.city.otsuki.yamanashi.jp/kosodate/kosodate/byoujibyougojihoiku.html"
    }
]
existing_keys = {(item.get("municipalityCode"), item.get("service"), item.get("type")) for item in corrections}
for item in new_corrections:
    key = (item["municipalityCode"], item["service"], item["type"])
    if key not in existing_keys:
        corrections.append(item)

rounds = audit.setdefault("rounds", [])
round3 = {
    "round": 3,
    "scope": "山梨県・訂正対象外5市の重点抜き取り",
    "municipalities": [
        {"code": "19201", "name": "甲府市"},
        {"code": "19202", "name": "富士吉田市"},
        {"code": "19204", "name": "都留市"},
        {"code": "19205", "name": "山梨市"},
        {"code": "19206", "name": "大月市"}
    ],
    "focus": ["年齢上限", "料金", "利用期間・回数", "県内広域利用", "住宅支援の分類"],
    "result": "passed_after_corrections",
    "confirmedErrors": 5,
    "corrections": [
        "甲府市のhousingSupportを令和8年度子育て世帯住宅取得支援へ差し替え",
        "富士吉田市KAITEKI住宅補助の年齢上限を120歳へ正規化",
        "富士吉田市・山梨市・大月市の病児保育広域料金を具体化"
    ],
    "notes": ["都留市は重点項目の現行公式情報と一致"]
}
rounds = [item for item in rounds if item.get("round") != 3]
rounds.append(round3)
audit["rounds"] = rounds
audit["nextAction"] = "長野県の訂正対象外5自治体以上を重点監査し、第2監査を完了する。"
audit["updatedAt"] = CHECKED_AT
write_json(audit_path, audit)

# checkpoint。
checkpoint_path = ROOT / "operations" / "control" / "session-checkpoints" / "east-a.json"
checkpoint = read_json(checkpoint_path)
checkpoint["updatedAt"] = CHECKED_AT
q2 = checkpoint.setdefault("qualityImprovementSecondAudit", {})
q2.update({
    "status": "in_progress",
    "completedRounds": 3,
    "targetRounds": 4,
    "currentRound": "yamanashi_sample_completed",
    "confirmedDataErrors": 7,
    "confirmedStateRecordErrors": 1,
    "sakaeOfficialSiteStatus": "http_502",
    "nextAction": "長野県の訂正対象外5自治体以上を重点監査し、第2監査を完了する。"
})
sampled = q2.setdefault("sampledMunicipalities", [])
for code in ["19201", "19202", "19204", "19205", "19206"]:
    if code not in sampled:
        sampled.append(code)
if isinstance(checkpoint.get("verificationCampaign"), dict):
    checkpoint["verificationCampaign"]["nextAction"] = "品質改善第2監査を継続する。次は長野県の訂正対象外5自治体以上を重点監査し完了判定する。栄村は9制度unavailable・Issue #2847維持。"
write_json(checkpoint_path, checkpoint)
