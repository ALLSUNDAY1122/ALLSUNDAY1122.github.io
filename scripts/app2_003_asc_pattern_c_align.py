#!/usr/bin/env python3
"""APP2-003 scoped ASC alignment after Pattern C UI merge.

This action is intentionally fixed to 夜の書架. It only:
1. verifies the app/version are still safely editable and unsubmitted,
2. removes the obsolete Build 3 relationship if present,
3. changes the editable App Store version from 1.1.0 to 1.2.0,
4. reads both values back.

It never submits Beta App Review, App Review, or releases the app.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794137637"
BUNDLE_ID = "io.github.allsunday1122.yorunoshoka"
VERSION_ID = "812cd84c-3efb-407b-a04c-f9fb1b5554e6"
OBSOLETE_BUILD_ID = "23521541-e269-4baf-800d-7830b94c36a1"
TARGET_VERSION = "1.2.0"
OUTPUT = Path("automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-pattern-c-asc-align.json")


def relationship_id(payload: dict) -> str | None:
    data = payload.get("data")
    return data.get("id") if isinstance(data, dict) else None


def main() -> int:
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise RuntimeError("Missing ASC issuer/key id")

    key_path, cleanup = load_private_key()
    evidence: dict = {
        "app_id": APP_ID,
        "version_id": VERSION_ID,
        "target_version": TARGET_VERSION,
        "obsolete_build_id": OBSOLETE_BUILD_ID,
        "steps": [],
        "ok": False,
    }
    try:
        token = make_token(issuer, key_id, key_path)

        _, app = api_get(token, f"/v1/apps/{APP_ID}")
        bundle = app["data"]["attributes"].get("bundleId")
        if bundle != BUNDLE_ID:
            raise RuntimeError("Bundle ID preflight mismatch")
        evidence["steps"].append({"step": "app_preflight", "ok": True, "bundleId": bundle})

        _, version = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        attrs = version["data"]["attributes"]
        before_version = attrs.get("versionString")
        state = attrs.get("appStoreState")
        if state != "PREPARE_FOR_SUBMISSION":
            raise RuntimeError(f"App Store version is not safely editable: {state}")
        if before_version not in {"1.1.0", TARGET_VERSION}:
            raise RuntimeError(f"Unexpected App Store version: {before_version}")
        evidence["steps"].append({
            "step": "version_preflight",
            "ok": True,
            "versionString": before_version,
            "appStoreState": state,
        })

        _, submissions = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=20")
        if submissions.get("data"):
            raise RuntimeError("Review submission exists; refusing to alter version/build")
        evidence["steps"].append({"step": "submission_preflight", "ok": True, "reviewSubmissionCount": 0})

        _, relationship = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
        before_build_id = relationship_id(relationship)
        if before_build_id not in {None, OBSOLETE_BUILD_ID}:
            raise RuntimeError(f"Unexpected attached build: {before_build_id}")
        evidence["steps"].append({"step": "build_preflight", "ok": True, "attached_build_id": before_build_id})

        if before_build_id == OBSOLETE_BUILD_ID:
            status, _ = api_request(
                token,
                f"/v1/appStoreVersions/{VERSION_ID}/relationships/build",
                method="PATCH",
                payload={"data": None},
            )
            evidence["steps"].append({"step": "detach_obsolete_build", "changed": True, "http_status": status})
        else:
            evidence["steps"].append({"step": "detach_obsolete_build", "changed": False})

        _, relationship_after = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
        if relationship_id(relationship_after) is not None:
            raise RuntimeError("Build relationship read-back is not empty")
        evidence["steps"].append({"step": "build_readback", "ok": True, "attached_build_id": None})

        if before_version != TARGET_VERSION:
            status, _ = api_request(
                token,
                f"/v1/appStoreVersions/{VERSION_ID}",
                method="PATCH",
                payload={
                    "data": {
                        "type": "appStoreVersions",
                        "id": VERSION_ID,
                        "attributes": {"versionString": TARGET_VERSION},
                    }
                },
            )
            evidence["steps"].append({"step": "update_version", "changed": True, "http_status": status})
        else:
            evidence["steps"].append({"step": "update_version", "changed": False})

        _, version_after = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        final_attrs = version_after["data"]["attributes"]
        if final_attrs.get("versionString") != TARGET_VERSION:
            raise RuntimeError("Version read-back mismatch")
        if final_attrs.get("appStoreState") != "PREPARE_FOR_SUBMISSION":
            raise RuntimeError("App Store state changed unexpectedly")
        evidence["steps"].append({
            "step": "version_readback",
            "ok": True,
            "versionString": final_attrs.get("versionString"),
            "appStoreState": final_attrs.get("appStoreState"),
        })
        evidence["ok"] = True
        return 0
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
