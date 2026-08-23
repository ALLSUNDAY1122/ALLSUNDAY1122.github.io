#!/usr/bin/env python3
import json
import os
import time
from pathlib import Path

from app_store_connect_api import load_private_key, make_token
from app2_004_yakuzaishi_iap_bootstrap import request

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
TARGET_BUILD = "4"
RESULT = Path("automation/app2-004-yakuzaishi-build4-asc.json")


def items(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])


def attrs(resource, keys):
    source = resource.get("attributes", {}) if isinstance(resource, dict) else {}
    return {k: source.get(k) for k in keys if k in source}


def read_state(token):
    _, app_payload = request(token, f"/v1/apps/{APP_ID}")
    app = app_payload["data"]
    if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
        raise RuntimeError("APP2-004 bundle mismatch")

    _, builds_payload = request(token, f"/v1/apps/{APP_ID}/builds?limit=200")
    builds = items(builds_payload)
    target = next((b for b in builds if b.get("attributes", {}).get("version") == TARGET_BUILD), None)
    if not target:
        return {"ready": False, "reason": "build_not_found"}

    build_id = target["id"]
    processing_state = target.get("attributes", {}).get("processingState")
    _, beta_detail_payload = request(token, f"/v1/builds/{build_id}/buildBetaDetail")
    beta_detail = beta_detail_payload["data"]
    internal_state = beta_detail.get("attributes", {}).get("internalBuildState")

    _, groups_payload = request(token, f"/v1/apps/{APP_ID}/betaGroups?limit=50")
    groups = items(groups_payload)
    memberships = []
    for group in groups:
        gid = group["id"]
        _, group_builds_payload = request(token, f"/v1/betaGroups/{gid}/builds?limit=200")
        member_ids = {x.get("id") for x in items(group_builds_payload)}
        if build_id in member_ids:
            memberships.append(group)

    result = {
        "task_id": "APP2-004",
        "target_build": TARGET_BUILD,
        "app": {"id": APP_ID, "attributes": attrs(app, ["name", "bundleId", "sku"])},
        "build": {
            "id": build_id,
            "attributes": attrs(target, [
                "version", "uploadedDate", "processingState", "expired", "expirationDate",
                "minOsVersion", "buildAudienceType", "usesNonExemptEncryption"
            ]),
        },
        "buildBetaDetail": {
            "id": beta_detail.get("id"),
            "attributes": attrs(beta_detail, ["autoNotifyEnabled", "internalBuildState", "externalBuildState"]),
        },
        "buildBetaGroups": [
            {
                "id": g.get("id"),
                "attributes": attrs(g, ["name", "isInternalGroup", "hasAccessToAllBuilds", "publicLinkEnabled", "createdDate"]),
            }
            for g in memberships
        ],
    }
    ready = (
        processing_state == "VALID"
        and internal_state == "IN_BETA_TESTING"
        and any(g.get("attributes", {}).get("isInternalGroup") for g in memberships)
    )
    return {"ready": ready, "result": result}


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)
        latest = None
        for attempt in range(36):
            latest = read_state(token)
            if latest.get("ready"):
                result = latest["result"]
                RESULT.parent.mkdir(parents=True, exist_ok=True)
                RESULT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                print(json.dumps(result, ensure_ascii=False))
                return
            if attempt < 35:
                time.sleep(10)
        raise RuntimeError("APP2-004 Build 4 did not become VALID / IN_BETA_TESTING with internal group membership in time: " + json.dumps(latest, ensure_ascii=False)[:4000])
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
