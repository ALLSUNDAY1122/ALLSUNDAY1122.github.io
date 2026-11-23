#!/usr/bin/env python3
"""Read-only ASC metadata crosscheck. Actual App Privacy questionnaire not exposed by documented Apps API."""
import datetime,json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
from app_store_connect_api import api_get,load_private_key,make_token
APP="6802119268"
EXPECTED="https://allsunday1122.github.io/touroku-hanbaisha-sprint/privacy.html"
OUT=ROOT/"touroku-hanbaisha-ios/ASC_Q5_PRIVACY_METADATA_READBACK_20261124.json"
def many(x):
    data=(x or {}).get("data",[])
    return data if isinstance(data,list) else ([data] if data else [])
def get(token,path):
    status,payload=api_get(token,path)
    if status<200 or status>=300:raise RuntimeError(f"read-only ASC {path} HTTP {status}")
    return payload
def main():
    p,cleanup=load_private_key()
    try:
        token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],p)
        app=get(token,f"/v1/apps/{APP}")["data"]
        assert app["attributes"]["bundleId"]=="com.allsunday1122.tourokuhanbaisha"
        infos=many(get(token,f"/v1/apps/{APP}/appInfos?limit=20"))
        locales=[]
        for item in infos:
            for l in many(get(token,f"/v1/appInfos/{item['id']}/appInfoLocalizations?limit=50")):
                attrs=l.get("attributes") or {}
                if attrs.get("locale") in ("ja","ja-JP"):
                    locales.append({"locale":attrs.get("locale"),"privacyPolicyUrl":attrs.get("privacyPolicyUrl")})
        versions=many(get(token,f"/v1/apps/{APP}/appStoreVersions?limit=30"))
        version_summaries=[]
        for version in versions:
            a=version.get("attributes") or {}
            if a.get("platform")!="IOS":continue
            locs=many(get(token,f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=50"))
            for loc in locs:
                attrs=loc.get("attributes") or {}
                if attrs.get("locale") not in ("ja","ja-JP"):continue
                desc=attrs.get("description") or ""
                version_summaries.append({"version":a.get("versionString"),"state":a.get("appStoreState") or a.get("state"),
                     "locale":attrs.get("locale"),"descriptionMentions599":("599問" in desc),"descriptionMentions360":("360問" in desc)})
        result={"schema":"touhan-q5-asc-readback-v1",
          "readAtJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
          "ascAppId":APP,"bundleIdVerified":True,"privacyPolicyUrls":locales,
          "expectedPrivacyPolicyUrl":EXPECTED,
          "privacyPolicyURLMatched":any(x["privacyPolicyUrl"]==EXPECTED for x in locales),
          "versionDescriptionSummaries":version_summaries,
          "privacyQuestionnaireDataTypes":"NOT_ACCESSIBLE_THROUGH_THIS_READ_ONLY_API",
          "questionnaireVerified":False,
          "scope":"Only read App Store Connect app, app info localization privacyPolicyUrl and version description. No metadata changes.",
          "submissionPerformed":False}
        OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
        print(json.dumps(result,ensure_ascii=False))
    finally:
        if cleanup:cleanup.unlink(missing_ok=True)
if __name__=="__main__":main()
