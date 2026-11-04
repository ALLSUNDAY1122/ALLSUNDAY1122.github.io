#!/usr/bin/env python3
"""Upload only the three approved Japanese images to a Shiwake 1.0.1 draft.

This script never deletes a published screenshot, attaches a build, submits for
App Review, or releases an app. It is intentionally hard-scoped to APP2-001.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
from urllib.request import Request, urlopen
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from app_store_connect_api import api_request, load_private_key, make_token

APP_ID = "6794796078"
BUNDLE = "jp.allsunday1122.shiwakeswipe"
CURRENT_VERSION = "1.0"
NEW_VERSION = "1.0.1"
DISPLAY_TYPE = "APP_IPHONE_67"
SOURCE = Path("automation/app2-001/screenshots/20261104/shiwake-store-ja.zip")
EXPECTED_ZIP_SHA256 = "515971bb1606afb315ad18221e2e92fdf6800923379343e25220571248ff7658"
FILES = (
    ("shiwake_appstore_01_1320x2868.png", "e55bade2caff17abb46d303e5aa273c9e16518dbde1cc366a39aba96bff27435"),
    ("shiwake_appstore_02_1320x2868.png", "715ead530ea9d20eafe07f80425331f59b3f12c97a57b4930313642094220e02"),
    ("shiwake_appstore_03_1320x2868.png", "4856ed67c3f352297b7b03d3db6f0b74c672604fe03e2394bc8806d5d3179704"),
)


def many(payload: object) -> list[dict]:
    data = (payload or {}).get("data") if isinstance(payload, dict) else None
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [data]
    return []


def one(payload: object, label: str) -> dict:
    data = many(payload)
    if len(data) != 1:
        raise RuntimeError(f"{label}: expected one result, got {len(data)}")
    return data[0]


def attrs(resource: dict) -> dict:
    return resource.get("attributes") or {}


def rel(resource_type: str, resource_id: str) -> dict:
    return {"data": {"type": resource_type, "id": resource_id}}


def valid_assets() -> dict[str, bytes]:
    raw = SOURCE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXPECTED_ZIP_SHA256:
        raise RuntimeError("Screenshot ZIP SHA256 mismatch")
    output = {}
    with zipfile.ZipFile(SOURCE) as archive:
        for name, expected_sha in FILES:
            data = archive.read(name)
            if hashlib.sha256(data).hexdigest() != expected_sha:
                raise RuntimeError(f"Screenshot hash mismatch: {name}")
            if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
                raise RuntimeError(f"Not a PNG: {name}")
            width, height = struct.unpack(">II", data[16:24])
            if (width, height) != (1320, 2868) or data[25] != 2:
                raise RuntimeError(f"Invalid Apple screenshot dimensions/alpha: {name}")
            output[name] = data
    return output


def upload(token: str) -> dict:
    assets = valid_assets()

    def request(path: str, method: str = "GET", payload=None) -> dict:
        return api_request(token, path, method=method, payload=payload)[1] or {}

    app = one(request(f"/v1/apps/{APP_ID}"), "app")
    if attrs(app).get("bundleId") != BUNDLE or attrs(app).get("primaryLocale") != "ja":
        raise RuntimeError("App ID, Bundle ID or Japanese locale mismatch")

    versions = many(request(f"/v1/apps/{APP_ID}/appStoreVersions?limit=100"))
    released = [v for v in versions if attrs(v).get("versionString") == CURRENT_VERSION]
    if len(released) != 1 or attrs(released[0]).get("appStoreState") != "READY_FOR_SALE":
        raise RuntimeError("Expected exactly one released version 1.0")
    unexpected = [v for v in versions if attrs(v).get("appStoreState") == "PREPARE_FOR_SUBMISSION"
                  and attrs(v).get("versionString") != NEW_VERSION]
    if unexpected:
        raise RuntimeError("Another editable version exists; refusing to create a competing draft")

    new = [v for v in versions if attrs(v).get("versionString") == NEW_VERSION]
    if len(new) > 1:
        raise RuntimeError("Duplicate target app versions")
    if new:
        version = new[0]
        if attrs(version).get("appStoreState") != "PREPARE_FOR_SUBMISSION":
            raise RuntimeError("Target version is not an editable draft")
    else:
        payload = {"data": {"type": "appStoreVersions",
                "attributes": {"platform": "IOS", "versionString": NEW_VERSION, "releaseType": "MANUAL"},
                "relationships": {"app": rel("apps", APP_ID)}}}
        version = one(request("/v1/appStoreVersions", "POST", payload), "created draft")
    vid = version["id"]

    locales = many(request(f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=100"))
    japanese = [v for v in locales if attrs(v).get("locale") == "ja"]
    if len(japanese) > 1:
        raise RuntimeError("Duplicate Japanese localizations")
    if japanese:
        localization = japanese[0]
    else:
        prior = many(request(
            f"/v1/appStoreVersions/{released[0]['id']}/appStoreVersionLocalizations?limit=100"))
        old_ja = [x for x in prior if attrs(x).get("locale") == "ja"]
        if len(old_ja) != 1:
            raise RuntimeError("Released Japanese localization missing")
        old_attrs = attrs(old_ja[0])
        local_attrs = {k: old_attrs[k] for k in
                       ("description", "keywords", "marketingUrl", "promotionalText", "supportUrl")
                       if old_attrs.get(k) is not None}
        local_attrs.update({"locale": "ja", "whatsNew": "App Storeの掲載画像を更新し、日本語表示に対応しました。"})
        payload = {"data": {"type": "appStoreVersionLocalizations",
                   "attributes": local_attrs,
                   "relationships": {"appStoreVersion": rel("appStoreVersions", vid)}}}
        localization = one(request("/v1/appStoreVersionLocalizations", "POST", payload), "new ja localization")
    lid = localization["id"]

    sets = many(request(f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets?limit=100"))
    desired = [s for s in sets if attrs(s).get("screenshotDisplayType") == DISPLAY_TYPE]
    if len(desired) > 1:
        raise RuntimeError("Duplicate 6.9-inch screenshot sets")
    if desired:
        set_id = desired[0]["id"]
    else:
        payload = {"data": {"type": "appScreenshotSets",
                   "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                   "relationships": {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", lid)}}}
        set_id = one(request("/v1/appScreenshotSets", "POST", payload), "created screenshot set")["id"]

    def screenshots():
        return many(request(f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=100"))

    existing = {attrs(s).get("fileName"): s for s in screenshots()}
    unexpected_files = set(existing) - set(assets)
    if unexpected_files:
        raise RuntimeError(f"Non-approved 6.9-inch screenshots already exist: {sorted(unexpected_files)}")

    for name, content in assets.items():
        if name in existing:
            if attrs(existing[name]).get("fileSize") != len(content):
                raise RuntimeError(f"Existing image with matching filename differs: {name}")
            continue
        payload = {"data": {"type": "appScreenshots",
                   "attributes": {"fileName": name, "fileSize": len(content)},
                   "relationships": {"appScreenshotSet": rel("appScreenshotSets", set_id)}}}
        reserved = one(request("/v1/appScreenshots", "POST", payload), f"reserved {name}")
        operations = attrs(reserved).get("uploadOperations") or []
        if not operations or sum(int(op.get("length", 0)) for op in operations) != len(content):
            raise RuntimeError(f"Apple did not provide a complete upload plan for {name}")
        for op in operations:
            url = op.get("url", "")
            offset, length = int(op["offset"]), int(op["length"])
            if not url.startswith("https://") or offset < 0 or length <= 0 or offset+length > len(content):
                raise RuntimeError("Invalid Apple upload operation")
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            upload_request = Request(url, data=content[offset:offset+length], headers=headers, method="PUT")
            with urlopen(upload_request, timeout=120) as response:
                if response.status not in (200, 201, 202, 204):
                    raise RuntimeError(f"Asset upload failed HTTP {response.status}")
        payload = {"data": {"type": "appScreenshots", "id": reserved["id"],
                   "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(content).hexdigest()}}}
        request(f"/v1/appScreenshots/{reserved['id']}", "PATCH", payload)

    report = {}
    for retry in range(30):
        received = screenshots()
        selected = {attrs(x).get("fileName"): x for x in received}
        if set(selected) == set(assets):
            states = {k: (attrs(v).get("assetDeliveryState") or {}).get("state") for k,v in selected.items()}
            if "FAILED" in states.values():
                raise RuntimeError(f"Apple screenshot processing failed: {states}")
            if all(s == "COMPLETE" for s in states.values()):
                report = {"app_id": APP_ID, "bundle_id": BUNDLE, "version": NEW_VERSION,
                          "app_store_version_id": vid, "version_state": attrs(version).get("appStoreState"),
                          "ja_localization_id": lid, "screenshot_set_id": set_id,
                          "display_type": DISPLAY_TYPE, "screenshots": [
                              {"file": k, "id": selected[k]["id"], "state": "COMPLETE"} for k in assets],
                          "build_uploaded": False, "review_submitted": False}
                break
        if retry < 29:
            time.sleep(6)
    if not report:
        raise RuntimeError("Screenshot processing not confirmed COMPLETE")
    return report


def main() -> None:
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        result = upload(token)
        destination = Path("automation/asc-results/shiwake-screenshots-20261104.json")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False, indent=2))
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
