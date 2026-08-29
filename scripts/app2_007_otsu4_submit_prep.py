#!/usr/bin/env python3
"""Complete machine-resolvable App Store submission metadata for APP2-007.

This script is deliberately pinned to the Otsu4 app/version and only copies the
review contact fields from an existing app owned by the same account. Sensitive
contact values are never written to logs or artifacts.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799755566"
BUNDLE_ID = "jp.allsunday1122.otsu4"
APP_INFO_ID = "9fd15be0-6953-4661-be50-7b97f5f4653e"
VERSION_ID = "d02ea66f-2452-4f75-b900-5d9347384b5d"
DONOR_VERSION_ID = "812cd84c-3efb-407b-a04c-f9fb1b5554e6"
CATEGORY_ID = "EDUCATION"
OUT = Path("automation/app2-007-otsu4-submit-prep-result.json")

REVIEW_NOTES = """本アプリは危険物取扱者 乙種第4類の試験対策アプリです。アカウント登録は不要です。\n\n購入導線: 「設定」→「Premium」、またはロックされた問題・模擬試験の解放ボタンから「乙4 プレミアム」を表示できます。Product ID は jp.allsunday1122.otsu4.premium、非消耗型です。購入後は全720問、模擬試験6回、全範囲の復習機能が解放されます。\n\n無料状態でも72問を利用でき、主要な学習導線を確認できます。学習履歴は端末内に保存し、広告・解析SDK・独自アカウント・開発者サーバーへの学習データ送信はありません。"""

AGE_ATTRIBUTES = {
    "advertising": False,
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gambling": False,
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "healthOrWellnessTopics": False,
    "lootBox": False,
    "medicalOrTreatmentInformation": "NONE",
    "messagingAndChat": False,
    "parentalControls": False,
    "profanityOrCrudeHumor": "NONE",
    "ageAssurance": False,
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "socialMedia": False,
    "socialMediaAgeRestricted": False,
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "unrestrictedWebAccess": False,
    "userGeneratedContent": False,
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "violenceRealistic": "NONE",
    "ageRatingOverrideV2": "NONE",
    "koreaAgeRatingOverride": "NONE",
}


def many(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([] if data is None else [data])


def one(payload, label):
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        raise RuntimeError(f"Missing {label}")
    return data


def req(token, path, method, payload):
    status, response = api_request(token, path, method=method, payload=payload)
    if not 200 <= status < 300:
        raise RuntimeError(f"ASC {method} {path} HTTP {status}")
    return response


def get_optional(token, path):
    try:
        status, response = api_get(token, path)
        if 200 <= status < 300:
            return response
        if status == 404:
            return None
        raise RuntimeError(f"ASC GET {path} HTTP {status}")
    except Exception as exc:
        if "404" in str(exc):
            return None
        raise


def verify_target(token):
    _, payload = api_get(token, f"/v1/apps/{APP_ID}")
    app = one(payload, "app")
    if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
        raise RuntimeError("App/bundle mismatch")
    _, versions = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
    if VERSION_ID not in {str(x.get("id")) for x in many(versions)}:
        raise RuntimeError("Version does not belong to app")


def ensure_category(token, actions):
    payload = {
        "data": {
            "type": "appInfos",
            "id": APP_INFO_ID,
            "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": CATEGORY_ID}}
            },
        }
    }
    req(token, f"/v1/appInfos/{APP_INFO_ID}", "PATCH", payload)
    _, after = api_get(token, f"/v1/appInfos/{APP_INFO_ID}?include=primaryCategory")
    included = after.get("included") or []
    if not any(x.get("type") == "appCategories" and x.get("id") == CATEGORY_ID for x in included):
        raise RuntimeError("Primary category read-back mismatch")
    actions.append("primary_category_education")


def ensure_age_rating(token, actions):
    _, current = api_get(token, f"/v1/appInfos/{APP_INFO_ID}/ageRatingDeclaration")
    rating = one(current, "age rating")
    rating_id = str(rating["id"])
    payload = {
        "data": {
            "type": "ageRatingDeclarations",
            "id": rating_id,
            "attributes": AGE_ATTRIBUTES,
        }
    }
    req(token, f"/v1/ageRatingDeclarations/{rating_id}", "PATCH", payload)
    _, after = api_get(token, f"/v1/appInfos/{APP_INFO_ID}/ageRatingDeclaration")
    attrs = one(after, "age rating after update").get("attributes") or {}
    for key, value in AGE_ATTRIBUTES.items():
        if attrs.get(key) != value:
            raise RuntimeError(f"Age rating read-back mismatch: {key}")
    actions.append("age_rating_completed")
    return rating_id


def donor_contact(token):
    _, donor_payload = api_get(token, f"/v1/appStoreVersions/{DONOR_VERSION_ID}/appStoreReviewDetail")
    donor = one(donor_payload, "donor review detail")
    attrs = donor.get("attributes") or {}
    required = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
    if any(not attrs.get(key) for key in required):
        raise RuntimeError("Donor review contact is incomplete")
    return {key: attrs[key] for key in required}


def ensure_review_detail(token, actions):
    contact = donor_contact(token)
    existing = get_optional(token, f"/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail")
    attrs = {**contact, "demoAccountRequired": False, "notes": REVIEW_NOTES}
    if existing and isinstance(existing.get("data"), dict):
        review_id = str(existing["data"]["id"])
        payload = {"data": {"type": "appStoreReviewDetails", "id": review_id, "attributes": attrs}}
        req(token, f"/v1/appStoreReviewDetails/{review_id}", "PATCH", payload)
        actions.append("review_detail_updated")
    else:
        payload = {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": attrs,
                "relationships": {
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION_ID}}
                },
            }
        }
        created = req(token, "/v1/appStoreReviewDetails", "POST", payload)
        review_id = str(one(created, "created review detail")["id"])
        actions.append("review_detail_created")

    _, after = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail")
    data = one(after, "review detail after update")
    ra = data.get("attributes") or {}
    for key in ("contactFirstName", "contactLastName", "contactPhone", "contactEmail"):
        if not ra.get(key):
            raise RuntimeError(f"Review contact missing after write: {key}")
    if ra.get("demoAccountRequired") is True or ra.get("notes") != REVIEW_NOTES:
        raise RuntimeError("Review detail read-back mismatch")
    return review_id


def main():
    actions = []
    cleanup = None
    result = {
        "task_id": "APP2-007",
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "app_info_id": APP_INFO_ID,
        "version_id": VERSION_ID,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "ok": False,
    }
    try:
        key, cleanup = load_private_key()
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key)
        verify_target(token)
        ensure_category(token, actions)
        result["age_rating_id"] = ensure_age_rating(token, actions)
        result["review_detail_id"] = ensure_review_detail(token, actions)
        _, info = api_get(token, f"/v1/appInfos/{APP_INFO_ID}?include=primaryCategory,ageRatingDeclaration")
        info_data = one(info, "app info")
        result["app_store_age_rating"] = (info_data.get("attributes") or {}).get("appStoreAgeRating")
        result["actions"] = actions
        result["review_contact_complete"] = True
        result["review_contact_values_redacted"] = True
        result["ok"] = True
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    except Exception as exc:
        result["actions"] = actions
        result["error"] = str(exc)
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
