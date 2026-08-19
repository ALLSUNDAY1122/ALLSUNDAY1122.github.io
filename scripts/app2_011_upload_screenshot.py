#!/usr/bin/env python3
"""Upload the approved APP2-011 screenshot to App Store Connect.

Bound to 卓 TAKU CALC / Version 1.5.0 / Japanese localization. This script only
creates or reuses the large-iPhone screenshot set and uploads one screenshot.
It never submits the app for review or releases it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794350490"
BUNDLE_ID = "com.koheimorita.takucalc"
VERSION_ID = "65ef287d-3ea2-42d6-a0df-32ff6d62c08c"
LOCALIZATION_ID = "c28c2619-d76f-4efd-b0d7-225f2a7e2069"
DISPLAY_TYPE = "APP_IPHONE_67"


def one_data(response: object, label: str) -> dict:
    if not isinstance(response, dict) or not isinstance(response.get("data"), dict):
        raise RuntimeError(f"Missing {label} resource")
    return response["data"]


def upload_operation(op: dict, data: bytes) -> None:
    offset = int(op.get("offset", 0))
    length = int(op.get("length", len(data) - offset))
    chunk = data[offset : offset + length]
    if len(chunk) != length:
        raise RuntimeError(f"Upload operation byte range is invalid: offset={offset} length={length}")
    request = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
    headers = op.get("requestHeaders") or []
    if isinstance(headers, dict):
        headers = [{"name": k, "value": v} for k, v in headers.items()]
    for header in headers:
        request.add_header(str(header["name"]), str(header["value"]))
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"Screenshot chunk upload failed with HTTP {response.status}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", default="automation/app2-011/taku-appstore-home.png")
    parser.add_argument("--output", default="app2-011-screenshot-upload-result.json")
    args = parser.parse_args()

    image_path = Path(args.image)
    raw = image_path.read_bytes()
    if len(raw) < 50_000:
        raise SystemExit("Screenshot file is missing or unexpectedly small")
    checksum = hashlib.md5(raw).hexdigest()

    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect API credentials")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)

        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        app = one_data(app_response, "app")
        if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app preflight failed")

        _, version_response = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        version = one_data(version_response, "version")
        if version.get("attributes", {}).get("versionString") != "1.5.0":
            raise RuntimeError("Target version preflight failed")

        _, loc_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}")
        loc = one_data(loc_response, "version localization")
        if loc.get("attributes", {}).get("locale") != "ja":
            raise RuntimeError("Target localization preflight failed")

        _, sets_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200")
        sets = sets_response.get("data") if isinstance(sets_response, dict) else []
        target_set = next((x for x in sets or [] if (x.get("attributes") or {}).get("screenshotDisplayType") == DISPLAY_TYPE), None)
        created_set = False
        if target_set is None:
            payload = {"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":DISPLAY_TYPE},"relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":LOCALIZATION_ID}}}}}
            _, created = api_request(token, "/v1/appScreenshotSets", method="POST", payload=payload)
            target_set = one_data(created, "created screenshot set")
            created_set = True

        set_id = target_set["id"]
        _, existing_response = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
        existing = existing_response.get("data") if isinstance(existing_response, dict) else []
        complete_existing = [item for item in existing or [] if (((item.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")) == "COMPLETE"]
        if complete_existing:
            result = {"task":"APP2-011","completed_at":datetime.now(timezone.utc).isoformat(),"app_id":APP_ID,"version":"1.5.0","screenshot_set_id":set_id,"display_type":DISPLAY_TYPE,"screenshot_id":complete_existing[0].get("id"),"state":"COMPLETE","created_set":created_set,"uploaded_new":False,"submission_performed":False}
            Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print("PASS: existing complete TAKU screenshot already present")
            return

        reserve_payload = {"data":{"type":"appScreenshots","attributes":{"fileSize":len(raw),"fileName":image_path.name},"relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":set_id}}}}}
        _, reserved_response = api_request(token, "/v1/appScreenshots", method="POST", payload=reserve_payload)
        reserved = one_data(reserved_response, "screenshot reservation")
        screenshot_id = reserved["id"]
        operations = (reserved.get("attributes") or {}).get("uploadOperations") or []
        if not operations:
            raise RuntimeError("App Store Connect did not return screenshot upload operations")
        for op in operations:
            upload_operation(op, raw)

        commit_payload = {"data":{"type":"appScreenshots","id":screenshot_id,"attributes":{"uploaded":True,"sourceFileChecksum":checksum}}}
        api_request(token, f"/v1/appScreenshots/{screenshot_id}", method="PATCH", payload=commit_payload)

        deadline = time.time() + 180
        final_state = None
        while time.time() < deadline:
            _, check = api_get(token, f"/v1/appScreenshots/{screenshot_id}")
            attrs = one_data(check, "screenshot read-back").get("attributes", {})
            delivery = attrs.get("assetDeliveryState") or {}
            final_state = delivery.get("state")
            if final_state == "COMPLETE": break
            if final_state == "FAILED": raise RuntimeError(f"Screenshot processing failed: {delivery}")
            time.sleep(5)
        if final_state != "COMPLETE": raise RuntimeError(f"Screenshot processing did not reach COMPLETE; state={final_state}")

        result = {"task":"APP2-011","completed_at":datetime.now(timezone.utc).isoformat(),"app_id":APP_ID,"version":"1.5.0","screenshot_set_id":set_id,"display_type":DISPLAY_TYPE,"screenshot_id":screenshot_id,"state":final_state,"created_set":created_set,"uploaded_new":True,"file_size":len(raw),"submission_performed":False}
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PASS: TAKU App Store screenshot uploaded and processed")
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
