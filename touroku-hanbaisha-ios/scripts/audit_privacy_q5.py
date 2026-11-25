#!/usr/bin/env python3
"""Q5: inspect actual launched official web page network + browser state.
This cannot read ASC privacy labels or GitHub hosting retention logs.
"""
import datetime,hashlib,json,plistlib,re,threading
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[2]
IOS=ROOT/"touroku-hanbaisha-ios"
WEB=IOS/"native-ios/OfflineWeb"
REPORT=IOS/"PRIVACY_Q5_AUDIT_20261124.json"
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*a,**kwargs):super().__init__(*a,directory=str(WEB),**kwargs)
    def log_message(self,*a):pass
httpd=ThreadingHTTPServer(("127.0.0.1",8766),Handler)
threading.Thread(target=httpd.serve_forever,daemon=True).start()
observations=[]
errors=[]
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        ctx=browser.new_context(viewport={"width":375,"height":812},device_scale_factor=1,is_mobile=True)
        page=ctx.new_page()
        page.on("request",lambda r:observations.append({"url":r.url,"method":r.method,"resourceType":r.resource_type}))
        page.on("pageerror",lambda err:errors.append(str(err)))
        page.goto("http://127.0.0.1:8766/official-practice.html",wait_until="networkidle")
        manifest=json.loads((WEB/"manifest.json").read_text())
        assert manifest.get("count")==599 and manifest.get("explanationsCount")==599
        page.locator("#homeProgress").wait_for(timeout=30000)
        page.locator("#homeStart").click()
        page.locator("#start").click()
        page.locator("#choices button").first.click()
        browser_store=page.evaluate("""() => ({
          localStorageKeys:Object.keys(localStorage),
          sessionStorageKeys:Object.keys(sessionStorage),
          cookie:document.cookie,
          indexedDBSupported:!!window.indexedDB,
          privacyLink:document.querySelector('a[href="./privacy.html"]')?.getAttribute('href')||null
        })""")
        urls=[v["url"] for v in observations]
        local_paths=[urlsplit(x).path for x in urls]
        local_only=all(urlsplit(u).hostname in ("127.0.0.1","localhost") for u in urls)
        data_ok=not browser_store["localStorageKeys"] and not browser_store["sessionStorageKeys"] and not browser_store["cookie"]
        page.locator("#navSettings").click()
        link=page.locator('a[href="./privacy.html"]')
        link_visible=link.count()==1
        page.goto("http://127.0.0.1:8766/privacy.html",wait_until="networkidle")
        policy_text=page.locator("body").inner_text()
        policy_ok=all(s in policy_text for s in ("公式過去問599問","GitHub Pages","IPアドレス","旧版"))
        ctx.close();browser.close()
finally:
    httpd.shutdown()
with (IOS/"native-ios/PrivacyInfo.xcprivacy").open("rb") as f:plist=plistlib.load(f)
manifest_ok=(plist.get("NSPrivacyTracking") is False
    and plist.get("NSPrivacyCollectedDataTypes")==[]
    and plist.get("NSPrivacyTrackingDomains")==[])
metadata=(IOS/"APP_STORE_METADATA.md").read_text()
metadata_ok=("privacy.html" in metadata and "通常学習は通信不要" in metadata)
runtime_ok=local_only and data_ok and link_visible and policy_ok and not errors and manifest_ok and metadata_ok
now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat()
result={"schema":"touhan-q5-privacy-audit-v1","timestampJST":now,
  "sourceAndBrowserAudit":"PASS" if runtime_ok else "FAIL",
  "appStoreConnectReconciliation":"NOT_VERIFIED",
  "gate":"NOT_VERIFIED" if runtime_ok else "FAIL",
  "observedRequestCount":len(observations),
  "observedHosts":sorted({urlsplit(x["url"]).hostname for x in observations}),
  "observedPaths":sorted(set(local_paths)),
  "networkOriginCheck":"PASS" if local_only else "FAIL",
  "browserStorage":browser_store,
  "noNewStorageDuringOneAnswer":data_ok,
  "privacyPolicyAccessible":link_visible,
  "privacyPolicyConsistent":policy_ok,
  "privacyManifestChecks":manifest_ok,
  "metadataPrivacyURLIncluded":metadata_ok,
  "pageErrors":errors,
  "appleRule":"https://developer.apple.com/jp/app-store/app-privacy-details/",
  "requiredASCVerification":["Read actual App Store Connect App Privacy questionnaire for app ID 6802119268",
       "Confirm hosting provider request/log retention and purposes; WebView traffic is in scope",
       "Reconcile declared data types, linkage, tracking, privacy policy URL against service and provider policies"],
  "limitations":["Local-host replay inspects actual shipped HTML/JS but does not prove external CDN/hosting retention.",
       "This evidence is not an App Store Connect configuration readback.",
       "No real iOS WebView network capture or privacy report was performed."]
  }
REPORT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"gate":result["gate"],"sourceAudit":result["sourceAndBrowserAudit"],
                  "requestCount":result["observedRequestCount"],"hosts":result["observedHosts"],
                  "readiness":result["requiredASCVerification"]},ensure_ascii=False))
if not runtime_ok:raise SystemExit("Q5 source/browser privacy audit failed")
