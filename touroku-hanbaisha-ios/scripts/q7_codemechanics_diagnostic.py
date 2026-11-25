#!/usr/bin/env python3
"""Read-only exact Codemagic build diagnostics. Never uploads or changes ASC/TestFlight."""
import datetime,json,os,time,urllib.parse,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
IOS=ROOT/"touroku-hanbaisha-ios"
START=IOS/"Q7_CODEMAGIC_SIGNING_BUILD_20261125.json"
OUT=IOS/"Q7_CODEMAGIC_DIAGNOSTIC_20261125.json"
APP="6a769d81a1add9d06020b524"
def get(token,path):
    req=urllib.request.Request("https://api.codemagic.io"+path,headers={"x-auth-token":token,"Accept":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=40) as f:return f.status,json.loads(f.read().decode())
    except urllib.error.HTTPError as e:return e.code,{"error":e.read().decode(errors="replace")[:500]}
def main():
    start=json.loads(START.read_text())
    token=os.environ.get("CM_API_TOKEN","").strip()
    if not token:raise RuntimeError("CM_API_TOKEN missing")
    bid=start["build_id"]
    deadline=time.time()+60*60
    build=None
    while time.time()<deadline:
        code,payload=get(token,"/builds?appId="+urllib.parse.quote(APP))
        if code!=200:raise RuntimeError(f"Codemagic builds HTTP {code}")
        rows=payload.get("builds") or payload.get("data") or []
        if isinstance(rows,dict):rows=rows.get("builds",[])
        build=next((x for x in rows if str(x.get("_id") or x.get("id"))==bid),None)
        if build:
            status=str(build.get("status") or "UNKNOWN").lower()
            if status in ("finished","success","succeeded","passed","failed","error","cancelled","canceled"):break
        time.sleep(30)
    if not build:raise RuntimeError("Exact Codemagic build not found")
    detail_code,detail_payload=get(token,"/builds/"+urllib.parse.quote(bid))
    if detail_code==200 and isinstance(detail_payload.get("build"),dict): build=detail_payload["build"]
    actions=[]
    for a in build.get("buildActions") or build.get("actions") or []:
        if not isinstance(a,dict):continue
        actions.append({k:a.get(k) for k in ("name","type","status","message","error","exitCode","startedAt","finishedAt") if a.get(k) is not None})
    artifacts=[]
    for a in build.get("artefacts") or build.get("artifacts") or []:
        if isinstance(a,dict):artifacts.append({k:a.get(k) for k in ("name","fileName","filename","path","size","type","url") if a.get(k) is not None})
    result={"schema":"touhan-q7-codemagic-diagnostic-v1",
      "timestampJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
      "buildId":bid,"buildUrl":start.get("build_url"),"status":build.get("status"),
      "workflowId":build.get("fileWorkflowId") or build.get("workflowId"),"branch":build.get("branch"),
      "buildNumber":build.get("buildNumber"),"buildVersion":build.get("buildVersion"),
      "message":build.get("message"),"startedAt":build.get("startedAt"),"finishedAt":build.get("finishedAt"),
      "actions":actions,"artifacts":artifacts,"rawKeys":sorted(build.keys()),"buildDetailHttpStatus":detail_code}
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps(result,ensure_ascii=False))
if __name__=="__main__":
    try:main()
    except Exception as e:
        OUT.write_text(json.dumps({"schema":"touhan-q7-codemagic-diagnostic-v1","status":"FAIL","error":str(e)[:500]},ensure_ascii=False,indent=2))
        raise
