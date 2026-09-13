#!/usr/bin/env python3
"""Read-only canonical platform probe for APP COMPLETION FACTORY."""
from __future__ import annotations
import json, os, urllib.error, urllib.parse, urllib.request
from datetime import datetime, timezone
from pathlib import Path
from app_store_connect_api import api_get, load_private_key, make_token
APPS={
 "touhan":("6802119268","com.allsunday1122.tourokuhanbaisha"),
 "hm2":("6799751657","jp.allsunday1122.healthmanager2"),
 "hm1":("6799581662","jp.allsunday1122.healthmanager1"),
 "pharmacist":("6799753724","jp.allsunday1122.yakuzaishi"),
}
REPOSITORY="ALLSUNDAY1122/ALLSUNDAY1122.github.io"; OUT=Path(os.environ.get("FACTORY_PLATFORM_RESULT","factory-platform-readback.json"))
SENSITIVE=("secret","token","password","credential","private","environment","variable")
def sanitize(v):
    if isinstance(v,dict): return {k:("[REDACTED]" if any(x in str(k).lower() for x in SENSITIVE) else sanitize(x)) for k,x in v.items()}
    if isinstance(v,list): return [sanitize(x) for x in v]
    return v
def cm_get(url,token):
    req=urllib.request.Request(url,method="GET",headers={"x-auth-token":token,"Accept":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            raw=r.read().decode(); return r.status,json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw=e.read().decode(errors="replace")
        try: body=json.loads(raw) if raw else {}
        except Exception: body={"error":raw[:1000]}
        return e.code,body
def list_data(payload):
    d=payload.get("data",[]) if isinstance(payload,dict) else []
    return d if isinstance(d,list) else ([] if d is None else [d])
def main():
    result={"completed_at":datetime.now(timezone.utc).isoformat(),"read_only":True,"testflight":{},"codemagic":{}}
    kp,cleanup=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],kp)
        for label,(app_id,bundle_id) in APPS.items():
            entry={"app_id":app_id,"bundle_id":bundle_id}
            for name,path in {"builds":f"/v1/apps/{app_id}/builds?sort=-uploadedDate&limit=20","beta_groups":f"/v1/apps/{app_id}/betaGroups?limit=50","beta_localizations":f"/v1/apps/{app_id}/betaAppLocalizations?limit=50"}.items():
                try: status,body=api_get(token,path); entry[name]={"http_status":status,"body":body}
                except Exception as exc: entry[name]={"error":str(exc)[:600]}
            builds=list_data((entry.get("builds") or {}).get("body") or {})
            latest=builds[0].get("attributes",{}) if builds else {}
            entry["summary"]={"latest_build":latest.get("version"),"latest_processing_state":latest.get("processingState"),"latest_expired":latest.get("expired"),"beta_group_count":len(list_data((entry.get("beta_groups") or {}).get("body") or {}))}
            result["testflight"][label]=entry
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)
    cm_token=os.environ.get("CM_API_TOKEN","").strip()
    if not cm_token: result["codemagic"]={"error":"CM_API_TOKEN unavailable"}
    else:
        status,apps=cm_get("https://api.codemagic.io/apps",cm_token); candidates=[]
        if 200<=status<300:
            raw=(apps.get("applications") or apps.get("data") or []) if isinstance(apps,dict) else []
            if isinstance(raw,dict): raw=raw.get("applications") or []
            needle=REPOSITORY.lower()
            for app in raw:
                serialized=json.dumps(app,ensure_ascii=False).lower().replace(".git","")
                if needle in serialized or needle.split("/")[-1] in serialized:
                    candidates.append({"id":app.get("_id") or app.get("id"),"name":app.get("appName") or app.get("name"),"repositoryUrl":app.get("repositoryUrl") or app.get("repository_url") or app.get("repoUrl")})
        result["codemagic"].update({"apps_http_status":status,"repository_candidates":candidates})
        if candidates:
            app_id=candidates[0].get("id"); bstatus,builds=cm_get(f"https://api.codemagic.io/builds?appId={urllib.parse.quote(str(app_id))}",cm_token)
            clean=sanitize(builds); result["codemagic"].update({"builds_http_status":bstatus,"builds":clean})
            arr=(builds.get("builds") or builds.get("data") or []) if isinstance(builds,dict) else []
            if isinstance(arr,dict): arr=arr.get("builds") or []
            if arr:
                b=arr[0]; result["codemagic"]["latest_summary"]={k:b.get(k) for k in ("_id","id","status","workflowId","branch","startedAt","finishedAt")}
    OUT.write_text(json.dumps(sanitize(result),ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    summary={"completed_at":result["completed_at"],"testflight":{k:v.get("summary") for k,v in result["testflight"].items()},"codemagic_apps_http":result["codemagic"].get("apps_http_status"),"codemagic_builds_http":result["codemagic"].get("builds_http_status"),"codemagic_candidates":len(result["codemagic"].get("repository_candidates") or []),"codemagic_latest":result["codemagic"].get("latest_summary")}
    print(json.dumps(summary,ensure_ascii=False))
    if result["codemagic"].get("apps_http_status")!=200: raise SystemExit("Codemagic fresh readback failed")
if __name__=="__main__": main()
