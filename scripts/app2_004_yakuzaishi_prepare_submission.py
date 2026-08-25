#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import struct
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6799753724"
BUNDLE_ID = "jp.allsunday1122.yakuzaishi"
TARGET_VERSION = "1.0"
TARGET_BUILD = "5"
SUPPORT_URL = "https://allsunday1122.github.io/pharmacist-manabi-sprint/support.html"
PRIVACY_URL = "https://allsunday1122.github.io/pharmacist-manabi-sprint/privacy.html"

DESCRIPTION = "薬剤師国家試験の直近3回分を収録した学習アプリです。第111回・第110回・第109回の採点対象1,031問を追加購入なしで利用できます。今日のスプリントは4・8・16問から選択でき、分野別は約20問ずつのセットで学習できます。間違えた問題は苦手として記録し、3回連続で正解すると苦手から卒業します。公式問題画像は全画面表示・ピンチズーム・ドラッグに対応。模擬試験、学習履歴、5週間ヒートマップ、試験日カウントダウン、JSONバックアップ、オフライン学習にも対応しています。厚生労働省が公開する薬剤師国家試験資料を出典として利用しています。本アプリは厚生労働省の公式アプリではなく、試験学習用です。診断・治療・調剤・服薬指導等の医療上の判断を提供するものではありません。"
KEYWORDS = "薬剤師,薬剤師国家試験,国試,薬学,過去問,必須,理論,実践,資格,学習"
REVIEW_NOTES = """薬剤師国家試験の学習用問題演習アプリです。ログイン、アカウント登録、広告、外部決済、アプリ内課金はありません。第111回・第110回・第109回の採点対象1,031問を追加購入なしで利用できます。

確認手順:
1. ホームの「今日のスプリント」から4・8・16問の短時間学習を開始できます。
2. 「分野から解く」では分野を選択後、約20問ずつのセットを最後まで解けます。
3. 模試タブでは第111・110・109回の必須・理論・実践を選択できます。
4. 公式紙面画像を使う問題は、画像タップ後に全画面表示・ピンチズーム・ドラッグ・ダブルタップ拡大ができます。
5. 学習記録、苦手復習、JSONバックアップは端末内で利用できます。

問題・図版はアプリ内に同梱し、学習本体はオフラインで利用できます。厚生労働省公開の薬剤師国家試験資料を出典として利用していますが、本アプリは厚生労働省の公式アプリではありません。また、診断・治療・調剤・服薬指導等の医療上の判断を提供するものではありません。"""

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
    if not 200 <= status < 300:
        raise RuntimeError(f"ASC {method} {path} returned HTTP {status}")
    return response


def patch(token: str, path: str, typ: str, rid: str, *, attributes=None, relationships=None) -> None:
    data: dict = {"type": typ, "id": rid}
    if attributes is not None:
        data["attributes"] = attributes
    if relationships is not None:
        data["relationships"] = relationships
    request_ok(token, path, "PATCH", {"data": data})


def resolve_version(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/appStoreVersions?limit=50")
    versions = [x for x in many(payload) if (x.get("attributes") or {}).get("platform") == "IOS" and (x.get("attributes") or {}).get("versionString") == TARGET_VERSION]
    if len(versions) != 1:
        raise RuntimeError(f"Expected one iOS {TARGET_VERSION} version; found {[(x.get('id'), state(x)) for x in versions]}")
    if state(versions[0]) not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}:
        raise RuntimeError(f"Unexpected version state: {state(versions[0])}")
    return versions[0]


def resolve_localization(token: str, version_id: str) -> dict:
    _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    loc = next((x for x in many(payload) if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    if not loc:
        raise RuntimeError("Japanese App Store version localization missing")
    return loc


def ensure_review_detail(token: str, version_id: str) -> str:
    detail = None
    current: dict = {}
    try:
        _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        detail = one(payload, "review detail")
        current = detail.get("attributes") or {}
    except Exception:
        pass

    keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
    contact = {k: current.get(k) for k in keys}
    if not all(contact.values()):
        _, beta_payload = api_get(token, f"/v1/apps/{APP_ID}/betaAppReviewDetail")
        beta = one(beta_payload, "beta review detail").get("attributes") or {}
        contact = {k: beta.get(k) for k in keys}
    if not all(contact.values()):
        raise RuntimeError("Real App Review contact data is incomplete")

    attrs = {**contact, "demoAccountRequired": False, "notes": REVIEW_NOTES}
    if detail:
        rid = str(detail["id"])
        patch(token, f"/v1/appStoreReviewDetails/{rid}", "appStoreReviewDetails", rid, attributes=attrs)
        return rid
    payload = {"data":{"type":"appStoreReviewDetails","attributes":attrs,"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":version_id}}}}}
    return str(one(request_ok(token, "/v1/appStoreReviewDetails", "POST", payload), "created review detail")["id"])


def ensure_app_info(token: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/appInfos?limit=20")
    infos = many(payload)
    if not infos:
        raise RuntimeError("AppInfo missing")
    info_id = str(infos[0]["id"])
    try:
        patch(token, f"/v1/appInfos/{info_id}", "appInfos", info_id, relationships={"primaryCategory":{"data":{"type":"appCategories","id":"EDUCATION"}}})
    except Exception:
        pass

    _, loc_payload = api_get(token, f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")
    loc = next((x for x in many(loc_payload) if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    if loc:
        patch(token, f"/v1/appInfoLocalizations/{loc['id']}", "appInfoLocalizations", str(loc["id"]), attributes={"privacyPolicyUrl": PRIVACY_URL})

    age_status = "unchanged"
    try:
        _, age_payload = api_get(token, f"/v1/appInfos/{info_id}/ageRatingDeclaration")
        age = one(age_payload, "age rating")
        patch(token, f"/v1/ageRatingDeclarations/{age['id']}", "ageRatingDeclarations", str(age["id"]), attributes=AGE_RATING_ATTRIBUTES)
        age_status = "updated"
    except Exception as exc:
        age_status = "api-unavailable-or-existing: " + str(exc)[:160]
    return {"app_info_id": info_id, "age_rating": age_status}


def wait_valid_build(token: str, timeout: int = 1200) -> dict:
    deadline = time.time() + timeout
    last = []
    while time.time() < deadline:
        _, payload = api_get(token, f"/v1/apps/{APP_ID}/builds?sort=-uploadedDate&limit=50")
        builds = many(payload)
        last = [((x.get("attributes") or {}).get("version"), (x.get("attributes") or {}).get("processingState")) for x in builds[:10]]
        for build in builds:
            attrs = build.get("attributes") or {}
            if str(attrs.get("version")) == TARGET_BUILD and attrs.get("processingState") == "VALID":
                return build
        time.sleep(15)
    raise RuntimeError(f"VALID Build {TARGET_BUILD} not found; latest={last}")


def attach_build(token: str, version_id: str, build_id: str) -> None:
    patch(token, f"/v1/appStoreVersions/{version_id}", "appStoreVersions", version_id, relationships={"build":{"data":{"type":"builds","id":build_id}}})
    _, rel = api_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
    selected = ((rel or {}).get("data") or {}).get("id") if isinstance(rel, dict) else None
    if selected != build_id:
        raise RuntimeError(f"Build selection read-back mismatch: {selected} != {build_id}")


def png_size(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError("Screenshot is not PNG")
    return struct.unpack(">II", raw[16:24])


def display_type_for(path: Path) -> str:
    size = png_size(path)
    mapping = {
        (1320, 2868): "APP_IPHONE_69",
        (1290, 2796): "APP_IPHONE_67",
        (1284, 2778): "APP_IPHONE_65",
        (1242, 2688): "APP_IPHONE_65",
    }
    if size not in mapping:
        raise RuntimeError(f"Unsupported App Store screenshot dimensions: {size}")
    return mapping[size]


def upload_ops(operations: list[dict], raw: bytes) -> None:
    for op in operations:
        offset = int(op.get("offset", 0)); length = int(op.get("length", len(raw) - offset))
        chunk = raw[offset:offset+length]
        req = urllib.request.Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        headers = op.get("requestHeaders") or []
        if isinstance(headers, dict):
            headers = [{"name": k, "value": v} for k, v in headers.items()]
        for h in headers:
            req.add_header(str(h["name"]), str(h["value"]))
        with urllib.request.urlopen(req, timeout=120) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(f"Screenshot upload failed HTTP {response.status}")


def wait_asset(token: str, sid: str, timeout: int = 180) -> None:
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        _, payload = api_get(token, f"/v1/appScreenshots/{sid}")
        item = one(payload, "app screenshot")
        last = (((item.get("attributes") or {}).get("assetDeliveryState") or {}).get("state"))
        if last == "COMPLETE": return
        if last == "FAILED": raise RuntimeError("App screenshot processing failed")
        time.sleep(5)
    raise RuntimeError(f"Screenshot did not reach COMPLETE; state={last}")


def ensure_screenshot(token: str, localization_id: str, image: Path) -> dict:
    display_type = display_type_for(image)
    _, sets_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200")
    sets = many(sets_payload)
    target = next((x for x in sets if (x.get("attributes") or {}).get("screenshotDisplayType") == display_type), None)
    if target is None:
        payload = {"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":display_type},"relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":localization_id}}}}}
        target = one(request_ok(token, "/v1/appScreenshotSets", "POST", payload), "created screenshot set")
    set_id = str(target["id"])
    _, existing_payload = api_get(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")
    complete = [x for x in many(existing_payload) if (((x.get("attributes") or {}).get("assetDeliveryState") or {}).get("state")) == "COMPLETE"]
    if complete:
        return {"display_type": display_type, "set_id": set_id, "complete": len(complete), "uploaded_new": False}
    raw = image.read_bytes(); checksum = hashlib.md5(raw).hexdigest()
    payload = {"data":{"type":"appScreenshots","attributes":{"fileSize":len(raw),"fileName":image.name},"relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":set_id}}}}}
    reserved = one(request_ok(token, "/v1/appScreenshots", "POST", payload), "reserved screenshot")
    sid = str(reserved["id"])
    upload_ops((reserved.get("attributes") or {}).get("uploadOperations") or [], raw)
    patch(token, f"/v1/appScreenshots/{sid}", "appScreenshots", sid, attributes={"uploaded": True, "sourceFileChecksum": checksum})
    wait_asset(token, sid)
    return {"display_type": display_type, "set_id": set_id, "complete": 1, "uploaded_new": True, "screenshot_id": sid}


def ensure_submission_draft(token: str, version_id: str) -> dict:
    _, payload = api_get(token, f"/v1/apps/{APP_ID}/reviewSubmissions?limit=200")
    submissions = many(payload)
    active = [x for x in submissions if state(x) in {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}]
    submitted = next((x for x in active if state(x) in {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}), None)
    if submitted:
        return {"id": str(submitted["id"]), "state": state(submitted), "already_submitted": True}
    draft = next((x for x in active if state(x) == "READY_FOR_REVIEW"), None)
    if not draft:
        payload = {"data":{"type":"reviewSubmissions","attributes":{"platform":"IOS"},"relationships":{"app":{"data":{"type":"apps","id":APP_ID}}}}}
        draft = one(request_ok(token, "/v1/reviewSubmissions", "POST", payload), "created review submission")
    sid = str(draft["id"])
    _, items_payload = api_get(token, f"/v1/reviewSubmissions/{sid}/items?limit=200")
    items = many(items_payload)
    has_version = False
    for item in items:
        rel = ((item.get("relationships") or {}).get("appStoreVersion") or {}).get("data") or {}
        if rel.get("id") == version_id:
            has_version = True
            break
    if not has_version:
        payload = {"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":sid}},"appStoreVersion":{"data":{"type":"appStoreVersions","id":version_id}}}}}
        request_ok(token, "/v1/reviewSubmissionItems", "POST", payload)
    _, after = api_get(token, f"/v1/reviewSubmissions/{sid}")
    resource = one(after, "review submission after prepare")
    return {"id": sid, "state": state(resource), "already_submitted": False}


def main() -> None:
    screen = Path(os.environ.get("PHARMACIST_SCREENSHOT", "/tmp/yakuzaishi-review/01-home.png"))
    output = Path(os.environ.get("PHARMACIST_SUBMISSION_OUTPUT", "/tmp/app2-004-yakuzaishi-prepare-result.json"))
    if not screen.is_file():
        raise RuntimeError(f"Screenshot missing: {screen}")
    result: dict = {"task_id":"APP2-004","completed_at":datetime.now(timezone.utc).isoformat(),"app_id":APP_ID,"bundle_id":BUNDLE_ID,"version":TARGET_VERSION,"build":TARGET_BUILD,"monetization":"none","submitted":False}
    key_path, cleanup = load_private_key()
    try:
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, app_payload = api_get(token, f"/v1/apps/{APP_ID}")
        app = one(app_payload, "app")
        if (app.get("attributes") or {}).get("bundleId") != BUNDLE_ID:
            raise RuntimeError("Target app mismatch")
        version = resolve_version(token); version_id = str(version["id"])
        loc = resolve_localization(token, version_id); loc_id = str(loc["id"])
        patch(token, f"/v1/appStoreVersionLocalizations/{loc_id}", "appStoreVersionLocalizations", loc_id, attributes={"description":DESCRIPTION,"keywords":KEYWORDS,"supportUrl":SUPPORT_URL})
        patch(token, f"/v1/appStoreVersions/{version_id}", "appStoreVersions", version_id, attributes={"usesIdfa": False})
        result.update(ensure_app_info(token))
        result["review_detail_id"] = ensure_review_detail(token, version_id)
        build = wait_valid_build(token); build_id = str(build["id"])
        result["build_id"] = build_id
        result["build_processing_state"] = (build.get("attributes") or {}).get("processingState")
        attach_build(token, version_id, build_id)
        result["screenshot"] = ensure_screenshot(token, loc_id, screen)
        result["review_submission"] = ensure_submission_draft(token, version_id)
        result["submission_ready"] = result["review_submission"]["state"] in {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
    except Exception as exc:
        result["error"] = str(exc)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
