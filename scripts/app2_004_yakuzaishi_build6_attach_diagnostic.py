#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799753724"
VERSION_ID = "430ba445-fae0-4d1d-9301-95d1ea342ac7"
TARGET_BUILD = "6"
OUT = Path("automation/asc-results/app2-004-yakuzaishi-build6-attach-diagnostic.json")


def many(payload):
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", [])
    return data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])


def attrs(resource):
    return (resource or {}).get("attributes") or {}


def safe_get(token, path):
    try:
        status, payload = api_get(token, path)
        return {"ok": True, "status": status, "payload": payload}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def main():
    result = {
        "task_id": "APP2-004",
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "target_build": TARGET_BUILD,
        "version_id": VERSION_ID,
        "attach_attempted": False,
        "attach_succeeded": False,
    }
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)

        _, builds_payload = api_get(token, f"/v1/apps/{APP_ID}/builds?sort=-uploadedDate&limit=50")
        builds = many(builds_payload)
        build = next((b for b in builds if str(attrs(b).get("version")) == TARGET_BUILD), None)
        if not build:
            raise RuntimeError("Build 6 not found")
        build_id = str(build["id"])
        result["build"] = {"id": build_id, "attributes": attrs(build)}

        version_read = safe_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        result["version"] = version_read
        selected_before = safe_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
        result["selected_build_before"] = selected_before

        submissions = safe_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200")
        if submissions.get("ok"):
            result["review_submissions"] = [
                {"id": x.get("id"), "attributes": attrs(x)} for x in many(submissions.get("payload"))
            ]
        else:
            result["review_submissions_error"] = submissions.get("error")

        result["attach_attempted"] = True
        payload = {
            "data": {
                "type": "appStoreVersions",
                "id": VERSION_ID,
                "relationships": {
                    "build": {"data": {"type": "builds", "id": build_id}}
                },
            }
        }
        try:
            status, response = api_request(token, f"/v1/appStoreVersions/{VERSION_ID}", method="PATCH", payload=payload)
            result["attach_http_status"] = status
            result["attach_response"] = response
            result["attach_succeeded"] = 200 <= status < 300
        except Exception as exc:
            result["attach_error"] = str(exc)

        selected_after = safe_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
        result["selected_build_after"] = selected_after

        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
