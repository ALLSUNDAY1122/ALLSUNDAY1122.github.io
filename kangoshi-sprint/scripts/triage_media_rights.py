#!/usr/bin/env python3
"""Risk triage only: references to exam-created figures are NOT proof of ownership."""
import json,re,pathlib,collections
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs"; records=[]
for exam in (115,114,113):
    bank=json.loads((ROOT/f"product-content/raw/set{116-exam}-raw.json").read_text())
    for q in bank["questions"]:
        if not q.get("requiresMedia"):continue
        stem=q.get("question","")
        if re.search(r"写真|CT|MRI|X線|レントゲン|画像|皮膚|患部|顔貌|眼底|心電図|超音波",stem,re.IGNORECASE):
            category="THIRD_PARTY_OR_PATIENT_IMAGE_SUSPECTED"
        elif re.search(r"図|表|グラフ|模式図|関係図",stem):
            category="EXAM_CREATED_CHART_CANDIDATE_UNPROVEN"
        else:category="MEDIA_TYPE_UNDETERMINED"
        records.append({"id":q["id"],"category":category,"rightsDecision":"HOLD_UNTIL_INDIVIDUAL_SOURCE_PROOF","sourceAttribution":q.get("sourceAttribution"),"mediaAuditStatus":q.get("mediaAuditStatus")})
counts=dict(collections.Counter(x["category"] for x in records))
out={"total":len(records),"counts":counts,"policy":"PDL1.0 coverage of government-created figures is possible, but individual source/publisher/third-party notice must be checked before release.","records":records}
OUT.mkdir(parents=True,exist_ok=True)
(OUT/"media-rights-triage.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"media":len(records),"triage":counts},ensure_ascii=False))
