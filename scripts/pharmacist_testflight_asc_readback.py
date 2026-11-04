#!/usr/bin/env python3
"""Read-only ASC/TestFlight readback for a specific pharmacist release window."""
from __future__ import annotations
import json, os, time
from datetime import datetime, timezone
from pathlib import Path
from app_store_connect_api import load_private_key, make_token
from app2_004_yakuzaishi_iap_bootstrap import request

COMMAND = Path("automation/pharmacist-testflight-asc-command.json")
RESULT = Path("automation/asc-results/pharmacist-testflight-readback.json")
APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"

def items(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])

def attrs(resource, keys):
    source = resource.get("attributes", {}) if isinstance(resource, dict) else {}
    return {k: source.get(k) for k in keys if k in source}

def parse_time(value):
    if not value:
        return None
    return datetime.fromisoformat(str(value).replace("Z", "+00:00")).astimezone(timezone.utc)

def read_once(token, command):
    _, app_payload = request(token, f"/v1/apps/{APP_ID}")
    app = app_payload["data"]
    if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
        raise RuntimeError("ASC app bundle ID mismatch")
    _, builds_payload = request(token, f"/v1/apps/{APP_ID}/builds?limit=200")
    builds = items(builds_payload)
    target_version = str(command.get("target_build") or "").strip()
    minimum = parse_time(command.get("minimum_uploaded_after"))
    candidates = []
    for build in builds:
        a = build.get("attributes", {})
        uploaded = parse_time(a.get("uploadedDate"))
        if target_version and str(a.get("version")) != target_version:
            continue
        if minimum and (uploaded is None or uploaded < minimum):
            continue
        candidates.append(build)
    target = max(candidates, key=lambda b: parse_time(b.get("attributes", {}).get("uploadedDate")) or datetime.min.replace(tzinfo=timezone.utc)) if candidates else None
    if not target:
        return {"ready": False, "reason": "matching_build_not_found", "candidate_count": len(candidates)}
    build_id = target["id"]
    a = target.get("attributes", {})
    if a.get("processingState") == "VALID" and a.get("buildAudienceType") != "INTERNAL_ONLY":
        return {
            "ready": False,
            "reason": "build_audience_is_not_internal_only",
            "result": {
                "request_id": command.get("request_id"),
                "read_only": True,
                "checked_at": datetime.now(timezone.utc).isoformat(),
                "app": {"id": APP_ID, "bundle_id": BUNDLE_ID},
                "build": {"id": build_id, "attributes": attrs(target, ["version", "uploadedDate", "processingState", "expired", "expirationDate", "minOsVersion", "buildAudienceType"])},
            }
        }
    _, beta_payload = request(token, f"/v1/builds/{build_id}/buildBetaDetail")
    beta = beta_payload["data"]
    beta_attrs = beta.get("attributes", {})
    # Use the build-to-betaGroups relationship directly rather than iterating
    # every app group and requesting each group's full build list.
    _, groups_payload = request(token, f"/v1/builds/{build_id}/betaGroups?limit=200")
    memberships = [
        {
            "id": group.get("id"),
            "attributes": attrs(group, ["name", "isInternalGroup", "hasAccessToAllBuilds", "publicLinkEnabled"])
        }
        for group in items(groups_payload)
    ]
    result = {
        "request_id": command.get("request_id"),
        "read_only": True,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "app": {"id": APP_ID, "bundle_id": BUNDLE_ID},
        "build": {"id": build_id, "attributes": attrs(target, ["version", "uploadedDate", "processingState", "expired", "expirationDate", "minOsVersion", "buildAudienceType"])},
        "buildBetaDetail": {"id": beta.get("id"), "attributes": attrs(beta, ["internalBuildState", "externalBuildState", "autoNotifyEnabled"])},
        "beta_group_memberships": memberships
    }
    internal = any(g.get("attributes", {}).get("isInternalGroup") for g in memberships)
    ready = a.get("processingState") == "VALID" and a.get("buildAudienceType") == "INTERNAL_ONLY" and beta_attrs.get("internalBuildState") == "IN_BETA_TESTING" and internal
    return {"ready": ready, "result": result, "reason": None if ready else "processing_or_internal_distribution_pending"}

def main():
    command = json.loads(COMMAND.read_text(encoding="utf-8"))
    if not command.get("request_id"):
        raise SystemExit("request_id missing")
    issuer, key_id = os.environ.get("ASC_ISSUER_ID"), os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("ASC credentials missing")
    key_path, cleanup = load_private_key()
    latest = None
    try:
        token = make_token(issuer, key_id, key_path)
        for attempt in range(36):
            latest = read_once(token, command)
            if latest.get("ready"):
                break
            if attempt < 35:
                time.sleep(10)
        RESULT.parent.mkdir(parents=True, exist_ok=True)
        payload = latest.get("result") or {
            "request_id": command.get("request_id"),
            "read_only": True,
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "ready": False,
            "reason": latest.get("reason"),
            "candidate_count": latest.get("candidate_count")
        }
        payload["ready"] = bool(latest.get("ready"))
        RESULT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(payload, ensure_ascii=False))
        if not latest.get("ready"):
            raise SystemExit("ASC build has not reached VALID / IN_BETA_TESTING / internal group membership")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
