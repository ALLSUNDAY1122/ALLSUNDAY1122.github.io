#!/usr/bin/env python3
"""Inspect only the exact Codemagic auto-provision build; no side effects."""
import datetime,json,os,urllib.request,re
from pathlib import Path
APP="6a769d81a1add9d06020b524"
BUILD="6b04cf7092306a39e3981ca4"
OUT=Path("touroku-hanbaisha-ios/Q7_ENV_SIGNING_ATTEMPT2_RESULT_20261124.json")
def red(x):
    if isinstance(x,str):
        x=re.sub(r'eyJ[A-Za-z0-9._-]{20,}','[JWT_REDACTED]',x)
        return x[:500]
    return x
def main():
    tok=os.environ["CM_API_TOKEN"]
    req=urllib.request.Request("https://api.codemagic.io/builds?appId="+APP,
        headers={"x-auth-token":tok,"Accept":"application/json"})
    with urllib.request.urlopen(req,timeout=40) as f:data=json.loads(f.read())
    rows=data.get("builds") or data.get("data") or []
    if isinstance(rows,dict):rows=rows.get("builds") or []
    build=next((x for x in rows if str(x.get("_id") or x.get("id"))==BUILD),None)
    if not build:raise RuntimeError("Build unavailable in API readback")
    acts=build.get("buildActions") or build.get("actions") or []
    steps=[{"name":red(str(a.get("name") or a.get("type") or "")), "status":str(a.get("status") or ""), "type":str(a.get("type") or "")}
       for a in acts if isinstance(a,dict)]
    arts=build.get("artefacts") or build.get("artifacts") or []
    arts_list=[{"type":str(a.get("type") or ""), "fileName":red(str(a.get("name") or a.get("fileName") or a.get("path") or ""))}
       for a in arts if isinstance(a,dict)]
    state=str(build.get("status","unknown")).lower()
    valid_steps=any("verify app store signing" in q["name"].lower() and q["status"].lower() in ("success","finished","passed") for q in steps)
    ipa_present=any(".ipa" in str(a).lower() for a in arts_list)
    gate="SIGNED_IPA_VERIFIED" if state in ("finished","success","succeeded") and valid_steps and ipa_present else ("FAILED" if state in ("failed","error","cancelled") else "PENDING")
    result={"schema":"touhan-q7-auto-provision-readback-v1",
      "readAtJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
      "buildId":BUILD,"appId":APP,"workflow":"touhan-q7-auto-provision",
      "status":state,"message":red(str(build.get("message") or "")),
      "startedAt":build.get("startedAt"),"finishedAt":build.get("finishedAt"),
      "stepResults":steps,"artifactSummaries":arts_list,"gate":gate,
      "appStoreConnectUpload":False,"testflightDistributed":False,"appReviewSubmitted":False,
      "codemagicUrl":"https://codemagic.io/app/"+APP+"/build/"+BUILD,
      "limits":["No Apple 2FA, agreement or physical-device actions were performed.",
                "Only a verified signed IPA can advance the signing gate; Q7 requires further TestFlight evidence."]}
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"gate":gate,"status":state,"message":result["message"],"steps":steps[-8:],"artifacts":arts_list[-5:]},ensure_ascii=False))
if __name__=="__main__":main()
