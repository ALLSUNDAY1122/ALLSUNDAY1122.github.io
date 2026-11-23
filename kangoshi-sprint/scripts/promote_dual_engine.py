#!/usr/bin/env python3
"""Promote ONLY double-engine+official-key-gated new 111/112 items to canonical source extension.
This is NOT a runtime/content/explanation release gate.
"""
import json,pathlib,collections,hashlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILE=ROOT/"product-content/verified-additions-20261124.json"
MANIFEST=ROOT/"product-content/manifest.json"
D=ROOT/"audit/runs/dual-engine-20261124"
OLD=json.loads(FILE.read_text(encoding="utf8"))
M=json.loads(MANIFEST.read_text(encoding="utf8"))
original=list(OLD["questions"])
previous_count=len(original)
seen={q["id"] for q in original}
fresh=json.loads((D/"bulk-verified-nonpublishable.json").read_text(encoding="utf8"))["questions"]
all_rows=[]
for e in (111,112):
 for s in ("AM","PM"):
  all_rows+=json.loads((D/f"{e}-{s}-per-question.json").read_text(encoding="utf8"))
byid={q["id"]:q for q in all_rows}
if len(all_rows)!=480 or len(byid)!=480:raise ValueError("480 ID uniqueness gate failed")
new=[]
for q in fresh:
    id=q["id"]
    if id in seen:raise ValueError("duplicate new ID "+id)
    r=byid.get(id)
    if not r or r["status"]!="PASS_DUAL_ENGINE_AND_OFFICIAL_KEY" or r["reasons"]:raise ValueError("unproven: "+id)
    if q.get("publishable") is not False or q.get("releaseEligible") is not False:raise ValueError("ungated: "+id)
    if not (len(q.get("choices") or []) in (4,5) and isinstance(q.get("answer"),int) and q["answer"] in range(len(q.get("choices") or []))):raise ValueError("bad content: "+id)
    q["printedOptionCount"]=len(q["choices"])
    q["category"]="必修" if q["questionNo"]<=25 else ("状況設定" if q["questionNo"]>=91 else "一般")
    if q["questionNo"]>=91 and (r.get("scenarioContext") or {}).get("status")!="DUAL_ENGINE_CONTEXT_MATCH":raise ValueError("situation context evidence missing: "+id)
    q["majorSubject"]=None
    q["point"]=None
    q["detail"]=None
    q["audit"]["explanationIndependentlyReviewed"]=False
    q["audit"]["runtimeIntegrationChecked"]=False
    q["reviewStatus"]="DUAL_ENGINE_SOURCE_AND_OFFICIAL_KEY_VERIFIED_EXPLANATION_PENDING"
    q["evidence"]={"sourcePdfPage":r["sourcePdfPage"],"sourcePdfSha256":r["sourcePdfSha256"],
        "dualEngineAuditRun":"GitHub Actions 2026-11-24","verifier":"PyMuPDF + Poppler pdftotext -layout",
        "originalPdfGlyphControlAbsent":True,"officialKeyRetestedAgainstPdf":True,
        "coordinateBoundaryEvidence":r.get("coordinateBoundaryEvidence"),"scenarioContextEvidence":r.get("scenarioContext")}
    new.append(q);seen.add(id)
if len(new)<1:print("NO_NEW_PASS; preserving existing canonical verified records")
OLD["questions"]+=new
OLD["questions"].sort(key=lambda q:(-q["sourceExam"],q["session"],q["questionNo"]))
OLD["count"]=len(OLD["questions"])
OLD["updatedAt"]="2026-11-24"
OLD["policy"]="Verified 112/111 canonical SOURCE bank; new questions pass two independent PDF text extraction and official answer token tests, but still require explanation, app tests, rights checks. Never auto-publish."
FILE.write_text(json.dumps(OLD,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
ext=M.get("verifiedExtension") or {}
ext.update({"file":"verified-additions-20261124.json","canonicalSourceVerifiedCount":len(OLD["questions"]),
"canonicalSourceVerifiedTotal":720+len(OLD["questions"]),"remainingNotVerified":480-len(OLD["questions"]),
"newBulkVerified":len(new),"verificationMethod":"PyMuPDF+Poppler independent full stem/options and MHLW official answer PDF, reject control glyphs/footer/media/scenarios",
"runtimeAdditionalCount":0,"releaseEligibleAdditionalCount":0,
"reviewStatus":"DUAL_ENGINE_SOURCE_KEY_VERIFIED_EXPLANATIONS_RUNTIME_PENDING"})
M["verifiedExtension"]=ext
MANIFEST.write_text(json.dumps(M,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
HOLD=[{"id":x["id"],"reasons":x["reasons"],"exam":x["exam"],"session":x["session"],"number":x["number"]} for x in all_rows if x["status"]!="PASS_DUAL_ENGINE_AND_OFFICIAL_KEY" and "ALREADY_VERIFIED_CANONICAL" not in x["reasons"]]
if len(HOLD)+len(new)+previous_count!=480:raise ValueError(f"Count invariant failed: HOLD={len(HOLD)} new={len(new)} old={previous_count}")
A=ROOT/"audit";A.mkdir(exist_ok=True)
(A/"dual-engine-promotion-ledger-20261124.json").write_text(json.dumps(
 {"schemaVersion":1,"newPromoted":len(new),"newIds":[x["id"] for x in new],"oldVerified":len(original),
 "canonicalVerified":len(OLD["questions"]),"runtimeAdditional":0,"officialKeyPdfRechecked":True,"pdfEngines":["PyMuPDF","Poppler"],
 "sourceAuditArtifact":"Workflow dual-engine-480 evidence","releaseBlocked":True,"eachItem":[byid[q["id"]] for q in new]},ensure_ascii=False,indent=2)+"\n")
(A/"dual-engine-hold-20261124.json").write_text(json.dumps({"count":len(HOLD),"hold":HOLD,"scope":"Nonverified draft questions after 2 independent extraction engines and official key. Only these require manual review."},ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"newPromoted":len(new),"verifiedCanonicalTotal":720+len(OLD["questions"]),"extensionCount":len(OLD["questions"]),"holdForManual":len(HOLD),"alreadyVerified":len(original)},ensure_ascii=False))
