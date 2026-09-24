#!/usr/bin/env python3
"""Upload TAKU 1.5.0 App Store screenshots for the Japanese localization."""
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
# App Review requires either APP_IPHONE_67 or APP_IPHONE_65 for this app.
# These uploads are 1242x2688 and target the iPhone 6.5-inch set.
DISPLAY_TYPE = "APP_IPHONE_65"


def one_data(response: object, label: str) -> dict:
    if not isinstance(response, dict) or not isinstance(response.get("data"), dict):
        raise RuntimeError(f"Missing {label} resource")
    return response["data"]


def upload_operation(op: dict, data: bytes) -> None:
    offset = int(op.get("offset", 0))
    length = int(op.get("length", len(data) - offset))
    chunk = data[offset : offset + length]
    if len(chunk) != length:
        raise RuntimeError(f"Invalid upload byte range: offset={offset} length={length}")
    request = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
    headers = op.get("requestHeaders") or []
    if isinstance(headers, dict):
        headers = [{"name": k, "value": v} for k, v in headers.items()]
    for header in headers:
        request.add_header(str(header["name"]), str(header["value"]))
    with urllib.request.urlopen(request, timeout=120) as response:
        if not 200 <= response.status < 300:
            raise RuntimeError(f"Screenshot upload failed with HTTP {response.status}")


def upload_one(token: str, set_id: str, image_path: Path, existing: list[dict]) -> dict:
    raw = image_path.read_bytes()
    if len(raw) < 40_000:
        raise RuntimeError(f"Screenshot unexpectedly small: {image_path} ({len(raw)} bytes)")
    checksum = hashlib.md5(raw).hexdigest()

    for item in existing:
        attrs = item.get("attributes") or {}
        state = (attrs.get("assetDeliveryState") or {}).get("state")
        if attrs.get("fileName") == image_path.name and state == "COMPLETE":
            return {"file": image_path.name, "id": item.get("id"), "state": state, "uploaded_new": False}

    reserve_payload = {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(raw), "fileName": image_path.name},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    }
    _, reserved_response = api_request(token, "/v1/appScreenshots", method="POST", payload=reserve_payload)
    reserved = one_data(reserved_response, "screenshot reservation")
    screenshot_id = reserved["id"]
    operations = (reserved.get("attributes") or {}).get("uploadOperations") or []
    if not operations:
        raise RuntimeError(f"No upload operations returned for {image_path.name}")
    for op in operations:
        upload_operation(op, raw)

    commit_payload = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
        }
    }
    api_request(token, f"/v1/appScreenshots/{screenshot_id}", method="PATCH", payload=commit_payload)

    deadline = time.time() + 180
    final_state = None
    delivery = {}
    while time.time() < deadline:
        _, check = api_get(token, f"/v1/appScreenshots/{screenshot_id}")
        attrs = one_data(check, "screenshot read-back").get("attributes", {})
        delivery = attrs.get("assetDeliveryState") or {}
        final_state = delivery.get("state")
        if final_state == "COMPLETE":
            break
        if final_state == "FAILED":
            raise RuntimeError(f"Screenshot processing failed for {image_path.name}: {delivery}")
        time.sleep(5)
    if final_state != "COMPLETE":
        raise RuntimeError(f"Screenshot did not reach COMPLETE for {image_path.name}: {delivery}")
    return {"file": image_path.name, "id": screenshot_id, "state": final_state, "uploaded_new": True, "file_size": len(raw)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", action="append", required=True, help="Repeat for each screenshot")
    parser.add_argument("--output", default="app2-011-screenshot-upload-result.json")
    args = parser.parse_args()
    image_paths = [Path(p) for p in args.image]
    for p in image_paths:
        if not p.is_file():
            raise SystemExit(f"Screenshot not found: {p}")

    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect API credentials")

    result = {
        "task": "APP2-011",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "version": "1.5.0",
        "display_type": DISPLAY_TYPE,
        "screenshots": [],
        "submission_performed": False,
    }

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        if one_data(app_response, "app").get("attributes", {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app preflight failed")
        _, version_response = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        if one_data(version_response, "version").get("attributes", {}).get("versionString") != "1.5.0":
            raise RuntimeError("Target version preflight failed")
        _, loc_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}")
        if one_data(loc_response, "version localization").get("attributes", {}).get("locale") != "ja":
            raise RuntimeError("Target localization preflight failed")

        _, sets_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200")
        sets = sets_response.get("data") if isinstance(sets_response, dict) else []
        target_set = next((x for x in sets or [] if (x.get("attributes") or {}).get("screenshotDisplayType") == DISPLAY_TYPE), None)
        if target_set is None:
            payload = {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": LOCALIZATION_ID}}},
                }
            }
            _, created = api_request(token, "/v1/appScreenshotSets", method="POST", payload=payload)
            target_set = one_data(created, "created screenshot set")
        set_id = target_set["id"]
        result["screenshot_set_id"] = set_id

        _, existing_response = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
        existing = existing_response.get("data") if isinstance(existing_response, dict) else []
        for image_path in image_paths:
            uploaded = upload_one(token, set_id, image_path, existing or [])
            result["screenshots"].append(uploaded)
            if uploaded.get("uploaded_new"):
                existing = list(existing or []) + [{"id": uploaded["id"], "attributes": {"fileName": uploaded["file"], "assetDeliveryState": {"state": "COMPLETE"}}}]

        _, verify_response = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
        verified = verify_response.get("data") if isinstance(verify_response, dict) else []
        complete_count = sum(1 for x in verified or [] if ((x.get("attributes") or {}).get("assetDeliveryState") or {}).get("state") == "COMPLETE")
        result["complete_count"] = complete_count
        if complete_count < len(image_paths):
            raise RuntimeError(f"Screenshot read-back incomplete: {complete_count}/{len(image_paths)}")

        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: {len(image_paths)} TAKU screenshots ready; complete_count={complete_count}")
    except Exception as exc:
        result["error"] = str(exc)
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
