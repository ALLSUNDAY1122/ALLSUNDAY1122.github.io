#!/usr/bin/env python3
"""Create FP3 lifetime-IAP availability for Japan, only when missing.

The operation is intentionally narrow: exact app/IAP identity, JPN only,
availableInNewTerritories=false. Existing availability is never mutated.
A sanitized result is written on both success and failure.
"""
import json
import os
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6796733578"
BUNDLE_ID = "com.allsunday1122.fp3kakomoncoach"
IAP_ID = "6798730387"
PRODUCT_ID = "com.allsunday1122.fp3kakomoncoach.premium.lifetime"
TERRITORY = "JPN"
OUT = Path("fp3-iap-availability-result.json")


def persist(result: dict) -> None:
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")
    key_path, cleanup = load_private_key()
    result = {"app_id": APP_ID, "iap_id": IAP_ID, "territory": TERRITORY, "ok": False}
    try:
        token = make_token(issuer, key_id, key_path)
        _, app = api_get(token, f"/v1/apps/{APP_ID}")
        app_data = app.get("data") or {}
        if app_data.get("id") != APP_ID or ((app_data.get("attributes") or {}).get("bundleId")) != BUNDLE_ID:
            raise RuntimeError("FP3 app identity mismatch")

        _, iap = api_get(token, f"/v2/inAppPurchases/{IAP_ID}")
        iap_data = iap.get("data") or {}
        attrs = iap_data.get("attributes") or {}
        if iap_data.get("id") != IAP_ID or attrs.get("productId") != PRODUCT_ID:
            raise RuntimeError("FP3 IAP identity mismatch")

        availability_path = f"/v2/inAppPurchases/{IAP_ID}/inAppPurchaseAvailability?include=availableTerritories&limit[availableTerritories]=50"
        try:
            _, av = api_get(token, availability_path)
            existing = sorted({str(x.get("id")) for x in (av.get("included") or []) if isinstance(x, dict) and x.get("type") == "territories" and x.get("id")})
            if existing != [TERRITORY]:
                raise RuntimeError(f"Existing IAP availability is not the expected JPN-only set: {existing}")
            result.update({"ok": True, "changed": False, "available_territories": existing})
        except RuntimeError as exc:
            if "HTTP 404" not in str(exc):
                raise
            payload = {
                "data": {
                    "type": "inAppPurchaseAvailabilities",
                    "attributes": {"availableInNewTerritories": False},
                    "relationships": {
                        "availableTerritories": {"data": [{"type": "territories", "id": TERRITORY}]},
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": IAP_ID}},
                    },
                }
            }
            status, _ = api_request(token, "/v1/inAppPurchaseAvailabilities", method="POST", payload=payload)
            if status not in (200, 201):
                raise RuntimeError(f"IAP availability create returned HTTP {status}")
            _, check = api_get(token, availability_path)
            actual = sorted({str(x.get("id")) for x in (check.get("included") or []) if isinstance(x, dict) and x.get("type") == "territories" and x.get("id")})
            if actual != [TERRITORY]:
                raise RuntimeError(f"IAP availability read-back mismatch: {actual}")
            result.update({"ok": True, "changed": True, "http_status": status, "available_territories": actual})
        persist(result)
        print(json.dumps(result, ensure_ascii=False))
    except Exception as exc:
        result["error"] = str(exc)[:4000]
        persist(result)
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
