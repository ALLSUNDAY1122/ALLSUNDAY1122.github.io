#!/usr/bin/env python3
"""Submit 卓 TAKU CALC 1.5.0 to App Review after strict preflight.

This helper is deliberately bound to APP2-011. It submits the review request but
never releases the app. Version 1.5.0 is configured for MANUAL release, so even
an approval remains pending developer release until a separate explicit action.
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794350490"
BUNDLE_ID = "com.koheimorita.takucalc"
VERSION_ID = "65ef287d-3ea2-42d6-a0df-32ff6d62c08c"
LOCALIZATION_ID = "c28c2619-d76f-4efd-b0d7-225f2a7e2069"
BUILD_ID = "e88d3687-830a-476c-8c5a-7d7b04a5027d"


def data_dict(response: object, label: str) -> dict:
    if not isinstance(response, dict) or not isinstance(response.get("data"), dict):
        raise RuntimeError(f"Missing {label} resource")
    return response["data"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="app2-011-submit-result.json")
    args = parser.parse_args()
    output = Path(args.output)

    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect API credentials")

    result = {
        "task": "APP2-011",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "version": "1.5.0",
        "build_id": BUILD_ID,
        "release_performed": False,
    }

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)

        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        app = data_dict(app_response, "app")
        if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app preflight failed")

        _, version_response = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        version = data_dict(version_response, "version")
        attrs = version.get("attributes", {})
        if attrs.get("versionString") != "1.5.0":
            raise RuntimeError("Target version preflight failed")
        if attrs.get("releaseType") != "MANUAL":
            raise RuntimeError(f"Refusing submission because releaseType is not MANUAL: {attrs.get('releaseType')}")
        result["pre_submit_version_state"] = attrs.get("appStoreState") or attrs.get("appVersionState")
        result["release_type"] = attrs.get("releaseType")

        _, build_rel = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
        selected_build = (build_rel.get("data") or {}).get("id") if isinstance(build_rel, dict) else None
        if selected_build != BUILD_ID:
            raise RuntimeError(f"Wrong build selected: {selected_build}")

        _, sets_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200&include=appScreenshots")
        sets = sets_response.get("data") if isinstance(sets_response, dict) else []
        included = sets_response.get("included") if isinstance(sets_response, dict) else []
        complete_screenshot_count = 0
        for item in included or []:
            if item.get("type") != "appScreenshots":
                continue
            state = (((item.get("attributes") or {}).get("assetDeliveryState") or {}).get("state"))
            if state == "COMPLETE":
                complete_screenshot_count += 1
        if not sets or complete_screenshot_count < 1:
            raise RuntimeError("Required App Store screenshot is not COMPLETE")
        result["complete_screenshot_count"] = complete_screenshot_count

        _, review_detail = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail")
        detail = data_dict(review_detail, "review detail")
        d = detail.get("attributes", {})
        required_review = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail", "notes")
        if not all(d.get(k) for k in required_review):
            raise RuntimeError("App Review contact/notes are incomplete")
        result["review_detail_complete"] = True

        _, submissions_response = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200&include=items,appStoreVersionForReview")
        submissions = submissions_response.get("data") if isinstance(submissions_response, dict) else []
        active_states = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"}
        active = [s for s in submissions or [] if (s.get("attributes") or {}).get("state") in active_states]

        already_submitted = [s for s in active if (s.get("attributes") or {}).get("state") in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}]
        if already_submitted:
            submission = already_submitted[0]
            result.update({
                "review_submission_id": submission.get("id"),
                "review_submission_state": (submission.get("attributes") or {}).get("state"),
                "submitted": True,
                "idempotent": True,
            })
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print("PASS: TAKU is already submitted for App Review")
            return

        draft = next((s for s in active if (s.get("attributes") or {}).get("state") == "READY_FOR_REVIEW"), None)
        if draft is None:
            create_submission = {
                "data": {
                    "type": "reviewSubmissions",
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": APP_ID}}
                    },
                }
            }
            _, created = api_request(token, "/v1/reviewSubmissions", method="POST", payload=create_submission)
            draft = data_dict(created, "created review submission")

        submission_id = draft["id"]
        _, items_response = api_get(token, f"/v1/reviewSubmissions/{submission_id}/items?limit=50&include=appStoreVersion")
        items = items_response.get("data") if isinstance(items_response, dict) else []
        version_attached = False
        for item in items or []:
            rel = (item.get("relationships") or {}).get("appStoreVersion") or {}
            if ((rel.get("data") or {}).get("id")) == VERSION_ID:
                version_attached = True
                break
        if not version_attached:
            item_payload = {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {
                            "data": {"type": "reviewSubmissions", "id": submission_id}
                        },
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": VERSION_ID}
                        },
                    },
                }
            }
            api_request(token, "/v1/reviewSubmissionItems", method="POST", payload=item_payload)

        # Explicitly submit for review. This does NOT release the version.
        submit_payload = {
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        }
        api_request(token, f"/v1/reviewSubmissions/{submission_id}", method="PATCH", payload=submit_payload)

        _, after = api_get(token, f"/v1/reviewSubmissions/{submission_id}")
        after_submission = data_dict(after, "review submission read-back")
        state = (after_submission.get("attributes") or {}).get("state")
        if state not in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}:
            raise RuntimeError(f"Unexpected review submission state after submit: {state}")

        result.update({
            "review_submission_id": submission_id,
            "review_submission_state": state,
            "submitted": True,
            "idempotent": False,
        })
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: TAKU submitted for App Review; state={state}; release remains manual")
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
