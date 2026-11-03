#!/usr/bin/env python3
"""Submit the user's expressly approved Nomikai Build 13 to Apple App Review.

All IDs are fixed. This program does not publish the app; release type is MANUAL.
Read-back rather than a 2xx response establishes that Apple received the submission.
"""
import json
import os
from pathlib import Path
import time
from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP="6794847479"
BUNDLE="jp.allsunday1122.nomikaiarcade"
VERSION="7dcad63e-8c82-4d19-8dc5-873458bca58b"
BUILD="3f27d9b8-4c16-4bce-a75f-b5add1a76ecd"
LOCALE="c5594cd3-427f-4d2a-8b62-55358c7825b6"
INFO_LOCALE="693f9319-d865-4d81-867e-df2df6345a06"
INFO="f48984ff-b308-432a-a8a8-d53db07bb61b"
REVIEW_DETAIL="880c68a3-1ca1-4df3-b4ec-a8c877a1d42d"
EXPECTED_SCREENS={"01-home-1179x2556.jpg","02-friends-1179x2556.jpg","03-conversation-1179x2556.jpg"}
ACTIVE={"READY_FOR_REVIEW","WAITING_FOR_REVIEW","IN_REVIEW","UNRESOLVED_ISSUES","CANCELING","COMPLETING"}

def rows(obj):
    data=(obj or {}).get("data") or []
    return [data] if isinstance(data,dict) else data

def get(token,path):
    return api_get(token,path)[1]

def post(token,path,payload):
    return api_request(token,path,method="POST",payload=payload)[1] or {}

def patch(token,path,payload):
    return api_request(token,path,method="PATCH",payload=payload)[1] or {}

def one(token,path):
    xs=rows(get(token,path))
    if len(xs)!=1:
        raise RuntimeError("Expected one Apple resource at "+path)
    return xs[0]

def attributes(r):
    return (r or {}).get("attributes") or {}

def assert_preflight(token):
    app=one(token,f"/v1/apps/{APP}")
    if attributes(app).get("bundleId")!=BUNDLE:
        raise RuntimeError("Target app bundle ID mismatch")
    version=one(token,f"/v1/appStoreVersions/{VERSION}")
    v=attributes(version)
    if v.get("versionString")!="1.0.0" or v.get("platform")!="IOS":
        raise RuntimeError("App version mismatch")
    if v.get("appStoreState") not in ("PREPARE_FOR_SUBMISSION","READY_FOR_REVIEW"):
        raise RuntimeError("Unexpected app version state "+str(v.get("appStoreState")))
    selected=rows(get(token,f"/v1/appStoreVersions/{VERSION}/relationships/build"))
    if len(selected)!=1 or selected[0].get("id")!=BUILD:
        raise RuntimeError("Selected app build is not Build 13")
    build=attributes(one(token,f"/v1/builds/{BUILD}"))
    if build.get("version")!="13" or build.get("processingState")!="VALID" or build.get("expired"):
        raise RuntimeError("Build 13 is not valid")
    if build.get("usesNonExemptEncryption") is not False:
        raise RuntimeError("Build 13 export compliance not settled")
    local=attributes(one(token,f"/v1/appStoreVersionLocalizations/{LOCALE}"))
    if "収録ゲームは19種類" not in (local.get("description") or "") or "〆にどうぞ" in (local.get("description") or ""):
        raise RuntimeError("Store description still references obsolete game")
    if local.get("supportUrl")!="https://allsunday1122.github.io/nomikai-arcade-support/":
        raise RuntimeError("Unexpected support URL")
    info=attributes(one(token,f"/v1/appInfoLocalizations/{INFO_LOCALE}"))
    if info.get("subtitle")!="スマホ1台で遊べるミニゲーム19選":
        raise RuntimeError("Store subtitle not updated")
    if info.get("privacyPolicyUrl")!="https://allsunday1122.github.io/nomikai-arcade-support/privacy/":
        raise RuntimeError("Unexpected privacy policy URL")
    age=attributes(one(token,f"/v1/appInfos/{INFO}/ageRatingDeclaration"))
    if age.get("alcoholTobaccoOrDrugUseOrReferences") not in ("INFREQUENT","FREQUENT"):
        raise RuntimeError("Age rating does not disclose alcohol references")
    if age.get("advertising") is not False:
        raise RuntimeError("Age rating advertising setting disagrees with Build 13")
    review=attributes(one(token,f"/v1/appStoreReviewDetails/{REVIEW_DETAIL}"))
    if not all(review.get(k) for k in ("contactFirstName","contactLastName","contactEmail","contactPhone")):
        raise RuntimeError("App Review contact information incomplete")
    if "Build 13" not in (review.get("notes") or ""):
        raise RuntimeError("Review notes do not describe Build 13")
    sets=rows(get(token,f"/v1/appStoreVersionLocalizations/{LOCALE}/appScreenshotSets?limit=100"))
    new_ids=[r["id"] for r in sets if attributes(r).get("screenshotDisplayType")=="APP_IPHONE_61"]
    if len(new_ids)!=1:
        raise RuntimeError("Required iPhone medium screenshot set missing")
    for s in sets:
        t=attributes(s).get("screenshotDisplayType")
        pictures=rows(get(token,f"/v1/appScreenshotSets/{s['id']}/appScreenshots?limit=100"))
        if t=="APP_IPHONE_61":
            names={attributes(p).get("fileName") for p in pictures}
            if names!=EXPECTED_SCREENS:
                raise RuntimeError("Not exactly three valid new screenshots")
            if any((attributes(p).get("assetDeliveryState") or {}).get("state")!="COMPLETE" for p in pictures):
                raise RuntimeError("New screenshot processing incomplete")
        elif pictures:
            raise RuntimeError("Unapproved old screenshots remain in display type "+str(t))
    if v.get("releaseType")!="MANUAL":
        patch(token,f"/v1/appStoreVersions/{VERSION}",{"data":{"type":"appStoreVersions","id":VERSION,"attributes":{"releaseType":"MANUAL"}}})
        after=attributes(one(token,f"/v1/appStoreVersions/{VERSION}"))
        if after.get("releaseType")!="MANUAL":
            raise RuntimeError("Failed to set manual release after review")
    return {"build":13,"screenshots":3,"age_references":age.get("alcoholTobaccoOrDrugUseOrReferences"),"release_type":"MANUAL","review_contact_present":True}

def submission_items(token, submission_id):
    return rows(get(token,f"/v1/reviewSubmissions/{submission_id}/items?limit=50"))

def item_has_version(item):
    rel=(item.get("relationships") or {}).get("appStoreVersion") or {}
    data=rel.get("data") or {}
    return isinstance(data,dict) and data.get("id")==VERSION

def submit(token):
    proof=assert_preflight(token)
    existing=rows(get(token,f"/v1/apps/{APP}/reviewSubmissions?limit=100"))
    active=[r for r in existing if attributes(r).get("state") in ACTIVE]
    if len(active)>1:
        raise RuntimeError("Multiple concurrent active App Review submissions")
    if active:
        submission=active[0]
        id=submission["id"]
        status=attributes(submission).get("state")
        if status in ("WAITING_FOR_REVIEW","IN_REVIEW"):
            if not any(item_has_version(i) for i in submission_items(token,id)):
                raise RuntimeError("An unrelated submission is already active")
            return {"submission_id":id,"apple_state":status,"app_id":APP,"build":13,
                    "submitted_to_app_review":True,"idempotent":True,"preflight":proof}
        if status!="READY_FOR_REVIEW":
            raise RuntimeError("Active submission is in an incompatible state "+str(status))
    else:
        payload={"data":{"type":"reviewSubmissions","relationships":{"app":{"data":{"type":"apps","id":APP}}}}}
        created=rows(post(token,"/v1/reviewSubmissions",payload))
        if len(created)!=1 or not created[0].get("id"):
            raise RuntimeError("Apple did not create a review submission")
        id=created[0]["id"]
        print("CREATED_APP_REVIEW_DRAFT_ID="+id)
    items=submission_items(token,id)
    if any(i.get("relationships",{}).get("appStoreVersion",{}).get("data",{}).get("id") not in (None,VERSION) for i in items):
        raise RuntimeError("Draft has item for a different App Store version")
    if not any(item_has_version(i) for i in items):
        payload={"data":{"type":"reviewSubmissionItems","relationships":{
            "reviewSubmission":{"data":{"type":"reviewSubmissions","id":id}},
            "appStoreVersion":{"data":{"type":"appStoreVersions","id":VERSION}}
        }}}
        post(token,"/v1/reviewSubmissionItems",payload)
        print("ATTACHED_APP_STORE_VERSION_1_0_0")
    check=submission_items(token,id)
    if not any(item_has_version(i) for i in check):
        raise RuntimeError("App Store version was not attached to the draft")
    patch(token,f"/v1/reviewSubmissions/{id}",{
        "data":{"type":"reviewSubmissions","id":id,"attributes":{"submitted":True}}
    })
    print("APPLE_SUBMISSION_PATCH_ACCEPTED",id)
    for n in range(15):
        live=attributes(one(token,f"/v1/reviewSubmissions/{id}"))
        state=live.get("state")
        if state in ("WAITING_FOR_REVIEW","IN_REVIEW","UNRESOLVED_ISSUES","COMPLETING","COMPLETE"):
            return {"submission_id":id,"apple_state":state,"app_id":APP,"build":13,
                    "submitted_to_app_review":state in ("WAITING_FOR_REVIEW","IN_REVIEW","COMPLETING","COMPLETE"),
                    "idempotent":False,"preflight":proof}
        if n<14:time.sleep(4)
    return {"submission_id":id,"apple_state":"UNKNOWN_AFTER_PATCH","app_id":APP,"build":13,
            "submitted_to_app_review":False,"preflight":proof}

def main():
    key, temporary=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
        result=submit(token)
        Path("nomikai-review-result.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print("APPLE_APP_REVIEW_RESULT",result["submission_id"],result["apple_state"])
        if not result["submitted_to_app_review"]:
            raise RuntimeError("Apple has not confirmed a submitted review state")
    finally:
        if temporary:temporary.unlink(missing_ok=True)

if __name__=="__main__":
    main()
