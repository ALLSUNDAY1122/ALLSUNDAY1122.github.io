#!/usr/bin/env python3
"""Run Ruby+layout examinations by year and record explicit failures."""
import datetime,json,subprocess,sys
from pathlib import Path
B=Path(__file__).resolve().parent
outputs=[]
for year in range(2022,2027):
    for kind,script in (("RUBY","reconstruct_ruby.py"),("LAYOUT","layout_exception_triage.py")):
        try:
            proc=subprocess.run([sys.executable,str(B/script),"--year",str(year)],cwd=B,text=True,capture_output=True,timeout=180)
            row={"year":year,"kind":kind,"result":"PASS" if proc.returncode==0 else "FAIL","returnCode":proc.returncode,"stdout":proc.stdout[-2000:],"stderr":proc.stderr[-4500:]}
        except Exception as e:
            row={"year":year,"kind":kind,"result":"FAIL","error":repr(e)}
        outputs.append(row)
        print(json.dumps({"year":year,"kind":kind,"result":row["result"]},ensure_ascii=False),flush=True)
        if row["result"]=="FAIL":print(row.get("stderr",row.get("error","")),file=sys.stderr)
report={"updatedAtUtc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "status":"PASS" if len(outputs)==10 and all(x["result"]=="PASS" for x in outputs) else "FAIL",
        "results":outputs}
(B/"RUBY_PIPELINE_DIAGNOSTICS.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
sys.exit(0 if report["status"]=="PASS" else 1)
