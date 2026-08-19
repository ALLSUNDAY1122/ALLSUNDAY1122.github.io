#!/usr/bin/env python3
import json
import os
from pathlib import Path

from app_store_connect_api import load_private_key, make_token
from app2_004_yakuzaishi_iap_bootstrap import request

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
LIFETIME_ID = "6802918851"
MONTHLY_ID = "6802958538"
OUT = Path("automation/app2-004-yakuzaishi-metadata-probe.json")


def safe_get(token, path):
    try:
        status, payload = request(token, path)
        data = payload.get("data") if isinstance(payload, dict) else None
        included = payload.get("included", []) if isinstance(payload, dict) else []
        return {
            "ok": True,
            "httpStatus": status,
            "data": data,
            "included": included,
        }
    except Exception as exc:
        return {"ok": False, "error": str(exc)[-1500:]}


def compact_linkage(result):
    if not result.get("ok"):
        return {"ok": False, "error": result.get("error")}
    data = result.get("data")
    if data is None:
        return {"ok": True, "present": False, "data": None}
    if isinstance(data, list):
        return {
            "ok": True,
            "present": bool(data),
            "count": len(data),
            "data": [{"type": x.get("type"), "id": x.get("id")} for x in data if isinstance(x, dict)],
        }
    if isinstance(data, dict):
        return {"ok": True, "present": True, "data": {"type": data.get("type"), "id": data.get("id")}}
    return {"ok": True, "present": False, "data": data}


def included_by_type(result):
    out = {}
    if not result.get("ok"):
        return out
    for item in result.get("included", []):
        if not isinstance(item, dict):
            continue
        typ = item.get("type") or "unknown"
        attrs = item.get("attributes", {}) or {}
        out.setdefault(typ, []).append({
            "id": item.get("id"),
            "attributes": {
                k: attrs.get(k)
                for k in (
                    "locale", "name", "description", "state", "version",
                    "planType", "availableInNewTerritories", "offerMode",
                    "duration", "numberOfPeriods", "startDate", "endDate",
                    "targetSubscriptionPlanType", "fileName", "fileSize",
                    "assetType", "assetDeliveryState"
                )
                if k in attrs
            },
        })
    return out


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")
    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)
        _, app_payload = request(token, f"/v1/apps/{APP_ID}")
        app = app_payload["data"]
        actual_bundle = app.get("attributes", {}).get("bundleId")
        if actual_bundle != BUNDLE_ID:
            raise RuntimeError(f"Bundle mismatch: {actual_bundle}")

        lifetime_detail = safe_get(
            token,
            f"/v2/inAppPurchases/{LIFETIME_ID}?include=inAppPurchaseLocalizations,iapPriceSchedule,inAppPurchaseAvailability,appStoreReviewScreenshot,versions",
        )
        lifetime_review_link = safe_get(token, f"/v2/inAppPurchases/{LIFETIME_ID}/relationships/appStoreReviewScreenshot")
        lifetime_availability_link = safe_get(token, f"/v2/inAppPurchases/{LIFETIME_ID}/relationships/inAppPurchaseAvailability")

        monthly_detail = safe_get(
            token,
            f"/v1/subscriptions/{MONTHLY_ID}?include=subscriptionLocalizations,appStoreReviewScreenshot,planAvailabilities,introductoryOffers,prices,versions",
        )
        monthly_review_link = safe_get(token, f"/v1/subscriptions/{MONTHLY_ID}/relationships/appStoreReviewScreenshot")
        monthly_plan_link = safe_get(token, f"/v1/subscriptions/{MONTHLY_ID}/relationships/planAvailabilities")

        result = {
            "task_id": "APP2-004",
            "app": {"id": APP_ID, "bundleId": actual_bundle, "name": app.get("attributes", {}).get("name")},
            "lifetime": {
                "detailOk": lifetime_detail.get("ok"),
                "state": ((lifetime_detail.get("data") or {}).get("attributes", {}) or {}).get("state") if lifetime_detail.get("ok") else None,
                "reviewScreenshot": compact_linkage(lifetime_review_link),
                "availability": compact_linkage(lifetime_availability_link),
                "included": included_by_type(lifetime_detail),
                "detailError": lifetime_detail.get("error"),
            },
            "monthly": {
                "detailOk": monthly_detail.get("ok"),
                "state": ((monthly_detail.get("data") or {}).get("attributes", {}) or {}).get("state") if monthly_detail.get("ok") else None,
                "reviewScreenshot": compact_linkage(monthly_review_link),
                "planAvailabilities": compact_linkage(monthly_plan_link),
                "included": included_by_type(monthly_detail),
                "detailError": monthly_detail.get("error"),
            },
        }
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
