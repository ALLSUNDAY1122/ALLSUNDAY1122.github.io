#!/usr/bin/env python3
"""Read-only Codemagic and ASC Q7 evidence. No certificates/secrets are printed."""
import datetime,json,os,sys,urllib.request,urllib.parse,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
from app_store_connect_api import api_get,load_private_key,make_token
APP="6a769d81a1add9d06020b524"
ASC="6802119268"
OUT=ROOT/"touroku-hanbaisha-ios/Q7_CODEMAGIC_PREP_20261124.json"
def cm(path,token):
    req=urllib.request.Request("https://api.codemagic.io"+path,headers={"x-auth-token":token,"Accept":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=35) as f:return f.status,json.loads(f.read().decode())
    except urllib.error.HTTPError as e:
        return e.code,{"errorCode":e.code}
def rows(data,key):
    v=data.get(key) or data.get("data") or []
    if isinstance(v,dict):v=v.get(key,[])
    return v if isinstance(v,list) else []
def main():
    stamp=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat()
    result={"schema":"touhan-q7-codemagic-inspect-v1","asOfJST":stamp,"cmAppId":APP,
      "ascAppId":ASC,"bundleId":"com.allsunday1122.tourokuhanbaisha",
      "cmApiRead":"NOT_RUN","ascRead":"NOT_RUN","workflowId":"touhan-ios",
      "signedIpaForCurrentHead":"NOT_VERIFIED","testFlightBuildCurrentHead":"NOT_VERIFIED",
      "humanGates":[],"automaticAppReviewSubmission":False}
    token=os.environ.get("CM_API_TOKEN","").strip()
    if not token:result["cmApiRead"]="BLOCKED_MISSING_CM_API_TOKEN";result["humanGates"].append("Codemagic API access must be configured")
    else:
        code,apps=cm("/apps",token)
        result["cmAppsHttpStatus"]=code
        if code==200:
            apps_rows=rows(apps,"applications")
            result["cmApiRead"]="PASS"
            result["cmAppPresent"]=any(str(x.get("_id") or x.get("id"))==APP for x in apps_rows)
            code,builds=cm("/builds?appId="+urllib.parse.quote(APP),token)
            result["cmBuildsHttpStatus"]=code
            if code==200:
                matching=[x for x in rows(builds,"builds") if str(x.get("fileWorkflowId") or x.get("workflowId")) in ("touhan-ios","touhan-testflight-preflight")]
                matching.sort(key=lambda x:str(x.get("startedAt") or x.get("createdAt") or ""),reverse=True)
                result["recentTouhanBuilds"]=[{k:x.get(k) for k in ("_id","status","workflowId","fileWorkflowId","branch","startedAt","finishedAt","buildVersion","buildNumber") if k in x} for x in matching[:8]]
                result["cmWorkflowHistoryCount"]=len(matching)
        else:result["cmApiRead"]="FAIL"
    if all(os.environ.get(x) for x in ("ASC_ISSUER_ID","ASC_KEY_ID")) and (os.environ.get("ASC_PRIVATE_KEY") or os.environ.get("ASC_PRIVATE_KEY_PATH")):
        key,cleanup=load_private_key()
        try:
            asc_token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
            status,data=api_get(asc_token,f"/v1/apps/{ASC}/builds?limit=60")
            result["ascBuildHttpStatus"]=status
            if status==200:
                result["ascRead"]="PASS"
                result["recentAscBuilds"]=[{"id":x.get("id"),"version":(x.get("attributes") or {}).get("version"),"processingState":(x.get("attributes") or {}).get("processingState"),"uploadedDate":(x.get("attributes") or {}).get("uploadedDate")}
                    for x in (data.get("data") or [])[:10]]
            else:result["ascRead"]="FAIL"
        finally:
            if cleanup:cleanup.unlink(missing_ok=True)
    else:result["ascRead"]="BLOCKED_MISSING_KEY";result["humanGates"].append("App Store Connect API key must be configured")
    result["gate"]="PENDING_SIGNED_IPA" if result["cmApiRead"]=="PASS" and result["ascRead"]=="PASS" else "BLOCKED_API_ACCESS"
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({k:v for k,v in result.items() if k not in ("recentAscBuilds","recentTouhanBuilds")},ensure_ascii=False))
if __name__=="__main__":main()
