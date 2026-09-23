#!/usr/bin/env python3
"""Resolve machine-fixable HM2 App Store submission prerequisites.

- Declare content rights on the App resource.
- Set the app itself to free pricing in Japan.
- Supply the required 12.9-inch iPad screenshot set from the audited app capture.

The source capture is preserved without cropping; side margins are added only to
meet Apple's required iPad screenshot canvas size.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from decimal import Decimal, InvalidOperation
from pathlib import Path

from PIL import Image

from app_store_connect_api import api_get, api_request, load_private_key, make_token
from app2_006_hm2_submit_review import (
    APP_ID,
    many,
    one,
    patch,
    request_ok,
    resolve_localization,
    resolve_version,
    upload_operations,
    wait_complete,
)

BASE_TERRITORY = "JPN"
IPAD_DISPLAY_TYPE = "APP_IPAD_PRO_3GEN_129"
IPAD_SIZE = (2048, 2732)


def rel_id(resource: dict, key: str) -> str | None:
    try:
        return str(resource["relationships"][key]["data"]["id"])
    except Exception:
        return None


def is_zero(value) -> bool:
    try:
        return Decimal(str(value)) == 0
    except (InvalidOperation, TypeError, ValueError):
        return False


def ensure_content_rights(token: str) -> str:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}?fields[apps]=bundleId,contentRightsDeclaration")
    app = one(payload, "app")
    current = (app.get("attributes") or {}).get("contentRightsDeclaration")
    if current != "DOES_NOT_USE_THIRD_PARTY_CONTENT":
        body = {
            "data": {
                "type": "apps",
                "id": APP_ID,
                "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"},
            }
        }
        request_ok(token, f"/v1/apps/{APP_ID}", "PATCH", body)
    _, after_payload = api_get(token, f"/v1/apps/{APP_ID}?fields[apps]=bundleId,contentRightsDeclaration")
    after = one(after_payload, "app after content rights")
    value = (after.get("attributes") or {}).get("contentRightsDeclaration")
    if value != "DOES_NOT_USE_THIRD_PARTY_CONTENT":
        raise RuntimeError(f"contentRightsDeclaration read-back mismatch: {value}")
    return value


def app_price_schedule(token: str) -> dict | None:
    try:
        _, payload = api_get(token, f"/v1/apps/{APP_ID}/appPriceSchedule?include=baseTerritory")
    except Exception as exc:
        if "404" in str(exc):
            return None
        raise
    data = payload.get("data") if isinstance(payload, dict) else None
    return data if isinstance(data, dict) else None


def manual_prices(token: str, schedule_id: str) -> list[dict]:
    _, payload = api_get(token, f"/v1/appPriceSchedules/{schedule_id}/manualPrices?include=appPricePoint,territory&limit=200")
    included = payload.get("included") or []
    point_attrs = {
        str(x.get("id")): (x.get("attributes") or {})
        for x in included
        if x.get("type") == "appPricePoints"
    }
    out = []
    for row in many(payload):
        point_id = rel_id(row, "appPricePoint")
        out.append({
            "id": str(row.get("id")),
            "territory": rel_id(row, "territory"),
            "price_point_id": point_id,
            "customer_price": (point_attrs.get(point_id) or {}).get("customerPrice"),
        })
    return out


def ensure_free_app_pricing(token: str) -> dict:
    schedule = app_price_schedule(token)
    if schedule:
        sid = str(schedule["id"])
        prices = manual_prices(token, sid)
        if any(is_zero(x.get("customer_price")) for x in prices):
            return {"schedule_id": sid, "customer_price": "0", "existing": True}

    _, points_payload = api_get(token, f"/v1/apps/{APP_ID}/appPricePoints?filter[territory]={BASE_TERRITORY}&limit=200")
    free_points = [x for x in many(points_payload) if is_zero((x.get("attributes") or {}).get("customerPrice"))]
    if not free_points:
        raise RuntimeError("No JPN zero-price app price point found")
    price_point_id = str(free_points[0]["id"])
    placeholder = "${hm2-free-price}"
    body = {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}},
                "baseTerritory": {"data": {"type": "territories", "id": BASE_TERRITORY}},
                "manualPrices": {"data": [{"type": "appPrices", "id": placeholder}]},
            },
        },
        "included": [
            {
                "type": "appPrices",
                "id": placeholder,
                "attributes": {},
                "relationships": {
                    "appPricePoint": {"data": {"type": "appPricePoints", "id": price_point_id}}
                },
            }
        ],
    }
    request_ok(token, "/v1/appPriceSchedules", "POST", body)
    after = app_price_schedule(token)
    if not after:
        raise RuntimeError("App price schedule missing after write")
    sid = str(after["id"])
    prices = manual_prices(token, sid)
    if not any(is_zero(x.get("customer_price")) for x in prices):
        raise RuntimeError("Free pricing read-back did not contain customerPrice=0")
    return {"schedule_id": sid, "customer_price": "0", "price_point_id": price_point_id, "existing": False}


def build_ipad_png(source: Path, dest: Path) -> None:
    with Image.open(source) as im:
        im = im.convert("RGB")
        target_w, target_h = IPAD_SIZE
        scale = min(target_w / im.width, target_h / im.height)
        inner_w = max(1, round(im.width * scale))
        inner_h = max(1, round(im.height * scale))
        resized = im.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
        # Use the source screen's edge/background tone so the complete audited UI
        # remains visible and undistorted on the required iPad canvas.
        bg = im.getpixel((0, min(8, im.height - 1)))
        canvas = Image.new("RGB", IPAD_SIZE, bg)
        canvas.paste(resized, ((target_w - inner_w) // 2, (target_h - inner_h) // 2))
        canvas.save(dest, format="PNG", optimize=True)
    with Image.open(dest) as check:
        if check.size != IPAD_SIZE:
            raise RuntimeError(f"iPad screenshot output size mismatch: {check.size}")


def ensure_ipad_screenshot(token: str, localization_id: str, source: Path, workdir: Path) -> dict:
    workdir.mkdir(parents=True, exist_ok=True)
    image = workdir / "03-ipad-129.png"
    build_ipad_png(source, image)

    _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200")
    target = next(
        (x for x in many(sets_payload) if (x.get("attributes") or {}).get("screenshotDisplayType") == IPAD_DISPLAY_TYPE),
        None,
    )
    if target is None:
        body = {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": IPAD_DISPLAY_TYPE},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": localization_id}
                    }
                },
            }
        }
        target = one(request_ok(token, "/v1/appScreenshotSets", "POST", body), "created iPad screenshot set")
    set_id = str(target["id"])

    _, existing_payload = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
    for item in many(existing_payload):
        status, _ = api_request(token, f"/v1/appScreenshots/{item['id']}", method="DELETE")
        if status not in {200, 204}:
            raise RuntimeError(f"Could not delete stale iPad screenshot {item['id']}: HTTP {status}")

    raw = image.read_bytes()
    checksum = hashlib.md5(raw).hexdigest()
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(raw), "fileName": image.name},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    }
    reserved = one(request_ok(token, "/v1/appScreenshots", "POST", body), "reserved iPad screenshot")
    sid = str(reserved["id"])
    upload_operations((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
    patch(token, f"/v1/appScreenshots/{sid}", "appScreenshots", sid,
          attributes={"uploaded": True, "sourceFileChecksum": checksum})
    wait_complete(token, f"/v1/appScreenshots/{sid}", "iPad app screenshot")
    return {"set_id": set_id, "screenshot_id": sid, "display_type": IPAD_DISPLAY_TYPE, "size": list(IPAD_SIZE)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-screen", required=True)
    parser.add_argument("--workdir", default="/tmp/hm2-ipad-shot")
    parser.add_argument("--output", default="/tmp/hm2-submission-prereqs.json")
    args = parser.parse_args()
    source = Path(args.source_screen)
    if not source.is_file():
        raise RuntimeError(f"Missing source screenshot: {source}")

    key_path, cleanup = load_private_key()
    result = {"app_id": APP_ID, "ok": False}
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        result["content_rights"] = ensure_content_rights(token)
        result["app_pricing"] = ensure_free_app_pricing(token)
        version = resolve_version(token)
        localization = resolve_localization(token, str(version["id"]))
        result["ipad_screenshot"] = ensure_ipad_screenshot(token, str(localization["id"]), source, Path(args.workdir))
        result["ok"] = True
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PASS: HM2 content rights, free app pricing, and required iPad screenshot are complete")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
