#!/usr/bin/env python3
"""APP2-011 scoped App Store Connect finalization helper for 卓 TAKU CALC.

This helper is deliberately bound to one app/version. It never submits for App
Review or releases the app. Credentials remain in GitHub Actions secrets. Review
contact data is copied inside App Store Connect from the existing Beta Review
record and is never written to the repository or result artifact.
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794350490"
BUNDLE_ID = "com.koheimorita.takucalc"
VERSION_ID = "65ef287d-3ea2-42d6-a0df-32ff6d62c08c"
APP_INFO_ID = "7fa2a775-89fd-4d1b-a2e3-ac33711fc342"
AGE_RATING_ID = "7fa2a775-89fd-4d1b-a2e3-ac33711fc342"
REVIEW_DETAIL_ID = "963d3df4-3455-4109-9baa-5ee28270a42b"
PRIMARY_CATEGORY_ID = "UTILITIES"

REVIEW_NOTES = """ログイン、アカウント作成、通信環境、外部機器は不要です。起動後すぐに全機能を利用できます。画面上部の現在モード表示から10種類の機能を選択できます。標準電卓では 200 + 10 % = で 220 を確認できます。通貨換算は自動レートを使用せず、利用者が手動入力したレートを使用します。税・ローン・BMIの結果は参考値であり、専門的判断には使用しない旨をアプリ内に表示しています。広告、解析、ログイン、外部API、プッシュ通知はありません。履歴、設定、メモリー、手動通貨レートは端末内にのみ保存します。"""

AGE_RATING_ATTRIBUTES = {
    "advertising": False,
    "ageAssurance": False,
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gambling": False,
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "healthOrWellnessTopics": True,
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
    parser.add_argument("--output", default="app2-011-store-finalize-result.json")
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
        if version.get("attributes", {}).get("versionString") != "1.5.0":
            raise RuntimeError("Target version preflight failed")

        # Reuse the already-verified Beta Review contact entirely inside ASC.
        _, beta_response = api_get(token, f"/v1/apps/{APP_ID}/betaAppReviewDetail")
        beta_attrs = one_data(beta_response, "beta review detail").get("attributes", {})
        contact_keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
        review_contact = {key: beta_attrs.get(key) for key in contact_keys}
        if not all(review_contact.values()):
            raise RuntimeError("Existing Beta Review contact is incomplete")
        review_attrs = {
            **review_contact,
            "demoAccountRequired": False,
            "notes": REVIEW_NOTES,
        }
        patch_resource(
            token,
            f"/v1/appStoreReviewDetails/{REVIEW_DETAIL_ID}",
            "appStoreReviewDetails",
            REVIEW_DETAIL_ID,
            attributes=review_attrs,
        )

        # Utilities is the natural top-level App Store category for a calculator.
        patch_resource(
            token,
            f"/v1/appInfos/{APP_INFO_ID}",
            "appInfos",
            APP_INFO_ID,
            relationships={
                "primaryCategory": {
                    "data": {"type": "appCategories", "id": PRIMARY_CATEGORY_ID}
                }
            },
        )

        # BMI is a wellness topic, but the app contains no diagnosis or treatment content.
        patch_resource(
            token,
            f"/v1/ageRatingDeclarations/{AGE_RATING_ID}",
            "ageRatingDeclarations",
            AGE_RATING_ID,
            attributes=AGE_RATING_ATTRIBUTES,
        )

        # Read back only non-sensitive facts.
        _, review_after = api_get(token, f"/v1/appStoreReviewDetails/{REVIEW_DETAIL_ID}")
        review_after_attrs = one_data(review_after, "review detail after update").get("attributes", {})
        _, category_after = api_get(token, f"/v1/appInfos/{APP_INFO_ID}/primaryCategory")
        category = one_data(category_after, "primary category")
        _, age_after = api_get(token, f"/v1/appInfos/{APP_INFO_ID}/ageRatingDeclaration")
        age_attrs = one_data(age_after, "age rating after update").get("attributes", {})
        _, build_after = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build")

        result = {
            "task": "APP2-011",
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "app_id": APP_ID,
            "bundle_id": BUNDLE_ID,
            "version": "1.5.0",
            "review_detail": {
                "contact_complete": all(review_after_attrs.get(k) for k in contact_keys),
                "demo_account_required": review_after_attrs.get("demoAccountRequired"),
                "notes_present": bool(review_after_attrs.get("notes")),
            },
            "primary_category": category.get("id"),
            "age_rating": {
                "health_or_wellness_topics": age_attrs.get("healthOrWellnessTopics"),
                "medical_or_treatment_information": age_attrs.get("medicalOrTreatmentInformation"),
                "advertising": age_attrs.get("advertising"),
                "unrestricted_web_access": age_attrs.get("unrestrictedWebAccess"),
                "user_generated_content": age_attrs.get("userGeneratedContent"),
            },
            "selected_build_id": (build_after.get("data") or {}).get("id") if isinstance(build_after, dict) else None,
            "submission_performed": False,
        }
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PASS: APP2-011 App Store review/category/age-rating finalization completed; no submission performed")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
