#!/usr/bin/env python3
"""Run same PDF text gate on 480 newly extracted staging questions.
Pass means equality to extracted PDF text only, NOT faithful glyph decoding or release readiness.
"""
import json,pathlib,subprocess,sys,collections
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/"audit/runs"
all_counts=collections.Counter();runs={}
for exam in (112,111):
    for session in ("AM","PM"):
        draft=OUT/f"exam{exam}-{session}-draft.json"
        pdf=pathlib.Path("/tmp/kangoshi-official")/f"{exam}-{session}.pdf"
        report=OUT/f"exam{exam}-{session}-draft-text-audit.json"
        if not draft.is_file() or not pdf.is_file():
            runs[f"{exam}-{session}"]={"status":"NOT_EXECUTED_SOURCE_MISSING"};continue
        obj=json.loads(draft.read_text())
        if obj.get("detected")!=120:
            runs[f"{exam}-{session}"]={"status":"NOT_EXECUTED_BAD_COUNT"};continue
        command=[sys.executable,str(ROOT/"scripts/audit_official_pdf.py"),"--exam",str(exam),"--session",session,"--source-url","source_manifest","--questions",str(draft),"--pdf",str(pdf),"--report",str(report)]
        p=subprocess.run(command,capture_output=True,text=True)
        if not report.exists():
            runs[f"{exam}-{session}"]={"status":"AUDIT_CRASH","stderr":p.stderr[-500:]};continue
        result=json.loads(report.read_text());counts=result["statusCounts"]
        all_counts.update(counts)
        runs[f"{exam}-{session}"]={"status":"EXECUTED_STAGING_ONLY","counts":counts,"invalidStructure":len(obj.get("invalidQuestionNumbers",[])),"exitCode":p.returncode}
summary={"target":480,"questionsAudited":sum(all_counts.values()),"counts":dict(all_counts),"sessions":runs,"officialCorrectAnswersChecked":0,"publishable":0,"note":"A same-source extract/text match can pass even when the PDF glyph mapping dropped original digits or symbols. ALL 480 remain quarantined."}
(OUT/"draft-text-audit-summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(summary,ensure_ascii=False))
