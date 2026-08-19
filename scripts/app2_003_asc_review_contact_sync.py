#!/usr/bin/env python3
"""APP2-003 scoped review-contact sync inside App Store Connect.

Copies already-present Beta App Review contact values to App Store Review Details.
No contact values are printed or persisted; evidence stores presence booleans only.
This script never submits an app for review.
"""
import json
import os
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794137637"
BUNDLE_ID = "io.github.allsunday1122.yorunoshoka"
VERSION_ID = "812cd84c-3efb-407b-a04c-f9fb1b5554e6"
REVIEW_DETAIL_ID = "630be79a-3c94-4c4b-8882-6644d165152e"
CONTACT_KEYS = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")


def presence(attrs):
    return {f"has_{k}": bool(str(attrs.get(k) or "").strip()) for k in CONTACT_KEYS}


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise RuntimeError("Missing ASC issuer/key id")
    key_path, cleanup = load_private_key()
    evidence = {"app_id": APP_ID, "version_id": VERSION_ID, "review_detail_id": REVIEW_DETAIL_ID, "steps": []}
    try:
        token = make_token(issuer, key_id, key_path)

        _, app = api_get(token, f"/v1/apps/{APP_ID}")
        if app["data"]["attributes"].get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Bundle ID preflight mismatch")

        _, linked = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail")
        if linked.get("data", {}).get("id") != REVIEW_DETAIL_ID:
            raise RuntimeError("Review detail preflight mismatch")

        _, beta = api_get(token, f"/v1/betaAppReviewDetails?filter[app]={APP_ID}&limit=20")
        beta_rows = beta.get("data") or []
        if len(beta_rows) != 1:
            raise RuntimeError("Expected exactly one Beta App Review detail")
        source = beta_rows[0].get("attributes") or {}
        source_presence = presence(source)
        if not all(source_presence.values()):
            raise RuntimeError("Beta App Review contact is incomplete")
        evidence["steps"].append({"step": "beta_contact_preflight", "ok": True, **source_presence})

        _, current = api_get(token, f"/v1/appStoreReviewDetails/{REVIEW_DETAIL_ID}")
        current_attrs = current.get("data", {}).get("attributes") or {}
        before = presence(current_attrs)
        evidence["steps"].append({"step": "app_store_contact_before", **before})

        desired = {k: source.get(k) for k in CONTACT_KEYS}
        if not all(before.values()):
            payload = {"data": {"type": "appStoreReviewDetails", "id": REVIEW_DETAIL_ID, "attributes": desired}}
            status, _ = api_request(token, f"/v1/appStoreReviewDetails/{REVIEW_DETAIL_ID}", method="PATCH", payload=payload)
            evidence["steps"].append({"step": "sync_contact", "changed": True, "http_status": status})
        else:
            evidence["steps"].append({"step": "sync_contact", "changed": False})

        _, after_resource = api_get(token, f"/v1/appStoreReviewDetails/{REVIEW_DETAIL_ID}")
        after = presence(after_resource.get("data", {}).get("attributes") or {})
        if not all(after.values()):
            raise RuntimeError("App Store Review contact read-back incomplete")
        evidence["steps"].append({"step": "app_store_contact_readback", "ok": True, **after})
        evidence["ok"] = True
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    output = Path("automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-review-contact-sync.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
