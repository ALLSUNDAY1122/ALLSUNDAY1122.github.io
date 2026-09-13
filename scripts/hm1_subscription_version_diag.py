#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

APP_ID = "6799581662"
SUB_ID = "6804373671"
GROUP_ID = "22329151"
OUT = Path("automation/asc-results/hm1-subscription-version-diag.json")


def data_list(payload: dict) -> list[dict]:
    data = payload.get("data", []) if isinstance(payload, dict) else []
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    return [data] if isinstance(data, dict) else []


def safe_get(token: str, path: str) -> dict:
    try:
        _, payload = api_get(token, path)
        return {"ok": True, "data": payload.get("data"), "included": payload.get("included", [])}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def summarize(resources: list[dict]) -> list[dict]:
    out = []
    for item in resources:
        attrs = item.get("attributes") or {}
        out.append({
            "id": item.get("id"),
            "type": item.get("type"),
            "attributes": {
                key: attrs.get(key)
                for key in ("state", "locale", "name", "customAppName", "description", "version")
                if key in attrs
            },
        })
    return out


def main() -> None:
    key_path, cleanup = load_private_key()
    result = {
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "subscription_id": SUB_ID,
        "subscription_group_id": GROUP_ID,
        "read_only": True,
    }
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, sub_versions_payload = api_get(token, f"/v1/subscriptions/{SUB_ID}/versions?limit=200")
        sub_versions = data_list(sub_versions_payload)
        result["subscription_versions"] = summarize(sub_versions)
        result["subscription_version_details"] = []
        for version in sub_versions:
            vid = str(version.get("id"))
            result["subscription_version_details"].append({
                "version_id": vid,
                "localizations": safe_get(token, f"/v1/subscriptionVersions/{vid}/localizations?limit=200"),
                "images": safe_get(token, f"/v1/subscriptionVersions/{vid}/images?limit=200"),
                "image": safe_get(token, f"/v1/subscriptionVersions/{vid}/image"),
            })

        _, group_versions_payload = api_get(token, f"/v1/subscriptionGroups/{GROUP_ID}/versions?limit=200")
        group_versions = data_list(group_versions_payload)
        result["group_versions"] = summarize(group_versions)
        result["group_version_details"] = []
        for version in group_versions:
            vid = str(version.get("id"))
            result["group_version_details"].append({
                "version_id": vid,
                "localizations": safe_get(token, f"/v1/subscriptionGroupVersions/{vid}/localizations?limit=200"),
            })

        result["legacy_subscription_localizations"] = safe_get(
            token, f"/v1/subscriptions/{SUB_ID}/subscriptionLocalizations?limit=200"
        )
        result["legacy_group_localizations"] = safe_get(
            token, f"/v1/subscriptionGroups/{GROUP_ID}/subscriptionGroupLocalizations?limit=200"
        )
        result["subscription_availability"] = safe_get(
            token, f"/v1/subscriptions/{SUB_ID}/subscriptionAvailability?include=availableTerritories&limit[availableTerritories]=200"
        )
        result["ok"] = True
    except Exception as exc:
        result.update({"ok": False, "error": str(exc)})
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
