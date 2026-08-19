#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.request
from decimal import Decimal
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = "6801792293"
BUNDLE_ID = "jp.allsunday1122.kangoshi"
PRODUCT_ID = "jp.allsunday1122.kangoshi.monthly"
GROUP_REFERENCE = "看護師国試プレミアム"
JPN = "JPN"
MONTHLY_PRICE = Decimal("200")
RESULT_PATH = Path("automation/app2-009-kangoshi-subscription-result.json")


def request(token, path, method="GET", payload=None):
    if not (path.startswith("/v1/") or path.startswith("/v2/")):
        raise ValueError(f"Unsupported ASC path: {path}")
    body = None
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(BASE_URL + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw.decode("utf-8")) if raw else None
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            detail = json.loads(raw)
        except json.JSONDecodeError:
            detail = {"raw": raw[:2000]}
        raise RuntimeError(f"ASC {method} {path} HTTP {exc.code}: {detail}") from None


def data_list(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else [data]


def by_product(items, product_id):
    return next((x for x in items if x.get("attributes", {}).get("productId") == product_id), None)


def decimal_equal(value, expected):
    try:
        return Decimal(str(value)) == expected
    except Exception:
        return False


def ensure_subscription(token, actions):
    _, groups_payload = request(token, f"/v1/apps/{APP_ID}/subscriptionGroups?limit=200")
    groups = data_list(groups_payload)
    group = next((x for x in groups if x.get("attributes", {}).get("referenceName") == GROUP_REFERENCE), None)
    if group is None:
        payload = {
            "data": {
                "type": "subscriptionGroups",
                "attributes": {"referenceName": GROUP_REFERENCE},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        }
        _, created = request(token, "/v1/subscriptionGroups", "POST", payload)
        group = created["data"]
        actions.append("created_subscription_group")
    group_id = group["id"]

    _, group_locs = request(token, f"/v1/subscriptionGroups/{group_id}/subscriptionGroupLocalizations?limit=200")
    if not any(x.get("attributes", {}).get("locale") == "ja" for x in data_list(group_locs)):
        payload = {
            "data": {
                "type": "subscriptionGroupLocalizations",
                "attributes": {"name": "看護師国試プレミアム", "locale": "ja"},
                "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group_id}}},
            }
        }
        request(token, "/v1/subscriptionGroupLocalizations", "POST", payload)
        actions.append("created_subscription_group_localization_ja")

    _, subs_payload = request(token, f"/v1/subscriptionGroups/{group_id}/subscriptions?limit=200")
    sub = by_product(data_list(subs_payload), PRODUCT_ID)
    if sub is None:
        payload = {
            "data": {
                "type": "subscriptions",
                "attributes": {
                    "name": "看護師国試 プレミアム月額",
                    "productId": PRODUCT_ID,
                    "subscriptionPeriod": "ONE_MONTH",
                    "familySharable": False,
                    "groupLevel": 1,
                    "reviewNote": "看護師国家試験のプレミアム学習機能を月額で解放します。"
                },
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": group_id}}},
            }
        }
        _, created = request(token, "/v1/subscriptions", "POST", payload)
        sub = created["data"]
        actions.append("created_monthly_subscription")
    sub_id = sub["id"]

    _, locs = request(token, f"/v1/subscriptions/{sub_id}/subscriptionLocalizations?limit=200")
    if not any(x.get("attributes", {}).get("locale") == "ja" for x in data_list(locs)):
        payload = {
            "data": {
                "type": "subscriptionLocalizations",
                "attributes": {
                    "name": "看護師国試 プレミアム月額",
                    "locale": "ja",
                    "description": "看護師国家試験のプレミアム学習機能を月額200円で利用できます。"
                },
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}},
            }
        }
        request(token, "/v1/subscriptionLocalizations", "POST", payload)
        actions.append("created_monthly_localization_ja")

    _, prices = request(token, f"/v1/subscriptions/{sub_id}/prices?filter[territory]={JPN}&include=subscriptionPricePoint&limit=200")
    included = prices.get("included", []) if isinstance(prices, dict) else []
    points_by_id = {x.get("id"): x for x in included if x.get("type") == "subscriptionPricePoints"}
    has_200 = False
    for price in data_list(prices):
        rel = price.get("relationships", {}).get("subscriptionPricePoint", {}).get("data") or {}
        point = points_by_id.get(rel.get("id"))
        if point and decimal_equal(point.get("attributes", {}).get("customerPrice"), MONTHLY_PRICE):
            has_200 = True
            break
    if not has_200:
        _, points = request(token, f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]={JPN}&fields[subscriptionPricePoints]=customerPrice,territory&include=territory&limit=8000")
        point = next((x for x in data_list(points) if decimal_equal(x.get("attributes", {}).get("customerPrice"), MONTHLY_PRICE)), None)
        if point is None:
            raise RuntimeError("No JPN 200 price point found for monthly subscription")
        payload = {
            "data": {
                "type": "subscriptionPrices",
                "attributes": {"preserveCurrentPrice": False},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                    "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point["id"]}},
                },
            }
        }
        request(token, "/v1/subscriptionPrices", "POST", payload)
        actions.append("set_monthly_price_jpn_200")

    _, detail = request(token, f"/v1/subscriptions/{sub_id}?include=subscriptionLocalizations,prices")
    return group_id, sub_id, detail


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")
    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)
        _, app_payload = request(token, f"/v1/apps/{APP_ID}")
        attrs = app_payload["data"].get("attributes", {})
        if attrs.get("bundleId") != BUNDLE_ID:
            raise RuntimeError(f"Bundle mismatch: {attrs.get('bundleId')}")
        actions = []
        group_id, sub_id, detail = ensure_subscription(token, actions)
        result = {
            "request_id": "APP2-009-kangoshi-subscription-bootstrap",
            "app": {"id": APP_ID, "bundleId": attrs.get("bundleId"), "name": attrs.get("name")},
            "actions": actions,
            "subscriptionGroup": {"id": group_id},
            "monthly": {
                "id": sub_id,
                "productId": detail["data"].get("attributes", {}).get("productId"),
                "state": detail["data"].get("attributes", {}).get("state"),
                "subscriptionPeriod": detail["data"].get("attributes", {}).get("subscriptionPeriod"),
                "configuredPriceJPN": "200"
            },
            "safeForBuild": True
        }
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
    RESULT_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULT_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
