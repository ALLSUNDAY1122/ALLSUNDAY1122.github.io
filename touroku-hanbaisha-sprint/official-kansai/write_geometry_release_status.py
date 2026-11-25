#!/usr/bin/env python3
"""Append second-stage evidence to canonical release files without overstating counts."""
# Count every independently approved promotion ledger, not only the original methods.
import collections,json
from datetime import datetime,timezone,timedelta
from pathlib import Path
B=Path(__file__).resolve().parent
ROOT=B.parents[1]
IOS=ROOT/"touroku-hanbaisha-ios"
status_path=IOS/"release-status.json"
md_path=IOS/"RELEASE_STATUS.md"
status=json.loads(status_path.read_text())
bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
per_year={};risk_totals=collections.Counter()
cross_totals=collections.Counter()
for year in range(2022,2027):
    geometry=json.loads((B/f"GEOMETRY_AUDIT_{year}.json").read_text())
    cross=json.loads((B/f"CROSSCHECK_{year}.json").read_text())
    if geometry["total"]!=120 or len(geometry["questions"])!=120 or cross["samples"]!=10:
        raise RuntimeError("incorrect geo/cross-check count")
    reasons=geometry["reasonCounts"]
    risk_totals.update(reasons)
    cross_totals.update(cross["summary"])
    mapped=bank["byYear"][str(year)]
    pg={
        "pdfQuestionCount":120,
        "oldAutoPass":geometry["previousAutoPass"],
        "newGeometryPass":geometry["newGeometryPass"],
        "geometryUnresolved":geometry["remainingHold"],
        "rubySourceAnchorAssociated":sum(q.get("ruby",{}).get("status")=="ASSOCIATED_SOURCE_ONLY" for q in geometry["questions"] if q.get("ruby")),
        "rubySourceInconclusive":sum(q.get("ruby",{}).get("status")=="INCONCLUSIVE" for q in geometry["questions"] if q.get("ruby")),
        "promotedTotal":sum(mapped.get(method,0) for method in ("auto","geometry","ruby","rubyOrdered","layout","cropImage","rubyFontCluster","visual","visualRubyV2","imageV3","directRubyV3","sourceOrderUnattached","ruby113Auto")),
        "promotedByMethod":{method:mapped.get(method,0) for method in ("auto","geometry","ruby","rubyOrdered","layout","cropImage","rubyFontCluster","visual","visualRubyV2","imageV3","directRubyV3","sourceOrderUnattached","ruby113Auto") if mapped.get(method,0)},
        "promotedByGeometry":mapped["geometry"],
        "promotedByRuby":mapped.get("ruby",0),
        "promotedByLayout":mapped.get("layout",0),
        "manualPass":mapped["visual"],
        "holdTotal":mapped["hold"],
        "reasons":reasons,
        "sampleCrossCheck":cross["summary"],
        "geometryEvidence":f"touroku-hanbaisha-sprint/official-kansai/GEOMETRY_AUDIT_{year}.json",
        "crosscheckEvidence":f"touroku-hanbaisha-sprint/official-kansai/CROSSCHECK_{year}.json",
    }
    if pg["promotedTotal"]+pg["holdTotal"]+mapped["pending"]!=120:
        raise RuntimeError("year count invariant "+str(year))
    per_year[str(year)]=pg
count=bank["count"];geo=sum(x["geometry"] for x in bank["byYear"].values())
ids=[q["id"] for q in bank["questions"]]
if count!=len(ids) or count!=len(set(ids)) or set(ids)!=set(bank["approvedIds"]):
    raise RuntimeError("bank count/ID integrity mismatch")
if count!=sum(x["promotedTotal"] for x in per_year.values()):
    raise RuntimeError("bank mismatch")
if "KSAI-2023-090" in bank["approvedIds"]:raise RuntimeError("Q90 erroneously released")
n=sum(x["pdfQuestionCount"] for x in per_year.values())
if n!=600:raise RuntimeError("not 600")
now=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
status["updated_at"]=now
qb=status.setdefault("question_bank",{})
qb.update({
    "production_official_bank_count":count,
    "verified_official_imported":count,
    "official_question_text_imported":count,
    "auto_geometry_new_promoted":geo,
    "auto_geometry_and_ruby_per_year":per_year,
    "auto_geometry_reason_totals":dict(risk_totals),
    "cross_engine_sample_size":sum(x["samples"] for x in [json.loads((B/f"CROSSCHECK_{y}.json").read_text()) for y in range(2022,2027)]),
    "cross_engine_sample_results":dict(cross_totals),
    "ruby_layout_auto_certification_policy":"Source glyph-to-Kanji mapping may be observed, but detached ruby cannot be approved until UI ruby markup layout is verified"
})
g=status.setdefault("gates",{})
g["pdf_coordinate_table_audit"]="COMPLETE_600_EVALUATED"
g["rubies_source_anchor_audit"]="COMPLETE_600_EVALUATED_REQUIRES_RENDER_FIDELITY"
g["alternative_extractor_crosscheck"]="50_STRATIFIED_SAMPLES_RECORDED"
g["official_source_import"]=f"PARTIAL_APPROVED_{count}_OF_600"
g["content_complete"]="PASS" if count==600 else "BLOCKED"
g["release_readiness"]="BLOCKED"
status["release_gate"]="BLOCKED"
status["app_review_submitted"]=False
ev=status.setdefault("evidence",[])
for year in range(2022,2027):
    for prefix in ("GEOMETRY_AUDIT","CROSSCHECK"):
        uri=f"touroku-hanbaisha-sprint/official-kansai/{prefix}_{year}.json"
        if uri not in ev:ev.append(uri)
status_path.write_text(json.dumps(status,ensure_ascii=False,indent=2)+"\n")
tab="\n".join(
    f"| {year} | {v['promotedTotal']} | {v['promotedByGeometry']} | {v['holdTotal']} | {v['rubySourceAnchorAssociated']} |"
    for year,v in per_year.items()
)
reasons="\n".join(f"| {k} | {v} |" for k,v in sorted(risk_totals.items()))
cross="\n".join(f"| {k} | {v} |" for k,v in sorted(cross_totals.items()))
section=f"""
## 座標照合ゲート・別エンジン交差検証 v2（{now}・最新）
**本番審査判定 BLOCKED。正式バンク {count}/600問。追加の表座標自動昇格 {geo}問。**

原典の保存済SHA-256を検証して、全600問を再走査。正誤組合せ表については、設問PDF座標領域に含まれる選択肢番号、各正誤セルの文字、左から右の列順、全行の物理的なx座標整列（各列のばらつき最大4pt）、y座標の昇順、一意の行対応がすべて成立した場合だけ自動PASSとする。別図、ふりがな、文字diff等のHOLDは無効化しない。

ルビはPDFの小フォントかなの矩形と直下の漢字スパン位置を対応付け、曖昧なものはHOLD。**元のアプリJSONにルビが独立行として残る場合、原典との対応が自動検出できても、画面に正しく配置できることが確認されるまでは昇格しない**。

| 年度 | 正式バンク | 今回の座標昇格 | 未昇格 | ルビ原典側アンカー検出 |
|---|---:|---:|---:|---:|
{tab}
| **合計** | **{count}** | **{geo}** | **{600-count}** | **{sum(x['rubySourceAnchorAssociated'] for x in per_year.values())}** |

### 残る保留理由（複数理由の重複あり）
| 判定理由 | 件数 |
|---|---:|
{reasons}

### 別抽出エンジンによる交差検証
年度ごとに指定された標本10問、**合計50問**をPyMuPDFとpdfplumber（pdfminer.six）の両方で原典PDFから再抽出し、座標範囲を合わせて文字集合と順序を照合した。標本の一致は600問全件の独立監査の証明ではない。

| 標本の判定 | 件数 |
|---|---:|
{cross}

原典PDF取得・SHA256・座標証跡：\`GEOMETRY_AUDIT_2022.json\`〜\`GEOMETRY_AUDIT_2026.json\`。標本の抽出差異と照合結果：\`CROSSCHECK_2022.json\`〜\`CROSSCHECK_2026.json\`。状態ファイルの過去の件数は時点記録として保持し、本節を最新値とする。
"""
md_path.write_text(md_path.read_text()+"\n"+section)
print(json.dumps({"approved":count,"geometry":geo,"years":per_year,"crossSamples":sum(cross_totals.values())},ensure_ascii=False))
