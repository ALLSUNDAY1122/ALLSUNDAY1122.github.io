#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = "6799581662"
BUNDLE_ID = "jp.allsunday1122.healthmanager1"
SUB_ID = "6804373671"
PRODUCT_ID = "jp.allsunday1122.healthmanager1.monthly"
JPN = "JPN"
OUT = Path("automation/app2-005-hm1-intro-offer-result.json")


def request(token, path, method="GET", payload=None):
    if not (path.startswith("/v1/") or path.startswith("/v2/")):
        raise ValueError(f"Unsupported ASC path: {path}")
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    req = urllib.request.Request(
        BASE_URL + path,
        data=body,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw.decode("utf-8")) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"ASC {method} {path} HTTP {exc.code}: {raw[:3000]}") from None


def rows(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else [data]


def preflight(token):
    _, app = request(token, f"/v1/apps/{APP_ID}")
    bundle = ((app.get("data") or {}).get("attributes") or {}).get("bundleId")
    if bundle != BUNDLE_ID:
        raise RuntimeError(f"bundle mismatch: {bundle!r}")
    _, sub = request(token, f"/v1/subscriptions/{SUB_ID}")
    attrs = (sub.get("data") or {}).get("attributes") or {}
    if attrs.get("productId") != PRODUCT_ID:
        raise RuntimeError(f"product mismatch: {attrs.get('productId')!r}")
    if attrs.get("subscriptionPeriod") != "ONE_MONTH":
        raise RuntimeError(f"period mismatch: {attrs.get('subscriptionPeriod')!r}")


def find_existing(token):
    _, payload = request(
        token,
        f"/v1/subscriptions/{SUB_ID}/introductoryOffers?filter[territory]={JPN}&include=territory&limit=200",
    )
    for offer in rows(payload):
        attrs = offer.get("attributes") or {}
        territory = (((offer.get("relationships") or {}).get("territory") or {}).get("data") or {}).get("id")
        if (
            territory == JPN
            and attrs.get("offerMode") == "FREE_TRIAL"
            and attrs.get("duration") == "ONE_WEEK"
            and int(attrs.get("numberOfPeriods") or 0) == 1
        ):
            return offer
    return None


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("missing ASC credentials")
    key_path, cleanup = load_private_key()
    result = {
        "task_id": "APP2-005",
        "app_id": APP_ID,
        "subscription_id": SUB_ID,
        "product_id": PRODUCT_ID,
        "territory": JPN,
        "offer_mode": "FREE_TRIAL",
        "duration": "ONE_WEEK",
        "number_of_periods": 1,
        "ok": False,
    }
    try:
        token = make_token(issuer, key_id, key_path)
        preflight(token)
        existing = find_existing(token)
        if existing is None:
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
                        "subscription": {"data": {"type": "subscriptions", "id": SUB_ID}},
                        "territory": {"data": {"type": "territories", "id": JPN}},
                    },
                }
            }
            status, created = request(token, "/v1/subscriptionIntroductoryOffers", "POST", payload)
            result["changed"] = True
            result["http_status"] = status
            result["offer_id"] = (created.get("data") or {}).get("id")
        else:
            result["changed"] = False
            result["offer_id"] = existing.get("id")
        readback = find_existing(token)
        if readback is None:
            raise RuntimeError("introductory offer read-back failed")
        attrs = readback.get("attributes") or {}
        result["readback"] = {
            "id": readback.get("id"),
            "offerMode": attrs.get("offerMode"),
            "duration": attrs.get("duration"),
            "numberOfPeriods": attrs.get("numberOfPeriods"),
            "startDate": attrs.get("startDate"),
            "endDate": attrs.get("endDate"),
        }
        result["ok"] = True
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
