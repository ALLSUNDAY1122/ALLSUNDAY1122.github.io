#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
TARGET_VERSION = "1.0"
TARGET_BUILD = "5"
SUBMITTED_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}


def one(payload: object, label: str) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"Missing {label}")
    return payload["data"]


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict): return []
    data = payload.get("data", [])
    return data if isinstance(data, list) else ([] if data is None else [data])


def state(resource: dict) -> str | None:
    attrs = resource.get("attributes") or {}
    return attrs.get("state") or attrs.get("appStoreState") or attrs.get("appVersionState")


def request_ok(token: str, path: str, method: str, payload: dict) -> dict:
    status, response = api_request(token, path, method=method, payload=payload)
    if not 200 <= status < 300: raise RuntimeError(f"ASC {method} {path} returned HTTP {status}")
    return response


def main() -> None:
    output = Path(os.environ.get("PHARMACIST_SUBMIT_OUTPUT", "/tmp/app2-004-yakuzaishi-submit-result.json"))
    result = {"task_id":"APP2-004","completed_at":datetime.now(timezone.utc).isoformat(),"app_id":APP_ID,"bundle_id":BUNDLE_ID,"version":TARGET_VERSION,"build":TARGET_BUILD,"submitted":False}
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, app_payload = api_get(token, f"/v1/apps/{APP_ID}")
        app = one(app_payload, "app")
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID: raise RuntimeError("Target app mismatch")

        _, versions_payload = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
        versions = [x for x in many(versions_payload) if (x.get("attributes") or {}).get("platform") == "IOS" and (x.get("attributes") or {}).get("versionString") == TARGET_VERSION]
        if len(versions) != 1: raise RuntimeError("Target App Store version is not unique")
        version = versions[0]; version_id = str(version["id"])
        if state(version) not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}: raise RuntimeError(f"Unexpected version state: {state(version)}")

        _, build_rel = api_get(token, f"/v1/appStoreVersions/{version_id}/build")
        build = one(build_rel, "selected build")
        attrs = build.get("attributes") or {}
        if str(attrs.get("version")) != TARGET_BUILD or attrs.get("processingState") != "VALID":
            raise RuntimeError(f"Selected build is not VALID Build {TARGET_BUILD}: {attrs.get('version')} / {attrs.get('processingState')}")
        result["build_id"] = str(build["id"])

        _, locs_payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
        loc = next((x for x in many(locs_payload) if (x.get("attributes") or {}).get("locale") in {"ja","ja-JP"}), None)
        if not loc: raise RuntimeError("Japanese localization missing")
        la = loc.get("attributes") or {}
        if not la.get("description") or not la.get("keywords") or not la.get("supportUrl"): raise RuntimeError("Japanese metadata incomplete")
        loc_id = str(loc["id"])

        _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=200&include=appScreenshots")
        included = sets_payload.get("included", []) if isinstance(sets_payload, dict) else []
        complete = [x for x in included if x.get("type") == "appScreenshots" and (((x.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")) == "COMPLETE"]
        if not complete: raise RuntimeError("No COMPLETE App Store screenshot")
        result["complete_screenshots"] = len(complete)

        _, review_payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        review = one(review_payload, "review detail"); ra = review.get("attributes") or {}
        for key in ("contactFirstName","contactLastName","contactPhone","contactEmail","notes"):
            if not ra.get(key): raise RuntimeError(f"App Review detail missing {key}")
        if ra.get("demoAccountRequired") is True: raise RuntimeError("Demo account must not be required")

        _, submissions_payload = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200")
        submissions = many(submissions_payload)
        already = next((x for x in submissions if state(x) in SUBMITTED_STATES), None)
        if already:
            result.update({"submitted":True,"idempotent":True,"review_submission_id":str(already["id"]),"review_submission_state":state(already)})
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n",encoding="utf-8")
            return
        draft = next((x for x in submissions if state(x) == "READY_FOR_REVIEW"), None)
        if not draft: raise RuntimeError("READY_FOR_REVIEW submission draft missing")
        sid = str(draft["id"])
        _, items_payload = api_get(token, f"/v1/reviewSubmissions/{sid}/items?limit=200")
        has_version = any((((x.get("relationships") or {}).get("appStoreVersion") or {}).get("data") or {}).get("id") == version_id for x in many(items_payload))
        if not has_version: raise RuntimeError("Review Submission does not contain target App Store version")

        payload = {"data":{"type":"reviewSubmissions","id":sid,"attributes":{"submitted":True}}}
        request_ok(token, f"/v1/reviewSubmissions/{sid}", "PATCH", payload)
        _, after_payload = api_get(token, f"/v1/reviewSubmissions/{sid}")
        after = one(after_payload, "review submission after submit"); after_state = state(after)
        if after_state not in SUBMITTED_STATES: raise RuntimeError(f"Unexpected state after submit: {after_state}")
        result.update({"submitted":True,"idempotent":False,"review_submission_id":sid,"review_submission_state":after_state})
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n",encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    except Exception as exc:
        result["error"] = str(exc)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n",encoding="utf-8")
        raise
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
