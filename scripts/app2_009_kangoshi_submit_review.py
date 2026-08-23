#!/usr/bin/env python3
"""Submit APP2-009 app version + first IAP/subscription together for App Review.

Hard-bound to 看護師国家試験 学びスプリント. This script performs strict
read-back preflight, selects a VALID build, creates/reuses current reviewable
IAP/subscription/group versions, adds all four items to one review submission,
and submits it. It never deletes products, changes prices, or revokes signing.
"""
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6801792293"
BUNDLE_ID = "jp.allsunday1122.kangoshi"
VERSION_ID = "394753bb-7066-4f35-b1a8-ac89c766eff8"
LOCALIZATION_ID = "8e284390-22f1-440b-bed1-766aec600b8a"
LIFETIME_ID = "6802961562"
MONTHLY_ID = "6802919444"
GROUP_ID = "22318786"

ACTIVE_SUBMISSION_STATES = {
    "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES",
    "CANCELING", "COMPLETING",
}
SUBMITTED_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}
REVIEWABLE_VERSION_STATES = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}


def one(payload: object, label: str) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"Missing {label}")
    return payload["data"]


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", [])
    return data if isinstance(data, list) else ([] if data is None else [data])


def state(resource: dict) -> str | None:
    return (resource.get("attributes") or {}).get("state")


def request_ok(token: str, path: str, method: str, payload: dict) -> dict:
    status, response = api_request(token, path, method=method, payload=payload)
    if not (200 <= status < 300):
        raise RuntimeError(f"ASC {method} {path} returned HTTP {status}")
    return response


def newest_valid_build(token: str) -> dict:
    query = f"filter[app]={APP_ID}&filter[processingState]=VALID&sort=-uploadedDate&limit=50"
    _, response = api_get(token, f"/v1/builds?{query}")
    builds = many(response)
    if not builds:
        raise RuntimeError("No VALID App Store Connect build exists for APP2-009")
    return builds[0]


def select_build(token: str, build_id: str) -> None:
    payload = {
        "data": {
            "type": "appStoreVersions",
            "id": VERSION_ID,
            "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
        }
    }
    request_ok(token, f"/v1/appStoreVersions/{VERSION_ID}", "PATCH", payload)
    _, rel = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
    selected = ((rel or {}).get("data") or {}).get("id") if isinstance(rel, dict) else None
    if selected != build_id:
        raise RuntimeError(f"Build selection read-back mismatch: {selected} != {build_id}")


def ensure_product_version(token: str, *, list_path: str, create_path: str, typ: str,
                           relationship_name: str, relationship_type: str, parent_id: str) -> dict:
    _, response = api_get(token, list_path)
    versions = many(response)
    reviewable = [v for v in versions if state(v) in REVIEWABLE_VERSION_STATES]
    if reviewable:
        reviewable.sort(key=lambda x: str((x.get("attributes") or {}).get("createdDate") or ""), reverse=True)
        return reviewable[0]
    already = [v for v in versions if state(v) in {"WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED", "ACCEPTED"}]
    if already:
        return already[0]
    payload = {
        "data": {
            "type": typ,
            "relationships": {
                relationship_name: {"data": {"type": relationship_type, "id": parent_id}}
            },
        }
    }
    created = one(request_ok(token, create_path, "POST", payload), f"created {typ}")
    if state(created) not in REVIEWABLE_VERSION_STATES:
        raise RuntimeError(f"New {typ} has unexpected state: {state(created)}")
    return created


def ensure_submission(token: str) -> dict:
    _, response = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200")
    active = [s for s in many(response) if state(s) in ACTIVE_SUBMISSION_STATES]
    submitted = [s for s in active if state(s) in SUBMITTED_STATES]
    if submitted:
        return submitted[0]
    draft = next((s for s in active if state(s) == "READY_FOR_REVIEW"), None)
    if draft:
        return draft
    payload = {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    }
    return one(request_ok(token, "/v1/reviewSubmissions", "POST", payload), "created review submission")


def ensure_item(token: str, submission_id: str, relationship_name: str, relationship_type: str, rid: str) -> None:
    _, response = api_get(token, f"/v1/reviewSubmissions/{submission_id}/items?limit=200")
    for item in many(response):
        rel = ((item.get("relationships") or {}).get(relationship_name) or {}).get("data") or {}
        if rel.get("id") == rid:
            return
    payload = {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                relationship_name: {"data": {"type": relationship_type, "id": rid}},
            },
        }
    }
    request_ok(token, "/v1/reviewSubmissionItems", "POST", payload)


def preflight_store_metadata(token: str) -> dict:
    _, loc_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}")
    loc = one(loc_response, "Japanese localization")
    la = loc.get("attributes") or {}
    if not la.get("description") or not la.get("keywords") or not la.get("supportUrl"):
        raise RuntimeError("App Store Japanese metadata is incomplete")

    _, sets_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200&include=appScreenshots")
    sets = many(sets_response)
    included = sets_response.get("included", []) if isinstance(sets_response, dict) else []
    complete_shots = [x for x in included if x.get("type") == "appScreenshots" and (((x.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")) == "COMPLETE"]
    if not sets or not complete_shots:
        raise RuntimeError("No COMPLETE App Store screenshot is available")

    _, review_response = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail")
    review = one(review_response, "App Review detail")
    ra = review.get("attributes") or {}
    required = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail", "notes")
    if not all(ra.get(k) for k in required):
        raise RuntimeError("App Review contact/notes are incomplete")
    return {"complete_screenshots": len(complete_shots), "review_detail_complete": True}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="app2-009-submit-review-result.json")
    args = parser.parse_args()
    result = {
        "task_id": "APP2-009",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "version_id": VERSION_ID,
        "release_performed": False,
    }

    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        app = one(app_response, "app")
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app mismatch")
        _, version_response = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        version = one(version_response, "app version")
        va = version.get("attributes") or {}
        if va.get("versionString") != "1.0":
            raise RuntimeError("Target app version mismatch")
        if (va.get("appStoreState") or va.get("appVersionState")) not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}:
            raise RuntimeError(f"Unexpected App Store version state: {va.get('appStoreState') or va.get('appVersionState')}")

        result.update(preflight_store_metadata(token))

        build = newest_valid_build(token)
        build_id = str(build["id"])
        ba = build.get("attributes") or {}
        select_build(token, build_id)
        result["build_id"] = build_id
        result["build_version"] = ba.get("version")
        result["build_uploaded_date"] = ba.get("uploadedDate")

        iap_version = ensure_product_version(
            token,
            list_path=f"/v2/inAppPurchases/{LIFETIME_ID}/versions?limit=50",
            create_path="/v1/inAppPurchaseVersions",
            typ="inAppPurchaseVersions",
            relationship_name="inAppPurchase",
            relationship_type="inAppPurchases",
            parent_id=LIFETIME_ID,
        )
        subscription_version = ensure_product_version(
            token,
            list_path=f"/v1/subscriptions/{MONTHLY_ID}/versions?limit=50",
            create_path="/v1/subscriptionVersions",
            typ="subscriptionVersions",
            relationship_name="subscription",
            relationship_type="subscriptions",
            parent_id=MONTHLY_ID,
        )
        group_version = ensure_product_version(
            token,
            list_path=f"/v1/subscriptionGroups/{GROUP_ID}/versions?limit=50",
            create_path="/v1/subscriptionGroupVersions",
            typ="subscriptionGroupVersions",
            relationship_name="subscriptionGroup",
            relationship_type="subscriptionGroups",
            parent_id=GROUP_ID,
        )
        result["iap_version"] = {"id": iap_version.get("id"), "state": state(iap_version)}
        result["subscription_version"] = {"id": subscription_version.get("id"), "state": state(subscription_version)}
        result["subscription_group_version"] = {"id": group_version.get("id"), "state": state(group_version)}

        submission = ensure_submission(token)
        submission_id = str(submission["id"])
        initial_state = state(submission)
        result["review_submission_id"] = submission_id
        result["pre_submit_state"] = initial_state
        if initial_state in SUBMITTED_STATES:
            result.update({"submitted": True, "idempotent": True, "review_submission_state": initial_state})
            Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            return

        ensure_item(token, submission_id, "appStoreVersion", "appStoreVersions", VERSION_ID)
        ensure_item(token, submission_id, "inAppPurchaseVersion", "inAppPurchaseVersions", str(iap_version["id"]))
        ensure_item(token, submission_id, "subscriptionVersion", "subscriptionVersions", str(subscription_version["id"]))
        ensure_item(token, submission_id, "subscriptionGroupVersion", "subscriptionGroupVersions", str(group_version["id"]))

        payload = {"data":{"type":"reviewSubmissions","id":submission_id,"attributes":{"submitted":True}}}
        request_ok(token, f"/v1/reviewSubmissions/{submission_id}", "PATCH", payload)
        _, after_response = api_get(token, f"/v1/reviewSubmissions/{submission_id}")
        after = one(after_response, "review submission after submit")
        after_state = state(after)
        if after_state not in SUBMITTED_STATES:
            raise RuntimeError(f"Unexpected submission state after submit: {after_state}")
        result.update({"submitted": True, "idempotent": False, "review_submission_state": after_state})
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: APP2-009 submitted with app + IAP + subscription; state={after_state}")
    except Exception as exc:
        result.update({"submitted": False, "error": str(exc)})
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
