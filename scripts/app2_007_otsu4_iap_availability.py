#!/usr/bin/env python3
import json, os, urllib.error, urllib.request
from pathlib import Path
from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID='6799755566'; BUNDLE_ID='jp.allsunday1122.otsu4'; IAP_ID='6806477067'; JPN='JPN'
OUT=Path('automation/app2-007-otsu4-iap-availability-result.json')

def req(token,path,method='GET',payload=None,allow404=False):
    body=None if payload is None else json.dumps(payload,separators=(',',':')).encode()
    r=urllib.request.Request(BASE_URL+path,data=body,method=method,headers={'Authorization':'Bearer '+token,'Accept':'application/json','Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(r,timeout=45) as x:
            raw=x.read(); return x.status,json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as e:
        if allow404 and e.code==404: return 404,{}
        raw=e.read().decode('utf-8','replace'); raise RuntimeError(f'ASC {method} {path} HTTP {e.code}: {raw[:4000]}') from e

def main():
    cleanup=None; result={'task_id':'APP2-007','app_id':APP_ID,'bundle_id':BUNDLE_ID,'iap_id':IAP_ID,'ok':False}
    try:
        key,cleanup=load_private_key(); token=make_token(os.environ['ASC_ISSUER_ID'],os.environ['ASC_KEY_ID'],key)
        _,app=req(token,f'/v1/apps/{APP_ID}')
        if ((app.get('data') or {}).get('attributes') or {}).get('bundleId')!=BUNDLE_ID: raise RuntimeError('bundle mismatch')
        status,_=req(token,f'/v2/inAppPurchases/{IAP_ID}/inAppPurchaseAvailability',allow404=True)
        payload={'data':{'type':'inAppPurchaseAvailabilities','attributes':{'availableInNewTerritories':False},'relationships':{'availableTerritories':{'data':[{'type':'territories','id':JPN}]},'inAppPurchase':{'data':{'id':IAP_ID,'type':'inAppPurchases'}}}}}
        # Apple's endpoint is POST-based for both initial and modified territory availability.
        req(token,'/v1/inAppPurchaseAvailabilities','POST',payload)
        _,avail=req(token,f'/v1/inAppPurchaseAvailabilities/{IAP_ID}')
        _,territories=req(token,f'/v1/inAppPurchaseAvailabilities/{IAP_ID}/relationships/availableTerritories?limit=200')
        ids=[str(x.get('id')) for x in territories.get('data',[]) if x.get('id')]
        if JPN not in ids: raise RuntimeError(f'JPN availability read-back failed: {ids}')
        _,product=req(token,f'/v2/inAppPurchases/{IAP_ID}')
        result.update(ok=True,availability_existed_before=status==200,available_territories=ids,available_in_new_territories=((avail.get('data') or {}).get('attributes') or {}).get('availableInNewTerritories'),iap_state=((product.get('data') or {}).get('attributes') or {}).get('state'))
    except Exception as e:
        result['error']=str(e); raise
    finally:
        OUT.parent.mkdir(parents=True,exist_ok=True); OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(result,ensure_ascii=False))
        if cleanup:
            try: cleanup.unlink(missing_ok=True)
            except Exception: pass
if __name__=='__main__': main()
