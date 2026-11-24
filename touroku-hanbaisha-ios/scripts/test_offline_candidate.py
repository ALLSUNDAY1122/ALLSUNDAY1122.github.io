#!/usr/bin/env python3
"""Exercise packaged file URLs with networking disabled and all official questions."""
import json,hashlib
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'touroku-hanbaisha-ios/native-ios/OfflineWeb'
bank=json.loads((ROOT/'touroku-hanbaisha-sprint/official-kansai/APPROVED_OFFICIAL_BANK.json').read_text())
report={'count':0,'figures':0,'externalRequests':[],'pageErrors':[]}
with sync_playwright() as pw:
    for engine in [pw.chromium,pw.webkit]:
        browser=engine.launch()
        ctx=browser.new_context(viewport={'width':375,'height':812})
        # Block every HTTP(S) request, without WebKit's offline mode also blocking file navigation.
        ctx.route('http://**/*', lambda route: route.abort())
        ctx.route('https://**/*', lambda route: route.abort())
        before=report['count']
        print('START engine='+engine.name,flush=True)
        page=ctx.new_page()
        page.on('request',lambda r:report['externalRequests'].append(r.url) if r.url.startswith(('http:','https:')) else None)
        page.on('pageerror',lambda e:report['pageErrors'].append(str(e)))
        page.goto((OUT/'official-practice.html').as_uri())
        page.locator('#available').get_by_text('599問',exact=False).wait_for()
        assert page.evaluate("JSON.parse(document.getElementById('offlineBank').textContent)") == bank
        page.locator('#start').click()
        for q in bank['questions']:
            assert page.locator('#question').inner_text().strip()
            assert page.locator('#choices button').count()==len(q['choices'])
            for img in page.locator('#sourceFigure img').all():
                img.scroll_into_view_if_needed()
                img.evaluate("(el)=>el.decode()")
                assert img.evaluate("(el)=>el.naturalWidth>0")
                report['figures']+=1
            page.locator('#choices button').nth(q['answer']).click()
            assert page.locator('#feedback').inner_text()=='正解'
            page.locator('#next').click()
            report['count']+=1
        assert '599 / 599' in page.locator('#summary').inner_text()
        page.locator('#restart').click()
        page.locator('a[href="./privacy.html"]').click()
        assert 'プライバシーポリシー' in page.locator('body').inner_text()
        page.go_back()
        page.locator('a[href="./support.html"]').click()
        assert '599問' in page.locator('body').inner_text()
        print(json.dumps({'engine':engine.name,'completed':report['count']-before,'externalRequests':report['externalRequests'],'pageErrors':report['pageErrors']},ensure_ascii=False),flush=True)
        browser.close()
assert report['count']==1198 and not report['externalRequests'] and not report['pageErrors'],report
print(json.dumps(report,ensure_ascii=False))
