#!/usr/bin/env python3
"""Upload the audited HM2 lifetime-IAP App Store review screenshot.

Fail-closed guarantees:
- verifies exact App ID, bundle ID, IAP ID and product ID;
- leaves an existing COMPLETE screenshot untouched;
- rejects an existing incomplete/unknown screenshot instead of replacing it;
- requires the newly uploaded screenshot to reach COMPLETE and read back from the exact IAP.

Set HM2_IAP_REVIEW_SCREENSHOT to the audited PNG path.
"""
from __future__ import annotations

import hashlib
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path

from app_store_connect_api import BASE_URL, load_private_key, make_token

APP_ID = "6799751657"
BUNDLE_ID = "jp.allsunday1122.healthmanager2"
IAP_ID = "6802989207"
PRODUCT_ID = "jp.allsunday1122.healthmanager2.lifetime"
OUT = Path("hm2-iap-review-screenshot-result.json")


def req(token: str, path: str, method: str = "GET", payload: dict | None = None):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    request = urllib.request.Request(
        BASE_URL + path,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"ASC {method} {path} HTTP {exc.code}: {raw[:4000]}") from exc


def req_allow_404(token: str, path: str):
    request = urllib.request.Request(
        BASE_URL + path,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return 404, {}
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"ASC GET {path} HTTP {exc.code}: {raw[:4000]}") from exc


def asset_state(resource: dict) -> str | None:
    return ((resource.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")


def upload_parts(resource: dict, file_path: Path) -> None:
    data = file_path.read_bytes()
    operations = (resource.get("attributes") or {}).get("uploadOperations") or []
    if not operations:
        raise RuntimeError("ASC returned no upload operations")
    for operation in operations:
        offset = int(operation.get("offset", 0))
        length = int(operation.get("length", 0))
        chunk = data[offset : offset + length]
        if len(chunk) != length:
            raise RuntimeError(f"Upload range mismatch: {offset}+{length}")
        headers = {
            str(item["name"]): str(item["value"])
            for item in (operation.get("requestHeaders") or [])
            if item.get("name")
        }
        request = urllib.request.Request(
            operation["url"],
            data=chunk,
            method=operation.get("method", "PUT"),
            headers=headers,
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8", "replace")
            raise RuntimeError(f"Asset upload HTTP {exc.code}: {raw[:2000]}") from exc


def wait_complete(token: str, screenshot_id: str, timeout: int = 240) -> dict:
    path = f"/v1/inAppPurchaseAppStoreReviewScreenshots/{screenshot_id}"
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        _, payload = req(token, path)
        resource = payload.get("data") or {}
        state = asset_state(resource)
        last = state
        if state == "COMPLETE":
            return resource
        if state in {"FAILED", "UPLOAD_FAILED"}:
            raise RuntimeError(f"Review screenshot delivery failed: {state}")
        time.sleep(5)
    raise RuntimeError(f"Timed out waiting for review screenshot COMPLETE; last={last}")


def validate_identity(token: str) -> None:
    _, app = req(token, f"/v1/apps/{APP_ID}")
    app_data = app.get("data") or {}
    if app_data.get("id") != APP_ID or ((app_data.get("attributes") or {}).get("bundleId")) != BUNDLE_ID:
        raise RuntimeError("HM2 app identity mismatch")

    _, iap = req(token, f"/v2/inAppPurchases/{IAP_ID}")
    iap_data = iap.get("data") or {}
    if iap_data.get("id") != IAP_ID or ((iap_data.get("attributes") or {}).get("productId")) != PRODUCT_ID:
        raise RuntimeError("HM2 IAP identity mismatch")


def main() -> None:
    screenshot = Path(os.environ.get("HM2_IAP_REVIEW_SCREENSHOT", ""))
    result = {"app_id": APP_ID, "iap_id": IAP_ID, "ok": False}
    cleanup = None
    try:
        if not screenshot.is_file():
            raise RuntimeError("HM2_IAP_REVIEW_SCREENSHOT must point to an audited screenshot file")
        if screenshot.suffix.lower() != ".png":
            raise RuntimeError("HM2 IAP review screenshot must be PNG")
        if screenshot.stat().st_size <= 0:
            raise RuntimeError("HM2 IAP review screenshot is empty")

        issuer = os.environ.get("ASC_ISSUER_ID")
        key_id = os.environ.get("ASC_KEY_ID")
        if not issuer or not key_id:
            raise RuntimeError("Missing ASC credentials")
        key_path, cleanup = load_private_key()
        token = make_token(issuer, key_id, key_path)
        validate_identity(token)

        status, current = req_allow_404(token, f"/v2/inAppPurchases/{IAP_ID}/appStoreReviewScreenshot")
        if status == 200 and current.get("data"):
            resource = current["data"]
            state = asset_state(resource)
            if state != "COMPLETE":
                raise RuntimeError(f"Existing IAP review screenshot is not COMPLETE: {state}")
            result.update({"ok": True, "changed": False, "screenshot_id": str(resource["id"]), "state": state})
        else:
            payload = {
                "data": {
                    "type": "inAppPurchaseAppStoreReviewScreenshots",
                    "attributes": {
                        "fileSize": screenshot.stat().st_size,
                        "fileName": "hm2-premium-review.png",
                    },
                    "relationships": {
                        "inAppPurchaseV2": {
                            "data": {"type": "inAppPurchases", "id": IAP_ID}
                        }
                    },
                }
            }
            _, created = req(token, "/v1/inAppPurchaseAppStoreReviewScreenshots", "POST", payload)
            resource = created.get("data") or {}
            screenshot_id = str(resource.get("id") or "")
            if not screenshot_id:
                raise RuntimeError("ASC did not return review screenshot id")
            upload_parts(resource, screenshot)
            checksum = hashlib.md5(screenshot.read_bytes()).hexdigest()
            req(
                token,
                f"/v1/inAppPurchaseAppStoreReviewScreenshots/{screenshot_id}",
                "PATCH",
                {
                    "data": {
                        "type": "inAppPurchaseAppStoreReviewScreenshots",
                        "id": screenshot_id,
                        "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
                    }
                },
            )
            final = wait_complete(token, screenshot_id)
            _, readback = req(token, f"/v2/inAppPurchases/{IAP_ID}/appStoreReviewScreenshot")
            readback_data = readback.get("data") or {}
            if str(readback_data.get("id") or "") != screenshot_id or asset_state(readback_data) != "COMPLETE":
                raise RuntimeError("IAP review screenshot read-back mismatch")
            result.update({
                "ok": True,
                "changed": True,
                "screenshot_id": screenshot_id,
                "state": asset_state(final),
                "file_size": screenshot.stat().st_size,
            })
    except Exception as exc:
        result["error"] = str(exc)[:4000]
        raise
    finally:
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
