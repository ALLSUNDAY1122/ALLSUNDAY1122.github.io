#!/usr/bin/env python3
"""Sync the two coordinator status files from actual on-disk promotion/hold evidence."""
import json,pathlib,collections,datetime,re
R=pathlib.Path(__file__).resolve().parents[1]
J=R/"release-status.json"
MD=R/"RELEASE_STATUS.md"
S=json.loads(J.read_text())
H=json.loads((R/"audit/dual-engine-hold-20261124.json").read_text())
E=json.loads((R/"product-content/verified-additions-20261124.json").read_text())
P=json.loads((R/"audit/dual-engine-promotion-ledger-20261124.json").read_text())
rows=H["hold"]
ext=len(E["questions"])
assert ext+len(rows)==480,(ext,len(rows))
assert len({q["id"] for q in E["questions"]})==ext
assert all(q.get("publishable") is False and q.get("releaseEligible") is False for q in E["questions"])
reasons=collections.Counter(x for q in rows for x in q["reasons"])
S.update(recordedImported=720+ext,additionalRequired=480-ext,
         newlyImported=ext,stagedCandidateCount=480,
         contentGate=f"CANONICAL_SOURCE_{720+ext}_OF_1200_EXISTING_RUNTIME_720_NEW{ext}_RELEASE_BLOCKED_{480-ext}_UNVERIFIED",
         releaseStatus="PREFLIGHT_BLOCKED",submissionAllowed=False)
S["canonicalBank"].update(sourceVerifiedExtension=ext,verifiedTotal=720+ext,
                          unverifiedRemaining=480-ext,extensionRuntimeEligible=0,extensionPublished=0)
S["staging"].update(verifiedExtensionCount=ext,remainingNotCanonicalVerified=480-ext,
                   publishableNew=0)
S["automation"]["bulkHoldCount"]=len(rows)
S["holdRemediation"].update(finalHold=len(rows),netReleasedFromHold=480-len(rows)-67,
                            reasonCountsNow=dict(reasons))
S["latestBoundaryContextAudit"]={
    "date":"2026-11-24","source":"GitHub Actions dual engine recheck",
    "newPromotedInRun":P["newPromoted"],"currentCanonical":720+ext,
    "currentHeld":len(rows),"reasonCountsOverlap":True,
    "boundaryCorrectionRequiresUniqueFiveFieldDualEngineMatch":True,
    "scenarioContextRequiresDualEngineSourcePassage":True,
    "svgOriginalDiagramFaithfulnessVerified":0,
    "svgPendingDetailedVisualInspection":18,
    "status":"SOURCE_ONLY_NO_RELEASE"}
# Report the verified reextracted pool without silently marking it publishable.
pending_file=R/"product-content/coordinate-reextracted-pending-20261124.json"
pending=json.loads(pending_file.read_text()) if pending_file.exists() else {"questions":[]}
verified_ids={q["id"] for q in E["questions"]}
pending_active=[q["id"] for q in pending["questions"] if q["id"] not in verified_ids]
evidence_path=R/"audit/coordinate-reextraction-evidence-20261124.json"
exvidence=json.loads(evidence_path.read_text()) if evidence_path.exists() else {"summary":{}}
S["latestContextAndControlAudit"]={
    "auditDate":"2026-11-24","scope":"all 480 candidates, prioritize 22 previously reextracted",
    "newPromoted":P["newPromoted"],"newIds":P["newIds"],
    "currentCanonical":720+ext,"remaining":len(rows),
    "quarantinedReextractedTotal":len(pending["questions"]),
    "quarantinedReextractedStillPending":len(pending_active),
    "lastReextraction":exvidence["summary"],
    "sources":["official exam PDF","independent official key PDF","PyMuPDF","Poppler"],
    "noAutoClearForUnknownControlGlyphs":True,
    "releaseEligibleNew":0,"publishableNew":0,
    "status":"SOURCE_ONLY_AND_PENDING_EXPLANATION_MEDIA_IOS"}
J.write_text(json.dumps(S,ensure_ascii=False,indent=2)+"\n")
lines=MD.read_text()
# Keep the canonical summary current, without rewriting the historical work log.
lines=re.sub(r"(\\| \\*\\*正規ソースバンク\\*\\* \\|) \\*\\*\\d+ / 1,200\\*\\*",lambda m:m.group(1)+f" **{720+ext} / 1,200**",lines,count=1)
lines=re.sub(r"(\\| \\*\\*第112・111回の未検証\\*\\* \\|) \\*\\*\\d+問\\*\\*",lambda m:m.group(1)+f" **{len(rows)}問**",lines,count=1)
lines=re.sub(r"(ソース検証済み拡張)\\d+問",lambda m:m.group(1)+str(ext)+"問",lines,count=1)
lines=re.sub(r"(保留)\\d+問(と理由 \\x60audit/dual-engine-hold-20261124.json\\x60)",lambda m:m.group(1)+str(len(rows))+"問"+m.group(2),lines,count=1)
lines=re.sub(r"(全)\\d+問(の正規拡張)",lambda m:m.group(1)+str(ext)+"問"+m.group(2),lines,count=1)
heading="## 境界位置・状況設定の再検証（自動実行記録）"
if heading in lines:lines=lines.split(heading)[0].rstrip()+"\n"
lines+="\n"+heading+"\n\n"
lines+=f"- 正規ソースバンク：**{720+ext}/1,200問**（追加{ext}問、既存720問）。\n"
lines+=f"- 追加480問の未昇格：**{len(rows)}問**。今回の自動昇格：**{P['newPromoted']}問**。\n"
lines+="- 番号境界を前後3ページで探索し、単独行の問題番号と問題文・4選択肢の両エンジン一致・候補一意性を確認する。状況設定の共通文も2エンジン一致がない限り保留。\n"
lines+="- 主要保留理由（重複）："+", ".join(f"{k} {v}" for k,v in reasons.most_common(12))+"。\n"
lines+="- SVG18件は原典との比較画像を再生成するが、画像の意味・医学的所見の忠実性は自動合格にしない。**18件の詳細視覚確認が残存**。\n"
lines+="- 解説・媒体権利・実機確認・本審査の公開ゲートは引き続き保留。\n"
print(json.dumps({"canonical":720+ext,"remaining":len(rows),"new":P["newPromoted"],"svgPending":18}))

lines += "\\n## 状況設定共通文・制御文字の再監査（2026-11-24）\\n\\n"
lines += f"- 新規正規ソース昇格：**{P['newPromoted']}問**。現行 **{720+ext}/1,200問**、未昇格 **{len(rows)}問**。\\n"
lines += f"- 先行再抽出22問のうち未昇格：**{len(pending_active)}問**。本文2方式一致の事実と、制御文字・状況設定共通文の最終ゲートは区別。\\n"
lines += f"- 全残件の保留理由（重複）："+", ".join(f"{k} {v}" for k,v in reasons.most_common(10))+"。\\n"
lines += "- 正本：`audit/dual-engine-promotion-ledger-20261124.json`、`audit/dual-engine-hold-20261124.json`、`audit/coordinate-reextraction-evidence-20261124.json`。権利・解説・iOS・本審査のゲートは引き続き閉鎖。\\n"
MD.write_text(lines)
