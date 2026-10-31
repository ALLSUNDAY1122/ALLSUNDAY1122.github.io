#!/usr/bin/env python3
"""Read-only, sanitized Apple App Store and IAP asset audit for Pitari 1.0."""
from __future__ import annotations
import json, os
from datetime import datetime, timezone
from pathlib import Path
from app_store_connect_api import api_get, load_private_key, make_token

APP_ID="6795941132"
BUNDLE_ID="jp.allsunday.pitariresize"
VERSION_ID="e0aa7c21-0569-4e59-85e7-3cc3afe65dff"
IAP_ID="6798713983"

def rows(payload):
    value=payload.get("data") if isinstance(payload,dict) else None
    return value if isinstance(value,list) else [value] if isinstance(value,dict) else []

def read(token,path):
    try:
        status,payload=api_get(token,path)
        return {"ok":True,"status":status,"data":payload}
    except Exception as exc:
        # Avoid publishing arbitrary server error bodies or credential-bearing traces.
        return {"ok":False,"error_type":type(exc).__name__,"http_404":("HTTP 404" in str(exc))}

def attrs(item):
    return (item or {}).get("attributes") or {}

def main():
    result={"read_only":True,"app_id":APP_ID,"bundle_id":BUNDLE_ID,"version":"1.0","build":"11","checked_at":datetime.now(timezone.utc).isoformat(),"localizations":[]}
    key_path,cleanup=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key_path)
        app=read(token,f"/v1/apps/{APP_ID}")
        if not app["ok"] or attrs(rows(app["data"])[0]).get("bundleId")!=BUNDLE_ID:
            raise RuntimeError("App identity mismatch; aborting")
        locs=read(token,f"/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations?limit=100")
        if not locs["ok"]: raise RuntimeError("Version localization list failed")
        for loc in rows(locs["data"]):
            a=attrs(loc)
            entry={"locale":a.get("locale"),"localization_id":loc.get("id"),"has_description":bool(a.get("description")),"has_keywords":bool(a.get("keywords")),"has_support_url":bool(a.get("supportUrl")),"has_marketing_url":bool(a.get("marketingUrl")),"screenshot_sets":[]}
            sets=read(token,f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?limit=100")
            if sets["ok"]:
                for ss in rows(sets["data"]):
                    ssid=ss.get("id")
                    shots=read(token,f"/v1/appScreenshotSets/{ssid}/appScreenshots?limit=100")
                    entry["screenshot_sets"].append({
                        "set_id":ssid,
                        "display_type":attrs(ss).get("screenshotDisplayType"),
                        "screenshots_count":len(rows(shots.get("data"))) if shots["ok"] else None,
                        "screenshots_ok":shots["ok"],
                        "screenshots":[{"id":im.get("id"),"asset_status":attrs(im).get("assetDeliveryState",{}).get("state") if isinstance(attrs(im).get("assetDeliveryState"),dict) else None} for im in rows(shots.get("data"))] if shots["ok"] else []
                    })
            else: entry["screenshot_sets_error"]=sets["error_type"]
            result["localizations"].append(entry)
        iap=read(token,f"/v2/inAppPurchases/{IAP_ID}")
        result["iap"]={"read_ok":iap["ok"]}
        if iap["ok"]:
            item=rows(iap["data"])[0]
            b=attrs(item)
            result["iap"].update({"id":item.get("id"),"name":b.get("name"),"product_id":b.get("productId"),"type":b.get("inAppPurchaseType"),"state":b.get("state")})
        else:result["iap"].update({k:iap.get(k) for k in ("error_type","http_404")})
        shot=read(token,f"/v2/inAppPurchases/{IAP_ID}/appStoreReviewScreenshot")
        result["iap_review_screenshot"]={"read_ok":shot["ok"],"exists":bool(rows(shot.get("data"))) if shot["ok"] else False}
        if shot["ok"] and rows(shot["data"]):
            result["iap_review_screenshot"].update({"id":rows(shot["data"])[0].get("id"),"asset_delivery_state":attrs(rows(shot["data"])[0]).get("assetDeliveryState")})
        else: result["iap_review_screenshot"]["http_404"]=shot.get("http_404")
        versions=read(token,f"/v2/inAppPurchases/{IAP_ID}/versions?limit=100")
        result["iap_versions"]={"read_ok":versions["ok"],"versions":[{"id":x.get("id"),"state":attrs(x).get("state")} for x in rows(versions.get("data"))] if versions["ok"] else []}
        result["summary"]={
            "locales":[x["locale"] for x in result["localizations"]],
            "screenshot_count":sum((s.get("screenshots_count") or 0) for x in result["localizations"] for s in x.get("screenshot_sets",[])),
            "has_any_support_url":any(x["has_support_url"] for x in result["localizations"]),
            "iap_review_screenshot_exists":result["iap_review_screenshot"]["exists"],
        }
        out=Path(os.environ.get("PITARI_ASSET_RESULT","/tmp/pitari-asset-check.json"))
        out.parent.mkdir(parents=True,exist_ok=True)
        out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print("PASS: sanitized Pitari Apple asset readback saved; no mutations")
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)

if __name__=="__main__":main()
