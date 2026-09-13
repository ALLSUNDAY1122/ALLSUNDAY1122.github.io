#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

APP_ID = "6799751657"
BUNDLE_ID = "jp.allsunday1122.healthmanager2"
SUB_ID = "6802988571"
IAP_ID = "6802989207"
OUT = Path(os.environ.get("HM2_ASC_RESULT", "hm2-release-readback.json"))


def data(payload):
    return payload.get("data") if isinstance(payload, dict) else None


def attrs(resource):
    return (resource or {}).get("attributes") or {} if isinstance(resource, dict) else {}


def get(token: str, path: str):
    try:
        status, payload = api_get(token, path)
        return {"ok": True, "status": status, "payload": payload}
    except Exception as exc:
        return {"ok": False, "error": str(exc), "path": path}


def summarize_collection(result):
    if not result.get("ok"):
        return result
    items = data(result.get("payload"))
    if not isinstance(items, list):
        items = [] if items is None else [items]
    return [{"id": x.get("id"), "type": x.get("type"), "attributes": attrs(x)} for x in items]


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("missing ASC credentials")
    key_path, cleanup_path = load_private_key()
    result = {
        "task": "HM2 direct ASC release readback",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "mutated": False,
        "submitted": False,
        "testflight_changed": False,
    }
    try:
        token = make_token(issuer, key_id, key_path)
        app = get(token, f"/v1/apps/{APP_ID}")
        result["app"] = app
        if app.get("ok"):
            actual_bundle = attrs(data(app.get("payload"))).get("bundleId")
            if actual_bundle != BUNDLE_ID:
                raise RuntimeError(f"target mismatch: {actual_bundle!r}")

        versions = get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
        result["versions"] = summarize_collection(versions)
        editable = []
        for v in result["versions"] if isinstance(result["versions"], list) else []:
            a = v.get("attributes") or {}
            state = a.get("appStoreState") or a.get("appVersionState") or a.get("state")
            if a.get("platform") == "IOS" and state in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}:
                editable.append(v)
        result["editable_versions"] = editable

        if len(editable) == 1:
            vid = editable[0]["id"]
            result["version_localizations"] = summarize_collection(get(token, f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=50"))
            result["selected_build_relationship"] = get(token, f"/v1/appStoreVersions/{vid}/relationships/build")
            result["review_detail"] = get(token, f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")

        result["builds"] = summarize_collection(get(token, f"/v1/apps/{APP_ID}/builds?limit=100"))
        result["beta_groups"] = summarize_collection(get(token, f"/v1/apps/{APP_ID}/betaGroups?limit=50"))
        result["beta_app_localizations"] = summarize_collection(get(token, f"/v1/apps/{APP_ID}/betaAppLocalizations?limit=50"))
        result["app_infos"] = summarize_collection(get(token, f"/v1/apps/{APP_ID}/appInfos?limit=20"))

        result["subscription"] = get(token, f"/v1/subscriptions/{SUB_ID}")
        result["subscription_localizations"] = summarize_collection(get(token, f"/v1/subscriptions/{SUB_ID}/subscriptionLocalizations?limit=50"))
        result["subscription_prices_jpn"] = get(token, f"/v1/subscriptions/{SUB_ID}/prices?filter[territory]=JPN&include=subscriptionPricePoint,territory&limit=200")
        result["subscription_availability"] = get(token, f"/v1/subscriptions/{SUB_ID}/subscriptionAvailability?include=availableTerritories&limit[availableTerritories]=50")
        result["subscription_review_screenshot"] = get(token, f"/v1/subscriptions/{SUB_ID}/appStoreReviewScreenshot")

        # In-app purchases use v2 relationship endpoints. The old v1 relationship URLs returned 404 and
        # were an audit bug, not evidence that metadata was missing.
        result["lifetime_iap"] = get(token, f"/v2/inAppPurchases/{IAP_ID}")
        result["lifetime_localizations"] = summarize_collection(get(token, f"/v2/inAppPurchases/{IAP_ID}/inAppPurchaseLocalizations?limit=50"))
        result["lifetime_price_schedule"] = get(token, f"/v2/inAppPurchases/{IAP_ID}/iapPriceSchedule?include=baseTerritory,manualPrices&limit[manualPrices]=50")
        result["lifetime_availability"] = get(token, f"/v2/inAppPurchases/{IAP_ID}/inAppPurchaseAvailability?include=availableTerritories&limit[availableTerritories]=50")
        result["lifetime_review_screenshot"] = get(token, f"/v2/inAppPurchases/{IAP_ID}/appStoreReviewScreenshot")

        # Fail only on canonical target/version path. Optional endpoint failures remain evidence and make
        # the readback explicit rather than turning an API-shape issue into a false product failure.
        if not app.get("ok") or not isinstance(result.get("versions"), list):
            raise RuntimeError("canonical app/version readback failed")
    finally:
        if cleanup_path:
            cleanup_path.unlink(missing_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
