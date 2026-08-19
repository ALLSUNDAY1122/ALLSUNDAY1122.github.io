#!/usr/bin/env python3
"""APP2-009 compatibility runner for App Store Connect versioned IAP metadata APIs."""
import copy
from datetime import date
import app2_009_kangoshi_iap_bootstrap as bootstrap

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
    _,listing=_original_req(token,list_path)
    versions=_rows(listing)
    if versions: return versions[-1]["id"],version_type
    payload={"data":{"type":version_type,"relationships":{relationship:{"data":{"type":parent_type,"id":parent_id}}}}}
    _,created=_original_req(token,create_path,"POST",payload)
    return created["data"]["id"],version_type

def _normalize_inline_price_payload(payload):
    payload=copy.deepcopy(payload)
    replacements={}
    for item in payload.get("included") or []:
        local_id=item.get("id")
        if isinstance(local_id,str) and not (local_id.startswith("${") and local_id.endswith("}")):
            normalized="${"+local_id+"}"; replacements[local_id]=normalized; item["id"]=normalized
        rel=(item.get("relationships") or {}).get("inAppPurchaseV2") or {}
        related=rel.get("data") or {}
        if related.get("type")=="inAppPurchasesV2": related["type"]="inAppPurchases"
    manual=payload.get("data",{}).get("relationships",{}).get("manualPrices",{}).get("data",[])
    for item in manual:
        if item.get("id") in replacements: item["id"]=replacements[item["id"]]
    return payload

def req(token,path,method="GET",payload=None):
    if method=="POST" and payload and isinstance(payload,dict):
        data=payload.get("data") or {}; relationships=data.get("relationships") or {}
        if path=="/v2/inAppPurchaseLocalizations" and "inAppPurchaseV2" in relationships:
            parent_id=relationships["inAppPurchaseV2"]["data"]["id"]
            version_id,version_type=_ensure_draft_version(token,"iap",parent_id)
            payload=copy.deepcopy(payload); payload["data"]["relationships"]={"version":{"data":{"type":version_type,"id":version_id}}}
        elif path=="/v1/subscriptionLocalizations" and "subscription" in relationships:
            parent_id=relationships["subscription"]["data"]["id"]
            version_id,version_type=_ensure_draft_version(token,"subscription",parent_id)
            payload=copy.deepcopy(payload); payload["data"]["relationships"]={"version":{"data":{"type":version_type,"id":version_id}}}; path="/v2/subscriptionLocalizations"
        elif path=="/v1/subscriptionGroupLocalizations" and "subscriptionGroup" in relationships:
            parent_id=relationships["subscriptionGroup"]["data"]["id"]
            version_id,version_type=_ensure_draft_version(token,"group",parent_id)
            payload=copy.deepcopy(payload); payload["data"]["relationships"]={"version":{"data":{"type":version_type,"id":version_id}}}; path="/v2/subscriptionGroupLocalizations"
        elif path=="/v1/inAppPurchasePriceSchedules":
            payload=_normalize_inline_price_payload(payload)
        elif path=="/v1/subscriptionPrices":
            payload=copy.deepcopy(payload); payload.setdefault("data",{}).setdefault("attributes",{}).setdefault("startDate",date.today().isoformat())
    return _original_req(token,path,method,payload)

bootstrap.req=req
bootstrap.main()
