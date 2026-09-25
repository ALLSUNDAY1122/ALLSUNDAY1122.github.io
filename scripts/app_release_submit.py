#!/usr/bin/env python3
"""Common final App Store Review submitter.

This script intentionally owns only the final, generic boundary:
registry identity -> exact approval -> remote preflight -> review submission -> read-back.
App-specific metadata, screenshots, privacy, pricing and IAP preparation must already be complete.
"""
from __future__ import annotations

import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

REGISTRY = Path(os.environ.get("APP_RELEASE_REGISTRY", "automation/app-release-registry.json"))
SUBMITTED_STATES = {
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "COMPLETING",
    "PENDING_DEVELOPER_RELEASE",
    "PROCESSING_FOR_DISTRIBUTION",
    "READY_FOR_SALE",
}
DRAFT_STATE = "READY_FOR_REVIEW"
REVIEWABLE_VERSION_STATES = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"} | SUBMITTED_STATES


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", [])
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [data]
    return []


def one(payload: object, label: str) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"Missing {label}")
    return payload["data"]


def attrs(resource: dict | None) -> dict:
    return (resource or {}).get("attributes") or {}


def state(resource: dict | None) -> str | None:
    a = attrs(resource)
    return a.get("state") or a.get("appStoreState") or a.get("appVersionState")


def request_ok(token: str, path: str, method: str, payload: dict) -> dict:
    status, response = api_request(token, path, method=method, payload=payload)
    if not 200 <= status < 300:
        raise RuntimeError(f"ASC {method} {path} returned HTTP {status}")
    return response if isinstance(response, dict) else {}


def patch(token: str, path: str, typ: str, rid: str, attributes: dict) -> dict:
    return request_ok(token, path, "PATCH", {"data": {"type": typ, "id": rid, "attributes": attributes}})


def load_command(path: Path) -> dict:
    command = json.loads(path.read_text(encoding="utf-8"))
    if command.get("approved") is not True:
        raise RuntimeError("FINAL_APPROVAL missing: command.approved must be true")
    for key in ("request_id", "app_key", "version", "build", "approval_scope"):
        if not command.get(key):
            raise RuntimeError(f"Missing command field: {key}")
    if not isinstance(command["approval_scope"], dict):
        raise RuntimeError("approval_scope must be an object")
    return command


def load_target(command: dict) -> tuple[str, dict]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    app_key = str(command["app_key"])
    app = (registry.get("apps") or {}).get(app_key)
    if not isinstance(app, dict):
        raise RuntimeError(f"Unknown app_key: {app_key}")
    app_id = str(app.get("app_id") or "")
    bundle_id = str(app.get("bundle_id") or "")
    if not app_id or not app_id.isdigit():
        raise RuntimeError(f"{app_key}: APPLE_ID_PENDING; final submission is not available")
    if not bundle_id:
        raise RuntimeError(f"{app_key}: bundle_id missing from registry")

    scope = command["approval_scope"]
    expected = {
        "app_id": app_id,
        "bundle_id": bundle_id,
        "version": str(command["version"]),
        "build": str(command["build"]),
    }
    actual = {k: str(scope.get(k) or "") for k in expected}
    if actual != expected:
        raise RuntimeError(f"FINAL_APPROVAL scope mismatch: expected={expected} actual={actual}")
    return app_key, app


def resolve_version(token: str, app_id: str, version_string: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{app_id}/appStoreVersions?limit=100")
    rows = [
        x for x in many(payload)
        if attrs(x).get("platform") == "IOS" and str(attrs(x).get("versionString")) == version_string
    ]
    if len(rows) != 1:
        raise RuntimeError(f"Expected exactly one iOS version {version_string}; found {[(x.get('id'), state(x)) for x in rows]}")
    if state(rows[0]) not in REVIEWABLE_VERSION_STATES:
        raise RuntimeError(f"Version is not reviewable: {state(rows[0])}")
    return rows[0]


def resolve_build(token: str, app_id: str, build_number: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{app_id}/builds?limit=200")
    rows = [x for x in many(payload) if str(attrs(x).get("version")) == build_number]
    valid = [x for x in rows if attrs(x).get("processingState") == "VALID" and not attrs(x).get("expired")]
    if len(valid) != 1:
        raise RuntimeError(
            f"Expected exactly one VALID non-expired build {build_number}; "
            f"found {[(x.get('id'), attrs(x).get('processingState'), attrs(x).get('expired')) for x in rows]}"
        )
    return valid[0]


def selected_build_id(token: str, version_id: str) -> str | None:
    _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
    data = payload.get("data") if isinstance(payload, dict) else None
    return str(data.get("id")) if isinstance(data, dict) and data.get("id") else None


def review_detail_exists(token: str, version_id: str) -> bool:
    try:
        _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        data = payload.get("data") if isinstance(payload, dict) else None
        return isinstance(data, dict) and bool(data.get("id"))
    except Exception:
        return False


def submission_items(token: str, submission_id: str) -> tuple[list[dict], list[dict]]:
    _, payload = api_get(
        token,
        f"/v1/reviewSubmissions/{submission_id}/items?limit=200&include=appStoreVersion,inAppPurchaseVersion,subscriptionVersion,subscriptionGroupVersion",
    )
    items = many(payload)
    included = payload.get("included", []) if isinstance(payload, dict) else []
    return items, included if isinstance(included, list) else []


def has_version_item(token: str, submission_id: str, version_id: str) -> bool:
    _, included = submission_items(token, submission_id)
    return any(x.get("type") == "appStoreVersions" and str(x.get("id")) == version_id for x in included)


def ensure_version_item(token: str, submission_id: str, version_id: str) -> None:
    if has_version_item(token, submission_id, version_id):
        return
    body = {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
            },
        }
    }
    request_ok(token, "/v1/reviewSubmissionItems", "POST", body)
    if not has_version_item(token, submission_id, version_id):
        raise RuntimeError("Review submission item read-back failed for target appStoreVersion")


def resolve_submission(token: str, app_id: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{app_id}/reviewSubmissions?limit=200")
    rows = many(payload)
    submitted = [x for x in rows if state(x) in SUBMITTED_STATES]
    if submitted:
        return submitted[0]
    drafts = [x for x in rows if state(x) == DRAFT_STATE]
    if drafts:
        return drafts[0]
    blocking = [x for x in rows if state(x) not in {None, "CANCELED", "COMPLETE"}]
    if blocking:
        raise RuntimeError(f"Existing review submission requires app-specific resolution: {[(x.get('id'), state(x)) for x in blocking]}")
    body = {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    return one(request_ok(token, "/v1/reviewSubmissions", "POST", body), "created review submission")


def wait_submitted(token: str, submission_id: str, timeout: int = 90) -> dict:
    deadline = time.time() + timeout
    last: dict | None = None
    while time.time() < deadline:
        _, payload = api_get(token, f"/v1/reviewSubmissions/{submission_id}")
        last = one(payload, "review submission read-back")
        if state(last) in SUBMITTED_STATES:
            return last
        time.sleep(5)
    raise RuntimeError(f"Submission did not reach submitted state; last_state={state(last)}")


def write_result(path: Path, result: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", default="automation/app-release-submit-command.json")
    parser.add_argument("--output", default="automation/asc-results/app-release-submit-last-result.json")
    args = parser.parse_args()
    command_path = Path(args.command)
    output = Path(args.output)

    command = load_command(command_path)
    app_key, app_cfg = load_target(command)
    app_id = str(app_cfg["app_id"])
    bundle_id = str(app_cfg["bundle_id"])
    version_string = str(command["version"])
    build_number = str(command["build"])
    result: dict = {
        "request_id": str(command["request_id"]),
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_key": app_key,
        "app2_task": app_cfg.get("app2_task"),
        "app_id": app_id,
        "bundle_id": bundle_id,
        "version": version_string,
        "build": build_number,
        "submitted": False,
        "stage": "SUBMISSION_PREFLIGHT",
    }

    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        app = one(api_get(token, f"/v1/apps/{app_id}")[1], "app")
        remote_bundle = str(attrs(app).get("bundleId") or "")
        if remote_bundle != bundle_id:
            raise RuntimeError(f"App identity mismatch: registry={bundle_id} remote={remote_bundle}")

        version = resolve_version(token, app_id, version_string)
        version_id = str(version["id"])
        build = resolve_build(token, app_id, build_number)
        build_id = str(build["id"])
        selected = selected_build_id(token, version_id)
        if selected != build_id:
            raise RuntimeError(f"Selected build mismatch: expected={build_id} selected={selected}")
        if not review_detail_exists(token, version_id):
            raise RuntimeError("App Review Detail is missing; app-specific preflight is incomplete")

        result.update({
            "version_id": version_id,
            "version_state_before": state(version),
            "build_id": build_id,
            "build_processing_state": attrs(build).get("processingState"),
            "build_expired": attrs(build).get("expired"),
            "selected_build_id": selected,
            "stage": "SUBMISSION_READY",
        })

        submission = resolve_submission(token, app_id)
        submission_id = str(submission["id"])
        before = state(submission)
        result.update({"review_submission_id": submission_id, "review_submission_state_before": before})

        if before in SUBMITTED_STATES:
            if not has_version_item(token, submission_id, version_id):
                raise RuntimeError("Existing submitted reviewSubmission does not contain the approved appStoreVersion")
            after = submission
            idempotent = True
        else:
            ensure_version_item(token, submission_id, version_id)
            result["stage"] = "SUBMITTING"
            patch(token, f"/v1/reviewSubmissions/{submission_id}", "reviewSubmissions", submission_id, {"submitted": True})
            after = wait_submitted(token, submission_id)
            idempotent = False

        after_state = state(after)
        final_version = one(api_get(token, f"/v1/appStoreVersions/{version_id}")[1], "version after submit")
        final_selected = selected_build_id(token, version_id)
        if final_selected != build_id:
            raise RuntimeError(f"Post-submit selected build mismatch: expected={build_id} selected={final_selected}")
        if after_state not in SUBMITTED_STATES:
            raise RuntimeError(f"Unexpected review state after submit: {after_state}")

        result.update({
            "submitted": True,
            "idempotent": idempotent,
            "stage": after_state,
            "review_submission_state": after_state,
            "app_store_version_state_after": state(final_version),
            "selected_build_id_after": final_selected,
        })
        write_result(output, result)
        print(f"PASS: {app_key} App Review submitted; state={after_state}; request_id={command['request_id']}")
    except Exception as exc:
        result.update({"submitted": False, "stage": result.get("stage") or "UNKNOWN", "error": str(exc)})
        write_result(output, result)
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
