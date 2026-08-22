#!/usr/bin/env python3
"""Configure fixed Japanese metadata for HM2 premium products."""
import json, os
from pathlib import Path
from app_store_connect_api import api_get, api_request, load_private_key, make_token

SUB='6802988571'; GROUP='22319275'; IAP='6802989207'; LOCALE='ja'
MONTHLY_NAME='月額プレミアム'
MONTHLY_DESC='学習を継続しながら、全300問・全30セット・全分野・苦手復習を利用できます。'
GROUP_NAME='プレミアム学習'
LIFETIME_NAME='買い切りプレミアム'
LIFETIME_DESC='一度の購入で、全300問・全30セット・全分野・苦手復習を期限なく利用できます。'
REVIEW_NOTE='第二種衛生管理者の学習アプリです。無料範囲は最新1回相当30問と今日のスプリント。月額または買い切りで同一のPremium権利を付与し、全300問・全30セット・全分野・苦手復習を解放します。購入復元は設定画面から実行できます。'

def data(resp):
    d=resp.get('data') if isinstance(resp,dict) else None
    return d if isinstance(d,list) else ([d] if isinstance(d,dict) else [])

def find_locale(resp):
    for x in data(resp):
        if (x.get('attributes') or {}).get('locale')==LOCALE: return x
    for x in (resp.get('included') or []) if isinstance(resp,dict) else []:
        if (x.get('attributes') or {}).get('locale')==LOCALE: return x
    return None

def ensure_v1_localization(t,parent_path,create_path,res_type,rel_key,rel_type,rel_id,attrs,label,r):
    _,listed=api_get(t,parent_path)
    cur=find_locale(listed)
    if cur:
        desired={k:v for k,v in attrs.items() if k!='locale'}
        actual=cur.get('attributes') or {}
        changes={k:v for k,v in desired.items() if actual.get(k)!=v}
        if changes:
            payload={'data':{'type':res_type,'id':cur['id'],'attributes':changes}}
            status,_=api_request(t,f"/v1/{res_type}/{cur['id']}",method='PATCH',payload=payload)
            r[label]={'changed':True,'http_status':status,'id':cur['id']}
        else:r[label]={'changed':False,'id':cur['id']}
        return
    payload={'data':{'type':res_type,'attributes':attrs,'relationships':{rel_key:{'data':{'type':rel_type,'id':rel_id}}}}}
    status,out=api_request(t,create_path,method='POST',payload=payload)
    r[label]={'changed':True,'http_status':status,'id':((out or {}).get('data') or {}).get('id')}

def ensure_iap_version(t,r):
    _,versions=api_get(t,f'/v2/inAppPurchases/{IAP}/versions?limit=50')
    for v in data(versions):
        if (v.get('attributes') or {}).get('state')=='PREPARE_FOR_SUBMISSION':
            r['lifetime_version']={'changed':False,'id':v['id'],'state':'PREPARE_FOR_SUBMISSION'}
            return v['id']
    payload={'data':{'type':'inAppPurchaseVersions','relationships':{'inAppPurchase':{'data':{'type':'inAppPurchases','id':IAP}}}}}
    status,out=api_request(t,'/v1/inAppPurchaseVersions',method='POST',payload=payload)
    vid=((out or {}).get('data') or {}).get('id')
    if not vid: raise RuntimeError('IAP version create returned no id')
    r['lifetime_version']={'changed':True,'http_status':status,'id':vid,'state':(((out or {}).get('data') or {}).get('attributes') or {}).get('state')}
    return vid

def ensure_iap_loc(t,r):
    vid=ensure_iap_version(t,r)
    _,listed=api_get(t,f'/v1/inAppPurchaseVersions/{vid}/localizations?limit=50')
    cur=find_locale(listed)
    attrs={'locale':LOCALE,'name':LIFETIME_NAME,'description':LIFETIME_DESC}
    if cur:
        actual=cur.get('attributes') or {}; changes={k:v for k,v in attrs.items() if k!='locale' and actual.get(k)!=v}
        if changes:
            payload={'data':{'type':'inAppPurchaseLocalizations','id':cur['id'],'attributes':changes}}
            status,_=api_request(t,f"/v2/inAppPurchaseLocalizations/{cur['id']}",method='PATCH',payload=payload)
            r['lifetime_localization']={'changed':True,'http_status':status,'id':cur['id'],'version_id':vid}
        else:r['lifetime_localization']={'changed':False,'id':cur['id'],'version_id':vid}
        return vid
    payload={'data':{'type':'inAppPurchaseLocalizations','attributes':attrs,'relationships':{'version':{'data':{'type':'inAppPurchaseVersions','id':vid}}}}}
    status,out=api_request(t,'/v2/inAppPurchaseLocalizations',method='POST',payload=payload)
    r['lifetime_localization']={'changed':True,'http_status':status,'id':((out or {}).get('data') or {}).get('id'),'version_id':vid}
    return vid

def patch_notes(t,r):
    _,s=api_get(t,f'/v1/subscriptions/{SUB}'); sa=(s.get('data') or {}).get('attributes') or {}
    if sa.get('reviewNote')!=REVIEW_NOTE:
        status,_=api_request(t,f'/v1/subscriptions/{SUB}',method='PATCH',payload={'data':{'type':'subscriptions','id':SUB,'attributes':{'reviewNote':REVIEW_NOTE}}})
        r['monthly_review_note']={'changed':True,'http_status':status}
    else:r['monthly_review_note']={'changed':False}
    _,i=api_get(t,f'/v2/inAppPurchases/{IAP}'); ia=(i.get('data') or {}).get('attributes') or {}
    if ia.get('reviewNote')!=REVIEW_NOTE:
        status,_=api_request(t,f'/v2/inAppPurchases/{IAP}',method='PATCH',payload={'data':{'type':'inAppPurchases','id':IAP,'attributes':{'reviewNote':REVIEW_NOTE}}})
        r['lifetime_review_note']={'changed':True,'http_status':status}
    else:r['lifetime_review_note']={'changed':False}

def main():
    issuer=os.environ.get('ASC_ISSUER_ID'); keyid=os.environ.get('ASC_KEY_ID')
    if not issuer or not keyid: raise SystemExit('missing ASC credentials')
    kp,cleanup=load_private_key(); r={}
    try:
        t=make_token(issuer,keyid,kp)
        ensure_v1_localization(t,f'/v1/subscriptions/{SUB}/subscriptionLocalizations?limit=50','/v1/subscriptionLocalizations','subscriptionLocalizations','subscription','subscriptions',SUB,{'locale':LOCALE,'name':MONTHLY_NAME,'description':MONTHLY_DESC},'monthly_localization',r)
        ensure_v1_localization(t,f'/v1/subscriptionGroups/{GROUP}/subscriptionGroupLocalizations?limit=50','/v1/subscriptionGroupLocalizations','subscriptionGroupLocalizations','subscriptionGroup','subscriptionGroups',GROUP,{'locale':LOCALE,'name':GROUP_NAME},'group_localization',r)
        vid=ensure_iap_loc(t,r); patch_notes(t,r)
        _,r['monthly_readback']=api_get(t,f'/v1/subscriptions/{SUB}?include=subscriptionLocalizations')
        _,r['group_readback']=api_get(t,f'/v1/subscriptionGroups/{GROUP}?include=subscriptionGroupLocalizations')
        _,r['lifetime_product_readback']=api_get(t,f'/v2/inAppPurchases/{IAP}')
        _,r['lifetime_version_readback']=api_get(t,f'/v1/inAppPurchaseVersions/{vid}?include=localizations')
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)
    Path('hm2-iap-metadata-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PASS: HM2 Japanese IAP metadata configured')
if __name__=='__main__': main()
