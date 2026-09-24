#!/usr/bin/env python3
"""Prepare API-exposed App Store submission prerequisites for TAKU CALC 1.5.0."""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = "6794350490"
BUNDLE_ID = "com.koheimorita.takucalc"
VERSION_ID = "65ef287d-3ea2-42d6-a0df-32ff6d62c08c"
COPYRIGHT = "2026 Kohei Morita"
BASE_TERRITORY = "JPN"
OUT = Path(os.environ.get("TAKU_PREP_OUTPUT", "app2-011-prepare-submission-result.json"))


def req(token, path, method="GET", payload=None, allow404=False):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    request = urllib.request.Request(
        BASE_URL + path,
        data=body,
        method=method,
        headers={
            "Authorization": "Bearer " + token,
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        if allow404 and exc.code == 404:
            return 404, {}
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"ASC {method} {path} HTTP {exc.code}: {raw[:8000]}") from exc


def rows(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([] if data is None else [data])


def attrs(resource):
    return (resource or {}).get("attributes") or {}


def rel_id(resource, key):
    try:
        return str(resource["relationships"][key]["data"]["id"])
    except Exception:
        return None


def is_zero(value):
    try:
        return Decimal(str(value)) == 0
    except (InvalidOperation, TypeError, ValueError):
        return False


def ensure_content_rights(token, actions):
    path = f"/v1/apps/{APP_ID}?fields[apps]=bundleId,contentRightsDeclaration"
    _, payload = req(token, path)
    app = payload.get("data") or {}
    a = attrs(app)
    if a.get("bundleId") != BUNDLE_ID:
        raise RuntimeError("App/bundle mismatch")
    if a.get("contentRightsDeclaration") != "DOES_NOT_USE_THIRD_PARTY_CONTENT":
        req(token, f"/v1/apps/{APP_ID}", "PATCH", {
            "data": {
                "type": "apps",
                "id": APP_ID,
                "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"},
            }
        })
        actions.append("content_rights_declared")
    _, after = req(token, path)
    value = attrs(after.get("data") or {}).get("contentRightsDeclaration")
    if value != "DOES_NOT_USE_THIRD_PARTY_CONTENT":
        raise RuntimeError(f"Unexpected contentRightsDeclaration after write: {value}")
    return value


def ensure_copyright(token, actions):
    _, payload = req(token, f"/v1/appStoreVersions/{VERSION_ID}")
    current = attrs(payload.get("data") or {}).get("copyright")
    if not current:
        req(token, f"/v1/appStoreVersions/{VERSION_ID}", "PATCH", {
            "data": {
                "type": "appStoreVersions",
                "id": VERSION_ID,
                "attributes": {"copyright": COPYRIGHT},
            }
        })
        actions.append("copyright_set")
    _, after = req(token, f"/v1/appStoreVersions/{VERSION_ID}")
    value = attrs(after.get("data") or {}).get("copyright")
    if not value:
        raise RuntimeError("Copyright read-back is empty")
    return value


def app_price_schedule(token):
    status, payload = req(token, f"/v1/apps/{APP_ID}/appPriceSchedule?include=baseTerritory", allow404=True)
    if status == 404 or not (payload.get("data") if isinstance(payload, dict) else None):
        return None
    return payload.get("data")


def read_manual_prices(token, schedule_id):
    _, payload = req(token, f"/v1/appPriceSchedules/{schedule_id}/manualPrices?include=appPricePoint,territory&limit=200")
    included = payload.get("included") or []
    point_attrs = {str(x.get("id")): attrs(x) for x in included if x.get("type") == "appPricePoints"}
    result = []
    for price in rows(payload):
        pp_id = rel_id(price, "appPricePoint")
        result.append({
            "id": str(price.get("id")),
            "territory": rel_id(price, "territory"),
            "price_point_id": pp_id,
            "customer_price": (point_attrs.get(pp_id) or {}).get("customerPrice"),
        })
    return result


def ensure_free_pricing(token, actions):
    schedule = app_price_schedule(token)
    if schedule:
        sid = str(schedule["id"])
        manual = read_manual_prices(token, sid)
        if any(is_zero(x.get("customer_price")) for x in manual):
            return {"schedule_id": sid, "customer_price": "0", "existing": True}
        raise RuntimeError("Existing app price schedule is present but no zero-price manual price was found")

    _, points_payload = req(token, f"/v1/apps/{APP_ID}/appPricePoints?filter[territory]={BASE_TERRITORY}&limit=200")
    free_points = [x for x in rows(points_payload) if is_zero(attrs(x).get("customerPrice"))]
    if not free_points:
        raise RuntimeError(f"No zero-price app price point found for {BASE_TERRITORY}")
    free_point = free_points[0]
    price_point_id = str(free_point["id"])
    placeholder = "${new-price}"
    payload = {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}},
                "baseTerritory": {"data": {"type": "territories", "id": BASE_TERRITORY}},
                "manualPrices": {"data": [{"type": "appPrices", "id": placeholder}]},
            },
        },
        "included": [{
            "type": "appPrices",
            "id": placeholder,
            "attributes": {},
            "relationships": {
                "appPricePoint": {"data": {"type": "appPricePoints", "id": price_point_id}},
            },
        }],
    }
    req(token, "/v1/appPriceSchedules", "POST", payload)
    actions.append("free_app_pricing_set")
    after = app_price_schedule(token)
    if not after:
        raise RuntimeError("App price schedule missing after write")
    sid = str(after["id"])
    manual = read_manual_prices(token, sid)
    if not any(is_zero(x.get("customer_price")) for x in manual):
        raise RuntimeError("Free pricing read-back did not contain customerPrice=0")
    return {"schedule_id": sid, "customer_price": "0", "price_point_id": price_point_id, "existing": False}


def main():
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect API credentials")

    result = {
        "task": "APP2-011",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "version": "1.5.0",
        "actions": [],
    }
    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        result["content_rights"] = ensure_content_rights(token, result["actions"])
        result["copyright"] = ensure_copyright(token, result["actions"])
        result["pricing"] = ensure_free_pricing(token, result["actions"])
        result["success"] = True
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PASS: TAKU API-exposed submission prerequisites are ready")
    except Exception as exc:
        result["success"] = False
        result["error"] = str(exc)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
