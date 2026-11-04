#!/usr/bin/env python3
"""Replace draft 1.0.1 legacy 6.5-inch screenshots with validated Japanese images.

Never mutates the released 1.0, iPad assets, review submission or app binary.
"""
from __future__ import annotations
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

sys.path.insert(0,str(Path(__file__).resolve().parent))
from app_store_connect_api import api_get, api_request, load_private_key, make_token
from shiwake_store_screenshots import valid_assets, APP_ID, BUNDLE

VERSION = "1.0.1"
VERSION_ID = "de10a2cf-3ff3-4f57-9b1c-f894691ed363"
LEGACY_TYPE = "APP_IPHONE_65"
NEW_TYPE = "APP_IPHONE_67"
OLD_NAMES = {"iphone-01-home.png", "iphone-02-quiz.png", "iphone-03-feedback.png"}
NEW_NAMES = (
    "shiwake_appstore_01_1242x2688.png",
    "shiwake_appstore_02_1242x2688.png",
    "shiwake_appstore_03_1242x2688.png",
)
RESULT_PATH=Path("automation/asc-results/shiwake-65-screenshots-20261104.json")


def many(payload):
    data=(payload or {}).get("data") or []
    return data if isinstance(data,list) else [data]


def attrs(entry):
    return entry.get("attributes") or {}


def read(token, path):
    return api_get(token,path)[1]


def write(token,path,method,payload):
    return api_request(token,path,method=method,payload=payload)[1] or {}


def delete(token,id):
    if not id or "/" in id or len(id)>100:
        raise RuntimeError("Invalid Apple screenshot ID")
    url="https://api.appstoreconnect.apple.com/v1/appScreenshots/"+id
    request=urllib.request.Request(url,method="DELETE",
               headers={"Authorization":"Bearer "+token,"Accept":"application/json"})
    try:
        with urllib.request.urlopen(request,timeout=35) as response:
            if response.status not in (200,202,204):
                raise RuntimeError("Unexpected Apple screenshot deletion status")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Apple screenshot deletion returned HTTP {e.code}") from None


def screenshot_list(token,set_id):
    return many(read(token,f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=100"))


def resized() -> dict[str,bytes]:
    source=valid_assets()
    if len(source)!=3:
        raise RuntimeError("Invalid screenshot archive count")
    result={}
    for i,(_,content) in enumerate(source.items()):
        with Image.open(io.BytesIO(content)) as photo:
            image=photo.convert("RGB").resize((1242,2688),Image.Resampling.LANCZOS)
        stream=io.BytesIO()
        image.save(stream,format="PNG",optimize=True)
        raw=stream.getvalue()
        if raw[12:16]!=b'IHDR' or raw[25]!=2:
            raise RuntimeError("Resized screenshot must have RGB pixels")
        result[NEW_NAMES[i]]=raw
    return result


def upload(token,set_id,name,raw):
    payload={"data":{"type":"appScreenshots","attributes":{"fileName":name,"fileSize":len(raw)},
           "relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":set_id}}}}}
    response=write(token,"/v1/appScreenshots","POST",payload)
    if len(many(response))!=1:
        raise RuntimeError("Apple failed to reserve screenshot")
    data=many(response)[0]
    operations=attrs(data).get("uploadOperations") or []
    if not operations or sum(int(op.get("length",0)) for op in operations)!=len(raw):
        raise RuntimeError("Invalid Apple upload operation coverage")
    for operation in operations:
        offset,length=int(operation["offset"]),int(operation["length"])
        url=operation.get("url","")
        if not url.startswith("https://") or ".apple.com/" not in url or offset<0 or length<=0 or offset+length>len(raw):
            raise RuntimeError("Invalid Apple upload URL or range")
        headers={h["name"]:h["value"] for h in operation.get("requestHeaders",[])}
        req=urllib.request.Request(url,data=raw[offset:offset+length],headers=headers,method="PUT")
        with urllib.request.urlopen(req,timeout=90) as response:
            if response.status not in (200,201,202,204):
                raise RuntimeError(f"Apple asset PUT returned HTTP {response.status}")
    payload={"data":{"type":"appScreenshots","id":data["id"],
                   "attributes":{"uploaded":True,"sourceFileChecksum":hashlib.md5(raw).hexdigest()}}}
    write(token,f"/v1/appScreenshots/{data['id']}","PATCH",payload)
    print("Uploaded replacement image",name)


def main():
    assets=resized()
    key,cleanup=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
        app=many(read(token,f"/v1/apps/{APP_ID}"))
        if len(app)!=1 or attrs(app[0]).get("bundleId")!=BUNDLE:
            raise RuntimeError("Shiwake app ID and Bundle ID mismatch")
        ver=many(read(token,f"/v1/appStoreVersions/{VERSION_ID}"))
        if len(ver)!=1 or attrs(ver[0]).get("versionString")!=VERSION or attrs(ver[0]).get("appStoreState")!="PREPARE_FOR_SUBMISSION":
            raise RuntimeError("Not editable target 1.0.1")
        locales=many(read(token,f"/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations?limit=100"))
        ja=[x for x in locales if attrs(x).get("locale")=="ja"]
        if len(ja)!=1: raise RuntimeError("Target ja locale not uniquely found")
        lid=ja[0]["id"]
        sets=many(read(token,f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets?limit=100"))
        old=[s for s in sets if attrs(s).get("screenshotDisplayType")==LEGACY_TYPE]
        new=[s for s in sets if attrs(s).get("screenshotDisplayType")==NEW_TYPE]
        if len(old)!=1 or len(new)!=1:
            raise RuntimeError("Expected one existing 6.5 and one new 6.7 screenshot set")
        legacy_id=old[0]["id"]
        new_images=screenshot_list(token,new[0]["id"])
        expected={f"shiwake_appstore_{i:02d}_1320x2868.png" for i in range(1,4)}
        verified={attrs(s).get("fileName") for s in new_images
                  if (attrs(s).get("assetDeliveryState") or {}).get("state")=="COMPLETE"}
        if expected!=verified: raise RuntimeError("New 6.7-inch screenshot set is not verified COMPLETE")
        first=screenshot_list(token,legacy_id)
        present={attrs(s).get("fileName"):s for s in first}
        if set(present)-OLD_NAMES-set(assets):
            raise RuntimeError("Unexpected screenshot filenames in old 6.5-inch set")
        for name,raw in assets.items():
            if name not in present:
                upload(token,legacy_id,name,raw)
            elif attrs(present[name]).get("fileSize")!=len(raw):
                raise RuntimeError("Existing screenshot with same filename differs in size")

        states={}
        for cycle in range(65):
            latest=screenshot_list(token,legacy_id)
            found={attrs(s).get("fileName"):s for s in latest}
            if set(assets).issubset(found):
                states={name:(attrs(found[name]).get("assetDeliveryState") or {}).get("state") for name in assets}
                if any(v=="FAILED" for v in states.values()):
                    raise RuntimeError(f"Apple screenshot processing failure: {states}")
                if all(v=="COMPLETE" for v in states.values()):
                    break
            if cycle<64: time.sleep(8)
        if not states or not all(v=="COMPLETE" for v in states.values()):
            raise RuntimeError(f"New 6.5-inch screenshot processing incomplete: {states}")
        latest=screenshot_list(token,legacy_id)
        for entry in latest:
            if attrs(entry).get("fileName") in OLD_NAMES:
                delete(token,entry["id"])
        after=screenshot_list(token,legacy_id)
        after_names={attrs(s).get("fileName") for s in after}
        if after_names!=set(assets):
            raise RuntimeError(f"Old screenshots not completely removed: {after_names}")
        if not all((attrs(s).get("assetDeliveryState") or {}).get("state")=="COMPLETE" for s in after):
            raise RuntimeError("New screenshot state regressed")
        result={"app_id":APP_ID,"bundle_id":BUNDLE,"version":"1.0.1","version_id":VERSION_ID,
                "display_type":LEGACY_TYPE,"old_images_deleted":sorted(OLD_NAMES),
                "new_images":[{"file":name,"sha256":hashlib.sha256(raw).hexdigest(),"state":"COMPLETE"} for name,raw in assets.items()],
                "released_1_0_untouched":True,"review_submitted":False}
        RESULT_PATH.parent.mkdir(parents=True,exist_ok=True)
        RESULT_PATH.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(result,ensure_ascii=False,indent=2))
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)


if __name__=="__main__":
    main()
