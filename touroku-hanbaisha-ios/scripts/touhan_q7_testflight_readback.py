#!/usr/bin/env python3
"""Poll one exact Codemagic build, verify its signed IPA, then read back TestFlight processing and internal group assignment."""
import datetime,json,os,time,urllib.parse,urllib.request,urllib.error,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
IOS=ROOT/"touroku-hanbaisha-ios"
START=IOS/"Q7_CODEMAGIC_SIGNING_BUILD_20261125.json"
OUT=IOS/"Q7_TESTFLIGHT_READBACK_20261125.json"
CM_APP="6a769d81a1add9d06020b524"
ASC_APP="6802119268"
BUNDLE="com.allsunday1122.tourokuhanbaisha"
BRANCH=os.environ.get("GITHUB_REF_NAME","integration/explanation-ui-20261125")
sys.path.insert(0,str(ROOT/"scripts"))
from app_store_connect_api import api_get,api_request,load_private_key,make_token

def cm_get(path,token):
    req=urllib.request.Request("https://api.codemagic.io"+path,headers={"x-auth-token":token,"Accept":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=40) as f:return f.status,json.loads(f.read().decode())
    except urllib.error.HTTPError as e:return e.code,{"error":e.read().decode(errors="replace")[:500]}
def asc_get(token,path):
    code,data=api_get(token,path)
    if not 200<=code<300:raise RuntimeError(f"ASC GET {path} HTTP {code}: {str(data)[:300]}")
    return data
def asc_request(token,path,method,payload):
    code,data=api_request(token,path,method=method,payload=payload)
    if not 200<=code<300:raise RuntimeError(f"ASC {method} {path} HTTP {code}: {str(data)[:300]}")
    return data
def rows(data,key="data"):
    x=(data or {}).get(key,[])
    return x if isinstance(x,list) else ([x] if x else [])
def main():
    stamp=lambda:datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat()
    result={"schema":"touhan-q7-testflight-readback-v1","startedAtJST":stamp(),"status":"BLOCKED",
      "signedIpaVerified":False,"ascProcessingState":"NOT_FOUND","testFlightAvailable":False,
      "testFlightDistributed":False,"appReviewSubmitted":False,"branch":BRANCH,"bundleId":BUNDLE}
    token=os.environ.get("CM_API_TOKEN","").strip()
    if not token:raise RuntimeError("CM_API_TOKEN missing")
    start=json.loads(START.read_text())
    if not start.get("ok") or start.get("workflow_id")!="touhan-ios" or start.get("branch")!=BRANCH:
        raise RuntimeError("Codemagic release-candidate start record does not match the intended workflow/branch")
    build_id=start["build_id"]
    result.update({"codemagicAppId":CM_APP,"codemagicBuildId":build_id,"codemagicBuildUrl":start.get("build_url")})
    deadline=time.time()+70*60
    build=None
    while time.time()<deadline:
        code,payload=cm_get("/builds?appId="+urllib.parse.quote(CM_APP),token)
        if code!=200:raise RuntimeError(f"Codemagic build list HTTP {code}")
        candidates=payload.get("builds") or payload.get("data") or []
        if isinstance(candidates,dict):candidates=candidates.get("builds",[])
        build=next((x for x in candidates if str(x.get("_id") or x.get("id"))==str(build_id)),None)
        if build:
            state=str(build.get("status") or "UNKNOWN").lower()
            result["codemagicStatus"]=state
            if state in ("finished","success","succeeded","passed"):break
            if state in ("failed","error","cancelled","canceled"):break
        time.sleep(30)
    if not build:raise RuntimeError("Exact Codemagic build ID not found before timeout")
    # The Codemagic REST API uses the original field names buildActions,
    # artefacts and index; accept the newer aliases as well, without weakening
    # any release assertions.
    detail_code,detail=cm_get("/builds/"+urllib.parse.quote(str(build_id),safe=""),token)
    if detail_code==200 and isinstance(detail,dict):
        build=detail.get("build") or detail.get("data") or detail
    actions=build.get("buildActions") or build.get("actions") or []
    steps=[{"name":str(x.get("name") or x.get("type") or "")[:180],"status":str(x.get("status") or "UNKNOWN").lower()}
      for x in actions if isinstance(x,dict)]
    artifacts=build.get("artefacts") or build.get("artifacts") or []
    artifact_names=[str(x.get("name") or x.get("fileName") or x.get("filename") or x.get("path") or "") for x in artifacts if isinstance(x,dict)]
    artifact_types=[str(x.get("type") or "").lower() for x in artifacts if isinstance(x,dict)]
    signed_step=next((x for x in steps if x["name"]=="Verify signed IPA contains offline 599 bank, explanations and privacy manifest"),None)
    upload_step=next((x for x in steps if x["name"]=="Upload signed release candidate IPA to App Store Connect"),None)
    version=build.get("version") if isinstance(build.get("version"),dict) else {}
    build_number=str(build.get("buildNumber") or build.get("index") or version.get("buildNumber") or version.get("index") or "")
    build_branch=build.get("branch")
    if isinstance(build_branch,dict): build_branch=build_branch.get("name") or build_branch.get("branch")
    result.update({"codemagicBranch":build_branch,"codemagicBuildNumber":build_number,
      "codemagicSteps":steps,"artifactNames":artifact_names,"artifactTypes":artifact_types,
      "codemagicDetailHttpStatus":detail_code})
    ipa_present=any(x.lower().endswith(".ipa") for x in artifact_names) or "ipa" in artifact_types
    signed=(str(build.get("status","")).lower() in ("finished","success","succeeded","passed")
      and ipa_present
      and signed_step is not None and signed_step["status"] in ("success","finished","passed")
      and upload_step is not None and upload_step["status"] in ("success","finished","passed")
      and build_branch==BRANCH)
    result["signedIpaVerified"]=signed
    if not signed:raise RuntimeError("Codemagic build did not prove signed IPA verification and ASC upload step success")
    build_number=result["codemagicBuildNumber"]
    if not build_number:raise RuntimeError("Codemagic build number missing; cannot uniquely match ASC build")
    key,cleanup=load_private_key()
    try:
        asc_token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
        asc_build=None
        asc_deadline=time.time()+25*60
        while time.time()<asc_deadline:
            data=asc_get(asc_token,f"/v1/apps/{ASC_APP}/builds?limit=100")
            asc_build=next((x for x in rows(data) if str((x.get("attributes") or {}).get("version",""))==build_number),None)
            if asc_build:
                state=str((asc_build.get("attributes") or {}).get("processingState") or "UNKNOWN")
                result["ascProcessingState"]=state
                if state in ("VALID","INVALID","FAILED","EXPIRED"):break
            time.sleep(30)
        if not asc_build:raise RuntimeError("Exact uploaded ASC build number not found after Codemagic publish")
        attrs=asc_build.get("attributes") or {}
        result.update({"ascBuildId":asc_build.get("id"),"ascBuildVersion":attrs.get("version"),
          "ascUploadedDate":attrs.get("uploadedDate"),"ascProcessingState":attrs.get("processingState")})
        if attrs.get("processingState")!="VALID":
            raise RuntimeError("App Store Connect processing state is not VALID")
        result["testFlightAvailable"]=True
        groups=rows(asc_get(asc_token,f"/v1/apps/{ASC_APP}/betaGroups?limit=100"))
        internal=[]
        for group in groups:
            ga=group.get("attributes") or {}
            if ga.get("isInternalGroup") is True:
                testers=rows(asc_get(asc_token,f"/v1/betaGroups/{group['id']}/betaTesters?limit=100"))
                if testers:internal.append({"id":group["id"],"name":ga.get("name",""),"testerCount":len(testers)})
        result["internalGroupsWithTesters"]=internal
        if len(internal)==1:
            group=internal[0]
            current=rows(asc_get(asc_token,f"/v1/betaGroups/{group['id']}/builds?limit=100"))
            if not any(x.get("id")==asc_build.get("id") for x in current):
                asc_request(asc_token,f"/v1/betaGroups/{group['id']}/relationships/builds","POST",
                  {"data":[{"type":"builds","id":asc_build["id"]}]})
            readback=rows(asc_get(asc_token,f"/v1/betaGroups/{group['id']}/builds?limit=100"))
            result["testFlightDistributed"]=any(x.get("id")==asc_build.get("id") for x in readback)
            result["assignedInternalGroup"]={"name":group["name"],"testerCount":group["testerCount"]}
        else:
            result["testFlightDistributed"]=False
            result["groupSelectionRequired"]=True
            result["groupSelectionReason"]="No internal beta group with testers" if not internal else "Multiple internal beta groups with testers; no group selected automatically"
        result["status"]="PASS" if result["testFlightDistributed"] else "BLOCKED_INTERNAL_GROUP"
    finally:
        if cleanup:cleanup.unlink(missing_ok=True)
    result["completedAtJST"]=stamp()
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({k:v for k,v in result.items() if k not in ("codemagicSteps","artifactNames","internalGroupsWithTesters")},ensure_ascii=False))
    if result["status"]!="PASS":raise SystemExit("Q7 uploaded build is not assigned to a verified internal TestFlight group")
if __name__=="__main__":
    try:main()
    except Exception as exc:
        partial={"schema":"touhan-q7-testflight-readback-v1","timestampJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
          "status":"FAIL","error":str(exc)[:800],"signedIpaVerified":False,"ascProcessingState":"NOT_VERIFIED",
          "testFlightAvailable":False,"testFlightDistributed":False,"appReviewSubmitted":False}
        OUT.write_text(json.dumps(partial,ensure_ascii=False,indent=2)+"\n")
        print(json.dumps(partial,ensure_ascii=False))
        raise
