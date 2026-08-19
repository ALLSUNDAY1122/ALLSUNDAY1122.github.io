#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.request
from datetime import date
from decimal import Decimal
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
MONTHLY_ID = "jp.allsunday1122.yakuzaishi.monthly"
LIFETIME_ID = "jp.allsunday1122.yakuzaishi.lifetime"
JPN = "JPN"
MONTHLY_PRICE = Decimal("200")
LIFETIME_PRICE = Decimal("980")
RESULT_PATH = Path("automation/app2-004-yakuzaishi-iap-result.json")


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


def ensure_iap(token, actions):
    _, listing = request(token, f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=200")
    item = by_product(data_list(listing), LIFETIME_ID)
    if item is None:
        payload = {
            "data": {
                "type": "inAppPurchases",
                "attributes": {
                    "name": "薬剤師国試 プレミアム買い切り",
                    "productId": LIFETIME_ID,
                    "inAppPurchaseType": "NON_CONSUMABLE",
                    "reviewNote": "薬剤師国家試験のプレミアム問題・分野別・模試・弱点学習を永久解放します。",
                    "familySharable": False,
                },
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        }
        _, created = request(token, "/v2/inAppPurchases", "POST", payload)
        item = created["data"]
        actions.append("created_lifetime_iap")
    iap_id = item["id"]

    _, detail = request(token, f"/v2/inAppPurchases/{iap_id}?include=inAppPurchaseLocalizations")
    included = detail.get("included", []) if isinstance(detail, dict) else []
    if not any(x.get("type") in {"inAppPurchaseLocalizations", "inAppPurchaseLocalizationsV2"} and x.get("attributes", {}).get("locale") == "ja" for x in included):
        payload = {
            "data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {
                    "name": "薬剤師国試 プレミアム買い切り",
                    "locale": "ja",
                    "description": "第111・110・109回の採点対象問題、分野別・模試・弱点学習を永久解放します。",
                },
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchasesV2", "id": iap_id}}},
            }
        }
        request(token, "/v2/inAppPurchaseLocalizations", "POST", payload)
        actions.append("created_lifetime_localization_ja")

    try:
        request(token, f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule")
        has_schedule = True
    except RuntimeError as exc:
        if "HTTP 404" not in str(exc):
            raise
        has_schedule = False

    if not has_schedule:
        _, points = request(
            token,
            f"/v2/inAppPurchases/{iap_id}/pricePoints?filter[territory]={JPN}&fields[inAppPurchasePricePoints]=customerPrice,territory&include=territory&limit=8000",
        )
        point = next((x for x in data_list(points) if decimal_equal(x.get("attributes", {}).get("customerPrice"), LIFETIME_PRICE)), None)
        if point is None:
            raise RuntimeError("No JPN 980 price point found for lifetime IAP")
        inline_id = "app2-004-lifetime-jpn"
        payload = {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
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
                        "inAppPurchaseV2": {"data": {"type": "inAppPurchasesV2", "id": iap_id}},
                        "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point["id"]}},
                    },
                }
            ],
        }
        request(token, "/v1/inAppPurchasePriceSchedules", "POST", payload)
        actions.append("set_lifetime_price_jpn_980")
    return iap_id


def ensure_introductory_offer(token, sub_id, actions):
    _, offers_payload = request(
        token,
        f"/v1/subscriptions/{sub_id}/introductoryOffers?filter[territory]={JPN}&include=territory&limit=200",
    )
    offers = data_list(offers_payload)
    for offer in offers:
        attrs = offer.get("attributes", {})
        territory = offer.get("relationships", {}).get("territory", {}).get("data") or {}
        if (
            attrs.get("offerMode") == "FREE_TRIAL"
            and attrs.get("duration") == "ONE_WEEK"
            and int(attrs.get("numberOfPeriods") or 0) == 1
            and territory.get("id") == JPN
        ):
            return offer["id"]

    payload = {
        "data": {
            "type": "subscriptionIntroductoryOffers",
            "attributes": {
                "startDate": date.today().isoformat(),
                "duration": "ONE_WEEK",
                "offerMode": "FREE_TRIAL",
                "numberOfPeriods": 1,
            },
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                "territory": {"data": {"type": "territories", "id": JPN}},
            },
        }
    }
    _, created = request(token, "/v1/subscriptionIntroductoryOffers", "POST", payload)
    actions.append("created_monthly_intro_free_trial_jpn_one_week")
    return created["data"]["id"]


def ensure_subscription(token, actions):
    _, groups_payload = request(token, f"/v1/apps/{APP_ID}/subscriptionGroups?limit=200")
    groups = data_list(groups_payload)
    group = next((x for x in groups if x.get("attributes", {}).get("referenceName") == "薬剤師国試プレミアム"), None)
    if group is None:
        payload = {
            "data": {
                "type": "subscriptionGroups",
                "attributes": {"referenceName": "薬剤師国試プレミアム"},
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
                "attributes": {"name": "薬剤師国試プレミアム", "locale": "ja"},
                "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group_id}}},
            }
        }
        request(token, "/v1/subscriptionGroupLocalizations", "POST", payload)
        actions.append("created_subscription_group_localization_ja")

    _, subs_payload = request(token, f"/v1/subscriptionGroups/{group_id}/subscriptions?limit=200")
    sub = by_product(data_list(subs_payload), MONTHLY_ID)
    if sub is None:
        payload = {
            "data": {
                "type": "subscriptions",
                "attributes": {
                    "name": "薬剤師国試 プレミアム月額",
                    "productId": MONTHLY_ID,
                    "subscriptionPeriod": "ONE_MONTH",
                    "familySharable": False,
                    "groupLevel": 1,
                    "reviewNote": "薬剤師国家試験のプレミアム問題・分野別・模試・弱点学習を月額で解放します。",
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
                    "name": "薬剤師国試 プレミアム月額",
                    "locale": "ja",
                    "description": "第111・110・109回の採点対象問題、分野別・模試・弱点学習を月額で利用できます。",
                },
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}},
            }
        }
        request(token, "/v1/subscriptionLocalizations", "POST", payload)
        actions.append("created_monthly_localization_ja")

    _, prices = request(token, f"/v1/subscriptions/{sub_id}/prices?filter[territory]={JPN}&include=subscriptionPricePoint&limit=200")
    included = prices.get("included", []) if isinstance(prices, dict) else []
    current_points = {x.get("id"): x for x in included if x.get("type") == "subscriptionPricePoints"}
    has_200 = False
    for price in data_list(prices):
        rel = price.get("relationships", {}).get("subscriptionPricePoint", {}).get("data") or {}
        point = current_points.get(rel.get("id"))
        if point and decimal_equal(point.get("attributes", {}).get("customerPrice"), MONTHLY_PRICE):
            has_200 = True
            break
    if not has_200:
        _, points = request(
            token,
            f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]={JPN}&fields[subscriptionPricePoints]=customerPrice,territory&include=territory&limit=8000",
        )
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

    intro_id = ensure_introductory_offer(token, sub_id, actions)
    return group_id, sub_id, intro_id


def collect_state(token, iap_id, group_id, sub_id, intro_id, actions):
    _, app = request(token, f"/v1/apps/{APP_ID}")
    _, iap = request(token, f"/v2/inAppPurchases/{iap_id}?include=inAppPurchaseLocalizations,iapPriceSchedule")
    _, sub = request(token, f"/v1/subscriptions/{sub_id}?include=subscriptionLocalizations,prices,introductoryOffers")
    _, intro = request(token, f"/v1/subscriptionIntroductoryOffers/{intro_id}?include=territory,subscription")
    _, groups = request(token, f"/v1/apps/{APP_ID}/subscriptionGroups?limit=200")
    intro_attrs = intro["data"].get("attributes", {})
    intro_territory = intro["data"].get("relationships", {}).get("territory", {}).get("data") or {}
    return {
        "request_id": "APP2-004-yakuzaishi-iap-bootstrap",
        "app": {
            "id": APP_ID,
            "bundleId": app["data"].get("attributes", {}).get("bundleId"),
            "name": app["data"].get("attributes", {}).get("name"),
        },
        "actions": actions,
        "lifetime": {
            "id": iap_id,
            "productId": iap["data"].get("attributes", {}).get("productId"),
            "state": iap["data"].get("attributes", {}).get("state"),
            "configuredPriceJPN": "980",
        },
        "monthly": {
            "id": sub_id,
            "productId": sub["data"].get("attributes", {}).get("productId"),
            "state": sub["data"].get("attributes", {}).get("state"),
            "configuredPriceJPN": "200",
            "introductoryOfferConfigured": True,
            "introductoryOffer": {
                "id": intro_id,
                "territory": intro_territory.get("id"),
                "offerMode": intro_attrs.get("offerMode"),
                "duration": intro_attrs.get("duration"),
                "numberOfPeriods": intro_attrs.get("numberOfPeriods"),
                "startDate": intro_attrs.get("startDate"),
                "endDate": intro_attrs.get("endDate"),
            },
        },
        "subscriptionGroup": {"id": group_id, "count": len(data_list(groups))},
        "safeForBuild": True,
        "note": "IAP/subscription and JPN one-week free introductory offer ensured idempotently from pharmacist app metadata.",
    }


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")
    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)
        _, app_payload = request(token, f"/v1/apps/{APP_ID}")
        actual_bundle = app_payload["data"].get("attributes", {}).get("bundleId")
        if actual_bundle != BUNDLE_ID:
            raise RuntimeError(f"Bundle mismatch: {actual_bundle}")
        actions = []
        iap_id = ensure_iap(token, actions)
        group_id, sub_id, intro_id = ensure_subscription(token, actions)
        result = collect_state(token, iap_id, group_id, sub_id, intro_id, actions)
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
    RESULT_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULT_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
