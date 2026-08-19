#!/usr/bin/env python3
"""APP2-004 compatibility runner for current App Store Connect subscription/IAP metadata APIs."""

import copy
import json

import app2_004_yakuzaishi_iap_bootstrap as bootstrap

_original_request = bootstrap.request


def _data_list(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else [data]


def _ensure_draft_version(token, kind, parent_id):
    if kind == "iap":
        list_path = f"/v2/inAppPurchases/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=200"
        create_path = "/v1/inAppPurchaseVersions"
        version_type = "inAppPurchaseVersions"
        relationship = "inAppPurchase"
        parent_type = "inAppPurchases"
    elif kind == "subscription":
        list_path = f"/v1/subscriptions/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=200"
        create_path = "/v1/subscriptionVersions"
        version_type = "subscriptionVersions"
        relationship = "subscription"
        parent_type = "subscriptions"
    elif kind == "group":
        list_path = f"/v1/subscriptionGroups/{parent_id}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=200"
        create_path = "/v1/subscriptionGroupVersions"
        version_type = "subscriptionGroupVersions"
        relationship = "subscriptionGroup"
        parent_type = "subscriptionGroups"
    else:
        raise ValueError(f"unsupported version kind: {kind}")

    _, listing = _original_request(token, list_path)
    versions = _data_list(listing)
    if versions:
        return versions[-1]["id"], version_type
    payload = {
        "data": {
            "type": version_type,
            "relationships": {relationship: {"data": {"type": parent_type, "id": parent_id}}},
        }
    }
    _, created = _original_request(token, create_path, "POST", payload)
    return created["data"]["id"], version_type


def _normalize_iap_price_schedule(payload):
    payload = copy.deepcopy(payload)
    included = payload.get("included") or []
    replacements = {}
    for item in included:
        local_id = item.get("id")
        if isinstance(local_id, str) and not (local_id.startswith("${") and local_id.endswith("}")):
            normalized = "${" + local_id + "}"
            replacements[local_id] = normalized
            item["id"] = normalized
        relationship = (item.get("relationships") or {}).get("inAppPurchaseV2") or {}
        related = relationship.get("data") or {}
        if related.get("type") == "inAppPurchasesV2":
            related["type"] = "inAppPurchases"
    manual = payload.get("data", {}).get("relationships", {}).get("manualPrices", {}).get("data", [])
    for item in manual:
        if item.get("id") in replacements:
            item["id"] = replacements[item["id"]]
    return payload


def _create_starting_subscription_price(token, original_payload):
    rels = original_payload.get("data", {}).get("relationships", {})
    sub = rels.get("subscription", {}).get("data") or {}
    sub_id = sub.get("id")
    if not sub_id:
        raise RuntimeError("Missing subscription linkage")

    _, availability_payload = _original_request(
        token,
        f"/v1/subscriptions/{sub_id}/planAvailabilities?include=availableTerritories&limit=200",
    )
    availabilities = _data_list(availability_payload)
    availability_summary = [
        {
            "id": item.get("id"),
            "planType": item.get("attributes", {}).get("planType"),
            "availableInNewTerritories": item.get("attributes", {}).get("availableInNewTerritories"),
        }
        for item in availabilities
    ]
    print("APP2-004 plan availabilities:", json.dumps(availability_summary, ensure_ascii=False))
    if not any(x.get("planType") == "UPFRONT" for x in availability_summary):
        raise RuntimeError("UPFRONT subscription plan availability is missing")

    _, points_payload = _original_request(
        token,
        f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]=JPN&filter[planType]=UPFRONT&fields[subscriptionPricePoints]=customerPrice,territory&include=territory&limit=8000",
    )
    point = next(
        (
            x
            for x in _data_list(points_payload)
            if bootstrap.decimal_equal(x.get("attributes", {}).get("customerPrice"), bootstrap.MONTHLY_PRICE)
        ),
        None,
    )
    if point is None:
        raise RuntimeError("No JPN 200 UPFRONT price point found for monthly subscription")
    point_id = point["id"]

    _, point_detail = _original_request(token, f"/v1/subscriptionPricePoints/{point_id}?include=territory")
    d = point_detail.get("data", {}) if isinstance(point_detail, dict) else {}
    territory_id = (d.get("relationships", {}).get("territory", {}).get("data") or {}).get("id") or "JPN"
    print("APP2-004 starting subscription price:", json.dumps({
        "pointId": d.get("id"),
        "attributes": d.get("attributes"),
        "territory": territory_id,
        "planType": "UPFRONT",
    }, ensure_ascii=False))

    local_id = "${app2-004-starting-price-jpn}"
    inline = {
        "type": "subscriptionPrices",
        "id": local_id,
        "attributes": {
            "startDate": None,
            "preserveCurrentPrice": False,
            "planType": "UPFRONT",
        },
        "relationships": {
            "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point_id}},
            "territory": {"data": {"type": "territories", "id": territory_id}},
        },
    }
    patch_payload = {
        "data": {
            "type": "subscriptions",
            "id": sub_id,
            "relationships": {"prices": {"data": [{"type": "subscriptionPrices", "id": local_id}]}},
        },
        "included": [inline],
    }
    return _original_request(token, f"/v1/subscriptions/{sub_id}", "PATCH", patch_payload)


def request(token, path, method="GET", payload=None):
    if method == "POST" and payload and isinstance(payload, dict):
        data = payload.get("data") or {}
        relationships = data.get("relationships") or {}

        if path == "/v2/inAppPurchaseLocalizations" and "inAppPurchaseV2" in relationships:
            parent_id = relationships["inAppPurchaseV2"]["data"]["id"]
            version_id, version_type = _ensure_draft_version(token, "iap", parent_id)
            payload = copy.deepcopy(payload)
            payload["data"]["relationships"] = {"version": {"data": {"type": version_type, "id": version_id}}}

        elif path == "/v1/subscriptionLocalizations" and "subscription" in relationships:
            parent_id = relationships["subscription"]["data"]["id"]
            version_id, version_type = _ensure_draft_version(token, "subscription", parent_id)
            payload = copy.deepcopy(payload)
            payload["data"]["relationships"] = {"version": {"data": {"type": version_type, "id": version_id}}}
            path = "/v2/subscriptionLocalizations"

        elif path == "/v1/subscriptionGroupLocalizations" and "subscriptionGroup" in relationships:
            parent_id = relationships["subscriptionGroup"]["data"]["id"]
            version_id, version_type = _ensure_draft_version(token, "group", parent_id)
            payload = copy.deepcopy(payload)
            payload["data"]["relationships"] = {"version": {"data": {"type": version_type, "id": version_id}}}
            path = "/v2/subscriptionGroupLocalizations"

        elif path == "/v1/inAppPurchasePriceSchedules":
            payload = _normalize_iap_price_schedule(payload)

        elif path == "/v1/subscriptionPrices":
            return _create_starting_subscription_price(token, payload)

        elif path == "/v1/subscriptionIntroductoryOffers":
            payload = copy.deepcopy(payload)
            payload.setdefault("data", {}).setdefault("attributes", {})["targetSubscriptionPlanType"] = "UPFRONT"

    return _original_request(token, path, method, payload)


bootstrap.request = request
bootstrap.main()
