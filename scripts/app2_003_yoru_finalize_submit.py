#!/usr/bin/env python3
from __future__ import annotations
import json, os
from datetime import datetime, timezone
from pathlib import Path
from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID='6794137637'; BUNDLE_ID='io.github.allsunday1122.yorunoshoka'; TARGET_VERSION='1.2.0'; TARGET_BUILD='7'
SUBMITTED={'WAITING_FOR_REVIEW','IN_REVIEW','COMPLETING'}
NOTES='''本アプリは日本語のオリジナル怪談を読むためのオフライン読書アプリです。サインイン、広告、アプリ内課金、外部コンテンツの取得はありません。

1.2.0では読書UIを「紙面・温かみ」テーマへ刷新しました。紙面／深いセピア／漆黒の3テーマ、明るさ、文字サイズ、行間、明朝／ゴシック切替、シリーズ／話者ガイド、読書進捗表示、ホーム・書架からの読書導線を追加・整理しています。

全148話はアプリ本体に収録されています。「書架」で検索・怖さ・長さ・シリーズによる絞り込み、「保存」でお気に入りと読了履歴を確認できます。読書設定と履歴は端末内にのみ保存され、利用者データは収集しません。読書画面ではiOS共有シートを利用できます。'''

def one(p,label):
    d=p.get('data') if isinstance(p,dict) else None
    if not isinstance(d,dict): raise RuntimeError('Missing '+label)
    return d

def many(p):
    d=p.get('data',[]) if isinstance(p,dict) else []
    return d if isinstance(d,list) else ([] if d is None else [d])

def state(r):
    a=r.get('attributes') or {}
    return a.get('state') or a.get('appStoreState') or a.get('appVersionState')

def req(token,path,method,payload):
    status,response=api_request(token,path,method=method,payload=payload)
    if not 200 <= status < 300: raise RuntimeError(f'ASC {method} {path} HTTP {status}')
    return response

def resolve_version(token):
    _,p=api_get(token,f'/v1/apps/{APP_ID}/appStoreVersions?limit=50')
    xs=[x for x in many(p) if (x.get('attributes') or {}).get('platform')=='IOS' and (x.get('attributes') or {}).get('versionString')==TARGET_VERSION]
    if len(xs)!=1: raise RuntimeError('Target version is not unique')
    if state(xs[0]) not in {'PREPARE_FOR_SUBMISSION','READY_FOR_REVIEW','WAITING_FOR_REVIEW','IN_REVIEW'}: raise RuntimeError('Unexpected version state '+str(state(xs[0])))
    return xs[0]

def resolve_build(token):
    _,p=api_get(token,f'/v1/apps/{APP_ID}/builds?sort=-uploadedDate&limit=100')
    xs=[x for x in many(p) if str((x.get('attributes') or {}).get('version'))==TARGET_BUILD]
    if len(xs)!=1: raise RuntimeError(f'Expected one Build {TARGET_BUILD}; found {len(xs)}')
    b=xs[0]; a=b.get('attributes') or {}
    if a.get('processingState')!='VALID': raise RuntimeError('Build 7 is not VALID: '+str(a.get('processingState')))
    if a.get('buildAudienceType')=='INTERNAL_ONLY': raise RuntimeError('Build 7 is INTERNAL_ONLY')
    if a.get('usesNonExemptEncryption') not in {False,None}: raise RuntimeError('Unexpected encryption state')
    return b

def attach(token,vid,bid):
    payload={'data':{'type':'appStoreVersions','id':vid,'relationships':{'build':{'data':{'type':'builds','id':bid}}}}}
    req(token,f'/v1/appStoreVersions/{vid}','PATCH',payload)
    _,r=api_get(token,f'/v1/appStoreVersions/{vid}/relationships/build')
    if ((r.get('data') or {}).get('id'))!=bid: raise RuntimeError('Build attach read-back mismatch')

def validate_metadata(token,vid):
    _,p=api_get(token,f'/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=50')
    loc=next((x for x in many(p) if (x.get('attributes') or {}).get('locale') in {'ja','ja-JP'}),None)
    if not loc: raise RuntimeError('Japanese localization missing')
    la=loc.get('attributes') or {}
    for k in ('description','keywords','supportUrl'):
        if not la.get(k): raise RuntimeError('Metadata missing '+k)
    lid=str(loc['id'])
    _,sp=api_get(token,f'/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets?limit=200&include=appScreenshots')
    shots=[x for x in (sp.get('included') or []) if x.get('type')=='appScreenshots'] if isinstance(sp,dict) else []
    complete=[x for x in shots if (((x.get('attributes') or {}).get('assetDeliveryState') or {}).get('state'))=='COMPLETE']
    if len(complete)<4: raise RuntimeError('Fewer than four COMPLETE screenshots')
    _,rp=api_get(token,f'/v1/appStoreVersions/{vid}/appStoreReviewDetail'); review=one(rp,'review detail'); ra=review.get('attributes') or {}
    for k in ('contactFirstName','contactLastName','contactPhone','contactEmail'):
        if not ra.get(k): raise RuntimeError('Review contact missing '+k)
    if ra.get('demoAccountRequired') is True: raise RuntimeError('Demo account unexpectedly required')
    rid=str(review['id'])
    if ra.get('notes')!=NOTES:
        req(token,f'/v1/appStoreReviewDetails/{rid}','PATCH',{'data':{'type':'appStoreReviewDetails','id':rid,'attributes':{'notes':NOTES}}})
        _,after=api_get(token,f'/v1/appStoreReviewDetails/{rid}')
        if (one(after,'review detail after patch').get('attributes') or {}).get('notes')!=NOTES: raise RuntimeError('Review notes read-back mismatch')
    _,ip=api_get(token,f'/v1/apps/{APP_ID}/appInfos?limit=20'); infos=many(ip)
    if not infos: raise RuntimeError('AppInfo missing')
    info=next((x for x in infos if state(x)=='PREPARE_FOR_SUBMISSION'),infos[0]); iid=str(info['id'])
    _,ilp=api_get(token,f'/v1/appInfos/{iid}/appInfoLocalizations?limit=50')
    il=next((x for x in many(ilp) if (x.get('attributes') or {}).get('locale') in {'ja','ja-JP'}),None)
    if not il or not (il.get('attributes') or {}).get('privacyPolicyUrl'): raise RuntimeError('Privacy policy URL missing')
    _,agep=api_get(token,f'/v1/appInfos/{iid}/ageRatingDeclaration'); age=one(agep,'age rating')
    return {'localization_id':lid,'complete_screenshots':len(complete),'review_detail_id':rid,'app_info_id':iid,'age_rating_id':str(age['id'])}

def ensure_draft(token,vid):
    _,p=api_get(token,f'/v1/apps/{APP_ID}/reviewSubmissions?limit=200'); subs=many(p)
    done=next((x for x in subs if state(x) in SUBMITTED),None)
    if done: return {'id':str(done['id']),'state':state(done),'already':True}
    draft=next((x for x in subs if state(x)=='READY_FOR_REVIEW'),None)
    if not draft:
        payload={'data':{'type':'reviewSubmissions','attributes':{'platform':'IOS'},'relationships':{'app':{'data':{'type':'apps','id':APP_ID}}}}}
        draft=one(req(token,'/v1/reviewSubmissions','POST',payload),'created submission')
    sid=str(draft['id']); _,items=api_get(token,f'/v1/reviewSubmissions/{sid}/items?limit=200')
    has=any(((((x.get('relationships') or {}).get('appStoreVersion') or {}).get('data') or {}).get('id'))==vid for x in many(items))
    if not has:
        payload={'data':{'type':'reviewSubmissionItems','relationships':{'reviewSubmission':{'data':{'type':'reviewSubmissions','id':sid}},'appStoreVersion':{'data':{'type':'appStoreVersions','id':vid}}}}}
        req(token,'/v1/reviewSubmissionItems','POST',payload)
    _,after=api_get(token,f'/v1/reviewSubmissions/{sid}'); r=one(after,'submission after prepare')
    return {'id':sid,'state':state(r),'already':False}

def main():
    out=Path(os.environ.get('YORU_SUBMIT_OUTPUT','/tmp/app2-003-yoru-final-submit.json'))
    result={'task_id':'APP2-003','completed_at':datetime.now(timezone.utc).isoformat(),'app_id':APP_ID,'bundle_id':BUNDLE_ID,'version':TARGET_VERSION,'build':TARGET_BUILD,'submitted':False}
    key,cleanup=load_private_key()
    try:
        token=make_token(os.environ['ASC_ISSUER_ID'],os.environ['ASC_KEY_ID'],key)
        _,ap=api_get(token,f'/v1/apps/{APP_ID}'); app=one(ap,'app')
        if (app.get('attributes') or {}).get('bundleId')!=BUNDLE_ID: raise RuntimeError('App/bundle mismatch')
        v=resolve_version(token); vid=str(v['id']); b=resolve_build(token); bid=str(b['id']); ba=b.get('attributes') or {}
        result.update({'version_id':vid,'build_id':bid,'build_processing_state':'VALID','build_audience_type':ba.get('buildAudienceType')})
        attach(token,vid,bid); result['metadata']=validate_metadata(token,vid)
        d=ensure_draft(token,vid); result.update({'review_submission_id':d['id'],'review_submission_state_before':d['state']})
        if d['already']:
            result.update({'submitted':True,'idempotent':True,'review_submission_state':d['state']})
        else:
            sid=d['id']; req(token,f'/v1/reviewSubmissions/{sid}','PATCH',{'data':{'type':'reviewSubmissions','id':sid,'attributes':{'submitted':True}}})
            _,after=api_get(token,f'/v1/reviewSubmissions/{sid}'); st=state(one(after,'submission after submit'))
            if st not in SUBMITTED: raise RuntimeError('Unexpected review state after submit: '+str(st))
            result.update({'submitted':True,'idempotent':False,'review_submission_state':st})
        out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps(result,ensure_ascii=False))
    except Exception as e:
        result['error']=str(e); out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); raise
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)
if __name__=='__main__': main()
