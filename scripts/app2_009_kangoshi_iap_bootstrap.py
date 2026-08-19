#!/usr/bin/env python3
import json, os, urllib.request, urllib.error
from decimal import Decimal
from pathlib import Path
from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = "6801792293"
MONTHLY_ID = "jp.allsunday1122.kangoshi.monthly"
LIFETIME_ID = "jp.allsunday1122.kangoshi.lifetime"
JPN = "JPN"
MONTHLY_PRICE = Decimal("200")
LIFETIME_PRICE = Decimal("800")
OUT = Path("automation/app2-009-kangoshi-iap-result.json")

def req(token, path, method="GET", payload=None):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    r = urllib.request.Request(BASE_URL + path, data=body, method=method, headers={"Authorization": f"Bearer {token}", "Accept":"application/json", "Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            raw=resp.read(); return resp.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as e:
        raw=e.read().decode("utf-8","replace")
        raise RuntimeError(f"ASC {method} {path} HTTP {e.code}: {raw[:3000]}")

def rows(p):
    d=p.get("data",[]) if isinstance(p,dict) else []
    return d if isinstance(d,list) else [d]

def by_product(xs,pid):
    return next((x for x in xs if x.get("attributes",{}).get("productId")==pid),None)

def dec(v):
    try:return Decimal(str(v))
    except:return Decimal("-1")

def ensure_lifetime(token, actions):
    _,p=req(token,f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=200")
    item=by_product(rows(p),LIFETIME_ID)
    if item is None:
        payload={"data":{"type":"inAppPurchases","attributes":{"name":"看護師国試 プレミアム買い切り","productId":LIFETIME_ID,"inAppPurchaseType":"NON_CONSUMABLE","reviewNote":"全720問・分野別・本番形式・弱点学習を永久解放します。","familySharable":False},"relationships":{"app":{"data":{"type":"apps","id":APP_ID}}}}}
        _,c=req(token,"/v2/inAppPurchases","POST",payload); item=c["data"]; actions.append("created_lifetime")
    iid=item["id"]
    _,detail=req(token,f"/v2/inAppPurchases/{iid}?include=inAppPurchaseLocalizations")
    inc=detail.get("included",[])
    if not any(x.get("attributes",{}).get("locale")=="ja" for x in inc):
        payload={"data":{"type":"inAppPurchaseLocalizations","attributes":{"name":"看護師国試 プレミアム買い切り","locale":"ja","description":"全720問・分野別・本番形式・弱点学習を永久に利用できます。"},"relationships":{"inAppPurchaseV2":{"data":{"type":"inAppPurchasesV2","id":iid}}}}}
        req(token,"/v2/inAppPurchaseLocalizations","POST",payload); actions.append("localized_lifetime_ja")
    try:req(token,f"/v2/inAppPurchases/{iid}/iapPriceSchedule"); has=True
    except RuntimeError as e:
        if "HTTP 404" not in str(e): raise
        has=False
    if not has:
        _,pp=req(token,f"/v2/inAppPurchases/{iid}/pricePoints?filter[territory]={JPN}&fields[inAppPurchasePricePoints]=customerPrice,territory&include=territory&limit=8000")
        point=next((x for x in rows(pp) if dec(x.get("attributes",{}).get("customerPrice"))==LIFETIME_PRICE),None)
        if point is None: raise RuntimeError("JPN 800 lifetime price point not found")
        inline="app2-009-kangoshi-lifetime-jpn"
        payload={"data":{"type":"inAppPurchasePriceSchedules","relationships":{"inAppPurchase":{"data":{"type":"inAppPurchases","id":iid}},"baseTerritory":{"data":{"type":"territories","id":JPN}},"manualPrices":{"data":[{"type":"inAppPurchasePrices","id":inline}]}}},"included":[{"type":"inAppPurchasePrices","id":inline,"attributes":{"startDate":None},"relationships":{"inAppPurchaseV2":{"data":{"type":"inAppPurchasesV2","id":iid}},"inAppPurchasePricePoint":{"data":{"type":"inAppPurchasePricePoints","id":point["id"]}}}}]}
        req(token,"/v1/inAppPurchasePriceSchedules","POST",payload); actions.append("priced_lifetime_800_jpn")
    return iid

def ensure_monthly(token,actions):
    _,gp=req(token,f"/v1/apps/{APP_ID}/subscriptionGroups?limit=200")
    group=next((x for x in rows(gp) if x.get("attributes",{}).get("referenceName")=="看護師国試プレミアム"),None)
    if group is None:
        payload={"data":{"type":"subscriptionGroups","attributes":{"referenceName":"看護師国試プレミアム"},"relationships":{"app":{"data":{"type":"apps","id":APP_ID}}}}}
        _,c=req(token,"/v1/subscriptionGroups","POST",payload); group=c["data"]; actions.append("created_subscription_group")
    gid=group["id"]
    _,sp=req(token,f"/v1/subscriptionGroups/{gid}/subscriptions?limit=200")
    sub=by_product(rows(sp),MONTHLY_ID)
    if sub is None:
        payload={"data":{"type":"subscriptions","attributes":{"name":"看護師国試 プレミアム月額","productId":MONTHLY_ID,"subscriptionPeriod":"ONE_MONTH","familySharable":False,"groupLevel":1,"reviewNote":"全720問・分野別・本番形式・弱点学習を月額で解放します。"},"relationships":{"group":{"data":{"type":"subscriptionGroups","id":gid}}}}}
        _,c=req(token,"/v1/subscriptions","POST",payload); sub=c["data"]; actions.append("created_monthly")
    sid=sub["id"]
    _,lp=req(token,f"/v1/subscriptions/{sid}/subscriptionLocalizations?limit=200")
    if not any(x.get("attributes",{}).get("locale")=="ja" for x in rows(lp)):
        payload={"data":{"type":"subscriptionLocalizations","attributes":{"name":"看護師国試 プレミアム月額","locale":"ja","description":"全720問・分野別・本番形式・弱点学習を月額で利用できます。"},"relationships":{"subscription":{"data":{"type":"subscriptions","id":sid}}}}}
        req(token,"/v1/subscriptionLocalizations","POST",payload); actions.append("localized_monthly_ja")
    _,prices=req(token,f"/v1/subscriptions/{sid}/prices?filter[territory]={JPN}&include=subscriptionPricePoint&limit=200")
    inc={x.get("id"):x for x in prices.get("included",[]) if x.get("type")=="subscriptionPricePoints"}
    ok=False
    for price in rows(prices):
        rid=(price.get("relationships",{}).get("subscriptionPricePoint",{}).get("data") or {}).get("id")
        if rid in inc and dec(inc[rid].get("attributes",{}).get("customerPrice"))==MONTHLY_PRICE: ok=True
    if not ok:
        _,pts=req(token,f"/v1/subscriptions/{sid}/pricePoints?filter[territory]={JPN}&fields[subscriptionPricePoints]=customerPrice,territory&include=territory&limit=8000")
        point=next((x for x in rows(pts) if dec(x.get("attributes",{}).get("customerPrice"))==MONTHLY_PRICE),None)
        if point is None: raise RuntimeError("JPN 200 monthly price point not found")
        payload={"data":{"type":"subscriptionPrices","attributes":{"preserveCurrentPrice":False},"relationships":{"subscription":{"data":{"type":"subscriptions","id":sid}},"subscriptionPricePoint":{"data":{"type":"subscriptionPricePoints","id":point["id"]}}}}}
        req(token,"/v1/subscriptionPrices","POST",payload); actions.append("priced_monthly_200_jpn")
    return gid,sid

def main():
    issuer=os.environ["ASC_ISSUER_ID"]; kid=os.environ["ASC_KEY_ID"]; key=load_private_key(os.environ["ASC_PRIVATE_KEY"]); token=make_token(issuer,kid,key)
    actions=[]; iid=ensure_lifetime(token,actions); gid,sid=ensure_monthly(token,actions)
    result={"task_id":"APP2-009","app_id":APP_ID,"monthly":{"product_id":MONTHLY_ID,"price_jpn":"200","id":sid},"lifetime":{"product_id":LIFETIME_ID,"price_jpn":"800","id":iid},"subscription_group_id":gid,"actions":actions,"ok":True}
    OUT.parent.mkdir(parents=True,exist_ok=True); OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8"); print(json.dumps(result,ensure_ascii=False))
if __name__=="__main__": main()
