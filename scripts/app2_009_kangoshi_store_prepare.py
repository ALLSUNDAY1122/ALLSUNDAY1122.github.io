#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6801792293"
BUNDLE_ID = "jp.allsunday1122.kangoshi"
VERSION_ID = "394753bb-7066-4f35-b1a8-ac89c766eff8"
LOCALIZATION_ID = "8e284390-22f1-440b-bed1-766aec600b8a"
MONTHLY_ID = "6802919444"
LIFETIME_ID = "6802961562"
DISPLAY_TYPE = "APP_IPHONE_67"

DESCRIPTION = """看護師国家試験の過去3回分、第115・114・113回を学習用に整理した問題演習アプリです。\n\n収録は720問。必修150問、一般390問、状況設定180問（60症例）を、短時間で繰り返し学べます。\n\n主な機能:\n- 今日のスプリント: 4・8・16問から学習量を設定\n- 必修・一般・状況設定のお試し問題\n- 苦手復習: 3回連続正解で苦手から卒業\n- 分野別学習\n- 第115・114・113回の本番形式\n- 学習履歴・正答率・苦手一覧\n- 図表・模式図を含む問題に対応\n- 公式採点上の除外・複数正答などの特殊採点を反映\n\n無料版では今日の学習と各区分のお試し問題、基本的な学習記録を利用できます。プレミアムでは苦手復習、分野別学習、本番形式、詳細記録を利用できます。\n\n制度・統計・ガイドラインなど更新が必要な項目は一次資料を確認して整備しています。本アプリは厚生労働省その他の公的機関が提供・承認する公式アプリではありません。"""
KEYWORDS = "看護師,国家試験,国試,過去問,必修,一般問題,状況設定,看護,勉強,模試"
PROMO = "必修・一般・状況設定を、今日の短いスプリントで反復。3回連続正解で苦手を卒業し、本番形式まで一つのアプリで進められます。"
SUPPORT_URL = "https://allsunday1122.github.io/kangoshi-sprint/support.html"
MARKETING_URL = "https://allsunday1122.github.io/kangoshi-sprint/"
REVIEW_NOTES = """看護師国家試験の学習用問題演習アプリです。ログインは不要です。\n\n起動後、無料状態で次を確認できます。\n1. ホーム → 「今日のスプリント」\n2. ホーム → 「無料お試し」→ 必修 / 一般 / 状況設定\n3. 模試タブ → 「プレミアムを見る」\n4. 設定タブ → 「購入を復元」\n\nプレミアムはApple StoreKit 2を使用します。月額商品IDは jp.allsunday1122.kangoshi.monthly、買い切り商品IDは jp.allsunday1122.kangoshi.lifetime です。価格表示はStoreKitのProduct.displayPriceを使用し、製品版コードへ価格文字列を固定していません。\n\n購入後に解放される主な機能は、苦手復習、分野別学習、第115・114・113回の本番形式、詳細な学習記録です。購入復元はプレミアム画面と設定画面の双方にあります。\n\n問題は720問（各試験回240問）をアプリ内に同梱しています。外部アカウント、広告、行動解析、独自サーバー通信はありません。学習記録は端末内保存です。\n\n本アプリは厚生労働省その他の公的機関が提供・承認する公式アプリではありません。"""

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
    "medicalOrTreatmentInformation": "FREQUENT_OR_INTENSE",
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
        raise RuntimeError(f"Missing {label}")
    return response["data"]


def upload_operations(operations: list[dict], raw: bytes) -> None:
    for op in operations:
        offset = int(op.get("offset", 0))
        length = int(op.get("length", len(raw) - offset))
        chunk = raw[offset:offset + length]
        if len(chunk) != length:
            raise RuntimeError("Invalid upload byte range")
        req = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        headers = op.get("requestHeaders") or []
        if isinstance(headers, dict):
            headers = [{"name": k, "value": v} for k, v in headers.items()]
        for h in headers:
            req.add_header(str(h["name"]), str(h["value"]))
        with urllib.request.urlopen(req, timeout=120) as response:
            if not (200 <= response.status < 300):
                raise RuntimeError(f"Asset upload failed HTTP {response.status}")


def wait_complete(token: str, path: str, label: str, timeout: int = 180) -> dict:
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        _, payload = api_get(token, path)
        item = one_data(payload, label)
        attrs = item.get("attributes") or {}
        delivery = attrs.get("assetDeliveryState") or {}
        last = delivery.get("state")
        if last == "COMPLETE":
            return item
        if last == "FAILED":
            raise RuntimeError(f"{label} processing failed: {delivery}")
        time.sleep(5)
    raise RuntimeError(f"{label} did not reach COMPLETE; state={last}")


def screenshot_map(root: Path) -> dict[str, Path]:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    out: dict[str, Path] = {}
    for test in manifest:
        for item in test.get("attachments", []):
            suggested = str(item.get("suggestedHumanReadableName", ""))
            exported = item.get("exportedFileName")
            if not exported:
                continue
            for name in ("01-home", "02-question", "03-mock", "04-premium", "05-settings"):
                if suggested.startswith(name):
                    out[name] = root / exported
    return out


def patch(token: str, path: str, typ: str, rid: str, *, attributes=None, relationships=None) -> None:
    data = {"type": typ, "id": rid}
    if attributes is not None:
        data["attributes"] = attributes
    if relationships is not None:
        data["relationships"] = relationships
    api_request(token, path, method="PATCH", payload={"data": data})


def upload_app_screenshots(token: str, files: list[Path]) -> dict:
    _, sets_response = api_get(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=200")
    sets = sets_response.get("data", []) if isinstance(sets_response, dict) else []
    target = next((x for x in sets if (x.get("attributes") or {}).get("screenshotDisplayType") == DISPLAY_TYPE), None)
    created = False
    if target is None:
        payload = {"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":DISPLAY_TYPE},"relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":LOCALIZATION_ID}}}}}
        _, resp = api_request(token, "/v1/appScreenshotSets", method="POST", payload=payload)
        target = one_data(resp, "created app screenshot set")
        created = True
    set_id = target["id"]
    _, existing_response = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
    existing = existing_response.get("data", []) if isinstance(existing_response, dict) else []
    complete = [x for x in existing if (((x.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")) == "COMPLETE"]
    uploaded = []
    if not complete:
        for image_path in files:
            raw = image_path.read_bytes()
            checksum = hashlib.md5(raw).hexdigest()
            payload = {"data":{"type":"appScreenshots","attributes":{"fileSize":len(raw),"fileName":image_path.name},"relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":set_id}}}}}
            _, reserved_response = api_request(token, "/v1/appScreenshots", method="POST", payload=payload)
            reserved = one_data(reserved_response, "reserved app screenshot")
            sid = reserved["id"]
            upload_operations((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
            patch(token, f"/v1/appScreenshots/{sid}", "appScreenshots", sid, attributes={"uploaded":True,"sourceFileChecksum":checksum})
            wait_complete(token, f"/v1/appScreenshots/{sid}", "app screenshot")
            uploaded.append(sid)
    return {"set_id": set_id, "created_set": created, "existing_complete": len(complete), "uploaded": uploaded}


def ensure_review_screenshot(token: str, *, kind: str, product_id: str, image_path: Path) -> dict:
    if kind == "iap":
        rel_path = f"/v2/inAppPurchases/{product_id}/appStoreReviewScreenshot"
        create_path = "/v1/inAppPurchaseAppStoreReviewScreenshots"
        typ = "inAppPurchaseAppStoreReviewScreenshots"
        relationship_name = "inAppPurchaseV2"
        relationship_type = "inAppPurchases"
        read_base = "/v1/inAppPurchaseAppStoreReviewScreenshots/"
    else:
        rel_path = f"/v1/subscriptions/{product_id}/appStoreReviewScreenshot"
        create_path = "/v1/subscriptionAppStoreReviewScreenshots"
        typ = "subscriptionAppStoreReviewScreenshots"
        relationship_name = "subscription"
        relationship_type = "subscriptions"
        read_base = "/v1/subscriptionAppStoreReviewScreenshots/"
    try:
        _, current = api_get(token, rel_path)
        data = current.get("data") if isinstance(current, dict) else None
        if isinstance(data, dict):
            state = (((data.get("attributes") or {}).get("assetDeliveryState") or {}).get("state"))
            if state == "COMPLETE":
                return {"id": data.get("id"), "state": state, "uploaded_new": False}
    except Exception:
        pass
    raw = image_path.read_bytes()
    checksum = hashlib.md5(raw).hexdigest()
    payload = {"data":{"type":typ,"attributes":{"fileSize":len(raw),"fileName":image_path.name},"relationships":{relationship_name:{"data":{"type":relationship_type,"id":product_id}}}}}
    _, reserved_response = api_request(token, create_path, method="POST", payload=payload)
    reserved = one_data(reserved_response, f"reserved {kind} review screenshot")
    rid = reserved["id"]
    upload_operations((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
    patch(token, read_base + rid, typ, rid, attributes={"uploaded":True,"sourceFileChecksum":checksum})
    final = wait_complete(token, read_base + rid, f"{kind} review screenshot")
    state = (((final.get("attributes") or {}).get("assetDeliveryState") or {}).get("state"))
    return {"id": rid, "state": state, "uploaded_new": True}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screens", required=True)
    parser.add_argument("--output", default="app2-009-store-prepare-result.json")
    args = parser.parse_args()
    root = Path(args.screens)
    shots = screenshot_map(root)
    required = ["01-home", "02-question", "03-mock", "04-premium", "05-settings"]
    missing = [x for x in required if x not in shots or not shots[x].is_file()]
    if missing:
        raise RuntimeError(f"Missing required screenshots: {missing}")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, app_response = api_get(token, f"/v1/apps/{APP_ID}")
        app = one_data(app_response, "app")
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app mismatch")
        _, version_response = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}")
        version = one_data(version_response, "version")
        if (version.get("attributes") or {}).get("versionString") != "1.0":
            raise RuntimeError("Target version mismatch")

        patch(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}", "appStoreVersionLocalizations", LOCALIZATION_ID, attributes={
            "description": DESCRIPTION,
            "keywords": KEYWORDS,
            "promotionalText": PROMO,
            "supportUrl": SUPPORT_URL,
            "marketingUrl": MARKETING_URL,
        })
        patch(token, f"/v1/appStoreVersions/{VERSION_ID}", "appStoreVersions", VERSION_ID, attributes={"usesIdfa": False})

        _, beta_response = api_get(token, f"/v1/apps/{APP_ID}/betaAppReviewDetail")
        beta_attrs = one_data(beta_response, "beta review detail").get("attributes") or {}
        contact_keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
        contact = {k: beta_attrs.get(k) for k in contact_keys}
        if not all(contact.values()):
            raise RuntimeError("Existing TestFlight review contact is incomplete")
        review_attrs = {**contact, "demoAccountRequired": False, "notes": REVIEW_NOTES}
        _, review_rel = api_get(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/appStoreReviewDetail")
        review_id = ((review_rel or {}).get("data") or {}).get("id") if isinstance(review_rel, dict) else None
        review_created = False
        if review_id:
            patch(token, f"/v1/appStoreReviewDetails/{review_id}", "appStoreReviewDetails", review_id, attributes=review_attrs)
        else:
            payload = {"data":{"type":"appStoreReviewDetails","attributes":review_attrs,"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":VERSION_ID}}}}}
            _, created = api_request(token, "/v1/appStoreReviewDetails", method="POST", payload=payload)
            review_id = one_data(created, "created review detail")["id"]
            review_created = True

        _, infos_response = api_get(token, f"/v1/apps/{APP_ID}/appInfos?limit=20")
        infos = infos_response.get("data", []) if isinstance(infos_response, dict) else []
        info = next((x for x in infos if (x.get("attributes") or {}).get("appStoreState") in (None, "PREPARE_FOR_SUBMISSION", "READY_FOR_SALE")), infos[0] if infos else None)
        if info:
            info_id = info["id"]
            patch(token, f"/v1/appInfos/{info_id}", "appInfos", info_id, relationships={
                "primaryCategory": {"data":{"type":"appCategories","id":"EDUCATION"}},
                "secondaryCategory": {"data":{"type":"appCategories","id":"MEDICAL"}},
            })
            try:
                _, age_response = api_get(token, f"/v1/appInfos/{info_id}/ageRatingDeclaration")
                age = one_data(age_response, "age rating declaration")
                patch(token, f"/v1/ageRatingDeclarations/{age['id']}", "ageRatingDeclarations", age["id"], attributes=AGE_RATING_ATTRIBUTES)
            except Exception:
                pass

        app_shots = upload_app_screenshots(token, [shots[x] for x in required])
        lifetime_shot = ensure_review_screenshot(token, kind="iap", product_id=LIFETIME_ID, image_path=shots["04-premium"])
        monthly_shot = ensure_review_screenshot(token, kind="subscription", product_id=MONTHLY_ID, image_path=shots["04-premium"])

        _, iap_after = api_get(token, f"/v2/inAppPurchases/{LIFETIME_ID}")
        _, sub_after = api_get(token, f"/v1/subscriptions/{MONTHLY_ID}")
        result = {
            "task_id": "APP2-009",
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "app_id": APP_ID,
            "version_id": VERSION_ID,
            "metadata_updated": True,
            "review_detail_id": review_id,
            "review_detail_created": review_created,
            "app_screenshots": app_shots,
            "lifetime_review_screenshot": lifetime_shot,
            "monthly_review_screenshot": monthly_shot,
            "lifetime_state": (one_data(iap_after, "lifetime after").get("attributes") or {}).get("state"),
            "monthly_state": (one_data(sub_after, "monthly after").get("attributes") or {}).get("state"),
            "submission_performed": False,
            "ok": True,
        }
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("PASS: Kangoshi App Store metadata/screenshots/IAP review screenshots prepared")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
