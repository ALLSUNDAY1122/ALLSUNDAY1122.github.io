#!/usr/bin/env python3
"""Codemagic Q7 exact build ID verification, no secret disclosure or side effects."""
import datetime,json,os,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
APP="6a769d81a1add9d06020b524"
BUILD="6b04cd655586d806fe29abea"
OUT=ROOT/"touroku-hanbaisha-ios/Q7_SIGNED_IPA_RESULT_20261124.json"
def main():
    token=os.environ.get("CM_API_TOKEN","")
    if not token:raise RuntimeError("Missing CM_API_TOKEN for read-only inspection")
    request=urllib.request.Request(f"https://api.codemagic.io/builds?appId={APP}",
         headers={"x-auth-token":token,"Accept":"application/json"})
    with urllib.request.urlopen(request,timeout=45) as response:
        data=json.loads(response.read())
    rows=data.get("builds") or data.get("data") or []
    if isinstance(rows,dict):rows=rows.get("builds") or []
    match=next((x for x in rows if str(x.get("_id") or x.get("id"))==BUILD),None)
    if not match:raise RuntimeError(f"Exact Codemagic build ID {BUILD} not found, rows={len(rows)}")
    status=str(match.get("status") or "UNKNOWN")
    steps=[]
    for x in match.get("actions") or []:
        if not isinstance(x,dict):continue
        kind=str(x.get("type") or x.get("name") or "")
        steps.append({"name":str(x.get("name") or kind)[:130],"type":kind,"status":str(x.get("status") or "UNKNOWN")})
    artifacts=match.get("artifacts") or []
    ids=[]
    for a in artifacts:
        if not isinstance(a,dict):continue
        name=str(a.get("name") or a.get("fileName") or a.get("filename") or a.get("path") or "")
        ids.append({"name":name[:150],"extension":Path(name).suffix.lower()})
    status_lower=status.lower()
    successful=status_lower in ("finished","success","succeeded","passed")
    failed=status_lower in ("failed","error","cancelled","canceled")
    gate="SIGNED_IPA_VERIFIED" if successful and any(x["extension"]==".ipa" for x in ids) and any("verify signed ipa" in x["name"].lower() and x["status"].lower() in ("success","finished","passed") for x in steps) else ("BUILD_FAILED" if failed else "PENDING_VERIFICATION")
    result={"schema":"touhan-q7-codemagic-exact-build-v1","readAtJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
      "appId":APP,"buildId":BUILD,"workflowId":str(match.get("fileWorkflowId") or match.get("workflowId")),
      "branch":match.get("branch"),"status":status,"startedAt":match.get("startedAt"),"finishedAt":match.get("finishedAt"),
      "buildNumber":match.get("buildNumber"),"stepResults":steps,"artifactSummaries":ids,
      "gate":gate,"ipaUploadedToASC":False,"testflightDistributed":False,
      "evidence":"https://codemagic.io/app/"+APP+"/build/"+BUILD,
      "limitations":["Uploaded IPA, if ever requested, requires an independent ASC readback.","Build status alone does not prove signing unless verification step and IPA artifact are observed."]}
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"status":status,"gate":gate,"stepCount":len(steps),"artifacts":ids},ensure_ascii=False))
if __name__=="__main__":main()
