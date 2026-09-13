#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token
from app2_005_hm1_prepare_submit import (
    APP_ID,
    BUNDLE_ID,
    DESCRIPTION,
    KEYWORDS,
    LIFETIME_ID,
    MONTHLY_ID,
    PROMO,
    SUPPORT_URL,
    ensure_info_metadata,
    ensure_review_detail,
    ensure_review_screenshot,
    one,
    patch,
    resolve_localization,
    resolve_version,
    state,
    upload_app_screenshots,
)


def included_checklist(payload: dict) -> dict:
    included = payload.get("included") or []
    counts = Counter(str(item.get("type")) for item in included if isinstance(item, dict))
    locales = sorted(
        {
            str((item.get("attributes") or {}).get("locale"))
            for item in included
            if isinstance(item, dict)
            and str(item.get("type")) in {"subscriptionLocalizations", "inAppPurchaseLocalizations"}
            and (item.get("attributes") or {}).get("locale")
        }
    )
    screenshots = []
    for item in included:
        if not isinstance(item, dict) or item.get("type") != "appStoreReviewScreenshots":
            continue
        attrs = item.get("attributes") or {}
        delivery = attrs.get("assetDeliveryState") or {}
        screenshots.append(
            {
                "id": item.get("id"),
                "file_name": attrs.get("fileName"),
                "delivery_state": delivery.get("state") if isinstance(delivery, dict) else None,
            }
        )
    return {
        "included_type_counts": dict(sorted(counts.items())),
        "locales": locales,
        "review_screenshots": screenshots,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare HM1 App Store metadata and review screenshots without submitting for review.")
    parser.add_argument("--screens", required=True)
    parser.add_argument("--output", default="app2-005-hm1-metadata-result.json")
    args = parser.parse_args()

    root = Path(args.screens)
    home = root / "01-home.png"
    premium = root / "02-premium.png"
    if not home.is_file() or not premium.is_file():
        raise RuntimeError("Required screenshots missing")

    result: dict = {
        "task_id": "APP2-005",
        "operation": "prepare_metadata_only",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "app_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "submitted": False,
        "build_selected": False,
    }

    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        app = one(api_get(token, f"/v1/apps/{APP_ID}")[1], "app")
        actual_bundle = (app.get("attributes") or {}).get("bundleId")
        if actual_bundle != BUNDLE_ID:
            raise RuntimeError(f"Target app mismatch: {actual_bundle}")

        version = resolve_version(token)
        version_id = str(version["id"])
        result["version_id"] = version_id
        result["version_string"] = (version.get("attributes") or {}).get("versionString")
        result["version_state"] = state(version)

        localization = resolve_localization(token, version_id)
        localization_id = str(localization["id"])
        patch(
            token,
            f"/v1/appStoreVersionLocalizations/{localization_id}",
            "appStoreVersionLocalizations",
            localization_id,
            attributes={
                "description": DESCRIPTION,
                "keywords": KEYWORDS,
                "promotionalText": PROMO,
                "supportUrl": SUPPORT_URL,
            },
        )
        result.update(ensure_info_metadata(token))

        # Finish every automatable, reversible metadata task before evaluating the
        # human-only App Review contact gate. No build selection or review submit.
        result["app_screenshots"] = upload_app_screenshots(token, localization_id, [home, premium])
        result["lifetime_review_screenshot"] = ensure_review_screenshot(
            token, kind="iap", product_id=LIFETIME_ID, image=premium
        )
        result["monthly_review_screenshot"] = ensure_review_screenshot(
            token, kind="subscription", product_id=MONTHLY_ID, image=premium
        )

        _, iap_payload = api_get(
            token,
            f"/v2/inAppPurchases/{LIFETIME_ID}?include=inAppPurchaseLocalizations,iapPriceSchedule,appStoreReviewScreenshot",
        )
        _, sub_payload = api_get(
            token,
            f"/v1/subscriptions/{MONTHLY_ID}?include=subscriptionLocalizations,prices,appStoreReviewScreenshot",
        )
        lifetime = one(iap_payload, "lifetime")
        monthly = one(sub_payload, "monthly")
        result["lifetime_state_after_metadata"] = state(lifetime)
        result["monthly_state_after_metadata"] = state(monthly)
        result["lifetime_metadata_checklist"] = included_checklist(iap_payload)
        result["monthly_metadata_checklist"] = included_checklist(sub_payload)
        # Keep only non-secret public metadata needed to diagnose ASC state.
        result["monthly_attributes"] = {
            key: (monthly.get("attributes") or {}).get(key)
            for key in ("name", "productId", "subscriptionPeriod", "familySharable", "groupLevel", "state")
        }

        # Human-only gate is deliberately last. It may fail closed while all safe
        # metadata and the diagnostic checklist above remain persisted.
        result["review_detail_id"] = ensure_review_detail(token, version_id)
        result["ok"] = True

        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(
            "PASS: HM1 metadata prepared without submission; "
            f"lifetime={result['lifetime_state_after_metadata']} monthly={result['monthly_state_after_metadata']}"
        )
    except Exception as exc:
        result.update({"ok": False, "error": str(exc), "submitted": False, "build_selected": False})
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
