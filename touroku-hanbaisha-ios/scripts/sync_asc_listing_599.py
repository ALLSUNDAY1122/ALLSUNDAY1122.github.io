#!/usr/bin/env python3
"""Guarded ASC metadata-only correction, read-back confirmed. No submission or TestFlight."""
import datetime,json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
from app_store_connect_api import api_get,api_request,load_private_key,make_token
APP="6802119268";BUNDLE="com.allsunday1122.tourokuhanbaisha"
META=(ROOT/"touroku-hanbaisha-ios/APP_STORE_METADATA.md").read_text()
OUT=ROOT/"touroku-hanbaisha-ios/ASC_599_METADATA_SYNC_20261124.json"
def segment(start,end):
    return META.split(start,1)[1].split(end,1)[0].strip()
def many(v):
    d=v.get("data",[]);return d if isinstance(d,list) else ([d] if d else [])
def get(token,path):
    code,j=api_get(token,path)
    if not 200<=code<300:raise RuntimeError(f"ASC GET failed: {path} HTTP {code}")
    return j
def patch(token,path,typ,id,attrs):
    code,response=api_request(token,path,method="PATCH",payload={"data":{"type":typ,"id":str(id),"attributes":attrs}})
    if not 200<=code<300:raise RuntimeError(f"ASC PATCH failed: {path} HTTP {code} {str(response)[:240]}")
def main():
    description=segment("## 説明","## キーワード案")
    promotional=segment("## プロモーションテキスト","## 説明")
    review_notes=segment("## App Review Notes","## 提出前にApp Store Connect")
    assert "599問" in description and "公式過去問" in description and "独立模擬試験3回" not in description
    assert "599問" in promotional and "360問" not in promotional
    assert "599" in review_notes and "360" not in review_notes
    key,cleanup=load_private_key()
    output={"schema":"touhan-asc-599-metadata-sync-v1","timestampJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
        "appId":APP,"bundleId":BUNDLE,"appReviewSubmitted":False,"testflightUpdated":False,"changes":[]}
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
        app=get(token,f"/v1/apps/{APP}")["data"]
        assert app["attributes"]["bundleId"]==BUNDLE
        versions=many(get(token,f"/v1/apps/{APP}/appStoreVersions?limit=50"))
        candidates=[v for v in versions if (v.get("attributes") or {}).get("platform")=="IOS"
            and (v.get("attributes") or {}).get("appStoreState")=="PREPARE_FOR_SUBMISSION"]
        assert len(candidates)==1,[(v.get("id"),v.get("attributes",{}).get("appStoreState")) for v in candidates]
        version=candidates[0];output["versionId"]=version["id"]
        locs=many(get(token,f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=50"))
        ja=[x for x in locs if x.get("attributes",{}).get("locale") in ("ja","ja-JP")]
        assert len(ja)==1
        loc=ja[0];lid=loc["id"]
        old=loc.get("attributes") or {}
        updates={}
        if old.get("description")!=description:updates["description"]=description
        if old.get("promotionalText")!=promotional:updates["promotionalText"]=promotional
        if updates:
            patch(token,f"/v1/appStoreVersionLocalizations/{lid}","appStoreVersionLocalizations",lid,updates)
            output["changes"]+=list(updates)
        check=get(token,f"/v1/appStoreVersionLocalizations/{lid}")["data"]["attributes"]
        assert check.get("description")==description
        assert check.get("promotionalText")==promotional
        output["description599Verified"]=True
        output["oldDescriptionMentioned360"]=("360問" in (old.get("description") or ""))
        # Review notes only if review detail already exists. Never create or submit a review.
        try:
            d=get(token,f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")["data"]
            rid=d["id"]
            if (d.get("attributes") or {}).get("notes")!=review_notes:
                patch(token,f"/v1/appStoreReviewDetails/{rid}","appStoreReviewDetails",rid,{"notes":review_notes})
                output["changes"].append("reviewNotes")
            readback=get(token,f"/v1/appStoreReviewDetails/{rid}")["data"]
            output["reviewNotes599Verified"]=readback.get("attributes",{}).get("notes")==review_notes
        except Exception as e:
            output["reviewNotes599Verified"]=False
            output["reviewNotesError"]=str(e)[:150]
        output["status"]="PASS" if output["description599Verified"] else "FAIL"
    finally:
        if cleanup:cleanup.unlink(missing_ok=True)
        OUT.write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(output,ensure_ascii=False))
    if output.get("status")!="PASS":raise SystemExit("ASC 599 description synchronization not verified")
if __name__=="__main__":main()
