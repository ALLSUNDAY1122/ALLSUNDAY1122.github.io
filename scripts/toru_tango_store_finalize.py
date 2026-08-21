#!/usr/bin/env python3
"""Scoped App Store Connect preflight finalizer for 撮る単語帳.

This helper is hard-bound to the Toru Tango app/version. It sets review details,
Education category, age-rating declarations, and IDFA=false. It never creates a
review submission, submits for review, changes availability, or releases the app.
Existing Beta Review contact data is copied only inside App Store Connect and is
never persisted to GitHub or the sanitized output.
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6795968222"
BUNDLE_ID = "com.allsunday1122.torutango"
VERSION_ID = "c19fe956-165f-474c-af0b-bbfa86a138df"
APP_INFO_ID = "02b9fefd-04a8-40ba-8fed-c93a2ac2472d"
AGE_RATING_ID = APP_INFO_ID
BUILD_ID = "76d69e5f-e484-41a1-a7e6-df3c0a9c3488"
PRIMARY_CATEGORY_ID = "EDUCATION"

REVIEW_NOTES = """ログインやアカウント作成、外部機器は不要です。初回起動後、下部タブの「作る」から手入力または教材写真の取り込みでカードを作成できます。標準OCRはApple Visionを使用して端末内で処理します。「iPhone内で問題を作る」はApple Foundation Models（利用不可時は端末内簡易作問）で処理します。Gemini OCR／クラウドAI作問は利用者が明示的に選択した場合のみ通信します。作成後は「フォルダ」で表裏一覧・編集・表示/非表示を確認でき、「学習」で表読み上げ→設定秒数待機→裏読み上げ→同じ秒数待機→次カードの自動学習を確認できます。「記録」では学習履歴と連続学習を確認できます。カードと学習履歴は原則端末内保存で、JSONバックアップ/復元に対応しています。広告、解析SDK、ログイン、トラッキングはありません。"""

AGE_RATING_ATTRIBUTES = {
    "advertising": False,
    "ageAssurance": False,
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gambling": False,
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "healthOrWellnessTopics": False,
    "horrorOrFearThemes": "NONE",
    "lootBox": False,
    "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "messagingAndChat": False,
    "parentalControls": False,
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "socialMedia": False,
    "socialMediaAgeRestricted": False,
    "unrestrictedWebAccess": False,
    "userGeneratedContent": False,
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "ageRatingOverrideV2": "NONE",
    "koreaAgeRatingOverride": "NONE",
}


def one_data(response: object, label: str) -> dict:
    if not isinstance(response, dict) or not isinstance(response.get("data"), dict):
        raise RuntimeError(f"Missing {label} resource")
    return response["data"]


def patch_resource(token: str, path: str, resource_type: str, resource_id: str, *, attributes=None, relationships=None):
    data = {"type": resource_type, "id": resource_id}
    if attributes is not None:
        data["attributes"] = attributes
    if relationships is not None:
        data["relationships"] = relationships
    status, response = api_request(token, path, method="PATCH", payload={"data": data})
    if status < 200 or status >= 300:
        raise RuntimeError(f"Unexpected PATCH status {status} for {path}")
    return response


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="toru-tango-store-finalize-result.json")
    args = parser.parse_args()

    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect API credentials")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)

        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        app = one_data(app_response, "app")
        if app.get("attributes", {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app preflight failed")

        _, version_response = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        version = one_data(version_response, "version")
        if version.get("attributes", {}).get("versionString") != "1.0":
            raise RuntimeError("Target version preflight failed")

        _, build_response = api_get(token, f"/v1/builds/{BUILD_ID}")
        build = one_data(build_response, "build")
        if build.get("attributes", {}).get("processingState") != "VALID":
            raise RuntimeError("Build 9 is not VALID")

        # Copy the already-verified TestFlight contact inside ASC only.
        _, beta_response = api_get(token, f"/v1/apps/{APP_ID}/betaAppReviewDetail")
        beta_attrs = one_data(beta_response, "beta review detail").get("attributes", {})
        contact_keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
        review_contact = {key: beta_attrs.get(key) for key in contact_keys}
        if not all(review_contact.values()):
            raise RuntimeError("Existing Beta Review contact is incomplete")
        review_attrs = {**review_contact, "demoAccountRequired": False, "notes": REVIEW_NOTES}

        _, review_rel = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/appStoreReviewDetail")
        review_id = ((review_rel or {}).get("data") or {}).get("id") if isinstance(review_rel, dict) else None
        review_created = False
        if review_id:
            patch_resource(token, f"/v1/appStoreReviewDetails/{review_id}", "appStoreReviewDetails", review_id, attributes=review_attrs)
        else:
            payload = {
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": review_attrs,
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION_ID}}},
                }
            }
            status, created = api_request(token, "/v1/appStoreReviewDetails", method="POST", payload=payload)
            if status != 201:
                raise RuntimeError(f"Unexpected review detail create status {status}")
            review_id = str(one_data(created, "created review detail")["id"])
            review_created = True

        # Education matches the app's primary learning/flashcard purpose.
        patch_resource(
            token,
            f"/v1/appInfos/{APP_INFO_ID}",
            "appInfos",
            APP_INFO_ID,
            relationships={"primaryCategory": {"data": {"type": "appCategories", "id": PRIMARY_CATEGORY_ID}}},
        )

        # Private study cards are not broadly distributed UGC; no chat/social/web/ads/mature content.
        patch_resource(
            token,
            f"/v1/ageRatingDeclarations/{AGE_RATING_ID}",
            "ageRatingDeclarations",
            AGE_RATING_ID,
            attributes=AGE_RATING_ATTRIBUTES,
        )

        # No advertising SDK, IDFA access, analytics, or tracking exists in Build 9.
        patch_resource(
            token,
            f"/v1/appStoreVersions/{VERSION_ID}",
            "appStoreVersions",
            VERSION_ID,
            attributes={"usesIdfa": False},
        )

        # Read back only non-sensitive state.
        _, review_after = api_get(token, f"/v1/appStoreReviewDetails/{review_id}")
        review_after_attrs = one_data(review_after, "review detail after update").get("attributes", {})
        _, category_after = api_get(token, f"/v1/appInfos/{APP_INFO_ID}/primaryCategory")
        category = one_data(category_after, "primary category")
        _, age_after = api_get(token, f"/v1/appInfos/{APP_INFO_ID}/ageRatingDeclaration")
        age_attrs = one_data(age_after, "age rating after update").get("attributes", {})
        _, version_after = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        version_attrs = one_data(version_after, "version after update").get("attributes", {})
        _, build_after = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")

        result = {
            "task": "toru-tango-store-preflight",
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "app_id": APP_ID,
            "bundle_id": BUNDLE_ID,
            "version": "1.0",
            "review_detail": {
                "created": review_created,
                "contact_complete": all(review_after_attrs.get(k) for k in contact_keys),
                "demo_account_required": review_after_attrs.get("demoAccountRequired"),
                "notes_present": bool(review_after_attrs.get("notes")),
            },
            "primary_category": category.get("id"),
            "age_rating_complete": all(age_attrs.get(k) is not None for k in AGE_RATING_ATTRIBUTES),
            "age_rating": {
                "advertising": age_attrs.get("advertising"),
                "health_or_wellness_topics": age_attrs.get("healthOrWellnessTopics"),
                "unrestricted_web_access": age_attrs.get("unrestrictedWebAccess"),
                "user_generated_content": age_attrs.get("userGeneratedContent"),
                "messaging_and_chat": age_attrs.get("messagingAndChat"),
                "age_rating_override_v2": age_attrs.get("ageRatingOverrideV2"),
            },
            "uses_idfa": version_attrs.get("usesIdfa"),
            "selected_build_id": (build_after.get("data") or {}).get("id") if isinstance(build_after, dict) else None,
            "review_submission_created": False,
            "app_review_submitted": False,
            "availability_changed": False,
            "release_performed": False,
        }
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PASS: Toru Tango review details/category/age rating/IDFA finalized; no submission performed")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
