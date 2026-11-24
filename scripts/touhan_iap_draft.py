#!/usr/bin/env python3
"""Create only draft products; no price/contract/review confirmation."""
import json, os
from pathlib import Path
from app_store_connect_api import load_private_key, make_token
from app2_005_hm1_iap_bootstrap import req, rows
P=json.loads(Path('touroku-hanbaisha-ios/IAP_POLICY.json').read_text())
OUT=Path('automation/touhan-iap-draft-result.json')
result={'appId':P['appId'],'bundleId':P['bundleId'],'actions':[],'ok':False,'reviewSubmitted':False,'priceFinalized':False}
def rel(t,i): return {'data':{'type':t,'id':i}}
def post(token,path,t,attrs,relationships):
    return req(token,path,'POST',{'data':{'type':t,'attributes':attrs,'relationships':relationships}})[1]['data']
def match(items,key,value):
    return next((x for x in items if x.get('attributes',{}).get(key)==value),None)
cleanup=None
try:
    key,cleanup=load_private_key()
    token=make_token(os.environ['ASC_ISSUER_ID'],os.environ['ASC_KEY_ID'],key)
    aid=P['appId']
    _,app=req(token,f'/v1/apps/{aid}')
    assert app['data']['attributes']['bundleId']==P['bundleId']
    _,listing=req(token,f'/v1/apps/{aid}/inAppPurchasesV2?limit=200')
    item=match(rows(listing),'productId',P['lifetime']['productId'])
    if item is None:
        item=post(token,'/v2/inAppPurchases','inAppPurchases',{'name':'登録販売者 買い切りプレミアム','productId':P['lifetime']['productId'],'inAppPurchaseType':'NON_CONSUMABLE','familySharable':False},{'app':rel('apps',aid)})
        result['actions'].append('created_lifetime_draft')
    result['lifetime']={'id':item['id'],'attributes':item['attributes']}
    assert item['attributes']['inAppPurchaseType']=='NON_CONSUMABLE'
    _,groups=req(token,f'/v1/apps/{aid}/subscriptionGroups?limit=200')
    group=match(rows(groups),'referenceName','登録販売者プレミアム')
    if group is None:
        group=post(token,'/v1/subscriptionGroups','subscriptionGroups',{'referenceName':'登録販売者プレミアム'},{'app':rel('apps',aid)})
        result['actions'].append('created_group_draft')
    gid=group['id']; result['groupId']=gid
    _,subs=req(token,f'/v1/subscriptionGroups/{gid}/subscriptions?limit=200')
    sub=match(rows(subs),'productId',P['monthly']['productId'])
    if sub is None:
        sub=post(token,'/v1/subscriptions','subscriptions',{'name':'登録販売者 プレミアム月額','productId':P['monthly']['productId'],'subscriptionPeriod':'ONE_MONTH','familySharable':False,'groupLevel':1},{'group':rel('subscriptionGroups',gid)})
        result['actions'].append('created_monthly_draft')
    result['monthly']={'id':sub['id'],'attributes':sub['attributes']}
    assert sub['attributes']['subscriptionPeriod']=='ONE_MONTH'
    for name,path in [('lifetime',f"/v2/inAppPurchases/{item['id']}"),('monthly',f"/v1/subscriptions/{sub['id']}")]:
        _,detail=req(token,path)
        result[name]['readback']=detail['data']['attributes']
        assert detail['data']['attributes']['productId']==P[name]['productId']
    result['ok']=True
except Exception as e:
    result['error']=str(e)[:2500]
finally:
    if cleanup: cleanup.unlink(missing_ok=True)
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False))
if not result['ok']: raise SystemExit(1)
