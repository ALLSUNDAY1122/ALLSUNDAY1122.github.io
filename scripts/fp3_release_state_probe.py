#!/usr/bin/env python3
"""Read-only FP3 App Store Connect release-state probe.

Fail-closed target identity; no ASC mutation is performed. Parent-app availability
is intentionally excluded because that relationship is not readable through the
current gateway/API combination. IAP release metadata remains fully observable.
"""
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

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


def list_territories(token: str, availability_id: str) -> list[str]:
    """Read all pages; an include is capped at 50 and is not a complete list."""
    resource = f"/v1/inAppPurchaseAvailabilities/{availability_id}/availableTerritories"
    path = resource + "?limit=50"
    result: set[str] = set()
    visited: set[str] = set()
    while path:
        if path in visited or len(visited) >= 20:
            raise RuntimeError("Invalid territory pagination")
        visited.add(path)
        _, payload = api_get(token, path)
        for item in payload.get("data") or []:
            if item.get("type") != "territories" or not item.get("id"):
                raise RuntimeError("Invalid territory response")
            result.add(str(item["id"]))
        next_url = (payload.get("links") or {}).get("next")
        if not next_url:
            break
        parsed = urlsplit(next_url)
        if ((parsed.netloc and (parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com"))
                or parsed.path != resource or parsed.fragment):
            raise RuntimeError("Unexpected territory pagination target")
        path = parsed.path + ("?" + parsed.query if parsed.query else "")
    return sorted(result)


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

        iap_av = safe_get(
            token,
            f"/v2/inAppPurchases/{IAP_ID}/inAppPurchaseAvailability",
        )
        _, loc = api_get(token, f"/v2/inAppPurchases/{IAP_ID}/inAppPurchaseLocalizations?limit=50")
        price = safe_get(
            token,
            f"/v2/inAppPurchases/{IAP_ID}/iapPriceSchedule?include=baseTerritory,manualPrices&limit[manualPrices]=50",
        )
        screenshot = safe_get(token, f"/v2/inAppPurchases/{IAP_ID}/appStoreReviewScreenshot")

        iap_available = []
        if iap_av["ok"]:
            availability_id = (iap_av["payload"].get("data") or {}).get("id")
            if not availability_id or not str(availability_id).isdigit():
                raise RuntimeError("Invalid IAP availability identity")
            iap_available = list_territories(token, str(availability_id))

        _, versions = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=10")
        version_summary = [
            {"version": (v.get("attributes") or {}).get("versionString"),
             "platform": (v.get("attributes") or {}).get("platform"),
             "state": (v.get("attributes") or {}).get("appStoreState")}
            for v in versions.get("data") or []
        ]
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
            "app_store_versions": version_summary,
            "iap_availability": {
                "exists": iap_av["ok"],
                "status": iap_av["status"],
                "available_territories": iap_available,
                "complete": iap_av["ok"],
            },
            "localizations": localizations,
            "price_schedule": price_summary,
            "review_screenshot": {"exists": screenshot["ok"], "status": screenshot["status"]},
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
