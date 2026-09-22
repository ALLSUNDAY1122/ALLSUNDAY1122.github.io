#!/usr/bin/env python3
"""Attach the current valid TAKU Build 10, then run the strict APP2-011 review submitter."""
from __future__ import annotations

import os

import app2_011_submit_review as submitter
from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794350490"
BUNDLE_ID = "com.koheimorita.takucalc"
VERSION_ID = "65ef287d-3ea2-42d6-a0df-32ff6d62c08c"
BUILD_ID = "593f6917-cca2-4cc5-b8e7-09fad16a6053"


def attach_build10() -> None:
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect API credentials")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        app = (app_response or {}).get("data") or {}
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app preflight failed")

        _, builds_response = api_get(token, f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=20")
        builds = (builds_response or {}).get("data") or []
        build = next((x for x in builds if x.get("id") == BUILD_ID), None)
        if build is None:
            raise RuntimeError("TAKU Build 10 not found in App Store Connect")
        attrs = build.get("attributes") or {}
        if attrs.get("version") != "10" or attrs.get("expired") is not False or attrs.get("processingState") != "VALID" or attrs.get("buildAudienceType") != "APP_STORE_ELIGIBLE":
            raise RuntimeError(f"TAKU Build 10 is not submission eligible: {attrs}")

        relationship_path = f"/v1/appStoreVersions/{VERSION_ID}/relationships/build"
        _, selected = api_get(token, relationship_path)
        selected_id = ((selected or {}).get("data") or {}).get("id")
        if selected_id != BUILD_ID:
            payload = {"data": {"type": "builds", "id": BUILD_ID}}
            api_request(token, relationship_path, method="PATCH", payload=payload)
            _, selected_after = api_get(token, relationship_path)
            selected_id = ((selected_after or {}).get("data") or {}).get("id")
            if selected_id != BUILD_ID:
                raise RuntimeError(f"Build 10 attachment read-back failed: {selected_id}")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    attach_build10()
    submitter.BUILD_ID = BUILD_ID
    submitter.main()
