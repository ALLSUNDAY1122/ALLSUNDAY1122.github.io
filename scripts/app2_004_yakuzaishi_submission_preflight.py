#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
OUT = Path("automation/app2-004-yakuzaishi-submission-preflight.json")


def many(payload):
    if not isinstance(payload, dict): return []
    data = payload.get("data", [])
    return data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])


def one(payload):
    if not isinstance(payload, dict): return None
    data = payload.get("data")
    return data if isinstance(data, dict) else None


def attrs(resource):
    return (resource or {}).get("attributes") or {}


def safe_get(token, path):
    try:
        status, payload = api_get(token, path)
        return {"ok": True, "status": status, "payload": payload}
    except Exception as exc:
        return {"ok": False, "error": str(exc)[-2000:]}


def main():
    result = {
        "task_id": "APP2-004",
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "errors": [],
        "warnings": [],
    }
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, app_payload = api_get(token, f"/v1/apps/{APP_ID}")
        app = one(app_payload)
        result["app"] = {"id": (app or {}).get("id"), "attributes": attrs(app)}
        if attrs(app).get("bundleId") != BUNDLE_ID:
            result["errors"].append("bundle mismatch")

        versions_read = safe_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
        versions = many((versions_read.get("payload") or {})) if versions_read.get("ok") else []
        result["versions"] = [{"id": v.get("id"), "attributes": attrs(v)} for v in versions]
        candidates = [v for v in versions if str(attrs(v).get("versionString")) in {"1.0", "1.0.0"}]
        if not candidates:
            result["errors"].append("App Store Version 1.0/1.0.0 not found")
            version = None
        else:
            version = candidates[0]
            vid = version["id"]
            result["target_version"] = {"id": vid, "attributes": attrs(version)}

            loc_read = safe_get(token, f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=50")
            locs = many((loc_read.get("payload") or {})) if loc_read.get("ok") else []
            result["version_localizations"] = [{"id": x.get("id"), "attributes": attrs(x)} for x in locs]
            ja = next((x for x in locs if attrs(x).get("locale") in {"ja", "ja-JP"}), None)
            if not ja:
                result["errors"].append("Japanese version localization missing")
            else:
                la = attrs(ja)
                for key in ("description", "keywords", "supportUrl"):
                    if not la.get(key): result["errors"].append(f"Japanese localization missing {key}")
                lid = ja["id"]
                sets_read = safe_get(token, f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets?limit=50&include=appScreenshots")
                payload = sets_read.get("payload") or {}
                sets = many(payload)
                included = payload.get("included", []) if isinstance(payload, dict) else []
                complete = [x for x in included if x.get("type") == "appScreenshots" and (((attrs(x).get("assetDeliveryState") or {}).get("state")) == "COMPLETE")]
                result["screenshots"] = {"set_count": len(sets), "complete_count": len(complete), "sets": [{"id": x.get("id"), "attributes": attrs(x)} for x in sets]}
                if not complete: result["errors"].append("No COMPLETE App Store screenshot")

            review_read = safe_get(token, f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
            review = one(review_read.get("payload") or {}) if review_read.get("ok") else None
            result["review_detail"] = {"id": (review or {}).get("id"), "attributes": attrs(review), "read_ok": review_read.get("ok")}
            ra = attrs(review)
            for key in ("contactFirstName", "contactLastName", "contactPhone", "contactEmail", "notes"):
                if not ra.get(key): result["errors"].append(f"review detail missing {key}")

            build_read = safe_get(token, f"/v1/appStoreVersions/{vid}/relationships/build")
            result["selected_build_relationship"] = build_read.get("payload") if build_read.get("ok") else None

            age_read = safe_get(token, f"/v1/appStoreVersions/{vid}/ageRatingDeclaration")
            result["age_rating"] = {"read_ok": age_read.get("ok"), "resource": one(age_read.get("payload") or {}) if age_read.get("ok") else None}
            if not age_read.get("ok"): result["warnings"].append("age rating read unavailable; verify before submit")

        builds_read = safe_get(token, f"/v1/apps/{APP_ID}/builds?limit=50")
        builds = many((builds_read.get("payload") or {})) if builds_read.get("ok") else []
        result["builds"] = [{"id": b.get("id"), "attributes": attrs(b)} for b in builds]
        build5 = next((b for b in builds if str(attrs(b).get("version")) == "5" and attrs(b).get("processingState") == "VALID"), None)
        result["valid_build5"] = {"id": build5.get("id"), "attributes": attrs(build5)} if build5 else None
        if not build5: result["warnings"].append("VALID Build 5 not present yet")

        submissions_read = safe_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=50")
        submissions = many((submissions_read.get("payload") or {})) if submissions_read.get("ok") else []
        result["review_submissions"] = [{"id": s.get("id"), "attributes": attrs(s)} for s in submissions]

        result["pass"] = not result["errors"]
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"pass": result["pass"], "errors": result["errors"], "warnings": result["warnings"]}, ensure_ascii=False))
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
