#!/usr/bin/env python3
"""Update only the editable Japanese App Store listing copy; never submit for review."""
import json, os, re, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
from app_store_connect_api import api_get, api_request, load_private_key, make_token
APP="6802119268"
BUNDLE="com.allsunday1122.tourokuhanbaisha"
SOURCE=ROOT/"touroku-hanbaisha-ios/APP_STORE_METADATA.md"
def many(x):
    d=(x or {}).get("data",[])
    return d if isinstance(d,list) else ([d] if d else [])
def get(token,path):
    status,data=api_get(token,path)
    if not 200<=status<300: raise RuntimeError(f"ASC GET {path} HTTP {status}")
    return data
def main():
    text=SOURCE.read_text(encoding="utf-8")
    promo=re.search(r"## プロモーションテキスト\n(.*?)(?=\n## )",text,re.S).group(1).strip()
    desc=re.search(r"## 説明\n(.*?)(?=\n## )",text,re.S).group(1).strip()
    assert all(x in desc for x in ("599問","2023年度問90","通常学習は通信不要","公式問題PDF","公式正答PDF"))
    assert "599問" in promo and len(desc)<=4000 and len(promo)<=170
    key,cleanup=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key)
        app=get(token,f"/v1/apps/{APP}")["data"]
        assert (app.get("attributes") or {}).get("bundleId")==BUNDLE
        versions=many(get(token,f"/v1/apps/{APP}/appStoreVersions?limit=50"))
        matches=[v for v in versions if (v.get("attributes") or {}).get("platform")=="IOS"
                 and (v.get("attributes") or {}).get("appStoreState")=="PREPARE_FOR_SUBMISSION"]
        assert len(matches)==1, f"Expected one editable iOS draft, found {len(matches)}"
        version=matches[0]
        locs=many(get(token,f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=50"))
        ja=[x for x in locs if (x.get("attributes") or {}).get("locale") in ("ja","ja-JP")]
        assert len(ja)==1, f"Expected one Japanese localization, found {len(ja)}"
        loc=ja[0]
        payload={"data":{"type":"appStoreVersionLocalizations","id":loc["id"],
          "attributes":{"description":desc,"promotionalText":promo}}}
        code,_=api_request(token,f"/v1/appStoreVersionLocalizations/{loc['id']}",method="PATCH",payload=payload)
        assert 200<=code<300
        verify=get(token,f"/v1/appStoreVersionLocalizations/{loc['id']}")
        attrs=verify["data"].get("attributes") or {}
        assert attrs.get("description")==desc and attrs.get("promotionalText")==promo
        result={"status":"PASS","appId":APP,"bundleIdVerified":True,"versionId":version["id"],
          "localizationId":loc["id"],"locale":attrs.get("locale"),"descriptionLength":len(desc),
          "promotionalTextLength":len(promo),"descriptionMentions599":"599問" in attrs["description"],
          "descriptionMentionsInvalidQ90":"2023年度問90" in attrs["description"],
          "descriptionDisclosesOffline":"通信不要" in attrs["description"],
          "descriptionLinksOfficialSources":("公式問題PDF" in attrs["description"] and "公式正答PDF" in attrs["description"]),
          "promotionalTextMentions599":"599問" in attrs["promotionalText"],"submissionPerformed":False}
        (ROOT/"touroku-hanbaisha-ios/ASC_METADATA_Q3_UPDATE_20261126.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
        print(json.dumps(result,ensure_ascii=False))
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)
if __name__=="__main__": main()
