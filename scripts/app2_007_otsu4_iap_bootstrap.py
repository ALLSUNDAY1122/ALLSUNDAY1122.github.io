#!/usr/bin/env python3
"""Idempotently configure the Otsu4 lifetime IAP in App Store Connect.

Secrets are supplied only through GitHub Actions. The script is pinned to the
canonical app/bundle/product identifiers and refuses a bundle mismatch.
"""

import json
import os
import traceback
import urllib.error
import urllib.request
from decimal import Decimal
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = "6799755566"
BUNDLE_ID = "jp.allsunday1122.otsu4"
PRODUCT_ID = "jp.allsunday1122.otsu4.premium"
PRODUCT_NAME = "乙4 プレミアム"
PRODUCT_DESCRIPTION = "全720問・模擬試験6回・全範囲の復習を解放します。"
REVIEW_NOTE = (
    "アプリ内の「設定」→「Premium」から購入画面を開けます。"
    "購入後は全720問、模擬試験6回、全範囲の復習機能が解放されます。"
)
JPN = "JPN"
TARGET_PRICE = Decimal("800")
OUT = Path("automation/app2-007-otsu4-iap-result.json")


def write_result(payload):
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False))


def req(token, path, method="GET", payload=None):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    request = urllib.request.Request(
        BASE_URL + path,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"ASC {method} {path} HTTP {exc.code}: {raw[:4000]}") from exc


def rows(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else [data]


def by_product(items, product_id):
    return next((item for item in items if item.get("attributes", {}).get("productId") == product_id), None)


def decimal(value):
    try:
        return Decimal(str(value))
    except Exception:
        return Decimal("-1")


def ensure_product(token, actions):
    _, existing_payload = req(token, f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=200")
    item = by_product(rows(existing_payload), PRODUCT_ID)
    if item is None:
        payload = {
            "data": {
                "type": "inAppPurchases",
                "attributes": {
                    "name": PRODUCT_NAME,
                    "productId": PRODUCT_ID,
                    "inAppPurchaseType": "NON_CONSUMABLE",
                    "reviewNote": REVIEW_NOTE,
                    "familySharable": False,
                },
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        }
        _, created = req(token, "/v2/inAppPurchases", "POST", payload)
        item = created["data"]
        actions.append("created_non_consumable")

    product_id = item["id"]
    _, detail = req(token, f"/v2/inAppPurchases/{product_id}?include=inAppPurchaseLocalizations")
    localized = any(
        x.get("type") == "inAppPurchaseLocalizations" and x.get("attributes", {}).get("locale") == "ja"
        for x in detail.get("included", [])
    )
    if not localized:
        payload = {
            "data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {
                    "name": PRODUCT_NAME,
                    "locale": "ja",
                    "description": PRODUCT_DESCRIPTION,
                },
                "relationships": {
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchasesV2", "id": product_id}}
                },
            }
        }
        req(token, "/v2/inAppPurchaseLocalizations", "POST", payload)
        actions.append("localized_ja")

    try:
        req(token, f"/v2/inAppPurchases/{product_id}/iapPriceSchedule")
        has_price_schedule = True
    except RuntimeError as exc:
        if "HTTP 404" not in str(exc):
            raise
        has_price_schedule = False

    if not has_price_schedule:
        _, points = req(
            token,
            f"/v2/inAppPurchases/{product_id}/pricePoints?filter[territory]={JPN}"
            "&fields[inAppPurchasePricePoints]=customerPrice,territory&include=territory&limit=8000",
        )
        point = next(
            (
                x
                for x in rows(points)
                if decimal(x.get("attributes", {}).get("customerPrice")) == TARGET_PRICE
            ),
            None,
        )
        if point is None:
            raise RuntimeError("JPN 800 JPY in-app purchase price point not found")
        inline_id = "app2-007-otsu4-lifetime-jpn"
        payload = {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": product_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": JPN}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": inline_id}]},
                },
            },
            "included": [
                {
                    "type": "inAppPurchasePrices",
                    "id": inline_id,
                    "attributes": {"startDate": None},
                    "relationships": {
                        "inAppPurchaseV2": {"data": {"type": "inAppPurchasesV2", "id": product_id}},
                        "inAppPurchasePricePoint": {
                            "data": {"type": "inAppPurchasePricePoints", "id": point["id"]}
                        },
                    },
                }
            ],
        }
        req(token, "/v1/inAppPurchasePriceSchedules", "POST", payload)
        actions.append("priced_800_jpy")

    return product_id


def collect_state(token, product_resource_id, actions):
    _, app = req(token, f"/v1/apps/{APP_ID}")
    actual_bundle = app["data"].get("attributes", {}).get("bundleId")
    if actual_bundle != BUNDLE_ID:
        raise RuntimeError(f"Bundle mismatch: expected {BUNDLE_ID}, got {actual_bundle!r}")

    _, product = req(
        token,
        f"/v2/inAppPurchases/{product_resource_id}?include=inAppPurchaseLocalizations,iapPriceSchedule",
    )
    _, all_products = req(token, f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=200")
    matching = by_product(rows(all_products), PRODUCT_ID)
    if not matching or matching.get("id") != product_resource_id:
        raise RuntimeError("Product read-back mismatch")

    localization = [
        x.get("attributes", {})
        for x in product.get("included", [])
        if x.get("type") == "inAppPurchaseLocalizations"
        and x.get("attributes", {}).get("locale") == "ja"
    ]
    return {
        "task_id": "APP2-007",
        "app": {"id": APP_ID, "bundle_id": actual_bundle},
        "product": {
            "resource_id": product_resource_id,
            "product_id": PRODUCT_ID,
            "type": "NON_CONSUMABLE",
            "target_price_jpy": "800",
            "state": product["data"].get("attributes", {}).get("state"),
            "localization_ja": localization[0] if localization else None,
        },
        "actions": actions,
        "review_screenshot_required_before_submission": True,
        "ok": True,
    }


def main():
    actions = []
    cleanup = None
    try:
        issuer = os.environ["ASC_ISSUER_ID"]
        key_id = os.environ["ASC_KEY_ID"]
        key_path, cleanup = load_private_key()
        token = make_token(issuer, key_id, key_path)

        _, app = req(token, f"/v1/apps/{APP_ID}")
        actual_bundle = app["data"].get("attributes", {}).get("bundleId")
        if actual_bundle != BUNDLE_ID:
            raise RuntimeError(f"Bundle mismatch: expected {BUNDLE_ID}, got {actual_bundle!r}")

        product_resource_id = ensure_product(token, actions)
        write_result(collect_state(token, product_resource_id, actions))
    except Exception as exc:
        write_result(
            {
                "task_id": "APP2-007",
                "app_id": APP_ID,
                "bundle_id": BUNDLE_ID,
                "product_id": PRODUCT_ID,
                "actions": actions,
                "ok": False,
                "error": str(exc),
                "traceback_tail": traceback.format_exc()[-5000:],
            }
        )
        raise
    finally:
        if cleanup:
            try:
                cleanup.unlink(missing_ok=True)
            except Exception:
                pass


if __name__ == "__main__":
    main()
