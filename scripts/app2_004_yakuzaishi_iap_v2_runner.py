#!/usr/bin/env python3
"""APP2-004 compatibility runner for App Store Connect API 4.4.1+ metadata versions."""

import copy
import json
from datetime import date

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
            "relationships": {
                relationship: {"data": {"type": parent_type, "id": parent_id}}
            },
        }
    }
    _, created = _original_request(token, create_path, "POST", payload)
    return created["data"]["id"], version_type


def _normalize_inline_price_payload(payload):
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
    manual = (
        payload.get("data", {})
        .get("relationships", {})
        .get("manualPrices", {})
        .get("data", [])
    )
    for item in manual:
        if item.get("id") in replacements:
            item["id"] = replacements[item["id"]]
    return payload


def request(token, path, method="GET", payload=None):
    if method == "POST" and payload and isinstance(payload, dict):
        data = payload.get("data") or {}
        relationships = data.get("relationships") or {}

        if path == "/v2/inAppPurchaseLocalizations" and "inAppPurchaseV2" in relationships:
            parent_id = relationships["inAppPurchaseV2"]["data"]["id"]
            version_id, version_type = _ensure_draft_version(token, "iap", parent_id)
            payload = copy.deepcopy(payload)
            payload["data"]["relationships"] = {
                "version": {"data": {"type": version_type, "id": version_id}}
            }

        elif path == "/v1/subscriptionLocalizations" and "subscription" in relationships:
            parent_id = relationships["subscription"]["data"]["id"]
            version_id, version_type = _ensure_draft_version(token, "subscription", parent_id)
            payload = copy.deepcopy(payload)
            payload["data"]["relationships"] = {
                "version": {"data": {"type": version_type, "id": version_id}}
            }
            path = "/v2/subscriptionLocalizations"

        elif path == "/v1/subscriptionGroupLocalizations" and "subscriptionGroup" in relationships:
            parent_id = relationships["subscriptionGroup"]["data"]["id"]
            version_id, version_type = _ensure_draft_version(token, "group", parent_id)
            payload = copy.deepcopy(payload)
            payload["data"]["relationships"] = {
                "version": {"data": {"type": version_type, "id": version_id}}
            }
            path = "/v2/subscriptionGroupLocalizations"

        elif path == "/v1/inAppPurchasePriceSchedules":
            payload = _normalize_inline_price_payload(payload)

        elif path == "/v1/subscriptionPrices":
            payload = copy.deepcopy(payload)
            payload.setdefault("data", {}).setdefault("attributes", {}).setdefault(
                "startDate", date.today().isoformat()
            )
            point = (
                payload.get("data", {})
                .get("relationships", {})
                .get("subscriptionPricePoint", {})
                .get("data", {})
            )
            point_id = point.get("id")
            if point_id:
                _, point_detail = _original_request(token, f"/v1/subscriptionPricePoints/{point_id}?include=territory")
                d = point_detail.get("data", {}) if isinstance(point_detail, dict) else {}
                print("APP2-004 selected subscription price point:", json.dumps({
                    "id": d.get("id"),
                    "type": d.get("type"),
                    "attributes": d.get("attributes"),
                    "territory": (d.get("relationships", {}).get("territory", {}).get("data") or {}).get("id"),
                    "postAttributes": payload.get("data", {}).get("attributes", {}),
                }, ensure_ascii=False))

    return _original_request(token, path, method, payload)


bootstrap.request = request
bootstrap.main()
