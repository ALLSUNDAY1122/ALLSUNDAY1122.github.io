#!/usr/bin/env python3
"""Read-only App Store Connect release-readiness probe for active iOS apps."""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

APPS = {
    "touhan": ("6802119268", "com.allsunday1122.tourokuhanbaisha"),
    "hm2": ("6799751657", "jp.allsunday1122.healthmanager2"),
    "hm1": ("6799581662", "jp.allsunday1122.healthmanager1"),
    "pharmacist": ("6799753724", "jp.allsunday1122.yakuzaishi"),
    "otsu4": ("6799755566", "jp.allsunday1122.otsu4"),
    "fp3": ("6796733578", "com.allsunday1122.fp3kakomoncoach"),
    "ap": ("6799754343", "jp.allsunday1122.apmanabisprint"),
    "tsukanshi": ("6799753744", "jp.allsunday1122.tsukanshi"),
    "network": ("6799754573", "jp.allsunday1122.networkspecialist"),
    "cpa": ("6799754783", "jp.allsunday1122.cpamanabisprint"),
    "shoshi": ("6799755748", "jp.allsunday1122.shoshi"),
    "kanteishi": ("6801787074", "jp.allsunday1122.kanteishishortanswer"),
    "kangoshi": ("6801792293", "jp.allsunday1122.kangoshi"),
    "kanrieiyoushi": ("6799753841", "jp.allsunday1122.kanrieiyoushi"),
    "hokenshi": ("6801783499", "jp.allsunday1122.hokenshi"),
}
OUT = Path(os.environ.get("FACTORY_RELEASE_RESULT", "factory-release-readback.json"))


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", [])
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [data]
    return []


def attrs(item: dict | None) -> dict:
    return (item or {}).get("attributes") or {}


def newest_build(rows: list[dict]) -> dict | None:
    if not rows:
        return None
    return max(rows, key=lambda x: str(attrs(x).get("uploadedDate") or attrs(x).get("expirationDate") or ""))


def editable_ios_version(rows: list[dict]) -> dict | None:
    ios = [x for x in rows if attrs(x).get("platform") == "IOS"]
    editable = [x for x in ios if (attrs(x).get("appStoreState") or attrs(x).get("appVersionState")) in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}]
    if editable:
        return max(editable, key=lambda x: str(attrs(x).get("createdDate") or attrs(x).get("versionString") or ""))
    return max(ios, key=lambda x: str(attrs(x).get("createdDate") or attrs(x).get("versionString") or "")) if ios else None


def relation_id(token: str, path: str) -> str | None:
    try:
        status, body = api_get(token, path)
        if not 200 <= status < 300 or not isinstance(body, dict):
            return None
        data = body.get("data")
        return str(data.get("id")) if isinstance(data, dict) and data.get("id") else None
    except Exception:
        return None


def safe_get(token: str, path: str) -> tuple[int | None, dict]:
    try:
        status, body = api_get(token, path)
        return status, body if isinstance(body, dict) else {}
    except Exception as exc:
        return None, {"error": str(exc)[:500]}


def main() -> None:
    result = {
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "read_only": True,
        "apps": {},
    }
    errors: list[str] = []
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        for label, (app_id, bundle_id) in APPS.items():
            app: dict = {"app_id": app_id, "bundle_id": bundle_id}
            endpoints = {
                "builds": f"/v1/apps/{app_id}/builds?limit=100",
                "versions": f"/v1/apps/{app_id}/appStoreVersions?limit=50",
                "iaps": f"/v1/apps/{app_id}/inAppPurchasesV2?limit=100",
                "subscription_groups": f"/v1/apps/{app_id}/subscriptionGroups?limit=100",
            }
            payloads: dict[str, dict] = {}
            for name, path in endpoints.items():
                status, body = safe_get(token, path)
                payloads[name] = body
                app[f"{name}_http_status"] = status
                if status is None or not 200 <= status < 300:
                    errors.append(f"{label}:{name}")

            builds = many(payloads["builds"])
            versions = many(payloads["versions"])
            iaps = many(payloads["iaps"])
            groups = many(payloads["subscription_groups"])
            latest = newest_build(builds)
            version = editable_ios_version(versions)
            la = attrs(latest)
            va = attrs(version)
            version_id = str((version or {}).get("id") or "")
            selected_build_id = relation_id(token, f"/v1/appStoreVersions/{version_id}/relationships/build") if version_id else None
            selected = next((x for x in builds if str(x.get("id")) == selected_build_id), None)
            sa = attrs(selected)

            iap_summary = []
            for item in iaps:
                a = attrs(item)
                iap_summary.append({
                    "id": item.get("id"),
                    "product_id": a.get("productId"),
                    "name": a.get("name"),
                    "state": a.get("state") or a.get("inAppPurchaseState"),
                    "type": a.get("inAppPurchaseType"),
                })
            group_summary = []
            for item in groups:
                a = attrs(item)
                group_summary.append({"id": item.get("id"), "reference_name": a.get("referenceName")})

            app["summary"] = {
                "latest_build_id": (latest or {}).get("id"),
                "latest_build": la.get("version"),
                "latest_processing_state": la.get("processingState"),
                "latest_expired": la.get("expired"),
                "latest_audience": la.get("buildAudienceType"),
                "latest_uploaded_date": la.get("uploadedDate"),
                "version_id": version_id or None,
                "version_string": va.get("versionString"),
                "version_state": va.get("appStoreState") or va.get("appVersionState"),
                "selected_build_id": selected_build_id,
                "selected_build": sa.get("version") if selected else None,
                "selected_build_state": sa.get("processingState") if selected else None,
                "selected_build_expired": sa.get("expired") if selected else None,
                "selected_build_audience": sa.get("buildAudienceType") if selected else None,
                "iap_count": len(iap_summary),
                "iaps": iap_summary,
                "subscription_group_count": len(group_summary),
                "subscription_groups": group_summary,
            }
            result["apps"][label] = app
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for label, app in result["apps"].items():
        s = app["summary"]
        iaps = ",".join(f"{x.get('product_id')}={x.get('state')}" for x in s["iaps"]) or "none"
        print(
            f"{label}: latest={s['latest_build']} state={s['latest_processing_state']} expired={s['latest_expired']} "
            f"audience={s['latest_audience']} | version={s['version_string']}:{s['version_state']} "
            f"selected={s['selected_build']} selected_audience={s['selected_build_audience']} | iap={iaps}"
        )
    if errors:
        raise SystemExit(f"Release readback incomplete: {errors}")


if __name__ == "__main__":
    main()
