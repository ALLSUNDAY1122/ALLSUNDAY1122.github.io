#!/usr/bin/env python3
"""APP2-005 compatibility runner for current App Store Connect subscription/IAP metadata APIs."""
import copy
import app2_005_hm1_iap_bootstrap as bootstrap

_original_req = bootstrap.req

def _rows(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else [data]

def _ensure_draft_version(token, kind, parent_id):
    if kind == "iap":
        list_path=f"/v2/inAppPurchases/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=200"
        create_path="/v1/inAppPurchaseVersions"; version_type="inAppPurchaseVersions"; relationship="inAppPurchase"; parent_type="inAppPurchases"
    elif kind == "subscription":
        list_path=f"/v1/subscriptions/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=200"
        create_path="/v1/subscriptionVersions"; version_type="subscriptionVersions"; relationship="subscription"; parent_type="subscriptions"
    elif kind == "group":
        list_path=f"/v1/subscriptionGroups/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=200"
        create_path="/v1/subscriptionGroupVersions"; version_type="subscriptionGroupVersions"; relationship="subscriptionGroup"; parent_type="subscriptionGroups"
    else:
        raise ValueError(kind)
    _,listing=_original_req(token,list_path); versions=_rows(listing)
    if versions: return versions[-1]["id"],version_type
    payload={"data":{"type":version_type,"relationships":{relationship:{"data":{"type":parent_type,"id":parent_id}}}}}
    _,created=_original_req(token,create_path,"POST",payload)
    return created["data"]["id"],version_type

def _normalize_inline_price_payload(payload):
    payload=copy.deepcopy(payload); replacements={}
    for item in payload.get("included") or []:
        local_id=item.get("id")
        if isinstance(local_id,str) and not (local_id.startswith("${") and local_id.endswith("}")):
            normalized="${"+local_id+"}"; replacements[local_id]=normalized; item["id"]=normalized
        rel=(item.get("relationships") or {}).get("inAppPurchaseV2") or {}; related=rel.get("data") or {}
        if related.get("type")=="inAppPurchasesV2": related["type"]="inAppPurchases"
    manual=payload.get("data",{}).get("relationships",{}).get("manualPrices",{}).get("data",[])
    for item in manual:
        if item.get("id") in replacements: item["id"]=replacements[item["id"]]
    return payload

def _create_starting_subscription_price(token, original_payload):
    rels=original_payload.get("data",{}).get("relationships",{}); sub=(rels.get("subscription",{}).get("data") or {}); sub_id=sub.get("id")
    if not sub_id: raise RuntimeError("Missing subscription linkage")
    _,availability_payload=_original_req(token,f"/v1/subscriptions/{sub_id}/planAvailabilities?include=availableTerritories&limit=200")
    availabilities=_rows(availability_payload)
    plan_types=[x.get("attributes",{}).get("planType") for x in availabilities if x.get("attributes",{}).get("planType")]
    plan_type=next((p for p in ("PAY_AS_YOU_GO","UPFRONT") if p in plan_types), plan_types[0] if plan_types else None)
    point_path=f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]=JPN&fields[subscriptionPricePoints]=customerPrice,territory&include=territory&limit=8000"
    if plan_type: point_path=f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]=JPN&filter[planType]={plan_type}&fields[subscriptionPricePoints]=customerPrice,territory&include=territory&limit=8000"
    _,points_payload=_original_req(token,point_path)
    point=next((x for x in _rows(points_payload) if bootstrap.dec(x.get("attributes",{}).get("customerPrice"))==bootstrap.MONTHLY_PRICE),None)
    if point is None: raise RuntimeError(f"No JPN 200 starting price point found; available_plan_types={plan_types}")
    point_id=point["id"]
    _,detail=_original_req(token,f"/v1/subscriptionPricePoints/{point_id}?include=territory")
    d=detail.get("data",{}) if isinstance(detail,dict) else {}; territory_id=(d.get("relationships",{}).get("territory",{}).get("data") or {}).get("id") or "JPN"
    attrs={"startDate":None,"preserveCurrentPrice":False}
    if plan_type: attrs["planType"]=plan_type
    local_id="${app2-005-hm1-starting-price-jpn}"
    patch_payload={"data":{"type":"subscriptions","id":sub_id,"relationships":{"prices":{"data":[{"type":"subscriptionPrices","id":local_id}]}}},"included":[{"type":"subscriptionPrices","id":local_id,"attributes":attrs,"relationships":{"subscription":{"data":{"type":"subscriptions","id":sub_id}},"subscriptionPricePoint":{"data":{"type":"subscriptionPricePoints","id":point_id}},"territory":{"data":{"type":"territories","id":territory_id}}}}]}
    return _original_req(token,f"/v1/subscriptions/{sub_id}","PATCH",patch_payload)

def req(token,path,method="GET",payload=None):
    if method=="POST" and payload and isinstance(payload,dict):
        data=payload.get("data") or {}; relationships=data.get("relationships") or {}
        if path=="/v2/inAppPurchaseLocalizations" and "inAppPurchaseV2" in relationships:
            parent_id=relationships["inAppPurchaseV2"]["data"]["id"]; version_id,version_type=_ensure_draft_version(token,"iap",parent_id)
            payload=copy.deepcopy(payload); payload["data"]["relationships"]={"version":{"data":{"type":version_type,"id":version_id}}}
        elif path=="/v1/subscriptionLocalizations" and "subscription" in relationships:
            parent_id=relationships["subscription"]["data"]["id"]; version_id,version_type=_ensure_draft_version(token,"subscription",parent_id)
            payload=copy.deepcopy(payload); payload["data"]["relationships"]={"version":{"data":{"type":version_type,"id":version_id}}}; path="/v2/subscriptionLocalizations"
        elif path=="/v1/subscriptionGroupLocalizations" and "subscriptionGroup" in relationships:
            parent_id=relationships["subscriptionGroup"]["data"]["id"]; version_id,version_type=_ensure_draft_version(token,"group",parent_id)
            payload=copy.deepcopy(payload); payload["data"]["relationships"]={"version":{"data":{"type":version_type,"id":version_id}}}; path="/v2/subscriptionGroupLocalizations"
        elif path=="/v1/inAppPurchasePriceSchedules": payload=_normalize_inline_price_payload(payload)
        elif path=="/v1/subscriptionPrices": return _create_starting_subscription_price(token,payload)
    return _original_req(token,path,method,payload)

bootstrap.req=req
bootstrap.main()
