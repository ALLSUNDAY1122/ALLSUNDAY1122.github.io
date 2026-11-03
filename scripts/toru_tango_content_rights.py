#!/usr/bin/env python3
"""Update only Toru Tango's missing App Store content-rights declaration.

Build 12 is a flashcard builder without bundled copyrighted textbook content.
Content the end user imports is not pre-packaged as third-party catalog content.
This does NOT modify privacy responses or submit for App Review.
"""
import json
import os
from pathlib import Path
from app_store_connect_api import api_get, api_request, load_private_key, make_token

APP_ID="6795968222"
BUNDLE="com.allsunday1122.torutango"
VALUE="DOES_NOT_USE_THIRD_PARTY_CONTENT"

def main():
    key, temporary=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
        _, data=api_get(token,f"/v1/apps/{APP_ID}")
        app=data.get("data") or {}
        if app.get("id")!=APP_ID or (app.get("attributes") or {}).get("bundleId")!=BUNDLE:
            raise RuntimeError("Wrong App ID / bundle, abort")
        current=(app.get("attributes") or {}).get("contentRightsDeclaration")
        if current not in (None,VALUE):
            raise RuntimeError("Unexpected existing content rights declaration")
        if current is None:
            payload={"data":{"type":"apps","id":APP_ID,"attributes":{"contentRightsDeclaration":VALUE}}}
            api_request(token,f"/v1/apps/{APP_ID}",method="PATCH",payload=payload)
        _, updated=api_get(token,f"/v1/apps/{APP_ID}")
        actual=((updated.get("data") or {}).get("attributes") or {}).get("contentRightsDeclaration")
        if actual != VALUE:
            raise RuntimeError("Content rights declaration read-back mismatch")
        proof={"app_id":APP_ID,"bundle_id":BUNDLE,"content_rights":actual,"verified":True,"app_review_submitted":False,"privacy_data_usages_published":"UNVERIFIED"}
        Path("toru-rights-result.json").write_text(json.dumps(proof,indent=2)+"\n",encoding="utf-8")
        print("PASS: content rights declaration saved and independently read back")
    finally:
        if temporary:temporary.unlink(missing_ok=True)

if __name__=="__main__":
    main()
