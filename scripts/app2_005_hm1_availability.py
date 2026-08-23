#!/usr/bin/env python3
import json, os
from pathlib import Path
from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID='6799581662'
BUNDLE_ID='jp.allsunday1122.healthmanager1'
SUB_ID='6804373671'
IAP_ID='6799583540'
JPN='JPN'
OUT=Path('automation/app2-005-hm1-availability-result.json')


def preflight(token):
    _,app=api_get(token,f'/v1/apps/{APP_ID}')
    actual=(((app.get('data') or {}).get('attributes') or {}).get('bundleId'))
    if actual!=BUNDLE_ID:
        raise RuntimeError(f'bundle mismatch: {actual!r}')
    _,sub=api_get(token,f'/v1/subscriptions/{SUB_ID}')
    if (((sub.get('data') or {}).get('attributes') or {}).get('productId'))!='jp.allsunday1122.healthmanager1.monthly':
        raise RuntimeError('monthly product mismatch')
    _,iap=api_get(token,f'/v2/inAppPurchases/{IAP_ID}')
    if (((iap.get('data') or {}).get('attributes') or {}).get('productId'))!='jp.allsunday1122.healthmanager1.lifetime':
        raise RuntimeError('lifetime product mismatch')


def has_jpn(payload):
    return any(x.get('type')=='territories' and x.get('id')==JPN for x in (payload.get('included') or []) if isinstance(x,dict))


def ensure_subscription_availability(token,result):
    try:
        _,av=api_get(token,f'/v1/subscriptions/{SUB_ID}/subscriptionAvailability?include=availableTerritories&limit[availableTerritories]=50')
        if has_jpn(av):
            result['subscription_availability']={'changed':False,'jpn':True}
            return
    except RuntimeError as exc:
        if 'HTTP 404' not in str(exc):
            raise
    payload={'data':{'type':'subscriptionAvailabilities','attributes':{'availableInNewTerritories':False},'relationships':{'availableTerritories':{'data':[{'type':'territories','id':JPN}]},'subscription':{'data':{'type':'subscriptions','id':SUB_ID}}}}}
    status,_=api_request(token,'/v1/subscriptionAvailabilities',method='POST',payload=payload)
    result['subscription_availability']={'changed':True,'http_status':status,'jpn':True}


def ensure_iap_availability(token,result):
    try:
        _,av=api_get(token,f'/v1/inAppPurchaseAvailabilities/{IAP_ID}?include=availableTerritories&limit[availableTerritories]=50')
        if has_jpn(av):
            result['iap_availability']={'changed':False,'jpn':True}
            return
    except RuntimeError as exc:
        if 'HTTP 404' not in str(exc):
            raise
    payload={'data':{'type':'inAppPurchaseAvailabilities','attributes':{'availableInNewTerritories':False},'relationships':{'availableTerritories':{'data':[{'type':'territories','id':JPN}]},'inAppPurchase':{'data':{'type':'inAppPurchases','id':IAP_ID}}}}}
    status,_=api_request(token,'/v1/inAppPurchaseAvailabilities',method='POST',payload=payload)
    result['iap_availability']={'changed':True,'http_status':status,'jpn':True}


def screenshot_status(token,path):
    try:
        _,payload=api_get(token,path)
        data=payload.get('data') if isinstance(payload,dict) else None
        attrs=(data or {}).get('attributes') if isinstance(data,dict) else {}
        delivery=(attrs or {}).get('assetDeliveryState') or {}
        return {
            'present': isinstance(data,dict) and bool(data.get('id')),
            'id': data.get('id') if isinstance(data,dict) else None,
            'file_name': (attrs or {}).get('fileName'),
            'delivery_state': delivery.get('state') if isinstance(delivery,dict) else None,
        }
    except RuntimeError as exc:
        if 'HTTP 404' in str(exc):
            return {'present':False}
        raise


def main():
    issuer=os.environ.get('ASC_ISSUER_ID'); keyid=os.environ.get('ASC_KEY_ID')
    if not issuer or not keyid:
        raise SystemExit('missing ASC credentials')
    key_path,cleanup=load_private_key()
    result={'task_id':'APP2-005','app_id':APP_ID,'territory':JPN,'ok':False}
    try:
        token=make_token(issuer,keyid,key_path)
        preflight(token)
        ensure_subscription_availability(token,result)
        ensure_iap_availability(token,result)
        _,sub_av=api_get(token,f'/v1/subscriptions/{SUB_ID}/subscriptionAvailability?include=availableTerritories&limit[availableTerritories]=50')
        _,iap_av=api_get(token,f'/v1/inAppPurchaseAvailabilities/{IAP_ID}?include=availableTerritories&limit[availableTerritories]=50')
        _,sub=api_get(token,f'/v1/subscriptions/{SUB_ID}')
        _,iap=api_get(token,f'/v2/inAppPurchases/{IAP_ID}')
        result['subscription_availability_readback_jpn']=has_jpn(sub_av)
        result['iap_availability_readback_jpn']=has_jpn(iap_av)
        result['monthly_state']=(((sub.get('data') or {}).get('attributes') or {}).get('state'))
        result['lifetime_state']=(((iap.get('data') or {}).get('attributes') or {}).get('state'))
        result['monthly_review_screenshot']=screenshot_status(token,f'/v1/subscriptions/{SUB_ID}/appStoreReviewScreenshot')
        result['lifetime_review_screenshot']=screenshot_status(token,f'/v2/inAppPurchases/{IAP_ID}/appStoreReviewScreenshot')
        result['ok']=True
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__':
    main()
