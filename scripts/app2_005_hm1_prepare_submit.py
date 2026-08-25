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

APP_ID = "6799581662"
BUNDLE_ID = "jp.allsunday1122.healthmanager1"
BUILD_VERSION = "2026082501"
MONTHLY_ID = "6804373671"
LIFETIME_ID = "6799583540"
GROUP_ID = "22329151"
DISPLAY_TYPE = "APP_IPHONE_67"

DESCRIPTION = """第一種衛生管理者試験の学習用問題演習アプリです。

公表問題の出題論点と現行法令を確認し、独自に作成・監査した264問を収録しています。公表回対応3セットと追加演習3セットを、44問通し・科目別・短時間のスプリントで繰り返し学習できます。

主な機能:
- 今日のスプリント（4・8・16問）
- 関係法令・労働衛生・労働生理の科目別学習
- 公表回対応3セット＋追加演習3セット
- 44問通し演習
- 苦手復習と学習記録
- プレミアムで全264問を利用

プレミアムは月額200円（対象者は7日間無料トライアル）または買い切り800円です。購入・復元はAppleのStoreKit 2を使用します。

本アプリは厚生労働省、公益財団法人安全衛生技術試験協会その他の公的機関が提供・承認する公式アプリではありません。"""
KEYWORDS = "第一種衛生管理者,衛生管理者,労働衛生,関係法令,労働生理,資格,試験,問題集,模試,過去問"
PROMO = "公表回対応＋追加演習の全264問。短いスプリントから44問通しまで、第一種衛生管理者の学習を一つにまとめました。"
SUPPORT_URL = "https://allsunday1122.github.io/health-manager-1/support.html"
PRIVACY_URL = "https://allsunday1122.github.io/health-manager-1/privacy.html"
REVIEW_NOTES = """第一種衛生管理者試験の学習用問題演習アプリです。ログインは不要です。

確認手順:
1. 起動後ホームに「プレミアム」が表示されます。
2. 「プレミアム」をタップすると、月額 ¥200/月（対象者は7日無料）と買い切り ¥800 が表示されます。
3. 購入後は全264問、追加演習、苦手復習などのプレミアム機能を利用できます。
4. 購入画面から「購入を復元」を実行できます。

StoreKit 2の商品ID:
- jp.allsunday1122.healthmanager1.monthly
- jp.allsunday1122.healthmanager1.lifetime

Appleの購入シートが実際の取引価格の最終確認画面です。外部決済、広告、行動解析、独自アカウント、独自サーバー通信はありません。学習記録は端末内保存です。

収録問題は公表問題の全文転載ではなく、出題論点・一次資料・現行法令を確認して独自作成しています。本アプリは公的機関の公式アプリではありません。"""

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

ACTIVE_SUBMISSION_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"}
SUBMITTED_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}
REVIEWABLE_VERSION_STATES = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}


def one(payload: object, label: str) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"Missing {label}")
    return payload["data"]


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", [])
    return data if isinstance(data, list) else ([] if data is None else [data])


def state(resource: dict) -> str | None:
    attrs = resource.get("attributes") or {}
    return attrs.get("state") or attrs.get("appStoreState") or attrs.get("appVersionState")


def request_ok(token: str, path: str, method: str, payload: dict) -> dict:
    status, response = api_request(token, path, method=method, payload=payload)
    if not (200 <= status < 300):
        raise RuntimeError(f"ASC {method} {path} returned HTTP {status}")
    return response


def patch(token: str, path: str, typ: str, rid: str, *, attributes=None, relationships=None) -> None:
    data: dict = {"type": typ, "id": rid}
    if attributes is not None:
        data["attributes"] = attributes
    if relationships is not None:
        data["relationships"] = relationships
    request_ok(token, path, "PATCH", {"data": data})


def upload_operations(operations: list[dict], raw: bytes) -> None:
    for op in operations:
        offset = int(op.get("offset", 0))
        length = int(op.get("length", len(raw) - offset))
        chunk = raw[offset:offset + length]
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
        item = one(payload, label)
        delivery = ((item.get("attributes") or {}).get("assetDeliveryState") or {})
        last = delivery.get("state")
        if last == "COMPLETE":
            return item
        if last == "FAILED":
            raise RuntimeError(f"{label} processing failed: {delivery}")
        time.sleep(5)
    raise RuntimeError(f"{label} did not reach COMPLETE; state={last}")


def resolve_version(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
    versions = [x for x in many(payload) if (x.get("attributes") or {}).get("platform") == "IOS"]
    reviewable = [x for x in versions if state(x) in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}]
    if len(reviewable) != 1:
        raise RuntimeError(f"Expected exactly one current iOS App Store version; found {[(x.get('id'), state(x), (x.get('attributes') or {}).get('versionString')) for x in reviewable]}")
    return reviewable[0]


def resolve_localization(token: str, version_id: str) -> dict:
    _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    locs = many(payload)
    ja = next((x for x in locs if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    if ja:
        return ja
    create = {"data":{"type":"appStoreVersionLocalizations","attributes":{"locale":"ja"},"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":version_id}}}}}
    return one(request_ok(token, "/v1/appStoreVersionLocalizations", "POST", create), "created ja localization")


def ensure_review_detail(token: str, version_id: str) -> str:
    try:
        _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        detail = one(payload, "review detail")
        current = detail.get("attributes") or {}
    except Exception:
        detail = None
        current = {}

    contact_keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
    contact = {k: current.get(k) for k in contact_keys}
    if not all(contact.values()):
        _, beta_payload = api_get(token, f"/v1/apps/{APP_ID}/betaAppReviewDetail")
        beta = one(beta_payload, "beta review detail").get("attributes") or {}
        contact = {k: beta.get(k) for k in contact_keys}
    if not all(contact.values()):
        raise RuntimeError("App Review contact is incomplete; real contact data is required")

    attrs = {**contact, "demoAccountRequired": False, "notes": REVIEW_NOTES}
    if detail:
        rid = str(detail["id"])
        patch(token, f"/v1/appStoreReviewDetails/{rid}", "appStoreReviewDetails", rid, attributes=attrs)
        return rid
    payload = {"data":{"type":"appStoreReviewDetails","attributes":attrs,"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":version_id}}}}}
    return str(one(request_ok(token, "/v1/appStoreReviewDetails", "POST", payload), "created review detail")["id"])


def ensure_info_metadata(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/appInfos?limit=20")
    infos = many(payload)
    if not infos:
        raise RuntimeError("AppInfo missing")
    info = infos[0]
    info_id = str(info["id"])
    try:
        patch(token, f"/v1/appInfos/{info_id}", "appInfos", info_id,
              attributes={"contentRightsDeclaration":"DOES_NOT_USE_THIRD_PARTY_CONTENT"},
              relationships={"primaryCategory":{"data":{"type":"appCategories","id":"EDUCATION"}}})
    except Exception:
        patch(token, f"/v1/appInfos/{info_id}", "appInfos", info_id,
              relationships={"primaryCategory":{"data":{"type":"appCategories","id":"EDUCATION"}}})

    _, loc_payload = api_get(token, f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")
    locs = many(loc_payload)
    ja = next((x for x in locs if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    if ja:
        patch(token, f"/v1/appInfoLocalizations/{ja['id']}", "appInfoLocalizations", str(ja["id"]), attributes={"privacyPolicyUrl":PRIVACY_URL})
    else:
        payload = {"data":{"type":"appInfoLocalizations","attributes":{"locale":"ja","name":"第一種衛生管理者｜学びスプリント","privacyPolicyUrl":PRIVACY_URL},"relationships":{"appInfo":{"data":{"type":"appInfos","id":info_id}}}}}
        request_ok(token, "/v1/appInfoLocalizations", "POST", payload)

    age_status = "unchanged"
    try:
        _, age_payload = api_get(token, f"/v1/appInfos/{info_id}/ageRatingDeclaration")
        age = one(age_payload, "age rating declaration")
        patch(token, f"/v1/ageRatingDeclarations/{age['id']}", "ageRatingDeclarations", str(age["id"]), attributes=AGE_RATING_ATTRIBUTES)
        age_status = "updated"
    except Exception as exc:
        age_status = f"existing-or-api-not-required: {str(exc)[:160]}"
    return {"app_info_id": info_id, "age_rating": age_status}


def upload_app_screenshots(token: str, localization_id: str, files: list[Path]) -> dict:
    _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200")
    sets = many(sets_payload)
    target = next((x for x in sets if (x.get("attributes") or {}).get("screenshotDisplayType") == DISPLAY_TYPE), None)
    if target is None:
        payload = {"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":DISPLAY_TYPE},"relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":localization_id}}}}}
        target = one(request_ok(token, "/v1/appScreenshotSets", "POST", payload), "created screenshot set")
    set_id = str(target["id"])
    _, existing_payload = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
    existing = many(existing_payload)
    for item in existing:
        try:
            api_request(token, f"/v1/appScreenshots/{item['id']}", method="DELETE")
        except Exception:
            pass
    uploaded = []
    for image in files:
        raw = image.read_bytes()
        checksum = hashlib.md5(raw).hexdigest()
        payload = {"data":{"type":"appScreenshots","attributes":{"fileSize":len(raw),"fileName":image.name},"relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":set_id}}}}}
        reserved = one(request_ok(token, "/v1/appScreenshots", "POST", payload), "reserved app screenshot")
        sid = str(reserved["id"])
        upload_operations((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
        patch(token, f"/v1/appScreenshots/{sid}", "appScreenshots", sid, attributes={"uploaded":True,"sourceFileChecksum":checksum})
        wait_complete(token, f"/v1/appScreenshots/{sid}", "app screenshot")
        uploaded.append(sid)
    return {"set_id": set_id, "uploaded": uploaded}


def ensure_review_screenshot(token: str, *, kind: str, product_id: str, image: Path) -> dict:
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
            delivery = ((data.get("attributes") or {}).get("assetDeliveryState") or {})
            if delivery.get("state") == "COMPLETE":
                return {"id": data.get("id"), "state": "COMPLETE", "uploaded_new": False}
    except Exception:
        pass
    raw = image.read_bytes()
    checksum = hashlib.md5(raw).hexdigest()
    payload = {"data":{"type":typ,"attributes":{"fileSize":len(raw),"fileName":image.name},"relationships":{relationship_name:{"data":{"type":relationship_type,"id":product_id}}}}}
    reserved = one(request_ok(token, create_path, "POST", payload), f"reserved {kind} review screenshot")
    rid = str(reserved["id"])
    upload_operations((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
    patch(token, read_base + rid, typ, rid, attributes={"uploaded":True,"sourceFileChecksum":checksum})
    final = wait_complete(token, read_base + rid, f"{kind} review screenshot")
    return {"id": rid, "state": (((final.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")), "uploaded_new": True}


def select_build(token: str, version_id: str) -> str:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/builds?limit=50")
    target = next((x for x in many(payload) if (x.get("attributes") or {}).get("version") == BUILD_VERSION and (x.get("attributes") or {}).get("processingState") == "VALID"), None)
    if not target:
        raise RuntimeError(f"VALID Build {BUILD_VERSION} not found")
    build_id = str(target["id"])
    patch(token, f"/v1/appStoreVersions/{version_id}", "appStoreVersions", version_id,
          attributes={"usesIdfa":False},
          relationships={"build":{"data":{"type":"builds","id":build_id}}})
    _, rel = api_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
    selected = ((rel or {}).get("data") or {}).get("id") if isinstance(rel, dict) else None
    if selected != build_id:
        raise RuntimeError(f"Build selection mismatch: {selected} != {build_id}")
    return build_id


def ensure_product_version(token: str, *, list_path: str, create_path: str, typ: str,
                           relationship_name: str, relationship_type: str, parent_id: str) -> dict:
    _, payload = api_get(token, list_path)
    versions = many(payload)
    reviewable = [v for v in versions if state(v) in REVIEWABLE_VERSION_STATES]
    if reviewable:
        return reviewable[0]
    already = [v for v in versions if state(v) in {"WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED", "ACCEPTED"}]
    if already:
        return already[0]
    body = {"data":{"type":typ,"relationships":{relationship_name:{"data":{"type":relationship_type,"id":parent_id}}}}}
    return one(request_ok(token, create_path, "POST", body), f"created {typ}")


def ensure_submission(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200")
    active = [s for s in many(payload) if state(s) in ACTIVE_SUBMISSION_STATES]
    submitted = [s for s in active if state(s) in SUBMITTED_STATES]
    if submitted:
        return submitted[0]
    draft = next((s for s in active if state(s) == "READY_FOR_REVIEW"), None)
    if draft:
        return draft
    body = {"data":{"type":"reviewSubmissions","attributes":{"platform":"IOS"},"relationships":{"app":{"data":{"type":"apps","id":APP_ID}}}}}
    return one(request_ok(token, "/v1/reviewSubmissions", "POST", body), "created review submission")


def ensure_item(token: str, submission_id: str, rel_name: str, rel_type: str, rid: str) -> None:
    _, payload = api_get(token, f"/v1/reviewSubmissions/{submission_id}/items?limit=200&include=appStoreVersion,inAppPurchaseVersion,subscriptionVersion,subscriptionGroupVersion")
    included = payload.get("included", []) if isinstance(payload, dict) else []
    if any(x.get("type") == rel_type and x.get("id") == rid for x in included):
        return
    body = {"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":submission_id}},rel_name:{"data":{"type":rel_type,"id":rid}}}}}
    request_ok(token, "/v1/reviewSubmissionItems", "POST", body)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screens", required=True)
    parser.add_argument("--output", default="app2-005-hm1-submit-result.json")
    args = parser.parse_args()
    root = Path(args.screens)
    home = root / "01-home.png"
    premium = root / "02-premium.png"
    if not home.is_file() or not premium.is_file():
        raise RuntimeError("Required screenshots missing")

    result: dict = {"task_id":"APP2-005","completed_at":datetime.now(timezone.utc).isoformat(),"app_id":APP_ID,"bundle_id":BUNDLE_ID,"build":BUILD_VERSION,"release_performed":False}
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        app = one(api_get(token, f"/v1/apps/{APP_ID}")[1], "app")
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app mismatch")

        version = resolve_version(token)
        version_id = str(version["id"])
        result["version_id"] = version_id
        result["version_string"] = (version.get("attributes") or {}).get("versionString")
        result["pre_version_state"] = state(version)
        localization = resolve_localization(token, version_id)
        localization_id = str(localization["id"])
        patch(token, f"/v1/appStoreVersionLocalizations/{localization_id}", "appStoreVersionLocalizations", localization_id,
              attributes={"description":DESCRIPTION,"keywords":KEYWORDS,"promotionalText":PROMO,"supportUrl":SUPPORT_URL})
        result.update(ensure_info_metadata(token))
        result["review_detail_id"] = ensure_review_detail(token, version_id)
        result["build_id"] = select_build(token, version_id)
        result["app_screenshots"] = upload_app_screenshots(token, localization_id, [home, premium])
        result["lifetime_review_screenshot"] = ensure_review_screenshot(token, kind="iap", product_id=LIFETIME_ID, image=premium)
        result["monthly_review_screenshot"] = ensure_review_screenshot(token, kind="subscription", product_id=MONTHLY_ID, image=premium)

        _, iap_payload = api_get(token, f"/v2/inAppPurchases/{LIFETIME_ID}")
        _, sub_payload = api_get(token, f"/v1/subscriptions/{MONTHLY_ID}")
        result["lifetime_state_after_metadata"] = state(one(iap_payload, "lifetime"))
        result["monthly_state_after_metadata"] = state(one(sub_payload, "monthly"))

        iap_version = ensure_product_version(token, list_path=f"/v2/inAppPurchases/{LIFETIME_ID}/versions?limit=50", create_path="/v1/inAppPurchaseVersions", typ="inAppPurchaseVersions", relationship_name="inAppPurchase", relationship_type="inAppPurchases", parent_id=LIFETIME_ID)
        sub_version = ensure_product_version(token, list_path=f"/v1/subscriptions/{MONTHLY_ID}/versions?limit=50", create_path="/v1/subscriptionVersions", typ="subscriptionVersions", relationship_name="subscription", relationship_type="subscriptions", parent_id=MONTHLY_ID)
        group_version = ensure_product_version(token, list_path=f"/v1/subscriptionGroups/{GROUP_ID}/versions?limit=50", create_path="/v1/subscriptionGroupVersions", typ="subscriptionGroupVersions", relationship_name="subscriptionGroup", relationship_type="subscriptionGroups", parent_id=GROUP_ID)
        result["iap_version"] = {"id":iap_version.get("id"),"state":state(iap_version)}
        result["subscription_version"] = {"id":sub_version.get("id"),"state":state(sub_version)}
        result["subscription_group_version"] = {"id":group_version.get("id"),"state":state(group_version)}

        submission = ensure_submission(token)
        submission_id = str(submission["id"])
        before = state(submission)
        result["review_submission_id"] = submission_id
        result["pre_submit_state"] = before
        if before in SUBMITTED_STATES:
            result.update({"submitted":True,"idempotent":True,"review_submission_state":before})
        else:
            ensure_item(token, submission_id, "appStoreVersion", "appStoreVersions", version_id)
            ensure_item(token, submission_id, "inAppPurchaseVersion", "inAppPurchaseVersions", str(iap_version["id"]))
            ensure_item(token, submission_id, "subscriptionVersion", "subscriptionVersions", str(sub_version["id"]))
            ensure_item(token, submission_id, "subscriptionGroupVersion", "subscriptionGroupVersions", str(group_version["id"]))
            patch(token, f"/v1/reviewSubmissions/{submission_id}", "reviewSubmissions", submission_id, attributes={"submitted":True})
            after = one(api_get(token, f"/v1/reviewSubmissions/{submission_id}")[1], "submission after")
            after_state = state(after)
            result.update({"submitted":after_state in SUBMITTED_STATES,"idempotent":False,"review_submission_state":after_state})
            if after_state not in SUBMITTED_STATES:
                raise RuntimeError(f"Unexpected submission state after submit: {after_state}")

        final_version = one(api_get(token, f"/v1/appStoreVersions/{version_id}")[1], "version after")
        result["app_store_version_state_after"] = state(final_version)
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        print(f"PASS: APP2-005 submitted; state={result['review_submission_state']}")
    except Exception as exc:
        result.update({"submitted":False,"error":str(exc)})
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
