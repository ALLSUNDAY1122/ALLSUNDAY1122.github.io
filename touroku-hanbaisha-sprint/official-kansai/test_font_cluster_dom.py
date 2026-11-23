#!/usr/bin/env python3
"""Real Chrome mobile DOM verification of exactly the newly approved ruby questions."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
B=Path(__file__).resolve().parent
bank=json.loads((B/'APPROVED_OFFICIAL_BANK.json').read_text())
approved=[q for q in bank['questions'] if q['audit']['method']=='PDF_RAW_FONT_CLUSTER_RUBY']
assert len(approved)==10,('Expected reviewed new approved set',len(approved))
assert bank['count']==440
result=[]
body=json.dumps({'count':len(approved),'questions':approved},ensure_ascii=False)
with sync_playwright() as p:
    browser=p.chromium.launch(channel='chrome',headless=True)
    for width in (375,430):
        ctx=browser.new_context(viewport={'width':width,'height':850},
             device_scale_factor=2,is_mobile=True,has_touch=True)
        page=ctx.new_page()
        errors=[]
        page.on('pageerror',lambda error:errors.append(str(error)))
        page.route('**/official-kansai/APPROVED_OFFICIAL_BANK.json',
            lambda route:route.fulfill(status=200,content_type='application/json',body=body))
        page.goto('http://127.0.0.1:8765/official-practice.html',wait_until='networkidle')
        assert '10問' in page.locator('#available').inner_text()
        page.locator('#start').click()
        for idx,q in enumerate(approved):
            assert str(q['questionNo']) in page.locator('#questionTitle').inner_text()
            assert page.locator('#choices button').count()==len(q['choices'])
            boxes=page.evaluate("""() => [...document.querySelectorAll('#question ruby,#choices ruby')].map(e=>{
               let base=document.createRange();base.selectNodeContents(e.firstChild);
               let b=base.getBoundingClientRect(),r=e.querySelector('rt').getBoundingClientRect();
               return {base:e.firstChild.textContent,reading:e.querySelector('rt').textContent,
                 horizontal:Math.abs((b.left+b.right-r.left-r.right)/2),
                 vertical:b.top-r.bottom,width:b.width};
            })""")
            expected=[z for part in [q['questionParts'],*q['choicesParts']] for z in part if 'rubyBase' in z]
            assert len(boxes)==len(expected),(q['id'],len(boxes),len(expected))
            for got,want in zip(boxes,expected):
                assert got['base']==want['rubyBase'] and got['reading']==want['rubyText']
                assert got['horizontal']<max(10,got['width']*1.3),(q['id'],got)
                assert got['vertical']>-3,(q['id'],got)
            overflow=page.evaluate('document.documentElement.scrollWidth-document.documentElement.clientWidth')
            assert overflow<=2,(q['id'],width,overflow)
            if idx in (0,5,9):
                page.screenshot(path=f'/tmp/touhan-font-dom-{width}-{q["id"]}.png',full_page=True)
            page.locator('#choices button').nth(q['answer']).click()
            assert '正解' in page.locator('#feedback').inner_text()
            page.locator('#next').click()
            result.append({'id':q['id'],'width':width,'rubyElements':len(boxes),'status':'PASS'})
        assert '100%' in page.locator('#summary').inner_text()
        assert not errors,errors
        ctx.close()
    browser.close()
(B/'RUBY_FONT_DOM_QA_20261124.json').write_text(json.dumps({
  'status':'PASS','viewportWidths':[375,430],'cases':len(result),
  'browser':'Real Chrome headless mobile viewport, not iOS device/Safari',
  'records':result},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'PASS','cases':len(result),'questions':len(approved)},ensure_ascii=False))
