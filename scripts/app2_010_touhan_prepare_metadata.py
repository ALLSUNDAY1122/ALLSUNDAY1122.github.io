#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6802119268"
BUNDLE_ID = "com.allsunday1122.tourokuhanbaisha"
APP_NAME = "登録販売者｜学びスプリント"
DESCRIPTION = """登録販売者試験の5分野を、短時間で繰り返し学べる試験対策アプリです。

・独立模擬試験3回分、全360問の独自問題
・各回120問、本試験の分野配分20・20・40・20・20問に対応
・毎回12問のクイック学習
・試験回・章別の15分類学習
・誤答と「わからない」を自動で苦手登録
・3回連続正解で苦手から解除
・第1回〜第3回を各120問通しで解ける総合模試
・学習履歴カレンダーと途中再開
・文字サイズ変更

問題は厚生労働省「登録販売者試験問題の作成に関する手引き（令和8年4月）」を基準にした独自問題です。実際の試験問題の転載を中心とした構成ではありません。

本アプリは試験学習用であり、実際の症状の診断、治療、医薬品の使用判断を行うものではありません。医薬品の使用については、医師・薬剤師・登録販売者等の専門家へご相談ください。"""
KEYWORDS = "登録販売者,資格,試験,過去問,医薬品,ドラッグストア,勉強,学習,模試,復習"
PROMOTIONAL_TEXT = "令和8年4月の厚生労働省「試験問題の作成に関する手引き」を基準に、短い反復で苦手論点を減らす登録販売者試験対策アプリです。"
SUPPORT_URL = "https://allsunday1122.github.io/touroku-hanbaisha-sprint/support.html"
PRIVACY_URL = "https://allsunday1122.github.io/touroku-hanbaisha-sprint/privacy.html"
REVIEW_NOTES = """登録販売者試験の学習用問題演習アプリです。ログインは不要です。

確認手順:
1. 起動後「今日の12問」から短時間学習を開始できます。
2. 解答後に解説と「ここだけ覚える」を確認できます。
3. 学習を中断するとホームから「前回の続きから始める」で復帰できます。
4. 学習記録では総回答・正答率・苦手を確認できます。
5. 第1回〜第3回の各120問模擬試験を利用できます。

収録360問は厚生労働省「登録販売者試験問題の作成に関する手引き（令和8年4月）」を基準に独自作成した学習問題です。本アプリは公的機関の公式アプリではなく、診断・治療・個別の医薬品使用判断を行いません。ログイン、広告SDK、解析SDK、位置情報、連絡先、カメラ、マイク、HealthKitは使用しません。学習記録は端末内に保存します。"""


def many(payload: object) -> list[dict]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", [])
    return data if isinstance(data, list) else ([] if data is None else [data])


def one(payload: object, label: str) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"Missing {label}")
    return payload["data"]


def state(resource: dict) -> str | None:
    attrs = resource.get("attributes") or {}
    return attrs.get("state") or attrs.get("appStoreState") or attrs.get("appVersionState")


def request_ok(token: str, path: str, method: str, payload: dict) -> dict:
    status, response = api_request(token, path, method=method, payload=payload)
    if not (200 <= status < 300):
        raise RuntimeError(f"ASC {method} {path} returned HTTP {status}: {response}")
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
    candidates = [
        x for x in many(payload)
        if (x.get("attributes") or {}).get("platform") == "IOS"
        and state(x) in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}
    ]
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one editable iOS version; found {[(x.get('id'), state(x)) for x in candidates]}")
    return candidates[0]


def ensure_version_localization(token: str, version_id: str) -> dict:
    _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    ja = next((x for x in many(payload) if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    if ja:
        return ja
    body = {"data":{"type":"appStoreVersionLocalizations","attributes":{"locale":"ja"},"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":version_id}}}}}
    return one(request_ok(token, "/v1/appStoreVersionLocalizations", "POST", body), "ja localization")


def ensure_info(token: str) -> dict:
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
    ja = next((x for x in many(loc_payload) if (x.get("attributes") or {}).get("locale") in {"ja", "ja-JP"}), None)
    if ja:
        patch(token, f"/v1/appInfoLocalizations/{ja['id']}", "appInfoLocalizations", str(ja["id"]),
              attributes={"privacyPolicyUrl":PRIVACY_URL})
        loc_id = str(ja["id"])
    else:
        body = {"data":{"type":"appInfoLocalizations","attributes":{"locale":"ja","name":APP_NAME,"privacyPolicyUrl":PRIVACY_URL},"relationships":{"appInfo":{"data":{"type":"appInfos","id":info_id}}}}}
        created = one(request_ok(token, "/v1/appInfoLocalizations", "POST", body), "app info localization")
        loc_id = str(created["id"])
    return {"app_info_id": info_id, "app_info_localization_id": loc_id}


def prepare_review_detail(token: str, version_id: str) -> dict:
    try:
        _, payload = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
        detail = one(payload, "review detail")
    except Exception:
        return {"exists": False, "notes_written": False, "contact_complete": False, "human_gate": "App Review contact required"}

    rid = str(detail["id"])
    attrs = detail.get("attributes") or {}
    contact_keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
    contact_complete = all(attrs.get(k) for k in contact_keys)
    patch(token, f"/v1/appStoreReviewDetails/{rid}", "appStoreReviewDetails", rid,
          attributes={"notes": REVIEW_NOTES, "demoAccountRequired": False})
    return {"exists": True, "id": rid, "notes_written": True, "contact_complete": contact_complete,
            "human_gate": None if contact_complete else "App Review contact required"}


def readback(token: str, version_id: str, localization_id: str) -> dict:
    _, loc_payload = api_get(token, f"/v1/appStoreVersionLocalizations/{localization_id}")
    loc_attrs = one(loc_payload, "version localization").get("attributes") or {}
    _, rel = api_get(token, f"/v1/appStoreVersions/{version_id}/relationships/build")
    selected_build_id = ((rel or {}).get("data") or {}).get("id") if isinstance(rel, dict) else None
    _, builds_payload = api_get(token, f"/v1/apps/{APP_ID}/builds?limit=100")
    builds = []
    for item in many(builds_payload):
        a = item.get("attributes") or {}
        builds.append({"id": item.get("id"), "version": a.get("version"), "processingState": a.get("processingState"), "expired": a.get("expired")})
    return {
        "localization": {k: loc_attrs.get(k) for k in ("description", "keywords", "promotionalText", "supportUrl")},
        "selected_build_id": selected_build_id,
        "builds": builds,
    }


def main() -> None:
    output = Path(os.environ.get("TOUHAN_ASC_RESULT", "touhan-asc-metadata-result.json"))
    result: dict = {"task":"APP2-010 Touhan ASC metadata prepare","completed_at":datetime.now(timezone.utc).isoformat(),"app_id":APP_ID,"bundle_id":BUNDLE_ID,"submitted":False,"release_performed":False,"testflight_changed":False}
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
        result["version_state"] = state(version)
        localization = ensure_version_localization(token, version_id)
        localization_id = str(localization["id"])
        patch(token, f"/v1/appStoreVersionLocalizations/{localization_id}", "appStoreVersionLocalizations", localization_id,
              attributes={"description":DESCRIPTION,"keywords":KEYWORDS,"promotionalText":PROMOTIONAL_TEXT,"supportUrl":SUPPORT_URL})
        result.update(ensure_info(token))
        result["review_detail"] = prepare_review_detail(token, version_id)
        result["readback"] = readback(token, version_id, localization_id)
        result["metadata_complete"] = all(result["readback"]["localization"].values())
    finally:
        cleanup()
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if not result.get("metadata_complete"):
        raise SystemExit("ASC metadata readback incomplete")


if __name__ == "__main__":
    main()
