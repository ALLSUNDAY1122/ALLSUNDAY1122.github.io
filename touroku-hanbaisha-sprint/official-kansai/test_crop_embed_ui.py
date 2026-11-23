#!/usr/bin/env python3
"""Exercise actual original PDF crop PNG in 375/430px UI, isolated mock rights clearance.

The fixture's licenseVerified/visualVerified flags are QA mocks only; no production
metadata is altered and no source-crop question is silently promoted.
"""
import json,hashlib
from pathlib import Path
from playwright.sync_api import sync_playwright
B=Path(__file__).resolve().parent
bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
year=2022
crop=json.loads((B/"LAYOUT_CROPS_2022.json").read_text())
chosen=next((r for r in crop["records"] if r["alreadyApproved"] and r["assets"]),None)
if not chosen:raise RuntimeError("no approved fixture with real source PNG")
question=next(q for q in bank["questions"] if q["id"]==chosen["id"])
asset=chosen["assets"][0]
data=(B/asset["relativePath"]).read_bytes()
assert hashlib.sha256(data).hexdigest()==asset["sha256"]
fig={"webPath":asset["webPath"],"sha256":asset["sha256"],
      "sourcePdfUrl":chosen["sourcePdfUrl"],"page":asset["page"],
      "licenseVerified":True,"visualVerified":True} # QA mock; not persisted
case=dict(question,sourceFigures=[fig])
payload=json.dumps({"count":1,"questions":[case]},ensure_ascii=False)
results=[]
with sync_playwright() as p:
    browser=p.chromium.launch()
    for width in (375,430):
        context=browser.new_context(viewport={"width":width,"height":820},device_scale_factor=2,is_mobile=True,has_touch=True)
        page=context.new_page()
        page.route("**/official-kansai/APPROVED_OFFICIAL_BANK.json",lambda route:route.fulfill(status=200,content_type="application/json",body=payload))
        page.goto("http://127.0.0.1:8765/official-practice.html",wait_until="networkidle")
        page.locator("#start").click()
        img=page.locator("#sourceFigure img")
        img.wait_for()
        assert img.count()==1
        loaded=img.evaluate("img=>({w:img.naturalWidth,h:img.naturalHeight,client:img.clientWidth,complete:img.complete})")
        assert loaded["complete"] and loaded["w"]==asset["width"] and loaded["h"]==asset["height"],loaded
        assert loaded["client"]<width,loaded
        assert page.locator("#sourceFigure figcaption").inner_text().count("関西広域連合")>=1
        assert page.locator("#sourceFigure a").get_attribute("href")==fig["webPath"]
        assert page.evaluate("document.documentElement.scrollWidth - document.documentElement.clientWidth")<=2
        page.screenshot(path=f"/tmp/touhan-crop-mobile-{width}.png",full_page=True)
        results.append({"width":width,"natural":loaded,"status":"PASS"})
        context.close()
    browser.close()
out={"status":"PASS","sourceQuestion":chosen["id"],"sourceImageSha256":asset["sha256"],
     "qaOnlyMockClearance":True,"views":results,
     "releaseAuthorization":"NONE - image rights and actual visual review remain blocked",
     "note":"Only tests approved existing question with unapproved crop image injected into browser; no production bank changed."}
(B/"CROP_EMBED_QA.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(out,ensure_ascii=False))
