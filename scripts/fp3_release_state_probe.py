#!/usr/bin/env python3
"""Read-only FP3 App Store Connect release-state probe.

Fail-closed target identity; no ASC mutation is performed. The result is sanitized
and intended for release/preflight decisions before any TestFlight human test.
"""
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

APP_ID = "6796733578"
BUNDLE_ID = "com.allsunday1122.fp3kakomoncoach"
IAP_ID = "6798730387"
PRODUCT_ID = "com.allsunday1122.fp3kakomoncoach.premium.lifetime"


def safe_get(token: str, path: str) -> dict:
    try:
        status, payload = api_get(token, path)
        return {"ok": True, "status": status, "payload": payload}
    except RuntimeError as exc:
        text = str(exc)
        if "HTTP 404" in text:
            return {"ok": False, "status": 404, "error": "NOT_FOUND"}
        raise


def included_territories(payload: dict) -> list[str]:
    result = []
    for item in (payload.get("included") or []):
        if isinstance(item, dict) and item.get("type") == "territories" and item.get("id"):
            result.append(str(item["id"]))
    return sorted(set(result))


def main() -> None:
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)

        _, app = api_get(token, f"/v1/apps/{APP_ID}")
        app_data = app.get("data") or {}
        app_attrs = app_data.get("attributes") or {}
        if app_data.get("id") != APP_ID or app_attrs.get("bundleId") != BUNDLE_ID:
            raise RuntimeError("FP3 target identity mismatch")

        _, iap = api_get(token, f"/v2/inAppPurchases/{IAP_ID}")
        iap_data = iap.get("data") or {}
        iap_attrs = iap_data.get("attributes") or {}
        if iap_data.get("id") != IAP_ID or iap_attrs.get("productId") != PRODUCT_ID:
            raise RuntimeError("FP3 IAP identity mismatch")

        app_av = safe_get(
            token,
            f"/v1/apps/{APP_ID}/appAvailabilityV2?include=territoryAvailabilities&limit[territoryAvailabilities]=200",
        )
        iap_av = safe_get(
            token,
            f"/v1/inAppPurchaseAvailabilities/{IAP_ID}?include=availableTerritories&limit[availableTerritories]=200",
        )
        _, loc = api_get(token, f"/v1/inAppPurchases/{IAP_ID}/inAppPurchaseLocalizations?limit=50")
        price = safe_get(
            token,
            f"/v2/inAppPurchases/{IAP_ID}/iapPriceSchedule?include=baseTerritory,manualPrices&limit[manualPrices]=50",
        )

        app_available = []
        if app_av["ok"]:
            payload = app_av["payload"]
            for item in payload.get("included") or []:
                if not isinstance(item, dict) or item.get("type") != "territoryAvailabilities":
                    continue
                if (item.get("attributes") or {}).get("available") is not True:
                    continue
                rel = ((item.get("relationships") or {}).get("territory") or {}).get("data") or {}
                if rel.get("id"):
                    app_available.append(str(rel["id"]))

        iap_available = []
        if iap_av["ok"]:
            iap_available = included_territories(iap_av["payload"])

        localizations = []
        for item in loc.get("data") or []:
            attrs = item.get("attributes") or {}
            localizations.append({
                "locale": attrs.get("locale"),
                "name_present": bool(attrs.get("name")),
                "description_present": bool(attrs.get("description")),
            })

        price_summary = {"exists": price["ok"], "status": price["status"]}
        if price["ok"]:
            pdata = price["payload"].get("data") or {}
            base_rel = ((pdata.get("relationships") or {}).get("baseTerritory") or {}).get("data") or {}
            manual = [x for x in (price["payload"].get("included") or []) if isinstance(x, dict) and x.get("type") == "inAppPurchasePrices"]
            price_summary.update({"base_territory": base_rel.get("id"), "manual_price_count": len(manual)})

        result = {
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "app": {"id": APP_ID, "bundle_id": BUNDLE_ID, "name": app_attrs.get("name")},
            "iap": {"id": IAP_ID, "product_id": PRODUCT_ID, "state": iap_attrs.get("state")},
            "app_availability": {
                "exists": app_av["ok"],
                "status": app_av["status"],
                "available_territories": sorted(set(app_available)),
            },
            "iap_availability": {
                "exists": iap_av["ok"],
                "status": iap_av["status"],
                "available_territories": iap_available,
            },
            "localizations": localizations,
            "price_schedule": price_summary,
        }
        Path("fp3-release-state.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(json.dumps(result, ensure_ascii=False))
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
