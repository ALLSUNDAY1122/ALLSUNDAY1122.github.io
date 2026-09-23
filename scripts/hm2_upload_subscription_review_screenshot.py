#!/usr/bin/env python3
"""Upload and verify the audited HM2 paywall screenshot for the monthly subscription."""
from __future__ import annotations
import hashlib, json, os, time, urllib.error, urllib.request
from pathlib import Path
from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID="6799751657"
BUNDLE_ID="jp.allsunday1122.healthmanager2"
SUB_ID="6802988571"
PRODUCT_ID="jp.allsunday1122.healthmanager2.monthly"
OUT=Path("hm2-subscription-review-screenshot-result.json")

def req(token,path,method="GET",payload=None,allow404=False):
    body=None if payload is None else json.dumps(payload,ensure_ascii=False,separators=(",",":")).encode()
    r=urllib.request.Request(BASE_URL+path,data=body,method=method,headers={"Authorization":f"Bearer {token}","Accept":"application/json","Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r,timeout=60) as x:
            raw=x.read(); return x.status,(json.loads(raw.decode()) if raw else {})
    except urllib.error.HTTPError as e:
        if allow404 and e.code==404: return 404,{}
        raw=e.read().decode("utf-8","replace")
        raise RuntimeError(f"ASC {method} {path} HTTP {e.code}: {raw[:3000]}") from e

def state(resource):
    return (((resource or {}).get("attributes") or {}).get("assetDeliveryState") or {}).get("state")

def upload_parts(resource,path:Path):
    raw=path.read_bytes(); ops=((resource.get("attributes") or {}).get("uploadOperations") or [])
    if not ops: raise RuntimeError("ASC returned no upload operations")
    for op in ops:
        off=int(op.get("offset",0)); length=int(op.get("length",0)); chunk=raw[off:off+length]
        if len(chunk)!=length: raise RuntimeError("upload range mismatch")
        headers={str(h["name"]):str(h["value"]) for h in (op.get("requestHeaders") or []) if h.get("name")}
        u=urllib.request.Request(op["url"],data=chunk,method=op.get("method","PUT"),headers=headers)
        with urllib.request.urlopen(u,timeout=120) as x: x.read()

def wait_complete(token,rid,timeout=240):
    deadline=time.time()+timeout; last=None
    while time.time()<deadline:
        _,p=req(token,f"/v1/subscriptionAppStoreReviewScreenshots/{rid}")
        resource=p.get("data") or {}; last=state(resource)
        if last=="COMPLETE": return resource
        if last in {"FAILED","UPLOAD_FAILED"}: raise RuntimeError(f"review screenshot failed: {last}")
        time.sleep(5)
    raise RuntimeError(f"review screenshot timeout; last={last}")

def main():
    shot=Path(os.environ.get("HM2_SUB_REVIEW_SCREENSHOT","")); result={"app_id":APP_ID,"subscription_id":SUB_ID,"ok":False}; cleanup=None
    try:
        if not shot.is_file() or shot.suffix.lower()!=".png" or shot.stat().st_size<=0: raise RuntimeError("audited PNG is required")
        issuer=os.environ.get("ASC_ISSUER_ID"); keyid=os.environ.get("ASC_KEY_ID")
        if not issuer or not keyid: raise RuntimeError("missing ASC credentials")
        kp,cleanup=load_private_key(); token=make_token(issuer,keyid,kp)
        _,app=req(token,f"/v1/apps/{APP_ID}"); aa=(app.get("data") or {}).get("attributes") or {}
        if aa.get("bundleId")!=BUNDLE_ID: raise RuntimeError("HM2 app identity mismatch")
        _,sub=req(token,f"/v1/subscriptions/{SUB_ID}"); sa=(sub.get("data") or {}).get("attributes") or {}
        if sa.get("productId")!=PRODUCT_ID or sa.get("subscriptionPeriod")!="ONE_MONTH": raise RuntimeError("monthly subscription identity/type mismatch")
        status,current=req(token,f"/v1/subscriptions/{SUB_ID}/appStoreReviewScreenshot",allow404=True)
        if status==200 and current.get("data"):
            r=current["data"]
            if state(r)!="COMPLETE": raise RuntimeError(f"existing monthly screenshot not COMPLETE: {state(r)}")
            result.update({"ok":True,"changed":False,"screenshot_id":str(r["id"]),"state":"COMPLETE"})
        else:
            payload={"data":{"type":"subscriptionAppStoreReviewScreenshots","attributes":{"fileSize":shot.stat().st_size,"fileName":"hm2-premium-review.png"},"relationships":{"subscription":{"data":{"type":"subscriptions","id":SUB_ID}}}}}
            _,created=req(token,"/v1/subscriptionAppStoreReviewScreenshots","POST",payload)
            r=created.get("data") or {}; rid=str(r.get("id") or "")
            if not rid: raise RuntimeError("ASC did not return monthly review screenshot id")
            upload_parts(r,shot)
            checksum=hashlib.md5(shot.read_bytes()).hexdigest()
            req(token,f"/v1/subscriptionAppStoreReviewScreenshots/{rid}","PATCH",{"data":{"type":"subscriptionAppStoreReviewScreenshots","id":rid,"attributes":{"uploaded":True,"sourceFileChecksum":checksum}}})
            wait_complete(token,rid)
            _,rb=req(token,f"/v1/subscriptions/{SUB_ID}/appStoreReviewScreenshot")
            rd=rb.get("data") or {}
            if str(rd.get("id") or "")!=rid or state(rd)!="COMPLETE": raise RuntimeError("monthly review screenshot readback mismatch")
            result.update({"ok":True,"changed":True,"screenshot_id":rid,"state":"COMPLETE","file_size":shot.stat().st_size})
    except Exception as e:
        result["error"]=str(e)[:4000]; raise
    finally:
        OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(result,ensure_ascii=False))
        if cleanup: cleanup.unlink(missing_ok=True)

if __name__=="__main__": main()
