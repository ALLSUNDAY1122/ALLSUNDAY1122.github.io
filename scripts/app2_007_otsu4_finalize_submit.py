#!/usr/bin/env python3
"""Final App Store review submission for APP2-007 Otsu4.

Requires a VALID, non-INTERNAL_ONLY build > 93, complete store screenshots,
READY_TO_SUBMIT first non-consumable IAP metadata, completed review contact,
privacy URL and age rating. Adds the app version and IAP version to the same
review submission and submits only after all read-back gates pass.
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID='6799755566'; BUNDLE_ID='jp.allsunday1122.otsu4'; TARGET_VERSION='1.0.0'
VERSION_ID='d02ea66f-2452-4f75-b900-5d9347384b5d'; LOCALIZATION_ID='3718791f-0edf-4a18-b045-65540780538b'
APP_INFO_ID='9fd15be0-6953-4661-be50-7b97f5f4653e'; IAP_ID='6806477067'; IAP_VERSION_ID='1a226705-e29a-4161-8ca5-0b77457dd9f9'
MIN_BUILD=94
SUBMITTED={'WAITING_FOR_REVIEW','IN_REVIEW','COMPLETING','COMPLETE'}
OUT=Path(os.environ.get('OTS4_FINAL_SUBMIT_OUTPUT','automation/app2-007-otsu4-final-submit-result.json'))
NOTES='''本アプリは危険物取扱者 乙種第4類の学習アプリです。アカウント登録、広告、行動解析、トラッキングはありません。学習履歴は端末内に保存されます。\n\n無料版では72問を利用できます。非消耗型アプリ内課金「乙4 プレミアム」（jp.allsunday1122.otsu4.premium）を購入すると、全720問、模擬試験6回、全範囲の復習機能を解放します。購入画面は「設定」→「乙4 プレミアム」から開けます。\n\n審査時は通常のSandbox購入フローをご利用ください。購入済みの場合は「購入を復元」でも権利を再確認できます。'''

def req(token,path,method='GET',payload=None,allow404=False):
    body=None if payload is None else json.dumps(payload,ensure_ascii=False,separators=(',',':')).encode()
    r=urllib.request.Request(BASE_URL+path,data=body,method=method,headers={'Authorization':'Bearer '+token,'Accept':'application/json','Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(r,timeout=60) as x:
            raw=x.read(); return x.status,json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as e:
        if allow404 and e.code==404: return 404,{}
        raw=e.read().decode('utf-8','replace'); raise RuntimeError(f'ASC {method} {path} HTTP {e.code}: {raw[:8000]}') from e

def rows(p):
    d=p.get('data',[]) if isinstance(p,dict) else []
    return d if isinstance(d,list) else ([] if d is None else [d])

def attrs(x): return (x or {}).get('attributes') or {}
def state(x): return attrs(x).get('state') or attrs(x).get('appStoreState') or attrs(x).get('appVersionState')
def rel_id(x,key):
    try: return str(x['relationships'][key]['data']['id'])
    except Exception: return None

def validate_app(token,actions):
    fields='?fields[apps]=bundleId,contentRightsDeclaration'
    _,p=req(token,f'/v1/apps/{APP_ID}{fields}'); app=p.get('data') or {}; a=attrs(app)
    if a.get('bundleId')!=BUNDLE_ID: raise RuntimeError('App/bundle mismatch')
    if not a.get('contentRightsDeclaration'):
        req(token,f'/v1/apps/{APP_ID}','PATCH',{'data':{'type':'apps','id':APP_ID,'attributes':{'contentRightsDeclaration':'DOES_NOT_USE_THIRD_PARTY_CONTENT'}}})
        actions.append('content_rights_declared')
        _,p=req(token,f'/v1/apps/{APP_ID}{fields}'); a=attrs(p.get('data') or {})
    if a.get('contentRightsDeclaration')!='DOES_NOT_USE_THIRD_PARTY_CONTENT': raise RuntimeError('Unexpected content rights declaration')
    return a

def resolve_build(token):
    _,p=req(token,f'/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=100')
    candidates=[]
    for b in rows(p):
        a=attrs(b); number=str(a.get('version',''))
        if not number.isdigit() or int(number)<MIN_BUILD: continue
        if a.get('processingState')!='VALID': continue
        if a.get('buildAudienceType')=='INTERNAL_ONLY': continue
        if a.get('usesNonExemptEncryption') not in {False,None}: continue
        candidates.append(b)
    if not candidates: raise RuntimeError('No VALID non-INTERNAL_ONLY Otsu4 build >= 94 is available')
    candidates.sort(key=lambda x:int(str(attrs(x).get('version','0'))),reverse=True)
    return candidates[0]

def attach_build(token,build_id,actions):
    _,r=req(token,f'/v1/appStoreVersions/{VERSION_ID}/relationships/build')
    current=(r.get('data') or {}).get('id')
    if current!=build_id:
        req(token,f'/v1/appStoreVersions/{VERSION_ID}','PATCH',{'data':{'type':'appStoreVersions','id':VERSION_ID,'relationships':{'build':{'data':{'type':'builds','id':build_id}}}}})
        actions.append('build_attached')
    _,after=req(token,f'/v1/appStoreVersions/{VERSION_ID}/relationships/build')
    if (after.get('data') or {}).get('id')!=build_id: raise RuntimeError('Build attach read-back mismatch')

def validate_metadata(token):
    _,vp=req(token,f'/v1/appStoreVersions/{VERSION_ID}'); v=vp.get('data') or {}
    if attrs(v).get('versionString')!=TARGET_VERSION: raise RuntimeError('Version mismatch')
    if state(v) not in {'PREPARE_FOR_SUBMISSION','READY_FOR_REVIEW','WAITING_FOR_REVIEW','IN_REVIEW'}: raise RuntimeError('Unexpected app version state '+str(state(v)))
    _,lp=req(token,f'/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}'); la=attrs(lp.get('data') or {})
    for k in ('description','keywords','supportUrl'):
        if not la.get(k): raise RuntimeError('Missing version metadata '+k)
    _,sets=req(token,f'/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200&include=appScreenshots')
    complete=[x for x in (sets.get('included') or []) if x.get('type')=='appScreenshots' and (((attrs(x).get('assetDeliveryState') or {}).get('state'))=='COMPLETE')]
    if len(complete)<6: raise RuntimeError(f'Expected at least 6 COMPLETE screenshots, found {len(complete)}')
    _,rp=req(token,f'/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail'); review=rp.get('data') or {}; ra=attrs(review)
    for k in ('contactFirstName','contactLastName','contactPhone','contactEmail'):
        if not ra.get(k): raise RuntimeError('Review contact missing '+k)
    rid=str(review['id'])
    if ra.get('notes')!=NOTES:
        req(token,f'/v1/appStoreReviewDetails/{rid}','PATCH',{'data':{'type':'appStoreReviewDetails','id':rid,'attributes':{'notes':NOTES}}})
    _,infos=req(token,f'/v1/apps/{APP_ID}/appInfos?limit=20&include=appInfoLocalizations'); info_ids={str(x.get('id')) for x in rows(infos)}
    if APP_INFO_ID not in info_ids: raise RuntimeError('AppInfo mismatch')
    locs=[x for x in (infos.get('included') or []) if x.get('type')=='appInfoLocalizations']
    ja=next((x for x in locs if attrs(x).get('locale') in {'ja','ja-JP'}),None)
    if not ja or not attrs(ja).get('privacyPolicyUrl'): raise RuntimeError('Privacy policy URL missing')
    _,age=req(token,f'/v1/appInfos/{APP_INFO_ID}/ageRatingDeclaration')
    if not (age.get('data') or {}).get('id'): raise RuntimeError('Age rating declaration missing')
    return {'screenshots':len(complete),'review_detail_id':rid,'age_rating_id':str(age['data']['id'])}

def validate_iap(token):
    _,pp=req(token,f'/v2/inAppPurchases/{IAP_ID}?include=appStoreReviewScreenshot,versions'); product=pp.get('data') or {}; ps=state(product)
    if ps not in {'READY_TO_SUBMIT','READY_FOR_REVIEW','WAITING_FOR_REVIEW','IN_REVIEW','APPROVED'}: raise RuntimeError('IAP parent not ready: '+str(ps))
    shots=[x for x in (pp.get('included') or []) if x.get('type')=='inAppPurchaseAppStoreReviewScreenshots']
    if not shots or (((attrs(shots[0]).get('assetDeliveryState') or {}).get('state'))!='COMPLETE'): raise RuntimeError('IAP review screenshot not COMPLETE')
    _,ivp=req(token,f'/v1/inAppPurchaseVersions/{IAP_VERSION_ID}'); iv=ivp.get('data') or {}; ivs=state(iv)
    if ivs not in {'PREPARE_FOR_SUBMISSION','READY_FOR_REVIEW','WAITING_FOR_REVIEW','IN_REVIEW','APPROVED'}: raise RuntimeError('Unexpected IAP version state '+str(ivs))
    _,loc=req(token,f'/v1/inAppPurchaseVersions/{IAP_VERSION_ID}/localizations?limit=50')
    ja=next((x for x in rows(loc) if attrs(x).get('locale')=='ja'),None)
    if not ja or not attrs(ja).get('name') or not attrs(ja).get('description'): raise RuntimeError('IAP Japanese localization incomplete')
    _,avail=req(token,f'/v1/inAppPurchaseAvailabilities/{IAP_ID}/relationships/availableTerritories?limit=200')
    if 'JPN' not in {str(x.get('id')) for x in rows(avail)}: raise RuntimeError('IAP is not available in JPN')
    return {'parent_state':ps,'version_state':ivs,'review_screenshot_id':str(shots[0]['id'])}

def ensure_submission(token,actions):
    _,p=req(token,f'/v1/apps/{APP_ID}/reviewSubmissions?limit=200')
    subs=rows(p)
    active=next((x for x in subs if state(x) in SUBMITTED),None)
    if active: return str(active['id']),True
    draft=next((x for x in subs if state(x)=='READY_FOR_REVIEW'),None)
    if not draft:
        _,created=req(token,'/v1/reviewSubmissions','POST',{'data':{'type':'reviewSubmissions','attributes':{'platform':'IOS'},'relationships':{'app':{'data':{'type':'apps','id':APP_ID}}}}})
        draft=created['data']; actions.append('review_submission_created')
    sid=str(draft['id'])
    _,items=req(token,f'/v1/reviewSubmissions/{sid}/items?limit=200&include=appStoreVersion,inAppPurchaseVersion')
    rs=rows(items)
    has_app=any(rel_id(x,'appStoreVersion')==VERSION_ID for x in rs)
    has_iap=any(rel_id(x,'inAppPurchaseVersion')==IAP_VERSION_ID for x in rs)
    if not has_app:
        req(token,'/v1/reviewSubmissionItems','POST',{'data':{'type':'reviewSubmissionItems','relationships':{'reviewSubmission':{'data':{'type':'reviewSubmissions','id':sid}},'appStoreVersion':{'data':{'type':'appStoreVersions','id':VERSION_ID}}}}})
        actions.append('app_version_added_to_review')
    if not has_iap:
        req(token,'/v1/reviewSubmissionItems','POST',{'data':{'type':'reviewSubmissionItems','relationships':{'reviewSubmission':{'data':{'type':'reviewSubmissions','id':sid}},'inAppPurchaseVersion':{'data':{'type':'inAppPurchaseVersions','id':IAP_VERSION_ID}}}}})
        actions.append('iap_version_added_to_review')
    _,after=req(token,f'/v1/reviewSubmissions/{sid}/items?limit=200&include=appStoreVersion,inAppPurchaseVersion')
    ars=rows(after)
    if not any(rel_id(x,'appStoreVersion')==VERSION_ID for x in ars): raise RuntimeError('App version review item missing after write')
    if not any(rel_id(x,'inAppPurchaseVersion')==IAP_VERSION_ID for x in ars): raise RuntimeError('IAP version review item missing after write')
    return sid,False

def main():
    cleanup=None; actions=[]; result={'task_id':'APP2-007','app_id':APP_ID,'bundle_id':BUNDLE_ID,'version':TARGET_VERSION,'submitted':False,'ok':False,'completed_at':datetime.now(timezone.utc).isoformat()}
    try:
        key,cleanup=load_private_key(); token=make_token(os.environ['ASC_ISSUER_ID'],os.environ['ASC_KEY_ID'],key)
        app_attrs=validate_app(token,actions)
        build=resolve_build(token); bid=str(build['id']); ba=attrs(build); bnum=str(ba.get('version'))
        result.update(build_id=bid,build_number=bnum,build_processing_state=ba.get('processingState'),build_audience_type=ba.get('buildAudienceType'),content_rights=app_attrs.get('contentRightsDeclaration'))
        attach_build(token,bid,actions)
        result['metadata']=validate_metadata(token); result['iap']=validate_iap(token)
        sid,already=ensure_submission(token,actions); result['review_submission_id']=sid
        if already:
            _,sp=req(token,f'/v1/reviewSubmissions/{sid}'); st=state(sp.get('data') or {})
            result.update(ok=True,submitted=True,idempotent=True,review_submission_state=st,actions=actions)
        else:
            req(token,f'/v1/reviewSubmissions/{sid}','PATCH',{'data':{'type':'reviewSubmissions','id':sid,'attributes':{'submitted':True}}})
            time.sleep(2)
            _,sp=req(token,f'/v1/reviewSubmissions/{sid}'); st=state(sp.get('data') or {})
            if st not in SUBMITTED: raise RuntimeError('Unexpected review submission state after submit: '+str(st))
            _,av=req(token,f'/v1/appStoreVersions/{VERSION_ID}'); _,iv=req(token,f'/v1/inAppPurchaseVersions/{IAP_VERSION_ID}')
            result.update(ok=True,submitted=True,idempotent=False,review_submission_state=st,app_version_state=state(av.get('data') or {}),iap_version_state=state(iv.get('data') or {}),actions=actions)
    except Exception as e:
        result['error']=str(e); result['actions']=actions; raise
    finally:
        OUT.parent.mkdir(parents=True,exist_ok=True); OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(result,ensure_ascii=False))
        if cleanup:
            try: cleanup.unlink(missing_ok=True)
            except Exception: pass
if __name__=='__main__': main()
