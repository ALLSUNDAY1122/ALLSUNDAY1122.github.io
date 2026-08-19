#!/usr/bin/env python3
import json
import os
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
RESULT = Path("automation/app2-004-yakuzaishi-asc-final.json")


def items(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else [data]


def attrs(resource, keys):
    source = resource.get("attributes", {}) if isinstance(resource, dict) else {}
    return {k: source.get(k) for k in keys if k in source}


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")
    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)
        _, app_payload = api_get(token, f"/v1/apps/{APP_ID}")
        app = app_payload["data"]
        if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("APP2-004 bundle mismatch")

        _, builds_payload = api_get(token, f"/v1/apps/{APP_ID}/builds?limit=20")
        builds = items(builds_payload)
        build2 = next((b for b in builds if b.get("attributes", {}).get("version") == "2"), None)
        if not build2:
            raise RuntimeError("APP2-004 Build 2 not found in ASC")
        build_id = build2["id"]

        _, beta_detail_payload = api_get(token, f"/v1/builds/{build_id}/buildBetaDetail")
        beta_detail = beta_detail_payload["data"]
        _, app_groups_payload = api_get(token, f"/v1/apps/{APP_ID}/betaGroups?limit=50")
        app_groups = items(app_groups_payload)
        group_membership = []
        for group in app_groups:
            gid = group["id"]
            _, group_builds_payload = api_get(token, f"/v1/betaGroups/{gid}/builds?limit=200")
            member_ids = {b.get("id") for b in items(group_builds_payload)}
            if build_id in member_ids:
                group_membership.append(group)

        _, iap_payload = api_get(token, f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=200")
        _, group_payload = api_get(token, f"/v1/apps/{APP_ID}/subscriptionGroups?limit=200")
        subgroups = []
        for group in items(group_payload):
            gid = group["id"]
            _, subs_payload = api_get(token, f"/v1/subscriptionGroups/{gid}/subscriptions?limit=200")
            subgroups.append({
                "id": gid,
                "attributes": attrs(group, ["referenceName"]),
                "subscriptions": [
                    {"id": s.get("id"), "attributes": attrs(s, ["name", "productId", "state", "subscriptionPeriod"])}
                    for s in items(subs_payload)
                ],
            })

        result = {
            "task_id": "APP2-004",
            "app": {"id": APP_ID, "attributes": attrs(app, ["name", "bundleId", "sku"])},
            "build2": {"id": build_id, "attributes": attrs(build2, ["version", "uploadedDate", "processingState", "expired", "expirationDate", "minOsVersion", "buildAudienceType", "usesNonExemptEncryption"])},
            "buildBetaDetail": {"id": beta_detail.get("id"), "attributes": attrs(beta_detail, ["autoNotifyEnabled", "internalBuildState", "externalBuildState"])},
            "buildBetaGroups": [
                {"id": g.get("id"), "attributes": attrs(g, ["name", "isInternalGroup", "hasAccessToAllBuilds", "publicLinkEnabled", "createdDate"])}
                for g in group_membership
            ],
            "appBetaGroups": [
                {"id": g.get("id"), "attributes": attrs(g, ["name", "isInternalGroup", "hasAccessToAllBuilds", "publicLinkEnabled", "createdDate"])}
                for g in app_groups
            ],
            "inAppPurchases": [
                {"id": x.get("id"), "attributes": attrs(x, ["name", "productId", "inAppPurchaseType", "state", "familySharable"])}
                for x in items(iap_payload)
            ],
            "subscriptionGroups": subgroups,
        }
        RESULT.parent.mkdir(parents=True, exist_ok=True)
        RESULT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
