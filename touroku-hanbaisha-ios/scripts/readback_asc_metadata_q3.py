#!/usr/bin/env python3
"""Read-only App Store Connect metadata verification for Q3. Never changes or submits metadata."""
import datetime,json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
from app_store_connect_api import api_get,load_private_key,make_token
APP="6802119268"
BUNDLE="com.allsunday1122.tourokuhanbaisha"
OUT=ROOT/"touroku-hanbaisha-ios/ASC_METADATA_Q3_READBACK_20261125.json"
def many(v):
    d=(v or {}).get("data",[])
    return d if isinstance(d,list) else ([d] if d else [])
def get(token,path):
    status,data=api_get(token,path)
    if not 200<=status<300:raise RuntimeError(f"ASC GET {path} HTTP {status}")
    return data
def main():
    result={"schema":"touhan-asc-metadata-q3-readback-v1",
      "readAtJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
      "appId":APP,"bundleIdVerified":False,"status":"NOT_VERIFIED","submissionPerformed":False}
    key=None;cleanup=None
    try:
        key,cleanup=load_private_key()
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
        app=get(token,f"/v1/apps/{APP}")["data"]
        result["bundleIdVerified"]=(app.get("attributes") or {}).get("bundleId")==BUNDLE
        assert result["bundleIdVerified"],"ASC bundle ID mismatch"
        versions=many(get(token,f"/v1/apps/{APP}/appStoreVersions?limit=50"))
        matches=[v for v in versions if (v.get("attributes") or {}).get("platform")=="IOS"
          and (v.get("attributes") or {}).get("appStoreState")=="PREPARE_FOR_SUBMISSION"]
        assert len(matches)==1, f"Expected one editable iOS version, got {len(matches)}"
        version=matches[0]
        locs=many(get(token,f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=50"))
        ja=[x for x in locs if (x.get("attributes") or {}).get("locale") in ("ja","ja-JP")]
        assert len(ja)==1, f"Expected one Japanese localization, got {len(ja)}"
        attrs=ja[0].get("attributes") or {}
        desc=attrs.get("description") or ""
        promo=attrs.get("promotionalText") or ""
        result.update({"versionId":version["id"],"versionString":(version.get("attributes") or {}).get("versionString"),
          "appStoreState":(version.get("attributes") or {}).get("appStoreState"),
          "locale":(attrs.get("locale")),"descriptionMentions599":"599問" in desc,
          "descriptionMentionsInvalidQ90":("2023年度問90" in desc or "2023年度の問90" in desc),
          "descriptionDisclosesOffline":("通信不要" in desc or "オフライン" in desc),
          "descriptionLinksOfficialSources":("公式問題PDF" in desc and "公式正答PDF" in desc),
          "promotionalTextMentions599":"599問" in promo,
          "descriptionLength":len(desc),"promotionalTextLength":len(promo)})
        checks=["descriptionMentions599","descriptionMentionsInvalidQ90","descriptionDisclosesOffline",
          "descriptionLinksOfficialSources","promotionalTextMentions599"]
        result["status"]="PASS" if all(result.get(k) is True for k in checks) else "FAIL"
        result["checkedFields"]=checks
    except Exception as e:
        result["status"]="FAIL"
        result["error"]=str(e)[:500]
    finally:
        if cleanup:cleanup.unlink(missing_ok=True)
        OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(result,ensure_ascii=False))
    if result["status"]!="PASS":raise SystemExit("Q3 live ASC metadata readback did not pass")
if __name__=="__main__":main()
