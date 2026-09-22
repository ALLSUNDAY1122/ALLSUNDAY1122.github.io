#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6795968222"
BUNDLE_ID = "com.allsunday1122.torutango"
VERSION = "1.0"
BUILD = "11"
SUPPORT_URL = "https://allsunday1122.github.io/toru-tango/"
PRIVACY_URL = "https://allsunday1122.github.io/toru-tango/privacy-policy.html"
DESCRIPTION = "写真や入力から自分だけの単語カードを作り、フォルダごとに整理して繰り返し学習できる単語帳アプリです。カードの表裏表示、読み上げ、自動めくり、学習記録に対応しています。"
KEYWORDS = "単語帳,暗記,学習,英単語,カード,写真,勉強,復習,読み上げ,記録"
REVIEW_NOTES = "撮る単語帳の審査用情報です。アカウント登録やログインは不要です。起動後、フォルダ作成・カード作成・学習・学習記録を確認できます。学習データは端末内に保存されます。"


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data")
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [data]
    return []


def one(payload: object, label: str) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"Missing {label}")
    return payload["data"]


def state(resource: dict) -> str | None:
    attrs = resource.get("attributes") or {}
    return attrs.get("state") or attrs.get("appStoreState") or attrs.get("appVersionState")


def request_ok(token: str, path: str, method: str = "GET", payload: dict | None = None) -> dict:
    status, response = api_request(token, path, method=method, payload=payload)
    if not 200 <= status < 300:
        raise RuntimeError(f"ASC {method} {path} returned HTTP {status}")
    return response if isinstance(response, dict) else {}


def patch(token: str, path: str, typ: str, rid: str, *, attributes=None, relationships=None) -> None:
    data: dict = {"type": typ, "id": rid}
    if attributes is not None:
        data["attributes"] = attributes
    if relationships is not None:
        data["relationships"] = relationships
    request_ok(token, path, "PATCH", {"data": data})


def png_size(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"Screenshot is not PNG: {path.name}")
    return struct.unpack(">II", raw[16:24])


def display_type_for(path: Path) -> str:
    size = png_size(path)
    mapping = {
        (1320, 2868): "APP_IPHONE_69",
        (1290, 2796): "APP_IPHONE_67",
        (1284, 2778): "APP_IPHONE_65",
        (1242, 2688): "APP_IPHONE_65",
        (1260, 2736): "APP_IPHONE_67",
    }
    if size not in mapping:
        raise RuntimeError(f"Unsupported App Store screenshot dimensions: {size}")
    return mapping[size]


def upload_ops(operations: list[dict], raw: bytes) -> None:
    if not operations:
        raise RuntimeError("Screenshot reservation returned no upload operations")
    for op in operations:
        offset = int(op.get("offset", 0))
        length = int(op.get("length", len(raw) - offset))
        chunk = raw[offset : offset + length]
        req = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        headers = op.get("requestHeaders") or []
        if isinstance(headers, dict):
            headers = [{"name": k, "value": v} for k, v in headers.items()]
        for header in headers:
            req.add_header(str(header["name"]), str(header["value"]))
        with urllib.request.urlopen(req, timeout=120) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(f"Screenshot upload failed HTTP {response.status}")


def wait_asset(token: str, screenshot_id: str, timeout: int = 240) -> str:
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        _, payload = api_get(token, f"/v1/appScreenshots/{screenshot_id}")
        item = one(payload, "app screenshot")
        last = (((item.get("attributes") or {}).get("assetDeliveryState") or {}).get("state"))
        if last == "COMPLETE":
            return last
        if last == "FAILED":
            raise RuntimeError(f"Screenshot processing failed: {screenshot_id}")
        time.sleep(5)
    raise RuntimeError(f"Screenshot did not reach COMPLETE; state={last}")


def resolve_version(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=100")
    matches = [
        row for row in many(payload)
        if (row.get("attributes") or {}).get("platform") == "IOS"
        and (row.get("attributes") or {}).get("versionString") == VERSION
    ]
    if len(matches) != 1:
        raise RuntimeError(f"Expected exactly one iOS version {VERSION}; found={len(matches)}")
    return matches[0]


def resolve_localization(token: str, version_id: str) -> dict:
    _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=100")
    rows = many(payload)
    loc = next((x for x in rows if (x.get("attributes") or {}).get("locale") in {"ja-JP", "ja"}), None)
    if not loc:
        raise RuntimeError("Japanese App Store localization missing")
    return loc


def ensure_metadata(token: str, version: dict, loc: dict, result: dict) -> None:
    version_id = str(version["id"])
    loc_id = str(loc["id"])
    vattrs = version.get("attributes") or {}
    if vattrs.get("releaseType") != "MANUAL":
        patch(token, f"/v1/appStoreVersions/{version_id}", "appStoreVersions", version_id, attributes={"releaseType": "MANUAL"})
    result["release_type"] = "MANUAL"

    lattrs = loc.get("attributes") or {}
    loc_patch = {}
    if not lattrs.get("description"):
        loc_patch["description"] = DESCRIPTION
    if not lattrs.get("keywords"):
        loc_patch["keywords"] = KEYWORDS
    if not lattrs.get("supportUrl"):
        loc_patch["supportUrl"] = SUPPORT_URL
    if loc_patch:
        patch(token, f"/v1/appStoreVersionLocalizations/{loc_id}", "appStoreVersionLocalizations", loc_id, attributes=loc_patch)
    result["localization_complete"] = True

    _, infos_payload = api_get(token, f"/v1/apps/{APP_ID}/appInfos?limit=20")
    infos = many(infos_payload)
    if infos:
        info_id = str(infos[0]["id"])
        _, info_locs_payload = api_get(token, f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=100")
        info_locs = many(info_locs_payload)
        info_loc = next((x for x in info_locs if (x.get("attributes") or {}).get("locale") in {"ja-JP", "ja"}), info_locs[0] if info_locs else None)
        if info_loc:
            attrs = info_loc.get("attributes") or {}
            if not attrs.get("privacyPolicyUrl"):
                patch(token, f"/v1/appInfoLocalizations/{info_loc['id']}", "appInfoLocalizations", str(info_loc["id"]), attributes={"privacyPolicyUrl": PRIVACY_URL})
            result["privacy_policy_url"] = PRIVACY_URL


def ensure_review_detail(token: str, version_id: str, result: dict) -> None:
    detail = None
    current: dict = {}
    try:
        _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        detail = one(payload, "review detail")
        current = detail.get("attributes") or {}
    except Exception:
        detail = None

    keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
    contact = {k: current.get(k) for k in keys}
    if not all(contact.values()):
        try:
            _, beta_payload = api_get(token, f"/v1/apps/{APP_ID}/betaAppReviewDetail")
            beta = one(beta_payload, "beta review detail").get("attributes") or {}
            for key in keys:
                contact[key] = contact.get(key) or beta.get(key)
        except Exception:
            pass
    if not all(contact.values()):
        missing = [k for k, v in contact.items() if not v]
        raise RuntimeError(f"App Review contact data incomplete: {missing}")

    attrs = {
        **contact,
        "demoAccountRequired": False,
        "notes": current.get("notes") or REVIEW_NOTES,
    }
    if detail:
        rid = str(detail["id"])
        patch(token, f"/v1/appStoreReviewDetails/{rid}", "appStoreReviewDetails", rid, attributes=attrs)
        result["review_detail_id"] = rid
    else:
        payload = {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": attrs,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }
        }
        created = one(request_ok(token, "/v1/appStoreReviewDetails", "POST", payload), "created review detail")
        result["review_detail_id"] = str(created["id"])
    result["review_detail_complete"] = True


def resolve_build(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/builds?limit=100")
    matching = []
    for row in many(payload):
        attrs = row.get("attributes") or {}
        if str(attrs.get("version")) == BUILD:
            matching.append(row)
    if not matching:
        raise RuntimeError("Apple Build 11 not found")
    valid = next((x for x in matching if (x.get("attributes") or {}).get("processingState") == "VALID" and not (x.get("attributes") or {}).get("expired", False)), None)
    if not valid:
        states = [(x.get("id"), (x.get("attributes") or {}).get("processingState"), (x.get("attributes") or {}).get("expired")) for x in matching]
        raise RuntimeError(f"Apple Build 11 is not VALID: {states}")
    return valid


def attach_build(token: str, version_id: str, build_id: str) -> None:
    patch(token, f"/v1/appStoreVersions/{version_id}", "appStoreVersions", version_id, relationships={"build": {"data": {"type": "builds", "id": build_id}}})
    _, rel = api_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
    attached = ((rel or {}).get("data") or {}).get("id") if isinstance(rel, dict) else None
    if attached != build_id:
        raise RuntimeError(f"Build attach readback mismatch: {attached} != {build_id}")


def complete_screenshots(token: str, localization_id: str) -> list[dict]:
    _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200")
    complete: list[dict] = []
    for screenshot_set in many(sets_payload):
        set_id = str(screenshot_set["id"])
        display_type = (screenshot_set.get("attributes") or {}).get("screenshotDisplayType")
        _, shots_payload = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
        for shot in many(shots_payload):
            delivery = ((shot.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")
            if delivery == "COMPLETE":
                complete.append({"id": str(shot["id"]), "set_id": set_id, "display_type": display_type})
    return complete


def ensure_screenshots(token: str, localization_id: str, screen_dir: Path, result: dict) -> None:
    existing = complete_screenshots(token, localization_id)
    if existing:
        result["complete_screenshot_count"] = len(existing)
        result["screenshots_uploaded_new"] = 0
        return

    images = sorted(screen_dir.glob("*.png"))
    if not images:
        raise RuntimeError(f"No PNG screenshots found in {screen_dir}")

    uploaded = 0
    for image in images:
        display_type = display_type_for(image)
        _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200")
        screenshot_set = next((x for x in many(sets_payload) if (x.get("attributes") or {}).get("screenshotDisplayType") == display_type), None)
        if screenshot_set is None:
            payload = {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": localization_id}}},
                }
            }
            screenshot_set = one(request_ok(token, "/v1/appScreenshotSets", "POST", payload), "created screenshot set")
        set_id = str(screenshot_set["id"])

        raw = image.read_bytes()
        checksum = hashlib.md5(raw).hexdigest()
        reserve_payload = {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileSize": len(raw), "fileName": image.name},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
            }
        }
        reserved = one(request_ok(token, "/v1/appScreenshots", "POST", reserve_payload), "reserved screenshot")
        screenshot_id = str(reserved["id"])
        upload_ops((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
        patch(token, f"/v1/appScreenshots/{screenshot_id}", "appScreenshots", screenshot_id, attributes={"uploaded": True, "sourceFileChecksum": checksum})
        wait_asset(token, screenshot_id)
        uploaded += 1

    complete = complete_screenshots(token, localization_id)
    if not complete:
        raise RuntimeError("No App Store screenshot reached COMPLETE after upload")
    result["complete_screenshot_count"] = len(complete)
    result["screenshots_uploaded_new"] = uploaded


def ensure_submission(token: str, version_id: str, result: dict) -> None:
    _, submissions_payload = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200")
    submissions = many(submissions_payload)
    already = next((x for x in submissions if state(x) in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING", "PENDING_DEVELOPER_RELEASE", "READY_FOR_SALE"}), None)
    if already:
        result["submitted"] = True
        result["idempotent"] = True
        result["review_submission_id"] = str(already["id"])
        result["review_submission_state"] = state(already)
        return

    draft = next((x for x in submissions if state(x) == "READY_FOR_REVIEW"), None)
    if draft is None:
        payload = {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        }
        draft = one(request_ok(token, "/v1/reviewSubmissions", "POST", payload), "created review submission")
    submission_id = str(draft["id"])

    _, items_payload = api_get(token, f"/v1/reviewSubmissions/{submission_id}/items?limit=200&include=appStoreVersion")
    has_version = False
    for item in many(items_payload):
        rel = ((item.get("relationships") or {}).get("appStoreVersion") or {}).get("data") or {}
        if rel.get("id") == version_id:
            has_version = True
            break
    if not has_version:
        payload = {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                },
            }
        }
        request_ok(token, "/v1/reviewSubmissionItems", "POST", payload)

    submit_payload = {"data": {"type": "reviewSubmissions", "id": submission_id, "attributes": {"submitted": True}}}
    request_ok(token, f"/v1/reviewSubmissions/{submission_id}", "PATCH", submit_payload)

    deadline = time.time() + 120
    last = None
    while time.time() < deadline:
        _, after_payload = api_get(token, f"/v1/reviewSubmissions/{submission_id}")
        after = one(after_payload, "review submission readback")
        last = state(after)
        if last in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING", "PENDING_DEVELOPER_RELEASE", "READY_FOR_SALE"}:
            result["submitted"] = True
            result["idempotent"] = False
            result["review_submission_id"] = submission_id
            result["review_submission_state"] = last
            return
        time.sleep(5)
    raise RuntimeError(f"Review submission did not advance after submit; state={last}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screens", default="/tmp/toru-final-screens")
    parser.add_argument("--output", default="/tmp/toru-tango-final-submit-result.json")
    args = parser.parse_args()

    screen_dir = Path(args.screens)
    output = Path(args.output)
    result: dict = {
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "version": VERSION,
        "build": BUILD,
        "submitted": False,
        "release_performed": False,
        "completed_at": datetime.now(timezone.utc).isoformat(),
    }

    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, app_payload = api_get(token, f"/v1/apps/{APP_ID}")
        app = one(app_payload, "app")
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app bundle ID mismatch")

        version = resolve_version(token)
        version_id = str(version["id"])
        result["version_id"] = version_id
        result["pre_submit_version_state"] = state(version)

        if state(version) in {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "READY_FOR_SALE", "PROCESSING_FOR_DISTRIBUTION"}:
            result.update({"submitted": True, "idempotent": True, "review_submission_state": state(version), "release_type": (version.get("attributes") or {}).get("releaseType") or "MANUAL"})
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(result, ensure_ascii=False))
            return

        loc = resolve_localization(token, version_id)
        loc_id = str(loc["id"])
        result["localization_id"] = loc_id
        ensure_metadata(token, version, loc, result)
        ensure_review_detail(token, version_id, result)

        build = resolve_build(token)
        build_id = str(build["id"])
        result["build_id"] = build_id
        result["build_processing_state"] = (build.get("attributes") or {}).get("processingState")
        attach_build(token, version_id, build_id)
        result["build_attached"] = True

        ensure_screenshots(token, loc_id, screen_dir, result)
        ensure_submission(token, version_id, result)

        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    except Exception as exc:
        result["submitted"] = False
        result["error"] = str(exc)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
