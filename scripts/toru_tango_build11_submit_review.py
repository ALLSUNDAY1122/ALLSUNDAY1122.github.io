#!/usr/bin/env python3
"""Submit 撮る単語帳 Build 11 to App Review after strict preflight.

This helper is hard-bound to App 6795968222 / version 1.0 / Build 11.
It may attach Build 11 and submit it for App Review, but it never releases the app.
The version is forced to MANUAL release before submission.
"""
from __future__ import annotations

import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6795968222"
BUNDLE_ID = "com.allsunday1122.torutango"
VERSION = "1.0"
BUILD = "11"


def data_dict(response: object, label: str) -> dict:
    if not isinstance(response, dict) or not isinstance(response.get("data"), dict):
        raise RuntimeError(f"Missing {label} resource")
    return response["data"]


def list_data(response: object) -> list[dict]:
    if not isinstance(response, dict):
        return []
    rows = response.get("data") or []
    return rows if isinstance(rows, list) else []


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="toru-tango-build11-submit-result.json")
    parser.add_argument("--wait-seconds", type=int, default=1500)
    args = parser.parse_args()
    output = Path(args.output)

    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect API credentials")

    result = {
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "version": VERSION,
        "build": BUILD,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "submitted": False,
        "release_performed": False,
    }

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)

        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        app = data_dict(app_response, "app")
        if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app preflight failed: bundle ID mismatch")

        deadline = time.time() + max(0, args.wait_seconds)
        selected_build = None
        while True:
            _, builds_response = api_get(token, f"/v1/apps/{APP_ID}/builds?sort=-uploadedDate&limit=100")
            for build in list_data(builds_response):
                attrs = build.get("attributes") or {}
                if str(attrs.get("version")) != BUILD:
                    continue
                result["apple_build_processing_state"] = attrs.get("processingState")
                result["apple_build_expired"] = attrs.get("expired")
                if attrs.get("processingState") == "VALID" and not attrs.get("expired", False):
                    selected_build = build
                    break
            if selected_build is not None:
                break
            if time.time() >= deadline:
                raise RuntimeError("Apple Build 11 did not reach VALID before timeout")
            time.sleep(20)

        build_id = selected_build["id"]
        result["build_id"] = build_id

        _, versions_response = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=100")
        version = next(
            (
                v
                for v in list_data(versions_response)
                if (v.get("attributes") or {}).get("versionString") == VERSION
                and (v.get("attributes") or {}).get("platform") == "IOS"
            ),
            None,
        )
        if version is None:
            raise RuntimeError("App Store Version 1.0 not found")
        version_id = version["id"]
        result["version_id"] = version_id
        attrs = version.get("attributes") or {}
        state = attrs.get("appStoreState") or attrs.get("appVersionState")
        result["pre_submit_version_state"] = state

        if state in {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "READY_FOR_SALE", "PROCESSING_FOR_DISTRIBUTION"}:
            result.update({"submitted": True, "idempotent": True, "review_submission_state": state})
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"PASS: version already beyond submission; state={state}")
            return
        if state not in {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}:
            raise RuntimeError(f"Version state not submittable: {state}")

        if attrs.get("releaseType") != "MANUAL":
            patch = {
                "data": {
                    "type": "appStoreVersions",
                    "id": version_id,
                    "attributes": {"releaseType": "MANUAL"},
                }
            }
            api_request(token, f"/v1/appStoreVersions/{version_id}", method="PATCH", payload=patch)
            _, version_readback = api_get(token, f"/v1/appStoreVersions/{version_id}")
            readback_attrs = data_dict(version_readback, "version readback").get("attributes") or {}
            if readback_attrs.get("releaseType") != "MANUAL":
                raise RuntimeError("Could not enforce MANUAL release type")
        result["release_type"] = "MANUAL"

        attach = {"data": {"type": "builds", "id": build_id}}
        api_request(token, f"/v1/appStoreVersions/{version_id}/relationships/build", method="PATCH", payload=attach)
        _, build_rel = api_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
        attached_build = (build_rel.get("data") or {}).get("id") if isinstance(build_rel, dict) else None
        if attached_build != build_id:
            raise RuntimeError(f"Build 11 attach readback mismatch: {attached_build}")
        result["build_attached"] = True

        _, loc_response = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=100")
        locs = list_data(loc_response)
        loc = next((x for x in locs if (x.get("attributes") or {}).get("locale") == "ja-JP"), locs[0] if locs else None)
        if loc is None:
            raise RuntimeError("Version localization missing")
        loc_id = loc["id"]
        result["localization_id"] = loc_id
        loc_attrs = loc.get("attributes") or {}
        missing_localization = [k for k in ("description", "keywords", "supportUrl") if not loc_attrs.get(k)]
        if missing_localization:
            raise RuntimeError(f"Version localization incomplete: {missing_localization}")

        _, sets_response = api_get(token, f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=200&include=appScreenshots")
        sets = list_data(sets_response)
        included = sets_response.get("included") if isinstance(sets_response, dict) else []
        complete_screenshot_count = 0
        for item in included or []:
            if item.get("type") != "appScreenshots":
                continue
            delivery = ((item.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")
            if delivery == "COMPLETE":
                complete_screenshot_count += 1
        if not sets or complete_screenshot_count < 1:
            raise RuntimeError("Required App Store screenshot is not COMPLETE")
        result["complete_screenshot_count"] = complete_screenshot_count

        _, review_response = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        review_detail = data_dict(review_response, "review detail")
        review_attrs = review_detail.get("attributes") or {}
        required_review = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail", "notes")
        missing_review = [k for k in required_review if not review_attrs.get(k)]
        if missing_review:
            raise RuntimeError(f"App Review contact/notes incomplete: {missing_review}")
        result["review_detail_complete"] = True

        _, submissions_response = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200&include=items,appStoreVersionForReview")
        submissions = list_data(submissions_response)
        active_states = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"}
        active = [s for s in submissions if (s.get("attributes") or {}).get("state") in active_states]

        already = next(
            (s for s in active if (s.get("attributes") or {}).get("state") in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}),
            None,
        )
        if already is not None:
            result.update({
                "submitted": True,
                "idempotent": True,
                "review_submission_id": already.get("id"),
                "review_submission_state": (already.get("attributes") or {}).get("state"),
            })
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print("PASS: 撮る単語帳 is already submitted for App Review")
            return

        draft = next((s for s in active if (s.get("attributes") or {}).get("state") == "READY_FOR_REVIEW"), None)
        if draft is None:
            create_payload = {
                "data": {
                    "type": "reviewSubmissions",
                    "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
                }
            }
            _, created = api_request(token, "/v1/reviewSubmissions", method="POST", payload=create_payload)
            draft = data_dict(created, "created review submission")

        submission_id = draft["id"]
        _, items_response = api_get(token, f"/v1/reviewSubmissions/{submission_id}/items?limit=100&include=appStoreVersion")
        version_attached = False
        for item in list_data(items_response):
            rel = (item.get("relationships") or {}).get("appStoreVersion") or {}
            if (rel.get("data") or {}).get("id") == version_id:
                version_attached = True
                break
        if not version_attached:
            item_payload = {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            }
            api_request(token, "/v1/reviewSubmissionItems", method="POST", payload=item_payload)

        submit_payload = {
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        }
        api_request(token, f"/v1/reviewSubmissions/{submission_id}", method="PATCH", payload=submit_payload)
        _, after_response = api_get(token, f"/v1/reviewSubmissions/{submission_id}")
        after = data_dict(after_response, "review submission readback")
        review_state = (after.get("attributes") or {}).get("state")
        if review_state not in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}:
            raise RuntimeError(f"Unexpected review submission state after submit: {review_state}")

        result.update({
            "submitted": True,
            "idempotent": False,
            "review_submission_id": submission_id,
            "review_submission_state": review_state,
        })
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: 撮る単語帳 submitted for App Review; state={review_state}; release remains manual")
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
