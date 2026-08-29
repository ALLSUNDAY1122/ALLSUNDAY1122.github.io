#!/usr/bin/env python3
"""Upload the audited Otsu4 App Store screenshots and IAP review screenshot.

The binary images are downloaded by the workflow from a pinned successful
GitHub Actions artifact. Credentials stay in GitHub Actions secrets. The script
is intentionally pinned to APP2-007 identifiers and fails rather than replacing
unknown existing screenshots.
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

APP_ID = "6799755566"
BUNDLE_ID = "jp.allsunday1122.otsu4"
VERSION_ID = "d02ea66f-2452-4f75-b900-5d9347384b5d"
LOCALIZATION_ID = "3718791f-0edf-4a18-b045-65540780538b"
IAP_ID = "6806477067"
IAP_VERSION_ID = "1a226705-e29a-4161-8ca5-0b77457dd9f9"
DISPLAY_TYPE = "APP_IPHONE_67"
ASSET_DIR = Path(os.environ.get("OTS4_STORE_ASSET_DIR", "otsu4-store-assets"))
OUT = Path(os.environ.get("OTS4_STORE_UPLOAD_OUTPUT", "automation/app2-007-otsu4-store-upload-result.json"))
PUBLIC_PREFIXES = ["01-home", "02-subject-index", "03-question", "04-explanation", "05-mocks", "06-history"]
IAP_PREFIX = "07-premium-review"


def req(token: str, path: str, method: str = "GET", payload: dict | None = None):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    r = urllib.request.Request(
        BASE_URL + path,
        data=body,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(r, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"ASC {method} {path} HTTP {exc.code}: {raw[:5000]}") from exc


def req_allow_404(token: str, path: str):
    r = urllib.request.Request(BASE_URL + path, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(r, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode()) if raw else {}
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return 404, {}
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"ASC GET {path} HTTP {exc.code}: {raw[:5000]}") from exc


def rows(payload: dict) -> list[dict]:
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([] if data is None else [data])


def asset_state(resource: dict) -> str | None:
    return ((resource.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")


def upload_parts(resource: dict, file_path: Path):
    data = file_path.read_bytes()
    ops = (resource.get("attributes") or {}).get("uploadOperations") or []
    if not ops:
        raise RuntimeError(f"No upload operations returned for {file_path.name}")
    for op in ops:
        offset, length = int(op.get("offset", 0)), int(op.get("length", 0))
        chunk = data[offset : offset + length]
        if len(chunk) != length:
            raise RuntimeError(f"Upload range mismatch for {file_path.name}: {offset}+{length}")
        headers = {str(x["name"]): str(x["value"]) for x in (op.get("requestHeaders") or []) if x.get("name")}
        request = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"), headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8", "replace")
            raise RuntimeError(f"Asset upload HTTP {exc.code}: {raw[:2000]}") from exc


def wait_complete(token: str, path: str, timeout: int = 240) -> dict:
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        _, payload = req(token, path)
        resource = payload.get("data") or {}
        state = asset_state(resource)
        if state != last:
            print(path, "state=", state)
            last = state
        if state == "COMPLETE":
            return resource
        if state in {"FAILED", "UPLOAD_FAILED"}:
            raise RuntimeError(f"Asset delivery failed for {path}: {payload}")
        time.sleep(5)
    raise RuntimeError(f"Timed out waiting for COMPLETE: {path}, last={last}")


def commit_asset(token: str, resource_type: str, resource_id: str, file_path: Path, path: str):
    checksum = hashlib.md5(file_path.read_bytes()).hexdigest()
    req(token, path, "PATCH", {"data": {"type": resource_type, "id": resource_id, "attributes": {"uploaded": True, "sourceFileChecksum": checksum}}})
    return wait_complete(token, path)


def manifest_files() -> tuple[list[Path], Path]:
    manifest_path = ASSET_DIR / "manifest.json"
    if not manifest_path.is_file():
        raise RuntimeError(f"Missing {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    attachments = []
    for entry in manifest:
        attachments.extend(entry.get("attachments") or [])
    by_prefix = {}
    for item in attachments:
        suggested = item.get("suggestedHumanReadableName") or ""
        exported = item.get("exportedFileName") or ""
        for prefix in PUBLIC_PREFIXES + [IAP_PREFIX]:
            if suggested.startswith(prefix + "_"):
                p = ASSET_DIR / exported
                if not p.is_file():
                    raise RuntimeError(f"Manifest image missing: {p}")
                by_prefix[prefix] = p
    missing = [x for x in PUBLIC_PREFIXES + [IAP_PREFIX] if x not in by_prefix]
    if missing:
        raise RuntimeError(f"Missing expected store assets: {missing}")
    return [by_prefix[x] for x in PUBLIC_PREFIXES], by_prefix[IAP_PREFIX]


def validate_target(token: str):
    _, app = req(token, f"/v1/apps/{APP_ID}")
    if ((app.get("data") or {}).get("attributes") or {}).get("bundleId") != BUNDLE_ID:
        raise RuntimeError("App/bundle mismatch")
    _, versions = req(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=100")
    if VERSION_ID not in {str(x.get("id")) for x in rows(versions)}:
        raise RuntimeError("Pinned App Store version is not owned by target app")


def ensure_screenshot_set(token: str, actions: list[str]) -> str:
    _, current = req(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200")
    matches = [x for x in rows(current) if (x.get("attributes") or {}).get("screenshotDisplayType") == DISPLAY_TYPE]
    if len(matches) > 1:
        raise RuntimeError("Multiple APP_IPHONE_67 screenshot sets found")
    if matches:
        return str(matches[0]["id"])
    payload = {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY_TYPE}, "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": LOCALIZATION_ID}}}}}
    _, created = req(token, "/v1/appScreenshotSets", "POST", payload)
    actions.append("created_app_iphone_67_set")
    return str(created["data"]["id"])


def ensure_public_screenshots(token: str, set_id: str, files: list[Path], actions: list[str]) -> list[str]:
    _, current = req(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
    existing = rows(current)
    desired_names = [f"otsu4-{i+1:02d}.png" for i in range(len(files))]
    if existing:
        names = [(x.get("attributes") or {}).get("fileName") for x in existing]
        states = [asset_state(x) for x in existing]
        if names == desired_names and all(x == "COMPLETE" for x in states):
            return [str(x["id"]) for x in existing]
        raise RuntimeError(f"Refusing to replace unknown/incomplete existing App Store screenshots: names={names}, states={states}")

    ids = []
    for idx, file_path in enumerate(files):
        name = desired_names[idx]
        payload = {"data": {"type": "appScreenshots", "attributes": {"fileSize": file_path.stat().st_size, "fileName": name}, "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}}
        _, created = req(token, "/v1/appScreenshots", "POST", payload)
        resource = created["data"]
        upload_parts(resource, file_path)
        commit_asset(token, "appScreenshots", str(resource["id"]), file_path, f"/v1/appScreenshots/{resource['id']}")
        ids.append(str(resource["id"]))
        actions.append(f"uploaded_public_{idx+1:02d}")

    req(token, f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots", "PATCH", {"data": [{"type": "appScreenshots", "id": x} for x in ids]})
    _, ordered = req(token, f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots?limit=200")
    if [str(x.get("id")) for x in rows(ordered)] != ids:
        raise RuntimeError("Public screenshot ordering read-back mismatch")
    return ids


def ensure_iap_screenshot(token: str, file_path: Path, actions: list[str]) -> str:
    status, current = req_allow_404(token, f"/v2/inAppPurchases/{IAP_ID}/appStoreReviewScreenshot")
    if status == 200 and current.get("data"):
        resource = current["data"]
        if asset_state(resource) == "COMPLETE":
            return str(resource["id"])
        raise RuntimeError(f"Existing IAP review screenshot is incomplete: {asset_state(resource)}")

    payload = {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "attributes": {"fileSize": file_path.stat().st_size, "fileName": "otsu4-premium-review.png"}, "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": IAP_ID}}}}}
    _, created = req(token, "/v1/inAppPurchaseAppStoreReviewScreenshots", "POST", payload)
    resource = created["data"]
    upload_parts(resource, file_path)
    commit_asset(token, "inAppPurchaseAppStoreReviewScreenshots", str(resource["id"]), file_path, f"/v1/inAppPurchaseAppStoreReviewScreenshots/{resource['id']}")
    actions.append("uploaded_iap_review_screenshot")
    return str(resource["id"])


def main():
    actions = []
    cleanup = None
    result = {"task_id": "APP2-007", "app_id": APP_ID, "bundle_id": BUNDLE_ID, "ok": False}
    try:
        public_files, iap_file = manifest_files()
        key_path, cleanup = load_private_key()
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        validate_target(token)
        set_id = ensure_screenshot_set(token, actions)
        screenshot_ids = ensure_public_screenshots(token, set_id, public_files, actions)
        iap_screenshot_id = ensure_iap_screenshot(token, iap_file, actions)

        _, final_public = req(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
        public_rows = rows(final_public)
        if len(public_rows) != 6 or not all(asset_state(x) == "COMPLETE" for x in public_rows):
            raise RuntimeError("Final public screenshot read-back failed")
        _, final_iap = req(token, f"/v2/inAppPurchases/{IAP_ID}?include=appStoreReviewScreenshot,versions")
        _, iap_version = req(token, f"/v1/inAppPurchaseVersions/{IAP_VERSION_ID}")
        result.update({
            "ok": True,
            "display_type": DISPLAY_TYPE,
            "screenshot_set_id": set_id,
            "public_screenshot_ids": screenshot_ids,
            "public_screenshot_count": 6,
            "iap_review_screenshot_id": iap_screenshot_id,
            "iap_parent_state": ((final_iap.get("data") or {}).get("attributes") or {}).get("state"),
            "iap_version_state": ((iap_version.get("data") or {}).get("attributes") or {}).get("state"),
            "actions": actions,
        })
    except Exception as exc:
        result["error"] = str(exc)
        raise
    finally:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        if cleanup:
            try: cleanup.unlink(missing_ok=True)
            except Exception: pass


if __name__ == "__main__":
    main()
