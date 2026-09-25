#!/usr/bin/env python3
"""Read-only App Store Connect release-readiness probe for registered iOS apps.

The canonical app list lives in automation/app-release-registry.json.  This
probe never guesses an Apple App ID: registry entries without an Apple-issued
ID are emitted as unresolved and skipped.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

REGISTRY = Path(os.environ.get("APP_RELEASE_REGISTRY", "automation/app-release-registry.json"))
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
    editable = [
        x
        for x in ios
        if (attrs(x).get("appStoreState") or attrs(x).get("appVersionState"))
        in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}
    ]
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


def empty_summary() -> dict:
    return {
        "latest_build_id": None,
        "latest_build": None,
        "latest_processing_state": None,
        "latest_expired": None,
        "latest_audience": None,
        "latest_uploaded_date": None,
        "version_id": None,
        "version_string": None,
        "version_state": None,
        "selected_build_id": None,
        "selected_build": None,
        "selected_build_state": None,
        "selected_build_expired": None,
        "selected_build_audience": None,
        "iap_count": 0,
        "iaps": [],
        "subscription_group_count": 0,
        "subscription_groups": [],
    }


def load_registry() -> tuple[int, dict[str, dict]]:
    if not REGISTRY.is_file():
        raise SystemExit(f"Release registry missing: {REGISTRY}")
    raw = json.loads(REGISTRY.read_text(encoding="utf-8"))
    schema = int(raw.get("schema_version") or 0)
    apps = raw.get("apps")
    if schema < 1 or not isinstance(apps, dict) or not apps:
        raise SystemExit("Release registry is invalid or empty")

    seen_app_ids: dict[str, str] = {}
    seen_bundle_ids: dict[str, str] = {}
    normalized: dict[str, dict] = {}
    for label, item in apps.items():
        if not isinstance(item, dict):
            raise SystemExit(f"Registry entry {label} must be an object")
        bundle_id = str(item.get("bundle_id") or "").strip()
        app_id_raw = item.get("app_id")
        app_id = str(app_id_raw).strip() if app_id_raw is not None else None
        if not bundle_id:
            raise SystemExit(f"Registry entry {label} has no bundle_id")
        if bundle_id in seen_bundle_ids:
            raise SystemExit(f"Duplicate bundle_id {bundle_id}: {seen_bundle_ids[bundle_id]} and {label}")
        seen_bundle_ids[bundle_id] = label
        if app_id:
            if not app_id.isdigit():
                raise SystemExit(f"Registry entry {label} has non-numeric Apple app_id")
            if app_id in seen_app_ids:
                raise SystemExit(f"Duplicate app_id {app_id}: {seen_app_ids[app_id]} and {label}")
            seen_app_ids[app_id] = label
        normalized[label] = {
            **item,
            "app_id": app_id,
            "bundle_id": bundle_id,
            "readback": bool(item.get("readback", True)),
        }
    return schema, normalized


def main() -> None:
    schema_version, registry_apps = load_registry()
    result = {
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "read_only": True,
        "registry_path": str(REGISTRY),
        "registry_schema_version": schema_version,
        "apps": {},
    }
    errors: list[str] = []
    pending: list[str] = []

    queryable = [x for x in registry_apps.values() if x.get("readback") and x.get("app_id")]
    token = None
    key_path = None
    cleanup = None
    if queryable:
        key_path, cleanup = load_private_key()
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)

    try:
        for label, entry in registry_apps.items():
            app_id = entry.get("app_id")
            bundle_id = entry["bundle_id"]
            app: dict = {
                "name": entry.get("name") or label,
                "app_id": app_id,
                "bundle_id": bundle_id,
                "app2_task": entry.get("app2_task"),
                "registry_status": entry.get("status"),
                "summary": empty_summary(),
            }

            if not entry.get("readback") or not app_id:
                reason = "apple_id_pending" if not app_id else "readback_disabled"
                app["readback_status"] = "UNRESOLVED"
                app["skipped_reason"] = reason
                pending.append(label)
                result["apps"][label] = app
                continue

            assert token is not None
            endpoints = {
                "builds": f"/v1/apps/{app_id}/builds?limit=100",
                "versions": f"/v1/apps/{app_id}/appStoreVersions?limit=50",
                "iaps": f"/v1/apps/{app_id}/inAppPurchasesV2?limit=100",
                "subscription_groups": f"/v1/apps/{app_id}/subscriptionGroups?limit=100",
            }
            payloads: dict[str, dict] = {}
            app_errors: list[str] = []
            for name, path in endpoints.items():
                status, body = safe_get(token, path)
                payloads[name] = body
                app[f"{name}_http_status"] = status
                if status is None or not 200 <= status < 300:
                    app_errors.append(name)
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
                iap_summary.append(
                    {
                        "id": item.get("id"),
                        "product_id": a.get("productId"),
                        "name": a.get("name"),
                        "state": a.get("state") or a.get("inAppPurchaseState"),
                        "type": a.get("inAppPurchaseType"),
                    }
                )
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
            app["readback_status"] = "OK" if not app_errors else "PARTIAL"
            if app_errors:
                app["readback_errors"] = app_errors
            result["apps"][label] = app
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    result["pending_registry_entries"] = pending
    result["readback_errors"] = errors
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for label, app in result["apps"].items():
        s = app["summary"]
        if app.get("readback_status") == "UNRESOLVED":
            print(f"{label}: UNKNOWN reason={app.get('skipped_reason')} bundle={app.get('bundle_id')}")
            continue
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
