#!/usr/bin/env python3
"""Browser rubric actual DOM + font-position test at iPhone-equivalent viewports."""
import copy,json
from pathlib import Path
from playwright.sync_api import sync_playwright
B=Path(__file__).resolve().parent
bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
ruby=[x for x in bank["questions"] if x["audit"]["method"]=="AUTO_PDF_GLYPH_XY_RUBY_DOM_RECONSTRUCTION"]
if ruby:
    chosen=ruby[0]
else:
    # Explicitly synthetic renderer-only fixture, not exam evidence.
    chosen=copy.deepcopy(bank["questions"][0])
    chosen.update({"question":"罹患について正しいものを選べ。","questionParts":[{"rubyBase":"罹","rubyText":"り"},{"text":"患について正しいものを選べ。"}],
                   "choices":["選択肢A","選択肢B","選択肢C","選択肢D","選択肢E"],
                   "choicesParts":[[{"text":f"選択肢{x}"}] for x in "ABCDE"],
                   "answer":0,"audit":{"method":"AUTO_PDF_GLYPH_XY_RUBY_DOM_RECONSTRUCTION","status":"PASS"}})
body={"count":1,"questions":[chosen]}
results=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    for width in [375,430]:
        context=browser.new_context(viewport={"width":width,"height":820},device_scale_factor=2,is_mobile=True,has_touch=True)
        page=context.new_page()
        page.route("**/official-kansai/APPROVED_OFFICIAL_BANK.json",lambda route:route.fulfill(status=200,content_type="application/json; charset=utf-8",body=json.dumps(body,ensure_ascii=False)))
        page.goto("http://127.0.0.1:8765/official-practice.html",wait_until="networkidle")
        assert "1問" in page.locator("#count").inner_text(),page.locator("#available").inner_text()
        page.locator("#start").click()
        positions=page.evaluate("""() => {
          const rubies=[...document.querySelectorAll('#question ruby, #choices ruby')];
          return rubies.map(el=>{
            let range=document.createRange();
            range.selectNodeContents(el.firstChild);
            let base=range.getBoundingClientRect(), reading=el.querySelector('rt').getBoundingClientRect();
            return {base:el.firstChild.textContent,rt:el.querySelector('rt').textContent,
              horizontalOffset:Math.abs((base.left+base.right)/2-(reading.left+reading.right)/2),
              verticalGap:base.top-reading.bottom,baseWidth:base.width};
          });
        }""")
        assert positions, "Missing actual ruby / rt DOM"
        for x in positions:
            assert x["base"] and x["rt"]
            assert x["horizontalOffset"]<max(10,x["baseWidth"]*1.3),x
            assert x["verticalGap"]>-3,x
        overflow=page.evaluate("document.documentElement.scrollWidth-document.documentElement.clientWidth")
        assert overflow<=2,overflow
        screenshot=f"/tmp/touhan-ruby-{width}.png"
        page.screenshot(path=screenshot,full_page=True)
        page.locator("#choices button").nth(chosen["answer"]).click()
        page.locator("#next").click()
        assert "100%" in page.locator("#summary").inner_text()
        results.append({"viewport":width,"rubyElements":len(positions),"maxHorizontalOffset":round(max(x["horizontalOffset"] for x in positions),2),
                        "screenshot":screenshot,"status":"PASS"})
        context.close()
    browser.close()
(B/"RUBY_DOM_QA_RESULT.json").write_text(json.dumps({"status":"PASS","fixture":"AUDITED_RUBY" if ruby else "SYNTHETIC_RENDERER_ONLY",
    "approvedRubyCount":len(ruby),"views":results,
    "limitation":"Browser CSS ruby geometry validated; synthetic fallback does not certify exam-level ruby."},ensure_ascii=False,indent=2)+"\n")
print("PASS ruby DOM geometry",results)
