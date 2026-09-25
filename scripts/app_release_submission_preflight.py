#!/usr/bin/env python3
"""Read-only final-submission preflight and exact approval-scope builder."""
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

REGISTRY = Path(os.environ.get("APP_RELEASE_REGISTRY", "automation/app-release-registry.json"))
OUT = Path(os.environ.get("APP_RELEASE_PREFLIGHT_RESULT", "automation/asc-results/app-release-preflight-last-result.json"))
REVIEWABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "READY_FOR_REVIEW",
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "PENDING_DEVELOPER_RELEASE",
    "PROCESSING_FOR_DISTRIBUTION",
    "READY_FOR_SALE",
}


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


def attrs(item: dict | None) -> dict:
    return (item or {}).get("attributes") or {}


def state(item: dict | None) -> str | None:
    a = attrs(item)
    return a.get("state") or a.get("appStoreState") or a.get("appVersionState")


def safe_get(token: str, path: str) -> tuple[bool, dict, str | None]:
    try:
        status, payload = api_get(token, path)
        if not 200 <= status < 300:
            return False, {}, f"HTTP {status}"
        return True, payload if isinstance(payload, dict) else {}, None
    except Exception as exc:
        return False, {}, str(exc)[:500]


def selected_build_id(token: str, version_id: str) -> str | None:
    ok, payload, _ = safe_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
    if not ok:
        return None
    data = payload.get("data")
    return str(data.get("id")) if isinstance(data, dict) and data.get("id") else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", required=True, dest="app_key")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--output", default=str(OUT))
    args = parser.parse_args()

    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    app = (registry.get("apps") or {}).get(args.app_key)
    if not isinstance(app, dict):
        raise SystemExit(f"Unknown app_key: {args.app_key}")
    app_id = str(app.get("app_id") or "")
    bundle_id = str(app.get("bundle_id") or "")

    result: dict = {
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "read_only": True,
        "app_key": args.app_key,
        "app2_task": app.get("app2_task"),
        "app_id": app_id or None,
        "bundle_id": bundle_id,
        "version": str(args.version),
        "build": str(args.build),
        "checks": {},
        "errors": [],
        "warnings": [],
        "submission_ready": False,
    }
    output = Path(args.output)

    if not app_id or not app_id.isdigit():
        result["errors"].append("APPLE_ID_PENDING")
        result["stage"] = "UNKNOWN"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise SystemExit("App Store Connect App ID is unresolved")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        remote_app = one(api_get(token, f"/v1/apps/{app_id}")[1], "app")
        remote_bundle = str(attrs(remote_app).get("bundleId") or "")
        identity_ok = remote_bundle == bundle_id
        result["checks"]["identity"] = {"ok": identity_ok, "remote_bundle_id": remote_bundle}
        if not identity_ok:
            result["errors"].append("APP_ID_BUNDLE_ID_MISMATCH")

        _, versions_payload = api_get(token, f"/v1/apps/{app_id}/appStoreVersions?limit=100")
        versions = [x for x in many(versions_payload) if attrs(x).get("platform") == "IOS" and str(attrs(x).get("versionString")) == str(args.version)]
        if len(versions) != 1:
            result["errors"].append("VERSION_NOT_UNIQUE")
            version = None
        else:
            version = versions[0]
        version_id = str((version or {}).get("id") or "")
        version_state = state(version)
        version_ok = bool(version_id) and version_state in REVIEWABLE_STATES
        result["checks"]["version"] = {"ok": version_ok, "version_id": version_id or None, "state": version_state}
        if not version_ok:
            result["errors"].append("VERSION_NOT_REVIEWABLE")

        _, builds_payload = api_get(token, f"/v1/apps/{app_id}/builds?limit=200")
        candidates = [x for x in many(builds_payload) if str(attrs(x).get("version")) == str(args.build)]
        valid = [x for x in candidates if attrs(x).get("processingState") == "VALID" and not attrs(x).get("expired")]
        build = valid[0] if len(valid) == 1 else None
        build_id = str((build or {}).get("id") or "")
        build_ok = bool(build_id)
        result["checks"]["build"] = {
            "ok": build_ok,
            "build_id": build_id or None,
            "matches": len(candidates),
            "valid_nonexpired_matches": len(valid),
        }
        if not build_ok:
            result["errors"].append("BUILD_NOT_VALID_UNIQUE")

        selected = selected_build_id(token, version_id) if version_id else None
        selection_ok = bool(build_id) and selected == build_id
        result["checks"]["selected_build"] = {"ok": selection_ok, "selected_build_id": selected}
        if not selection_ok:
            result["errors"].append("VERSION_BUILD_SELECTION_MISMATCH")

        review_detail_ok = False
        if version_id:
            ok, detail_payload, detail_error = safe_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
            detail = detail_payload.get("data") if isinstance(detail_payload, dict) else None
            review_detail_ok = ok and isinstance(detail, dict) and bool(detail.get("id"))
            result["checks"]["review_detail"] = {"ok": review_detail_ok, "error": detail_error}
        else:
            result["checks"]["review_detail"] = {"ok": False, "error": "version unresolved"}
        if not review_detail_ok:
            result["errors"].append("APP_REVIEW_DETAIL_MISSING")

        localization_ok = False
        screenshot_count = 0
        support_url = None
        if version_id:
            _, loc_payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
            ja = next((x for x in many(loc_payload) if attrs(x).get("locale") in {"ja", "ja-JP"}), None)
            if ja:
                localization_ok = True
                support_url = attrs(ja).get("supportUrl")
                loc_id = str(ja.get("id"))
                _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=200")
                for screenshot_set in many(sets_payload):
                    sid = str(screenshot_set.get("id") or "")
                    if not sid:
                        continue
                    ok, shots_payload, _ = safe_get(token, f"/v1/appScreenshotSets/{sid}/appScreenshots?limit=200")
                    if ok:
                        screenshot_count += len(many(shots_payload))
        result["checks"]["localization"] = {"ok": localization_ok, "support_url": support_url}
        result["checks"]["screenshots"] = {"ok": screenshot_count > 0, "count": screenshot_count}
        if not localization_ok:
            result["errors"].append("JA_LOCALIZATION_MISSING")
        if not support_url:
            result["errors"].append("SUPPORT_URL_MISSING")
        if screenshot_count <= 0:
            result["errors"].append("APP_STORE_SCREENSHOTS_MISSING")

        _, iap_payload = api_get(token, f"/v1/apps/{app_id}/inAppPurchasesV2?limit=100")
        _, group_payload = api_get(token, f"/v1/apps/{app_id}/subscriptionGroups?limit=100")
        iap_count = len(many(iap_payload))
        subscription_group_count = len(many(group_payload))
        result["checks"]["monetization"] = {
            "iap_count": iap_count,
            "subscription_group_count": subscription_group_count,
            "requires_app_specific_preflight": bool(iap_count or subscription_group_count),
        }
        if iap_count or subscription_group_count:
            result["warnings"].append("MONETIZATION_PRESENT_VERIFY_APP_SPECIFIC_IAP_PREFLIGHT")

        result["submission_ready"] = not result["errors"]
        result["stage"] = "SUBMISSION_READY" if result["submission_ready"] else "PREFLIGHT_BLOCKED"
        if result["submission_ready"]:
            result["approval_candidate"] = {
                "request_id": f"{args.app_key}-{args.version}-{args.build}-FINAL-APPROVAL",
                "approved": False,
                "app_key": args.app_key,
                "version": str(args.version),
                "build": str(args.build),
                "approval_scope": {
                    "app_id": app_id,
                    "bundle_id": bundle_id,
                    "version": str(args.version),
                    "build": str(args.build),
                },
            }

        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if result["errors"]:
            raise SystemExit("submission preflight blocked")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
