#!/usr/bin/env python3
"""TAKU prerequisite runner with robust rights and free-pricing handling."""
from __future__ import annotations

from decimal import Decimal

import app2_011_prepare_submission_v2  # patches content-rights handling
import app2_011_prepare_submission as base


def is_zero(value):
    try:
        return Decimal(str(value)) == 0
    except Exception:
        return False


def manual_prices_or_empty(token, schedule_id):
    status, payload = base.req(
        token,
        f"/v1/appPriceSchedules/{schedule_id}/manualPrices?include=appPricePoint,territory&limit=200",
        allow404=True,
    )
    if status == 404:
        return []
    included = payload.get("included") or []
    point_attrs = {str(x.get("id")): base.attrs(x) for x in included if x.get("type") == "appPricePoints"}
    result = []
    for price in base.rows(payload):
        pp_id = base.rel_id(price, "appPricePoint")
        result.append({
            "id": str(price.get("id")),
            "territory": base.rel_id(price, "territory"),
            "price_point_id": pp_id,
            "customer_price": (point_attrs.get(pp_id) or {}).get("customerPrice"),
        })
    return result


def ensure_free_pricing(token, actions):
    schedule = base.app_price_schedule(token)
    if schedule:
        sid = str(schedule["id"])
        manual = manual_prices_or_empty(token, sid)
        if any(is_zero(x.get("customer_price")) for x in manual):
            return {"schedule_id": sid, "customer_price": "0", "existing": True}
        # ASC can return a synthetic empty schedule whose id equals the app id
        # before pricing has actually been configured. Fall through and create
        # the real free-price schedule when there are no manual prices.
        if manual:
            raise RuntimeError("Existing app price schedule has non-zero manual pricing")

    _, points_payload = base.req(
        token,
        f"/v1/apps/{base.APP_ID}/appPricePoints?filter[territory]={base.BASE_TERRITORY}&limit=200",
    )
    free_points = [x for x in base.rows(points_payload) if is_zero(base.attrs(x).get("customerPrice"))]
    if not free_points:
        raise RuntimeError(f"No zero-price app price point found for {base.BASE_TERRITORY}")
    price_point_id = str(free_points[0]["id"])
    placeholder = "${new-price}"
    payload = {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": base.APP_ID}},
                "baseTerritory": {"data": {"type": "territories", "id": base.BASE_TERRITORY}},
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
    base.req(token, "/v1/appPriceSchedules", "POST", payload)
    actions.append("free_app_pricing_set")

    after = base.app_price_schedule(token)
    if not after:
        raise RuntimeError("App price schedule missing after free-price write")
    sid = str(after["id"])
    manual = manual_prices_or_empty(token, sid)
    # Submission itself is the authoritative validation. Some ASC accounts can
    # omit included appPricePoint details immediately after creation, so accept
    # a successful POST plus a nonempty manual price row when customerPrice is
    # temporarily absent from the included resource.
    if not manual:
        raise RuntimeError("No manual price row after free-price write")
    visible_prices = [x.get("customer_price") for x in manual if x.get("customer_price") is not None]
    if visible_prices and not any(is_zero(x) for x in visible_prices):
        raise RuntimeError(f"Free pricing read-back was non-zero: {visible_prices}")
    return {
        "schedule_id": sid,
        "customer_price": "0",
        "price_point_id": price_point_id,
        "existing": False,
        "manual_price_count": len(manual),
    }


base.ensure_free_pricing = ensure_free_pricing

if __name__ == "__main__":
    base.main()
