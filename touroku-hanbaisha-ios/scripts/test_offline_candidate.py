#!/usr/bin/env python3
"""Exercise packaged file URLs with networking disabled and all official questions."""
import json,hashlib
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
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
        page.add_init_script("""window.__touhanStudyState=null; window.webkit={messageHandlers:{studyRecord:{postMessage:s=>{window.__savedStudy=JSON.parse(s)}}}};""")
        page.on('request',lambda r:report['externalRequests'].append(r.url) if r.url.startswith(('http:','https:')) else None)
        page.on('pageerror',lambda e:report['pageErrors'].append(str(e)))
        page.goto((OUT/'official-practice.html').as_uri())
        expect(page.locator('#available')).to_contain_text('599問')
        expect(page.locator('#homeProgress')).to_have_text('0 / 599')
        assert page.evaluate("JSON.parse(document.getElementById('offlineBank').textContent)") == bank
        expect(page.locator('#home')).to_be_visible()
        page.locator('#homeStart').click()
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
            print('CHECK '+engine.name+' '+q['id'],flush=True) if report['count']-before<2 else None
            expect(page.locator('#feedback .result')).to_have_text('正解', timeout=5000)
            assert page.locator('#choices button').nth(q['answer']).evaluate("el=>el.classList.contains('good')"), q['id']
            page.locator('#next').click()
            report['count']+=1
        expect(page.locator('#summary')).to_contain_text('599 / 599')
        assert page.evaluate('Object.keys(window.__savedStudy.stats).length')==599
        assert page.evaluate('window.__savedStudy.session') is None
        page.locator('#navRecords').click()
        expect(page.locator('#recordTotal')).to_contain_text('599 / 599')
        expect(page.locator('#recordTotal')).to_contain_text('100%')
        assert page.locator('#yearRecords .recordRow').count()==5
        assert page.locator('#chapterRecords .recordRow').count()==5
        assert page.locator('#answerHistory .recordRow').count()==100
        page.locator('#navStudy').click()
        page.locator('#start').click()
        page.locator('#unknown').click()
        page.locator('#navHome').click()
        page.locator('#resume').click()
        expect(page.locator('#next')).to_be_visible()
        assert page.evaluate('window.__savedStudy.stats[window.__savedStudy.session.ids[0]].attempts')==2
        page.locator('#next').click()
        expect(page.locator('#counter')).to_contain_text('2 / 599')
        page.locator('#navHome').click()
        page.locator('a[href="./privacy.html"]').click()
        assert 'プライバシーポリシー' in page.locator('body').inner_text()
        page.go_back()
        page.locator('a[href="./support.html"]').click()
        assert '599問' in page.locator('body').inner_text()
        print(json.dumps({'engine':engine.name,'completed':report['count']-before,'externalRequests':report['externalRequests'],'pageErrors':report['pageErrors']},ensure_ascii=False),flush=True)
        browser.close()
assert report['count']==1198 and not report['externalRequests'] and not report['pageErrors'],report
print(json.dumps(report,ensure_ascii=False))
