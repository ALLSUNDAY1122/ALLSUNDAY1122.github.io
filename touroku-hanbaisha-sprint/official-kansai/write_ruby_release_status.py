#!/usr/bin/env python3
"""Report only actual GitHub Actions ruby/layout QA results, with per-year counts."""
import collections,json
from datetime import datetime,timezone,timedelta
from pathlib import Path
B=Path(__file__).resolve().parent
IOS=B.parents[1]/"touroku-hanbaisha-ios"
state_path=IOS/"release-status.json"
md_path=IOS/"RELEASE_STATUS.md"
s=json.loads(state_path.read_text())
bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
per_year={};ruby_reasons=collections.Counter();layout_reasons=collections.Counter()
for year in range(2022,2027):
    rr=json.loads((B/f"RUBY_RECON_{year}.json").read_text())
    layout=json.loads((B/f"LAYOUT_TRIAGE_{year}.json").read_text())
    if rr["total"]!=120 or layout["total"]!=120 or len(rr["records"])!=120 or len(layout["records"])!=120:
        raise RuntimeError("not all 120 question events saved")
    data=bank["byYear"][str(year)]
    credited=data.get("ruby",0)
    layout_credited=data.get("layout",0)
    if rr["rubyPass"]<credited or layout["cleared"]<layout_credited:
        raise RuntimeError("reported promotion exceeds passed evidence")
    per_year[str(year)]={
        "sourceRubyCandidates":rr["target"],
        "rubyEvidencePass":rr["rubyPass"],
        "rubyPromoted":credited,
        "rubyOrderedPromoted":data.get("rubyOrdered",0),
        "rubyHoldAfterReconstruction":rr["rubyHold"],
        "layoutTriageTargets":layout["targets"],
        "layoutEvidencePass":layout["cleared"],
        "layoutPromoted":layout_credited,
        "layoutUnresolved":layout["held"],
        "approvedTotal":data["auto"]+data["geometry"]+data.get("ruby",0)+data.get("rubyOrdered",0)+data.get("layout",0)+data.get("cropImage",0)+data.get("rubyFontCluster",0)+data["visual"],
        "unapproved":data["hold"]+data["pending"],
        "rubyReasons":rr["reasonCounts"],
        "layoutReasons":layout["reasonCounts"]
    }
    if per_year[str(year)]["approvedTotal"]+per_year[str(year)]["unapproved"]!=120:
        raise RuntimeError("year approved/hold mismatch")
    ruby_reasons.update(rr["reasonCounts"]);layout_reasons.update(layout["reasonCounts"])
total=bank["count"]
if total!=sum(x["approvedTotal"] for x in per_year.values()):raise RuntimeError("bank total")
if "KSAI-2023-090" in bank["approvedIds"]:raise RuntimeError("Q90 cannot auto publish")
now=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
s["updated_at"]=now
qb=s.setdefault("question_bank",{})
qb.update({
    "production_official_bank_count":total,
    "verified_official_imported":total,
    "official_question_text_imported":total,
    "ruby_ui_per_year":per_year,
    "auto_ruby_new_promoted":sum(x["rubyPromoted"] for x in per_year.values()),
    "auto_ruby_ordered_promoted":sum(x["rubyOrderedPromoted"] for x in per_year.values()),
    "auto_layout_new_promoted":sum(x["layoutPromoted"] for x in per_year.values()),
    "ruby_reconstruction_hold_reason_totals":dict(ruby_reasons),
    "special_diagram_triage_reason_totals":dict(layout_reasons),
    "ruby_renderer":"Native DOM ruby+rt with validated source glyph positions and isolated furigana readings",
    "ruby_source_related_count":sum(x["sourceRubyCandidates"] for x in per_year.values())
})
g=s.setdefault("gates",{})
g["ruby_position_to_dom_reconstruction"]="COMPLETE_WITH_PER_QUESTION_HOLDS"
g["special_structure_and_graphics_triage"]="COMPLETE_WITH_PER_QUESTION_HOLDS"
g["official_source_import"]=f"PARTIAL_APPROVED_{total}_OF_600"
g["content_complete"]="PASS" if total==600 else "BLOCKED"
g["official_release_readiness"]="BLOCKED_UNTIL_CONTENT_AND_APP_REVIEW"
s["release_gate"]="BLOCKED"
s["app_review_submitted"]=False
for year in range(2022,2027):
    for kind in ("RUBY_RECON","LAYOUT_TRIAGE"):
        entry=f"touroku-hanbaisha-sprint/official-kansai/{kind}_{year}.json"
        if entry not in s.setdefault("evidence",[]):s["evidence"].append(entry)
state_path.write_text(json.dumps(s,ensure_ascii=False,indent=2)+"\n")
rows="\n".join(f"| {year} | {v['sourceRubyCandidates']} | {v['rubyPromoted']} | {v['rubyHoldAfterReconstruction']} | {v['layoutTriageTargets']} | {v['layoutPromoted']} | {v['approvedTotal']} | {v['unapproved']} |" for year,v in per_year.items())
rr="\n".join(f"| {key} | {n} |" for key,n in sorted(ruby_reasons.items()))
lr="\n".join(f"| {key} | {n} |" for key,n in sorted(layout_reasons.items()))
section=f"""
## 【最新】ルビ漢字対応・HTML ruby 表示、特殊構造／図表トリアージ（{now}）
**正式問題バンク：{total}/600問。残る未昇格：{600-total}問。本番審査判定：BLOCKED。**

公式PDFの字形矩形と候補テキスト内の一意な漢字・ふりがな独立行を照合し、一意に確定するもののみ、DOM \`ruby\`／\`rt\` の構造化データを付けて正式バンクへ昇格。長いPDF行全体との曖昧な対応、複数の同字、複数の読み、他の図表保留がある問題は昇格しない。画面で読みだけ重複する事態を避けるため、表示用本文から独立ルビ行を除き、読みを \`rt\` で示す。候補の原文・過去の監査記録は変更しない。

| 年度 | 原典側ルビ対応対象 | 今回ルビ昇格 | ルビ保留 | 特殊構造・図表の再検討対象 | 追加昇格 | 正式バンク | 未昇格 |
|---|---:|---:|---:|---:|---:|---:|---:|
{rows}
| **計** | **{sum(x['sourceRubyCandidates'] for x in per_year.values())}** | **{sum(x['rubyPromoted'] for x in per_year.values())}** | **{sum(x['rubyHoldAfterReconstruction'] for x in per_year.values())}** | **{sum(x['layoutTriageTargets'] for x in per_year.values())}** | **{sum(x['layoutPromoted'] for x in per_year.values())}** | **{total}** | **{600-total}** |

### ルビを昇格できない理由（重複あり）
| 理由コード | 件数 |
|---|---:|
{rr}

### 特殊構造・図表の未確定理由（重複あり）
| 理由コード | 件数 |
|---|---:|
{lr}

**図表対応の扱い：** \`図られる\` の「図」を誤検出したケースや、通常の文章選択肢を表扱いしたケースだけを、自動的な誤検出として解除可能。実際の成分一覧表・線画・画像・座標が一致しない表は引き続きHOLD。PDFの物理図版や第三者権利がある素材を無断で作り替えない。

**独立抽出：** 直前のpdfplumber/pdfminer標本50件（完全一致44・文字集合一致2・不一致4）の不一致4件は昇格不可とした。標本の照合は全件の無誤りを保証しない。

証跡：\`RUBY_RECON_2022.json\`〜\`RUBY_RECON_2026.json\`、\`LAYOUT_TRIAGE_2022.json\`〜\`LAYOUT_TRIAGE_2026.json\`。以前の集計値は履歴として維持し、この節を最新とする。
"""
md_path.write_text(md_path.read_text()+"\n"+section)
print(json.dumps({"approved":total,"ruby":qb["auto_ruby_new_promoted"],"layout":qb["auto_layout_new_promoted"],"years":per_year},ensure_ascii=False))
