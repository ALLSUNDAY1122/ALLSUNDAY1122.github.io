#!/usr/bin/env python3
"""Fill HM2 App Review contact from a verified review detail in the same ASC account.

Contact values are copied entirely inside App Store Connect and are never logged or persisted.
"""
from __future__ import annotations

import os
from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799751657"
TARGET_VERSION = "1.0"
DONOR_VERSION_ID = "812cd84c-3efb-407b-a04c-f9fb1b5554e6"
REQUIRED = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")


def one(payload, label):
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        raise RuntimeError(f"Missing {label}")
    return data


def many(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([] if data is None else [data])


def request_ok(token, path, method, payload):
    status, response = api_request(token, path, method=method, payload=payload)
    if not 200 <= status < 300:
        raise RuntimeError(f"ASC {method} {path} HTTP {status}")
    return response


def main():
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)

        _, versions_payload = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
        matches = [
            v for v in many(versions_payload)
            if (v.get("attributes") or {}).get("platform") == "IOS"
            and (v.get("attributes") or {}).get("versionString") == TARGET_VERSION
        ]
        if len(matches) != 1:
            raise RuntimeError(f"Expected one HM2 iOS {TARGET_VERSION} version; found {len(matches)}")
        version_id = str(matches[0]["id"])

        _, donor_payload = api_get(token, f"/v1/appStoreVersions/{DONOR_VERSION_ID}/appStoreReviewDetail")
        donor = one(donor_payload, "donor review detail")
        donor_attrs = donor.get("attributes") or {}
        if any(not donor_attrs.get(k) for k in REQUIRED):
            raise RuntimeError("Verified donor App Review contact is incomplete")
        contact = {k: donor_attrs[k] for k in REQUIRED}

        current = None
        try:
            _, current_payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
            d = current_payload.get("data") if isinstance(current_payload, dict) else None
            if isinstance(d, dict):
                current = d
        except Exception:
            current = None

        if current:
            rid = str(current["id"])
            attrs = current.get("attributes") or {}
            patch_attrs = {**contact, "demoAccountRequired": bool(attrs.get("demoAccountRequired", False))}
            if attrs.get("notes") is not None:
                patch_attrs["notes"] = attrs.get("notes")
            payload = {"data": {"type": "appStoreReviewDetails", "id": rid, "attributes": patch_attrs}}
            request_ok(token, f"/v1/appStoreReviewDetails/{rid}", "PATCH", payload)
        else:
            payload = {
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": {**contact, "demoAccountRequired": False},
                    "relationships": {
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
                    },
                }
            }
            request_ok(token, "/v1/appStoreReviewDetails", "POST", payload)

        _, after_payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        after = one(after_payload, "HM2 review detail after update")
        attrs = after.get("attributes") or {}
        if any(not attrs.get(k) for k in REQUIRED):
            raise RuntimeError("HM2 App Review contact remains incomplete after copy")
        print("PASS: HM2 App Review contact completed from verified same-account donor; values redacted")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
