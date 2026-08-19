#!/usr/bin/env python3
"""APP2-003 scoped, idempotent App Store version/build alignment.

Fixed to 夜の書架. Never submits an app for review. Credentials come only from
GitHub Actions secrets. Evidence contains no credentials or personal contact data.
"""
import json
import os
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794137637"
BUNDLE_ID = "io.github.allsunday1122.yorunoshoka"
VERSION_ID = "812cd84c-3efb-407b-a04c-f9fb1b5554e6"
BUILD_ID = "23521541-e269-4baf-800d-7830b94c36a1"
PRERELEASE_ID = "c655ea9f-08a8-4f82-9aa6-6b4f43a527da"
TARGET_VERSION = "1.1.0"
OUTPUT = Path("automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-version-build-fix.json")


def save(evidence):
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    evidence = {"app_id": APP_ID, "version_id": VERSION_ID, "build_id": BUILD_ID, "target_version": TARGET_VERSION, "steps": [], "ok": False}
    cleanup = None
    try:
        issuer = os.environ.get("ASC_ISSUER_ID")
        key_id = os.environ.get("ASC_KEY_ID")
        if not issuer or not key_id:
            raise RuntimeError("Missing ASC issuer/key id")
        key_path, cleanup = load_private_key()
        token = make_token(issuer, key_id, key_path)

        _, app = api_get(token, f"/v1/apps/{APP_ID}")
        bundle = app["data"]["attributes"].get("bundleId")
        if bundle != BUNDLE_ID:
            raise RuntimeError("Bundle ID preflight mismatch")
        evidence["steps"].append({"step": "app_preflight", "ok": True, "bundleId": bundle})

        _, version = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        va = version["data"]["attributes"]
        before_version = va.get("versionString")
        state = va.get("appStoreState")
        if state != "PREPARE_FOR_SUBMISSION":
            raise RuntimeError(f"App Store version is not safely editable: {state}")
        if before_version not in {"1.0", TARGET_VERSION}:
            raise RuntimeError(f"Unexpected App Store version: {before_version}")
        evidence["steps"].append({"step": "version_preflight", "ok": True, "versionString": before_version, "appStoreState": state})

        _, build = api_get(token, f"/v1/builds/{BUILD_ID}")
        ba = build["data"]["attributes"]
        if ba.get("version") != "3" or ba.get("processingState") != "VALID" or ba.get("expired") is True:
            raise RuntimeError("Build preflight failed")
        evidence["steps"].append({"step": "build_preflight", "ok": True, "buildNumber": "3", "processingState": "VALID", "expired": False})

        _, rel = api_get(token, f"/v1/preReleaseVersions/{PRERELEASE_ID}/relationships/builds?limit=20")
        if BUILD_ID not in {item.get("id") for item in rel.get("data", [])}:
            raise RuntimeError("Build does not belong to prerelease 1.1.0")
        evidence["steps"].append({"step": "prerelease_preflight", "ok": True, "version": TARGET_VERSION})

        if before_version != TARGET_VERSION:
            payload = {"data": {"type": "appStoreVersions", "id": VERSION_ID, "attributes": {"versionString": TARGET_VERSION}}}
            status, _ = api_request(token, f"/v1/appStoreVersions/{VERSION_ID}", method="PATCH", payload=payload)
            evidence["steps"].append({"step": "update_version", "changed": True, "http_status": status})
        else:
            evidence["steps"].append({"step": "update_version", "changed": False})

        _, version_after = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        after_version = version_after["data"]["attributes"].get("versionString")
        if after_version != TARGET_VERSION:
            raise RuntimeError("Version read-back mismatch")
        evidence["steps"].append({"step": "version_readback", "ok": True, "versionString": after_version})

        _, before_rel = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
        current = before_rel.get("data")
        current_id = current.get("id") if isinstance(current, dict) else None
        if current_id != BUILD_ID:
            payload = {"data": {"type": "builds", "id": BUILD_ID}}
            status, _ = api_request(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build", method="PATCH", payload=payload)
            evidence["steps"].append({"step": "attach_build", "changed": True, "http_status": status})
        else:
            evidence["steps"].append({"step": "attach_build", "changed": False})

        _, after_rel = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")
        attached = after_rel.get("data")
        attached_id = attached.get("id") if isinstance(attached, dict) else None
        if attached_id != BUILD_ID:
            raise RuntimeError("Build read-back mismatch")
        evidence["steps"].append({"step": "build_readback", "ok": True, "attached_build_id": attached_id})
        evidence["ok"] = True
    except Exception as exc:
        evidence["error"] = str(exc)[-800:]
        save(evidence)
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
        save(evidence)


if __name__ == "__main__":
    main()
