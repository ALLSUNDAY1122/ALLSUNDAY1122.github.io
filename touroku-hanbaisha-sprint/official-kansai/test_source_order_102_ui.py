#!/usr/bin/env python3
"""Real Chromium render test of full merged bank and unattached ruby list."""
import json,threading
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
from playwright.sync_api import sync_playwright
from auto_diff_pdf import B
ROOT=B.parents[1]
bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
report=json.loads((B/"RUBY_102_SOURCE_ORDER_PROMOTION_20261124.json").read_text())
passed={r["id"] for r in report["records"] if r["status"]=="SOURCE_ORDER_PASS"}
new=[q for q in bank["questions"] if q["id"] in passed]
assert len(new)==report["promoted"]
assert all(q["originalRubyReadings"] for q in new)
class Quiet(SimpleHTTPRequestHandler):
    def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT/"touroku-hanbaisha-sprint"),**kw)
    def log_message(self,*a):pass
httpd=ThreadingHTTPServer(("127.0.0.1",8765),Quiet)
threading.Thread(target=httpd.serve_forever,daemon=True).start()
results=[]
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(channel="chrome",headless=True)
        for w in (375,430):
            ctx=browser.new_context(viewport={"width":w,"height":850},device_scale_factor=1,is_mobile=True,has_touch=True)
            page=ctx.new_page()
            errors=[]
            page.on("pageerror",lambda e:errors.append(str(e)))
            page.goto("http://127.0.0.1:8765/official-practice.html",wait_until="networkidle")
            assert f"{bank['count']}問" in page.locator("#available").inner_text(),page.locator("#available").inner_text()
            assert not errors,errors
            # Run every newly promoted question through exactly the production rendering functions.
            if new:
                page.route("**/official-kansai/APPROVED_OFFICIAL_BANK.json",
                           lambda route:route.fulfill(status=200,content_type="application/json",
                           body=json.dumps({"count":len(new),"questions":new},ensure_ascii=False)))
                page.reload(wait_until="networkidle")
                assert f"{len(new)}問" in page.locator("#available").inner_text()
                page.locator("#start").click()
                for q in new:
                    dom=page.locator("#rubySequence")
                    assert dom.is_visible(),q["id"]
                    readings=page.locator("#rubySequence span").inner_text().split("　／　")
                    assert readings==q["originalRubyReadings"],q["id"]
                    assert page.locator("#choices button").count()==len(q["choices"]),q["id"]
                    overflow=page.evaluate("document.documentElement.scrollWidth > document.documentElement.clientWidth+2")
                    assert not overflow,(q["id"],w)
                    page.locator("#choices button").nth(q["answer"]).click()
                    assert "正解" in page.locator("#feedback").inner_text(),q["id"]
                    page.locator("#next").click()
                    results.append({"id":q["id"],"width":w,"status":"PASS"})
            assert not errors,errors
            ctx.close()
        browser.close()
finally:
    httpd.shutdown()
out={"result":"PASS","productionBankLoaded":bank["count"],"newQuestionCount":len(new),
     "browserCases":len(results),"widths":[375,430],"results":results}
(B/"RUBY_102_SOURCE_ORDER_BROWSER_QA_20261124.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({k:v for k,v in out.items() if k!="results"},ensure_ascii=False))
