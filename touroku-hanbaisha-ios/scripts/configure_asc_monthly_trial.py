#!/usr/bin/env python3
"""Idempotently ensure the JPN monthly subscription has a one-week free introductory offer."""
import datetime,json,os,urllib.error,urllib.request,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
from app_store_connect_api import BASE_URL,load_private_key,make_token
APP_ID="6802119268"
BUNDLE_ID="com.allsunday1122.tourokuhanbaisha"
SUB_ID="6838742389"
PRODUCT_ID="com.allsunday1122.tourokuhanbaisha.premium.monthly"
JPN="JPN"
OUT=ROOT/"touroku-hanbaisha-ios/ASC_MONTHLY_TRIAL_READBACK_20261126.json"
def request(token,path,method="GET",payload=None):
    body=None if payload is None else json.dumps(payload,ensure_ascii=False,separators=(",",":")).encode()
    req=urllib.request.Request(BASE_URL+path,data=body,method=method,headers={"Authorization":f"Bearer {token}","Accept":"application/json","Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=30) as response:
            raw=response.read()
            return response.status,json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"ASC {method} {path} HTTP {exc.code}: {exc.read().decode('utf-8','replace')[:2000]}") from None
def rows(payload):
    d=(payload or {}).get("data",[])
    return d if isinstance(d,list) else ([d] if d else [])
def matching_offer(token):
    _,payload=request(token,f"/v1/subscriptions/{SUB_ID}/introductoryOffers?filter[territory]={JPN}&include=territory&limit=200")
    for offer in rows(payload):
        attrs=offer.get("attributes") or {}
        territory=((((offer.get("relationships") or {}).get("territory") or {}).get("data")) or {}).get("id")
        if territory==JPN and attrs.get("offerMode")=="FREE_TRIAL" and attrs.get("duration")=="ONE_WEEK" and int(attrs.get("numberOfPeriods") or 0)==1:
            return offer
    return None
def main():
    issuer=os.environ.get("ASC_ISSUER_ID");key_id=os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id: raise SystemExit("ASC credentials missing")
    key,cleanup=load_private_key()
    result={"status":"BLOCKED","appId":APP_ID,"bundleId":BUNDLE_ID,"subscriptionId":SUB_ID,"productId":PRODUCT_ID,
      "territory":JPN,"expected":{"offerMode":"FREE_TRIAL","duration":"ONE_WEEK","numberOfPeriods":1},"changed":False}
    try:
        token=make_token(issuer,key_id,key)
        _,app=request(token,f"/v1/apps/{APP_ID}")
        assert ((app.get("data") or {}).get("attributes") or {}).get("bundleId")==BUNDLE_ID,"App bundle mismatch"
        _,sub=request(token,f"/v1/subscriptions/{SUB_ID}")
        attrs=((sub.get("data") or {}).get("attributes") or {})
        assert attrs.get("productId")==PRODUCT_ID,f"Subscription product mismatch: {attrs.get('productId')!r}"
        assert attrs.get("subscriptionPeriod")=="ONE_MONTH",f"Subscription period mismatch: {attrs.get('subscriptionPeriod')!r}"
        offer=matching_offer(token)
        if offer is None:
            payload={"data":{"type":"subscriptionIntroductoryOffers","attributes":{
              "startDate":datetime.datetime.now(datetime.timezone.utc).date().isoformat(),
              "duration":"ONE_WEEK","offerMode":"FREE_TRIAL","numberOfPeriods":1},
              "relationships":{"subscription":{"data":{"type":"subscriptions","id":SUB_ID}},
                               "territory":{"data":{"type":"territories","id":JPN}}}}}
            code,created=request(token,"/v1/subscriptionIntroductoryOffers","POST",payload)
            assert 200<=code<300
            result["changed"]=True
            result["createHttpStatus"]=code
            result["offerId"]=(created.get("data") or {}).get("id")
        offer=matching_offer(token)
        assert offer is not None,"JPN one-week free trial did not read back"
        a=offer.get("attributes") or {}
        result.update({"status":"PASS","offerId":offer.get("id"),"readback":{
          "offerMode":a.get("offerMode"),"duration":a.get("duration"),
          "numberOfPeriods":a.get("numberOfPeriods"),"startDate":a.get("startDate"),
          "endDate":a.get("endDate")},"verified":a.get("offerMode")=="FREE_TRIAL" and a.get("duration")=="ONE_WEEK" and int(a.get("numberOfPeriods") or 0)==1})
        assert result["verified"]
        OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
        print(json.dumps(result,ensure_ascii=False))
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)
if __name__=="__main__": main()
