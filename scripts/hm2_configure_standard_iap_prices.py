#!/usr/bin/env python3
"""Configure HM2 ordinary 1-month subscription + lifetime IAP for Japan.

Do not use SubscriptionPlanType.MONTHLY here: Apple's current plan type means
monthly payments over a 12-month commitment, which is not this product.
"""
import json, os
from pathlib import Path
from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID='6799751657'
BUNDLE_ID='jp.allsunday1122.healthmanager2'
SUB_ID='6802988571'
IAP_ID='6802989207'
JPN='JPN'


def items(x):
    d=x.get('data') if isinstance(x,dict) else None
    return d if isinstance(d,list) else ([d] if isinstance(d,dict) else [])


def pp_for(resp, price):
    for x in items(resp):
        if str((x.get('attributes') or {}).get('customerPrice')) == str(price): return x
    raise RuntimeError(f'price point {price} JPY not found')


def preflight(t):
    _,a=api_get(t,f'/v1/apps/{APP_ID}')
    assert (((a.get('data') or {}).get('attributes') or {}).get('bundleId'))==BUNDLE_ID
    _,s=api_get(t,f'/v1/subscriptions/{SUB_ID}')
    sa=(s.get('data') or {}).get('attributes') or {}
    assert sa.get('productId')=='jp.allsunday1122.healthmanager2.monthly'
    assert sa.get('subscriptionPeriod')=='ONE_MONTH'
    _,i=api_get(t,f'/v2/inAppPurchases/{IAP_ID}')
    assert (((i.get('data') or {}).get('attributes') or {}).get('productId'))=='jp.allsunday1122.healthmanager2.lifetime'


def ensure_sub_availability(t,r):
    try:
        _,av=api_get(t,f'/v1/subscriptions/{SUB_ID}/subscriptionAvailability?include=availableTerritories&limit[availableTerritories]=50')
        inc=av.get('included') or []
        if any(x.get('type')=='territories' and x.get('id')==JPN for x in inc):
            r['subscription_availability']={'changed':False,'jpn':True}; return
    except RuntimeError as e:
        if 'HTTP 404' not in str(e): raise
    payload={'data':{'type':'subscriptionAvailabilities','attributes':{'availableInNewTerritories':False},'relationships':{'availableTerritories':{'data':[{'type':'territories','id':JPN}]},'subscription':{'data':{'type':'subscriptions','id':SUB_ID}}}}}
    status,_=api_request(t,'/v1/subscriptionAvailabilities',method='POST',payload=payload)
    r['subscription_availability']={'changed':True,'http_status':status,'jpn':True}


def set_sub_price(t,r):
    ensure_sub_availability(t,r)
    _,points=api_get(t,f'/v1/subscriptions/{SUB_ID}/pricePoints?filter[territory]=JPN&include=territory&limit=200')
    p=pp_for(points,'200')
    _,cur=api_get(t,f'/v1/subscriptions/{SUB_ID}/prices?filter[territory]=JPN&include=subscriptionPricePoint,territory&limit=200')
    if any(((((x.get('relationships') or {}).get('subscriptionPricePoint') or {}).get('data') or {}).get('id'))==p['id'] and (x.get('attributes') or {}).get('startDate') is None for x in items(cur)):
        r['monthly_price']={'changed':False,'price':'200','price_point_id':p['id']}; return
    payload={'data':{'type':'subscriptionPrices','attributes':{'startDate':None},'relationships':{'subscription':{'data':{'type':'subscriptions','id':SUB_ID}},'subscriptionPricePoint':{'data':{'type':'subscriptionPricePoints','id':p['id']}}}}}
    status,res=api_request(t,'/v1/subscriptionPrices',method='POST',payload=payload)
    r['monthly_price']={'changed':True,'http_status':status,'price':'200','price_point_id':p['id'],'created_id':((res or {}).get('data') or {}).get('id')}


def ensure_iap_availability(t,r):
    try:
        _,av=api_get(t,f'/v1/inAppPurchaseAvailabilities/{IAP_ID}?include=availableTerritories&limit[availableTerritories]=50')
        inc=av.get('included') or []
        if any(x.get('type')=='territories' and x.get('id')==JPN for x in inc):
            r['iap_availability']={'changed':False,'jpn':True}; return
    except RuntimeError as e:
        if 'HTTP 404' not in str(e): raise
    payload={'data':{'type':'inAppPurchaseAvailabilities','attributes':{'availableInNewTerritories':False},'relationships':{'availableTerritories':{'data':[{'type':'territories','id':JPN}]},'inAppPurchase':{'data':{'type':'inAppPurchases','id':IAP_ID}}}}}
    status,_=api_request(t,'/v1/inAppPurchaseAvailabilities',method='POST',payload=payload)
    r['iap_availability']={'changed':True,'http_status':status,'jpn':True}


def set_iap_price(t,r):
    ensure_iap_availability(t,r)
    _,points=api_get(t,f'/v2/inAppPurchases/{IAP_ID}/pricePoints?filter[territory]=JPN&include=territory&limit=200')
    p=pp_for(points,'800')
    try:
        _,sch=api_get(t,f'/v2/inAppPurchases/{IAP_ID}/iapPriceSchedule?include=baseTerritory,manualPrices&limit[manualPrices]=50')
        if isinstance(sch.get('data'),dict):
            base=((((sch['data'].get('relationships') or {}).get('baseTerritory') or {}).get('data') or {}).get('id'))
            for x in sch.get('included') or []:
                if x.get('type')!='inAppPurchasePrices': continue
                pp=((((x.get('relationships') or {}).get('inAppPurchasePricePoint') or {}).get('data') or {}).get('id'))
                if base==JPN and pp==p['id'] and (x.get('attributes') or {}).get('startDate') is None:
                    r['lifetime_price']={'changed':False,'price':'800','price_point_id':p['id']}; return
    except RuntimeError as e:
        if 'HTTP 404' not in str(e): raise
    tmp='manualPrice-0'
    payload={'data':{'type':'inAppPurchasePriceSchedules','relationships':{'inAppPurchase':{'data':{'type':'inAppPurchases','id':IAP_ID}},'baseTerritory':{'data':{'type':'territories','id':JPN}},'manualPrices':{'data':[{'type':'inAppPurchasePrices','id':tmp}]}}},'included':[{'type':'inAppPurchasePrices','id':tmp,'attributes':{'startDate':None},'relationships':{'inAppPurchasePricePoint':{'data':{'type':'inAppPurchasePricePoints','id':p['id']}},'inAppPurchaseV2':{'data':{'type':'inAppPurchases','id':IAP_ID}}}}]}
    status,res=api_request(t,'/v1/inAppPurchasePriceSchedules',method='POST',payload=payload)
    r['lifetime_price']={'changed':True,'http_status':status,'price':'800','price_point_id':p['id'],'created_id':((res or {}).get('data') or {}).get('id')}


def main():
    issuer=os.environ.get('ASC_ISSUER_ID'); keyid=os.environ.get('ASC_KEY_ID')
    if not issuer or not keyid: raise SystemExit('missing ASC credentials')
    kp,cleanup=load_private_key(); r={'app_id':APP_ID,'territory':'JPN'}
    try:
        t=make_token(issuer,keyid,kp); preflight(t); set_sub_price(t,r); set_iap_price(t,r)
        _,r['monthly_readback']=api_get(t,f'/v1/subscriptions/{SUB_ID}/prices?filter[territory]=JPN&include=subscriptionPricePoint,territory&limit=200')
        _,r['lifetime_readback']=api_get(t,f'/v2/inAppPurchases/{IAP_ID}/iapPriceSchedule?include=baseTerritory,manualPrices&limit[manualPrices]=50')
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)
    Path('hm2-iap-price-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PASS: standard HM2 monthly 200 JPY + lifetime 800 JPY configured')

if __name__=='__main__': main()
