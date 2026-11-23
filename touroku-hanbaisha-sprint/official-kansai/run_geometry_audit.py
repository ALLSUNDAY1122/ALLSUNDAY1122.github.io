#!/usr/bin/env python3
"""Run each annual XY and alternative-PDF-engine check; persist explicit failures."""
import datetime,json,subprocess,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent
results=[]
for year in range(2022,2027):
    for phase,script in (("GEOMETRY", "geometry_second_gate.py"),("CROSSCHECK","crosscheck_pdfplumber.py")):
        try:
            p=subprocess.run([sys.executable,str(BASE/script),"--year",str(year)],cwd=BASE,capture_output=True,text=True,timeout=290)
            outcome={"year":year,"phase":phase,"status":"PASS" if p.returncode==0 else "FAIL",
                 "exitCode":p.returncode,"stdout":p.stdout[-4000:],"stderr":p.stderr[-5000:]}
        except Exception as exc:
            outcome={"year":year,"phase":phase,"status":"FAIL","error":repr(exc)}
        results.append(outcome)
        print(json.dumps({k:v for k,v in outcome.items() if k not in ("stdout","stderr")},ensure_ascii=False),flush=True)
        if outcome["status"]=="FAIL":
            print(outcome.get("stderr","")[-2200:],file=sys.stderr)
manifest={"updated_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "status":"PASS" if all(x["status"]=="PASS" for x in results) and len(results)==10 else "FAIL",
          "results":results}
(BASE/"GEOMETRY_PIPELINE_DIAGNOSTICS.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
if manifest["status"]!="PASS":
    print("Geometry / crosscheck not complete, all produced outputs remain staging",file=sys.stderr)
    sys.exit(1)
