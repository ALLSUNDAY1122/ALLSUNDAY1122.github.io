#!/usr/bin/env python3
"""Reconcile Otsu4 IAP metadata with the audited 360-question release contract.

This script updates metadata only. It never creates/submits an App Store review
submission and never uploads a build.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799755566"
BUNDLE_ID = "jp.allsunday1122.otsu4"
IAP_ID = "6806477067"
PRODUCT_ID = "jp.allsunday1122.otsu4.premium"
PRODUCT_NAME = "乙4 プレミアム"
PRODUCT_DESCRIPTION = "全360問・模擬試験3回・全範囲の復習を解放します。"
REVIEW_NOTE = (
    "アプリ内の「設定」→「Premium」から購入画面を開けます。"
    "購入後は全360問、模擬試験3回、全範囲の復習機能が解放されます。"
)
OUT = Path("automation/app2-007-otsu4-iap-contract-reconcile-result.json")


def many(payload):
    data = payload.get("data", []) if isinstance(payload, dict) else []
    return data if isinstance(data, list) else ([] if data is None else [data])


def request(token, path, method="GET", payload=None):
    if method == "GET":
        status, body = api_get(token, path)
    else:
        status, body = api_request(token, path, method=method, payload=payload)
    if not 200 <= status < 300:
        raise RuntimeError(f"ASC {method} {path} HTTP {status}")
    return body


def main():
    cleanup = None
    actions = []
    result = {"ok": False, "app_id": APP_ID, "iap_id": IAP_ID, "product_id": PRODUCT_ID}
    try:
        key, cleanup = load_private_key()
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key)

        app = request(token, f"/v1/apps/{APP_ID}").get("data") or {}
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("App/bundle mismatch")

        product = request(token, f"/v2/inAppPurchases/{IAP_ID}").get("data") or {}
        pa = product.get("attributes") or {}
        if pa.get("productId") != PRODUCT_ID:
            raise RuntimeError("IAP productId mismatch")
        if pa.get("state") not in {"PREPARE_FOR_SUBMISSION", "READY_TO_SUBMIT", "READY_FOR_REVIEW"}:
            raise RuntimeError(f"IAP is not safely editable: {pa.get('state')}")

        if pa.get("reviewNote") != REVIEW_NOTE:
            request(token, f"/v2/inAppPurchases/{IAP_ID}", "PATCH", {
                "data": {"type": "inAppPurchases", "id": IAP_ID, "attributes": {"reviewNote": REVIEW_NOTE}}
            })
            actions.append("review_note_updated")

        detail = request(token, f"/v2/inAppPurchases/{IAP_ID}?include=versions")
        versions = [x for x in detail.get("included", []) if x.get("type") == "inAppPurchaseVersions"]
        editable = [x for x in versions if (x.get("attributes") or {}).get("state") in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}]
        if not editable:
            # READY_TO_SUBMIT parent can still expose a draft version without state in include; fall back to newest included.
            editable = versions
        if not editable:
            raise RuntimeError("No IAP version available for localization readback")
        version_id = str(editable[-1]["id"])

        loc_payload = request(token, f"/v1/inAppPurchaseVersions/{version_id}/localizations?limit=50")
        ja = next((x for x in many(loc_payload) if (x.get("attributes") or {}).get("locale") == "ja"), None)
        if not ja:
            raise RuntimeError("Japanese IAP localization missing; bootstrap must create it first")
        ja_id = str(ja["id"])
        ja_attrs = ja.get("attributes") or {}
        if ja_attrs.get("name") != PRODUCT_NAME or ja_attrs.get("description") != PRODUCT_DESCRIPTION:
            request(token, f"/v2/inAppPurchaseLocalizations/{ja_id}", "PATCH", {
                "data": {
                    "type": "inAppPurchaseLocalizations",
                    "id": ja_id,
                    "attributes": {"name": PRODUCT_NAME, "description": PRODUCT_DESCRIPTION},
                }
            })
            actions.append("ja_localization_updated")

        product_after = request(token, f"/v2/inAppPurchases/{IAP_ID}").get("data") or {}
        loc_after = request(token, f"/v1/inAppPurchaseVersions/{version_id}/localizations?limit=50")
        ja_after = next((x for x in many(loc_after) if (x.get("attributes") or {}).get("locale") == "ja"), None)
        paa = product_after.get("attributes") or {}
        laa = (ja_after or {}).get("attributes") or {}
        if paa.get("reviewNote") != REVIEW_NOTE:
            raise RuntimeError("IAP reviewNote read-back mismatch")
        if laa.get("name") != PRODUCT_NAME or laa.get("description") != PRODUCT_DESCRIPTION:
            raise RuntimeError("IAP Japanese localization read-back mismatch")
        if "720" in json.dumps({"reviewNote": paa.get("reviewNote"), "localization": laa}, ensure_ascii=False) or "6回" in json.dumps({"reviewNote": paa.get("reviewNote"), "localization": laa}, ensure_ascii=False):
            raise RuntimeError("Stale 720/6 claim remains after reconciliation")

        result.update({"ok": True, "actions": actions, "iap_state": paa.get("state"), "version_id": version_id, "metadata_contract": "360_questions_3_mocks"})
    except Exception as exc:
        result.update({"actions": actions, "error": str(exc)})
        raise
    finally:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
