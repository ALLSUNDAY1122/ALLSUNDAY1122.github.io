#!/usr/bin/env python3
"""Configure the fixed HM2 Japanese IAP prices safely and idempotently.

This script is intentionally app-specific: it can only touch the two known
HealthManager2 products. Credentials come from GitHub Actions secrets.
"""
import json
import os
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799751657"
BUNDLE_ID = "jp.allsunday1122.healthmanager2"
SUBSCRIPTION_ID = "6802988571"
IAP_ID = "6802989207"
TERRITORY = "JPN"
MONTHLY_PRICE = "200"
LIFETIME_PRICE = "800"


def data_list(resp):
    if not isinstance(resp, dict):
        return []
    d = resp.get("data")
    return d if isinstance(d, list) else ([d] if isinstance(d, dict) else [])


def find_price_point(resp, customer_price):
    for item in data_list(resp):
        if str((item.get("attributes") or {}).get("customerPrice")) == customer_price:
            return item
    raise RuntimeError(f"No {TERRITORY} price point for customerPrice={customer_price}")


def preflight(token):
    _, app = api_get(token, f"/v1/apps/{APP_ID}")
    actual = ((app.get("data") or {}).get("attributes") or {}).get("bundleId")
    if actual != BUNDLE_ID:
        raise RuntimeError(f"HM2 bundle preflight failed: {actual!r}")

    _, subs = api_get(token, f"/v1/subscriptions/{SUBSCRIPTION_ID}")
    sub_product = ((subs.get("data") or {}).get("attributes") or {}).get("productId")
    if sub_product != "jp.allsunday1122.healthmanager2.monthly":
        raise RuntimeError(f"Unexpected subscription productId: {sub_product!r}")

    _, iap = api_get(token, f"/v2/inAppPurchases/{IAP_ID}")
    iap_product = ((iap.get("data") or {}).get("attributes") or {}).get("productId")
    if iap_product != "jp.allsunday1122.healthmanager2.lifetime":
        raise RuntimeError(f"Unexpected IAP productId: {iap_product!r}")


def ensure_monthly_plan_availability(token, result):
    _, avail = api_get(token, f"/v1/subscriptions/{SUBSCRIPTION_ID}/planAvailabilities?include=availableTerritories&limit=20")
    for item in data_list(avail):
        attrs = item.get("attributes") or {}
        if attrs.get("planType") != "MONTHLY":
            continue
        rel = ((item.get("relationships") or {}).get("availableTerritories") or {}).get("data") or []
        if any(x.get("id") == TERRITORY for x in rel if isinstance(x, dict)):
            result["monthly_plan_availability"] = {"changed": False, "id": item.get("id"), "territory": TERRITORY}
            return
        # Existing MONTHLY config: replace available territories with JPN only for
        # this launch configuration rather than creating a duplicate plan.
        payload = {"data": [{"type": "territories", "id": TERRITORY}]}
        status, _ = api_request(token, f"/v1/subscriptionPlanAvailabilities/{item['id']}/relationships/availableTerritories", method="PATCH", payload=payload)
        result["monthly_plan_availability"] = {"changed": True, "http_status": status, "id": item.get("id"), "territory": TERRITORY}
        return

    payload = {
        "data": {
            "type": "subscriptionPlanAvailabilities",
            "attributes": {"planType": "MONTHLY", "availableInNewTerritories": True},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": SUBSCRIPTION_ID}},
                "availableTerritories": {"data": [{"type": "territories", "id": TERRITORY}]},
            },
        }
    }
    status, created = api_request(token, "/v1/subscriptionPlanAvailabilities", method="POST", payload=payload)
    result["monthly_plan_availability"] = {"changed": True, "http_status": status, "id": (created.get("data") or {}).get("id") if isinstance(created, dict) else None, "territory": TERRITORY}


def configure_subscription(token, result):
    ensure_monthly_plan_availability(token, result)
    _, points = api_get(token, f"/v1/subscriptions/{SUBSCRIPTION_ID}/pricePoints?filter[territory]={TERRITORY}&include=territory&limit=200")
    point = find_price_point(points, MONTHLY_PRICE)

    _, prices = api_get(token, f"/v1/subscriptions/{SUBSCRIPTION_ID}/prices?filter[territory]={TERRITORY}&include=subscriptionPricePoint,territory&limit=200")
    current = [p for p in data_list(prices) if (p.get("attributes") or {}).get("startDate") is None]
    if any(((p.get("relationships") or {}).get("subscriptionPricePoint") or {}).get("data", {}).get("id") == point["id"] for p in current):
        result["monthly"] = {"changed": False, "price": MONTHLY_PRICE, "price_point_id": point["id"]}
        return

    payload = {
        "data": {
            "type": "subscriptionPrices",
            "attributes": {"startDate": None, "planType": "MONTHLY"},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": SUBSCRIPTION_ID}},
                "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point["id"]}},
            },
        }
    }
    status, created = api_request(token, "/v1/subscriptionPrices", method="POST", payload=payload)
    result["monthly"] = {"changed": True, "http_status": status, "price": MONTHLY_PRICE, "price_point_id": point["id"], "created_id": (created.get("data") or {}).get("id") if isinstance(created, dict) else None}


def configure_lifetime(token, result):
    _, points = api_get(token, f"/v2/inAppPurchases/{IAP_ID}/pricePoints?filter[territory]={TERRITORY}&include=territory&limit=200")
    point = find_price_point(points, LIFETIME_PRICE)

    schedule = None
    try:
        _, schedule = api_get(token, f"/v2/inAppPurchases/{IAP_ID}/iapPriceSchedule?include=baseTerritory,manualPrices&limit[manualPrices]=200")
    except RuntimeError as exc:
        if "HTTP 404" not in str(exc):
            raise

    schedule_data = (schedule or {}).get("data") if isinstance(schedule, dict) else None
    if isinstance(schedule_data, dict):
        base = (((schedule_data.get("relationships") or {}).get("baseTerritory") or {}).get("data") or {}).get("id")
        included = (schedule or {}).get("included") or []
        for item in included:
            if item.get("type") != "inAppPurchasePrices":
                continue
            pp = ((((item.get("relationships") or {}).get("inAppPurchasePricePoint") or {}).get("data") or {}).get("id"))
            start = (item.get("attributes") or {}).get("startDate")
            if base == TERRITORY and pp == point["id"] and start is None:
                result["lifetime"] = {"changed": False, "price": LIFETIME_PRICE, "price_point_id": point["id"]}
                return

    manual_id = "manualPrice-0"
    payload = {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": IAP_ID}},
                "baseTerritory": {"data": {"type": "territories", "id": TERRITORY}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": manual_id}]},
            },
        },
        "included": [
            {
                "type": "inAppPurchasePrices",
                "id": manual_id,
                "attributes": {"startDate": None},
                "relationships": {
                    "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point["id"]}},
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": IAP_ID}},
                },
            }
        ],
    }
    status, created = api_request(token, "/v1/inAppPurchasePriceSchedules", method="POST", payload=payload)
    result["lifetime"] = {"changed": True, "http_status": status, "price": LIFETIME_PRICE, "price_point_id": point["id"], "created_id": (created.get("data") or {}).get("id") if isinstance(created, dict) else None}


def readback(token, result):
    _, prices = api_get(token, f"/v1/subscriptions/{SUBSCRIPTION_ID}/prices?filter[territory]={TERRITORY}&include=subscriptionPricePoint,territory&limit=200")
    result["monthly_readback"] = prices
    _, schedule = api_get(token, f"/v2/inAppPurchases/{IAP_ID}/iapPriceSchedule?include=baseTerritory,manualPrices&limit[manualPrices]=200")
    result["lifetime_readback"] = schedule


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing App Store Connect credentials")
    key_path, cleanup = load_private_key()
    result = {"app_id": APP_ID, "bundle_id": BUNDLE_ID, "territory": TERRITORY}
    try:
        token = make_token(issuer, key_id, key_path)
        preflight(token)
        configure_subscription(token, result)
        configure_lifetime(token, result)
        readback(token, result)
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
    Path("hm2-iap-price-result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PASS: HM2 IAP pricing configured/read back for JPN")


if __name__ == "__main__":
    main()
