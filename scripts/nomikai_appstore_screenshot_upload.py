#!/usr/bin/env python3
"""Bespoke, app-scoped screenshot sync. Never submits for App Review."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request

from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID = "6794847479"
BUNDLE = "jp.allsunday1122.nomikaiarcade"
BUILD_ID = "3f27d9b8-4c16-4bce-a75f-b5add1a76ecd"
VERSION_ID = "7dcad63e-8c82-4d19-8dc5-873458bca58b"
LOCALIZATION_ID = "c5594cd3-427f-4d2a-8b62-55358c7825b6"
OLD_SET = "97823792-2bbe-42fb-a738-6b5e4b7e9c4d"
EXPECTED_OLD_FILES = {"01-relay-home.png", "02-relay-cup.png", "03-closing-dish.png"}
NEW_TYPE = "APP_IPHONE_61"
ROOT = Path("automation/app2-002/screenshots/20261103")
RESULT_PATH = Path("nomikai-screenshot-result.json")

def data_list(payload):
    data = (payload or {}).get("data") or []
    if isinstance(data, dict):
        return [data]
    if not isinstance(data, list):
        raise RuntimeError("Unexpected data")
    return data

def attrs(resource):
    return (resource or {}).get("attributes") or {}

def read(token, path):
    return api_get(token, path)[1]

def write(token, path, method, payload):
    return api_request(token, path, method=method, payload=payload)[1] or {}

def remote_delete(token, path):
    # Deletion is restricted to the pre-verified legacy screenshot IDs below.
    if not path.startswith("/v1/appScreenshots/"):
        raise RuntimeError("Delete refused: unsupported resource")
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path,
        headers={"Authorization": "Bearer " + token, "Accept": "application/json"},
        method="DELETE")
    try:
        with urllib.request.urlopen(req, timeout=35) as response:
            if response.status not in (200, 202, 204):
                raise RuntimeError("Unexpected deletion status")
    except urllib.error.HTTPError as exc:
        raise RuntimeError("Screenshot deletion rejected with HTTP " + str(exc.code)) from None

def prepare(token):
    app = data_list(read(token, f"/v1/apps/{APP_ID}"))[0]
    if attrs(app).get("bundleId") != BUNDLE:
        raise RuntimeError("Bundle preflight mismatch")
    version = data_list(read(token, f"/v1/appStoreVersions/{VERSION_ID}"))[0]
    if attrs(version).get("versionString") != "1.0.0" or attrs(version).get("appStoreState") != "PREPARE_FOR_SUBMISSION":
        raise RuntimeError("App version is not an editable 1.0.0 draft")
    selected = data_list(read(token, f"/v1/appStoreVersions/{VERSION_ID}/relationships/build"))
    if len(selected) != 1 or selected[0].get("id") != BUILD_ID:
        raise RuntimeError("Build 13 is not selected")
    build = data_list(read(token, f"/v1/builds/{BUILD_ID}"))[0]
    if attrs(build).get("version") != "13" or attrs(build).get("processingState") != "VALID":
        raise RuntimeError("Build 13 is not VALID")
    localization = data_list(read(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}"))[0]
    description = attrs(localization).get("description") or ""
    if "収録ゲームは19種類" not in description or "〆にどうぞ" in description or "リレーカップ" in description:
        raise RuntimeError("Store listing does not match the 19-game app")
    return read(token, f"/v1/appStoreVersionLocalizations/{LOCALIZATION_ID}/appScreenshotSets?limit=100")

def read_sets(sets):
    out = {}
    for item in data_list(sets):
        t = attrs(item).get("screenshotDisplayType")
        if t in (NEW_TYPE, "APP_IPHONE_65"):
            if t in out:
                raise RuntimeError("Duplicate screenshot set for " + t)
            out[t] = item["id"]
    return out

def manifest():
    doc=json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    if doc.get("app_id") != APP_ID or doc.get("bundle_id") != BUNDLE or doc.get("build") != "13":
        raise RuntimeError("Screenshot manifest target mismatch")
    entries = doc.get("entries") or []
    if len(entries) != 3 or len({e["name"] for e in entries}) != 3:
        raise RuntimeError("Expected exactly three unique screenshots")
    for e in entries:
        name=e["name"]
        if name not in ("01-home-1179x2556.jpg", "02-friends-1179x2556.jpg", "03-conversation-1179x2556.jpg"):
            raise RuntimeError("Unexpected asset filename")
        data=(ROOT/name).read_bytes()
        if hashlib.sha256(data).hexdigest()!=e["sha256"] or len(data)!=e["bytes"]:
            raise RuntimeError("Screenshot SHA-256 or byte length mismatch")
        if e["width"] != 1179 or e["height"] != 2556 or not data.startswith(b"\\xff\\xd8"):
            raise RuntimeError("Screenshot format or dimensions invalid")
    return entries

def screens(token, set_id):
    return data_list(read(token, f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=100"))

def upload_part(op, raw):
    offset=int(op.get("offset", -1))
    length=int(op.get("length", -1))
    if offset<0 or length<=0 or offset+length>len(raw) or op.get("method") != "PUT":
        raise RuntimeError("Unexpected screenshot upload range")
    url=op.get("url")
    if not isinstance(url, str) or not url.startswith("https://") or ".apple.com/" not in url:
        raise RuntimeError("Non-Apple upload endpoint")
    headers={h["name"]:h["value"] for h in op.get("requestHeaders", [])}
    req=urllib.request.Request(url, data=raw[offset:offset+length], headers=headers, method="PUT")
    try:
        with urllib.request.urlopen(req,timeout=120) as response:
            if response.status not in (200,201,202,204):
                raise RuntimeError("Asset part upload unsuccessful")
    except urllib.error.HTTPError as exc:
        raise RuntimeError("Asset part upload rejected HTTP " + str(exc.code)) from None

def screenshot_state(token, id):
    return attrs(data_list(read(token,f"/v1/appScreenshots/{id}"))[0]).get("assetDeliveryState") or {}

def create_set(token):
    payload={"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":NEW_TYPE},
       "relationships":{"appStoreVersionLocalization":{"data":{"type":"appStoreVersionLocalizations","id":LOCALIZATION_ID}}}}}
    created=data_list(write(token,"/v1/appScreenshotSets","POST",payload))
    if len(created)!=1 or not created[0].get("id"):
        raise RuntimeError("No screenshot set ID returned")
    return created[0]["id"]

def create_screenshot(token,set_id,entry):
    raw=(ROOT/entry["name"]).read_bytes()
    payload={"data":{"type":"appScreenshots",
        "attributes":{"fileSize":len(raw),"fileName":entry["name"]},
        "relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":set_id}}}}}
    created=data_list(write(token,"/v1/appScreenshots","POST",payload))
    if len(created)!=1 or not created[0].get("id"):
        raise RuntimeError("Screenshot reservation was not created")
    resource=created[0]
    ops=attrs(resource).get("uploadOperations") or []
    if not ops or sum(int(o.get("length",0)) for o in ops)!=len(raw):
        raise RuntimeError("Upload reservation has invalid part coverage")
    for part in ops:
        upload_part(part,raw)
    id=resource["id"]
    checksum=hashlib.md5(raw).hexdigest()
    patch={"data":{"type":"appScreenshots","id":id,"attributes":{"uploaded":True,"sourceFileChecksum":checksum}}}
    write(token,f"/v1/appScreenshots/{id}","PATCH",patch)
    return id

def wait_all_complete(token,set_id,entries):
    wanted={e["name"] for e in entries}
    for tick in range(25):
        got=screens(token,set_id)
        matched={attrs(x).get("fileName"):x for x in got if attrs(x).get("fileName") in wanted}
        if set(matched)==wanted:
            states={name:attrs(item).get("assetDeliveryState") or {} for name,item in matched.items()}
            failed=[(name,v) for name,v in states.items() if v.get("state")=="FAILED" or v.get("errors")]
            if failed:
                raise RuntimeError("Apple screenshot processing failed: " + str([(n,v.get("state")) for n,v in failed]))
            if all(v.get("state")=="COMPLETE" for v in states.values()):
                return [{"name":n,"id":matched[n]["id"],"state":"COMPLETE"} for n in sorted(wanted)]
        if tick<24:time.sleep(6)
    raise RuntimeError("Screenshots uploaded but Apple has not confirmed COMPLETE yet; retry safely")

def upload(token):
    entries=manifest()
    sets=read_sets(prepare(token))
    set_id=sets.get(NEW_TYPE)
    if not set_id:
        set_id=create_set(token)
    current={attrs(x).get("fileName"):x for x in screens(token,set_id)}
    for e in entries:
        old=current.get(e["name"])
        if old:
            if attrs(old).get("fileSize")!=e["bytes"]:
                raise RuntimeError("Filename reused with different bytes: "+e["name"])
            print("EXISTING",e["name"],old["id"])
        else:
            id=create_screenshot(token,set_id,e)
            print("RESERVED_AND_UPLOADED",e["name"],id)
    done=wait_all_complete(token,set_id,entries)
    return {"stage":"uploaded_and_processed","new_set":set_id,"images":done,"old_set_untouched":sets.get("APP_IPHONE_65"),"review_submitted":False}

def cleanup(token):
    entries=manifest()
    sets=read_sets(prepare(token))
    new_id=sets.get(NEW_TYPE)
    if not new_id:
        raise RuntimeError("New medium iPhone screenshot set missing")
    done=wait_all_complete(token,new_id,entries)
    old_id=sets.get("APP_IPHONE_65")
    if old_id and old_id != OLD_SET:
        raise RuntimeError("Legacy set ID mismatch; deletion forbidden")
    removed=[]
    if old_id:
        legacy=screens(token,old_id)
        names={attrs(x).get("fileName") for x in legacy}
        if not names.issubset(EXPECTED_OLD_FILES):
            raise RuntimeError("Legacy screenshot list changed; no deletion")
        for item in legacy:
            remote_delete(token,f"/v1/appScreenshots/{item['id']}")
            removed.append({"id":item["id"],"name":attrs(item).get("fileName")})
        if screens(token,old_id):
            raise RuntimeError("Some legacy screenshots remain after cleanup")
    return {"stage":"old_screenshots_removed","new_set":new_id,"images":done,"removed":removed,"review_submitted":False}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--phase",required=True,choices=["upload","cleanup"])
    args=parser.parse_args()
    key_path,cleanup_file=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key_path)
        result=upload(token) if args.phase=="upload" else cleanup(token)
        RESULT_PATH.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print("PASS:",result["stage"],"screenshots=",len(result["images"]))
    finally:
        if cleanup_file:cleanup_file.unlink(missing_ok=True)

if __name__=="__main__":
    main()
