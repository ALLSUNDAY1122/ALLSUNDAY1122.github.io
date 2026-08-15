#!/usr/bin/env python3
"""Idempotently configure the Hokenshi non-consumable IAP in App Store Connect.

Requires Codemagic App Store Connect integration credentials in:
APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_KEY_IDENTIFIER,
APP_STORE_CONNECT_PRIVATE_KEY.
"""

from __future__ import annotations

import json
import os
import sys
import time
import uuid
from decimal import Decimal
from urllib.parse import quote

import jwt
import requests

BASE = "https://api.appstoreconnect.apple.com"
APP_ID = "6801783499"
PRODUCT_ID = "jp.allsunday1122.hokenshi.premium"
REFERENCE_NAME = "保健師国家試験 プレミアム解放"
DISPLAY_NAME = "プレミアム解放"
DESCRIPTION = "残り300問と模試機能を買い切りで解放します。購入済みの場合は購入を復元できます。"
REVIEW_NOTE = "無料30問から、残り300問と模試機能を非消耗型の買い切りで解放します。StoreKit 2の購入復元に対応しています。"
TARGET_JPY = Decimal("800")


def require(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def make_token() -> str:
    issuer = require("APP_STORE_CONNECT_ISSUER_ID")
    key_id = require("APP_STORE_CONNECT_KEY_IDENTIFIER")
    private_key = require("APP_STORE_CONNECT_PRIVATE_KEY")
    if "\\n" in private_key and "\n" not in private_key:
        private_key = private_key.replace("\\n", "\n")
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def request(method: str, path: str, *, params=None, payload=None, expected=(200,)):
    token = make_token()
    response = requests.request(
        method,
        BASE + path,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        params=params,
        data=json.dumps(payload, ensure_ascii=False) if payload is not None else None,
        timeout=60,
    )
    if response.status_code not in expected:
        body = response.text[:4000]
        raise RuntimeError(f"{method} {path} -> {response.status_code}: {body}")
    if not response.content:
        return None
    return response.json()


def get_or_create_iap() -> str:
    existing = request(
        "GET",
        f"/v1/apps/{APP_ID}/inAppPurchasesV2",
        params={"filter[productId]": PRODUCT_ID, "limit": 20},
    )
    matches = [x for x in existing.get("data", []) if x.get("attributes", {}).get("productId") == PRODUCT_ID]
    if matches:
        iap_id = matches[0]["id"]
        print(f"PASS: IAP already exists: {PRODUCT_ID} / {iap_id}")
        return iap_id

    payload = {
        "data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": REFERENCE_NAME,
                "productId": PRODUCT_ID,
                "inAppPurchaseType": "NON_CONSUMABLE",
                "reviewNote": REVIEW_NOTE,
                "availableInAllTerritories": True,
                "familySharable": False,
            },
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    }
    created = request("POST", "/v2/inAppPurchases", payload=payload, expected=(201,))
    iap_id = created["data"]["id"]
    print(f"PASS: created IAP: {PRODUCT_ID} / {iap_id}")
    return iap_id


def ensure_japanese_localization(iap_id: str) -> None:
    current = request("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations", params={"limit": 200})
    locales = {x.get("attributes", {}).get("locale") for x in current.get("data", [])}
    if "ja" in locales or "ja-JP" in locales:
        print("PASS: Japanese IAP localization already exists")
        return

    payload = {
        "data": {
            "type": "inAppPurchaseLocalizations",
            "attributes": {"locale": "ja", "name": DISPLAY_NAME, "description": DESCRIPTION},
            "relationships": {
                "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}
            },
        }
    }
    request("POST", "/v1/inAppPurchaseLocalizations", payload=payload, expected=(201,))
    print("PASS: created Japanese IAP localization")


def current_japan_price(iap_id: str) -> Decimal | None:
    schedule = request(
        "GET",
        f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule",
        params={"include": "manualPrices", "limit[manualPrices]": 50},
        expected=(200, 404),
    )
    if not schedule or not schedule.get("data"):
        return None
    manual_ids = {
        x.get("id")
        for x in schedule.get("included", [])
        if x.get("type") == "inAppPurchasePrices" and x.get("attributes", {}).get("startDate") is None
    }
    if not manual_ids:
        return None
    # Confirm the effective JPN price by reading manual prices with price points included.
    manual = request(
        "GET",
        f"/v1/inAppPurchasePriceSchedules/{iap_id}/manualPrices",
        params={"filter[territory]": "JPN", "include": "inAppPurchasePricePoint", "limit": 50},
        expected=(200, 404),
    )
    if not manual:
        return None
    points = {x["id"]: x.get("attributes", {}) for x in manual.get("included", []) if x.get("type") == "inAppPurchasePricePoints"}
    for row in manual.get("data", []):
        if row.get("attributes", {}).get("startDate") is not None:
            continue
        rel = row.get("relationships", {}).get("inAppPurchasePricePoint", {}).get("data") or {}
        attrs = points.get(rel.get("id"), {})
        if attrs.get("customerPrice") is not None:
            return Decimal(str(attrs["customerPrice"]))
    return None


def ensure_japan_price(iap_id: str) -> None:
    current = current_japan_price(iap_id)
    if current == TARGET_JPY:
        print("PASS: Japan IAP price already equals 800 JPY")
        return
    if current is not None:
        raise RuntimeError(f"Existing JPN price is {current} JPY; refusing to overwrite an existing price automatically")

    points = request(
        "GET",
        f"/v2/inAppPurchases/{iap_id}/pricePoints",
        params={
            "filter[territory]": "JPN",
            "fields[inAppPurchasePricePoints]": "customerPrice,territory",
            "include": "territory",
            "limit": 8000,
        },
    )
    candidates = []
    for point in points.get("data", []):
        value = point.get("attributes", {}).get("customerPrice")
        if value is not None and Decimal(str(value)) == TARGET_JPY:
            candidates.append(point["id"])
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one 800 JPY price point, found {len(candidates)}")
    price_point_id = candidates[0]
    local_price_id = str(uuid.uuid4())
    payload = {
        "data": {
            "type": "inAppPurchases",
            "id": iap_id,
            "attributes": {},
            "relationships": {
                "prices": {"data": [{"type": "inAppPurchasePrices", "id": local_price_id}]}
            },
        },
        "included": [
            {
                "type": "inAppPurchasePrices",
                "id": local_price_id,
                "attributes": {"startDate": None},
                "relationships": {
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchasesV2", "id": iap_id}},
                    "inAppPurchasePricePoint": {
                        "data": {"type": "inAppPurchasePricePoints", "id": price_point_id}
                    },
                },
            }
        ],
    }
    request("POST", "/v1/inAppPurchasePriceSchedules", payload=payload, expected=(201,))
    print(f"PASS: configured Japan IAP price at {TARGET_JPY} JPY")


def main() -> int:
    iap_id = get_or_create_iap()
    ensure_japanese_localization(iap_id)
    ensure_japan_price(iap_id)
    final = request("GET", f"/v2/inAppPurchases/{iap_id}")
    attrs = final.get("data", {}).get("attributes", {})
    if attrs.get("productId") != PRODUCT_ID or attrs.get("inAppPurchaseType") != "NON_CONSUMABLE":
        raise RuntimeError("Final IAP verification failed")
    print(f"PASS: final IAP state={attrs.get('state')} id={iap_id}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
