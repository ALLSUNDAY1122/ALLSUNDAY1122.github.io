#!/usr/bin/env python3
"""Read-only recovery of the FP3 App Store icon from processed ASC Build 9.

This script never mutates App Store Connect. It validates the exact app identity,
locates build number 9, selects exactly one APP_STORE BuildIcon, downloads the
rendered PNG from Apple's ImageAsset template URL, validates PNG structure and
records a sanitized recovery manifest.
"""
from __future__ import annotations

import hashlib
import json
import os
import struct
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

APP_ID = "6796733578"
BUNDLE_ID = "com.allsunday1122.fp3kakomoncoach"
TARGET_BUILD_NUMBER = "9"
OUT_PNG = Path("fp3-build9-appstore-icon.png")
OUT_JSON = Path("fp3-build9-appstore-icon-recovery.json")


def png_dimensions(data: bytes) -> tuple[int, int]:
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise RuntimeError("Recovered BuildIcon is not a valid PNG")
    width, height = struct.unpack(">II", data[16:24])
    if width <= 0 or height <= 0:
        raise RuntimeError("Recovered PNG dimensions are invalid")
    return width, height


def render_url(template: str, width: int, height: int) -> str:
    url = template
    replacements = {
        "{w}": str(width),
        "{h}": str(height),
        "{f}": "png",
        "{c}": "",
    }
    for key, value in replacements.items():
        url = url.replace(key, value)
    if "{" in url or "}" in url:
        raise RuntimeError(f"Unsupported ImageAsset template placeholders remain: {url}")
    if not url.startswith("https://"):
        raise RuntimeError("BuildIcon template URL is not HTTPS")
    return url


def main() -> None:
    issuer = os.environ.get("ASC_ISSUER_ID", "").strip()
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)

        _, app_payload = api_get(token, f"/v1/apps/{APP_ID}")
        app = app_payload.get("data") or {}
        attrs = app.get("attributes") or {}
        if app.get("id") != APP_ID or attrs.get("bundleId") != BUNDLE_ID:
            raise RuntimeError("FP3 target app identity mismatch")

        _, builds_payload = api_get(token, f"/v1/builds?filter[app]={APP_ID}&limit=200")
        candidates = []
        for item in builds_payload.get("data") or []:
            item_attrs = item.get("attributes") or {}
            if str(item_attrs.get("version")) == TARGET_BUILD_NUMBER:
                candidates.append(item)
        if len(candidates) != 1:
            raise RuntimeError(f"Expected exactly one FP3 build {TARGET_BUILD_NUMBER}; found {len(candidates)}")
        build = candidates[0]
        build_id = str(build.get("id") or "")
        if not build_id:
            raise RuntimeError("FP3 build id missing")

        _, icons_payload = api_get(token, f"/v1/builds/{build_id}/icons?limit=200")
        icons = []
        for item in icons_payload.get("data") or []:
            icon_attrs = item.get("attributes") or {}
            icon_type = str(icon_attrs.get("iconType") or "")
            if icon_type == "APP_STORE":
                icons.append(item)
        if len(icons) != 1:
            summary = [str((x.get("attributes") or {}).get("iconType")) for x in (icons_payload.get("data") or [])]
            raise RuntimeError(f"Expected one APP_STORE BuildIcon; found {len(icons)}; types={summary}")

        icon = icons[0]
        icon_attrs = icon.get("attributes") or {}
        asset = icon_attrs.get("iconAsset") or {}
        width = int(asset.get("width") or 0)
        height = int(asset.get("height") or 0)
        template = str(asset.get("templateUrl") or "")
        if width < 512 or height < 512 or not template:
            raise RuntimeError(f"APP_STORE BuildIcon asset is unexpectedly small/incomplete: {width}x{height}")

        png_url = render_url(template, width, height)
        with urllib.request.urlopen(png_url, timeout=30) as response:
            png = response.read()
        actual_width, actual_height = png_dimensions(png)
        if (actual_width, actual_height) != (width, height):
            raise RuntimeError(
                f"Downloaded BuildIcon dimensions mismatch: API={width}x{height}, PNG={actual_width}x{actual_height}"
            )
        if len(png) < 10_000:
            raise RuntimeError(f"Recovered BuildIcon PNG unexpectedly small: {len(png)} bytes")

        sha256 = hashlib.sha256(png).hexdigest()
        OUT_PNG.write_bytes(png)
        result = {
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "read_only": True,
            "source": "App Store Connect processed BuildIcon",
            "app_id": APP_ID,
            "bundle_id": BUNDLE_ID,
            "build_id": build_id,
            "build_number": TARGET_BUILD_NUMBER,
            "build_processing_state": (build.get("attributes") or {}).get("processingState"),
            "build_expired": (build.get("attributes") or {}).get("expired"),
            "build_icon_id": icon.get("id"),
            "icon_type": icon_attrs.get("iconType"),
            "icon_name": icon_attrs.get("name"),
            "icon_masked": icon_attrs.get("isPrerendered"),
            "asset_width": width,
            "asset_height": height,
            "png_width": actual_width,
            "png_height": actual_height,
            "png_bytes": len(png),
            "png_sha256": sha256,
            "apple_template_url_present": True,
            "app_store_connect_mutated": False,
        }
        OUT_JSON.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
