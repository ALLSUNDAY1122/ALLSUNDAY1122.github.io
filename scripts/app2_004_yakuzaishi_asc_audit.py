#!/usr/bin/env python3
import json
import os
from pathlib import Path

from app_store_connect_api import load_private_key, make_token
from app2_004_yakuzaishi_iap_bootstrap import request

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
MONTHLY_ID = "jp.allsunday1122.yakuzaishi.monthly"
LIFETIME_ID = "jp.allsunday1122.yakuzaishi.lifetime"
RESULT = Path("automation/app2-004-yakuzaishi-asc-final.json")


def items(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])


def attrs(resource, keys):
    source = resource.get("attributes", {}) if isinstance(resource, dict) else {}
    return {k: source.get(k) for k in keys if k in source}


def safe_get(token, path):
    try:
        status, payload = request(token, path)
        return {"ok": True, "httpStatus": status, "payload": payload}
    except RuntimeError as exc:
        text = str(exc)
        code = None
        for candidate in (404, 403, 409, 400):
            if f"HTTP {candidate}" in text:
                code = candidate
                break
        return {"ok": False, "httpStatus": code, "error": text[-2000:]}


def summarize_screenshot(result):
    if not result.get("ok"):
        return {"present": False, "httpStatus": result.get("httpStatus")}
    data = (result.get("payload") or {}).get("data")
    if not isinstance(data, dict):
        return {"present": False, "httpStatus": result.get("httpStatus")}
    return {
        "present": True,
        "id": data.get("id"),
        "attributes": attrs(data, ["fileSize", "fileName", "sourceFileChecksum", "assetType", "assetDeliveryState"]),
    }


def main():
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer or not key_id:
        raise SystemExit("Missing ASC credentials")
    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer, key_id, key_path)
        _, app_payload = request(token, f"/v1/apps/{APP_ID}")
        app = app_payload["data"]
        if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("APP2-004 bundle mismatch")

        _, builds_payload = request(token, f"/v1/apps/{APP_ID}/builds?limit=20")
        builds = items(builds_payload)
        build2 = next((b for b in builds if b.get("attributes", {}).get("version") == "2"), None)
        if not build2:
            raise RuntimeError("APP2-004 Build 2 not found in ASC")
        build_id = build2["id"]

        _, beta_detail_payload = request(token, f"/v1/builds/{build_id}/buildBetaDetail")
        beta_detail = beta_detail_payload["data"]
        _, app_groups_payload = request(token, f"/v1/apps/{APP_ID}/betaGroups?limit=50")
        app_groups = items(app_groups_payload)
        group_membership = []
        for group in app_groups:
            gid = group["id"]
            _, group_builds_payload = request(token, f"/v1/betaGroups/{gid}/builds?limit=200")
            member_ids = {b.get("id") for b in items(group_builds_payload)}
            if build_id in member_ids:
                group_membership.append(group)

        _, iap_payload = request(token, f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=200")
        iaps = items(iap_payload)
        lifetime = next((x for x in iaps if x.get("attributes", {}).get("productId") == LIFETIME_ID), None)
        if not lifetime:
            raise RuntimeError("Lifetime IAP missing")
        lifetime_id = lifetime["id"]
        lifetime_detail = safe_get(token, f"/v2/inAppPurchases/{lifetime_id}?include=inAppPurchaseLocalizations,iapPriceSchedule,versions")
        lifetime_screenshot = safe_get(token, f"/v2/inAppPurchases/{lifetime_id}/appStoreReviewScreenshot")
        lifetime_availability = safe_get(token, f"/v2/inAppPurchases/{lifetime_id}/inAppPurchaseAvailability")

        _, group_payload = request(token, f"/v1/apps/{APP_ID}/subscriptionGroups?limit=200")
        subgroups = []
        monthly = None
        for group in items(group_payload):
            gid = group["id"]
            _, subs_payload = request(token, f"/v1/subscriptionGroups/{gid}/subscriptions?limit=200")
            subs = items(subs_payload)
            if monthly is None:
                monthly = next((s for s in subs if s.get("attributes", {}).get("productId") == MONTHLY_ID), None)
            subgroups.append({
                "id": gid,
                "attributes": attrs(group, ["referenceName"]),
                "subscriptions": [
                    {"id": s.get("id"), "attributes": attrs(s, ["name", "productId", "state", "subscriptionPeriod", "reviewNote"])}
                    for s in subs
                ],
            })
        if not monthly:
            raise RuntimeError("Monthly subscription missing")
        monthly_id = monthly["id"]
        monthly_detail = safe_get(token, f"/v1/subscriptions/{monthly_id}?include=subscriptionLocalizations,appStoreReviewScreenshot,planAvailabilities,introductoryOffers")
        monthly_screenshot = safe_get(token, f"/v1/subscriptions/{monthly_id}/appStoreReviewScreenshot")

        lifetime_included = ((lifetime_detail.get("payload") or {}).get("included") or []) if lifetime_detail.get("ok") else []
        monthly_included = ((monthly_detail.get("payload") or {}).get("included") or []) if monthly_detail.get("ok") else []
        lifetime_localizations = [x for x in lifetime_included if x.get("type") in {"inAppPurchaseLocalizations", "inAppPurchaseLocalizationsV2"}]
        lifetime_versions = [x for x in lifetime_included if x.get("type") == "inAppPurchaseVersions"]
        monthly_localizations = [x for x in monthly_included if x.get("type") in {"subscriptionLocalizations", "subscriptionLocalizationsV2"}]
        monthly_plans = [x for x in monthly_included if x.get("type") == "subscriptionPlanAvailabilities"]
        monthly_offers = [x for x in monthly_included if x.get("type") == "subscriptionIntroductoryOffers"]

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
            "lifetime": {
                "id": lifetime_id,
                "attributes": attrs(lifetime, ["name", "productId", "inAppPurchaseType", "state", "familySharable", "reviewNote"]),
                "reviewScreenshot": summarize_screenshot(lifetime_screenshot),
                "localizations": [{"id": x.get("id"), "attributes": attrs(x, ["locale", "name", "description", "state"])} for x in lifetime_localizations],
                "versions": [{"id": x.get("id"), "attributes": attrs(x, ["version", "state"])} for x in lifetime_versions],
                "availabilityRead": {"ok": lifetime_availability.get("ok"), "httpStatus": lifetime_availability.get("httpStatus")},
            },
            "subscriptionGroups": subgroups,
            "monthly": {
                "id": monthly_id,
                "attributes": attrs(monthly, ["name", "productId", "state", "subscriptionPeriod", "reviewNote"]),
                "reviewScreenshot": summarize_screenshot(monthly_screenshot),
                "localizations": [{"id": x.get("id"), "attributes": attrs(x, ["locale", "name", "description", "state"])} for x in monthly_localizations],
                "planAvailabilities": [{"id": x.get("id"), "attributes": attrs(x, ["planType", "availableInNewTerritories"])} for x in monthly_plans],
                "introductoryOffers": [{"id": x.get("id"), "attributes": attrs(x, ["offerMode", "duration", "numberOfPeriods", "startDate", "endDate", "targetSubscriptionPlanType"])} for x in monthly_offers],
            },
        }
        RESULT.parent.mkdir(parents=True, exist_ok=True)
        RESULT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
