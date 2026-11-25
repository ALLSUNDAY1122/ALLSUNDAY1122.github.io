#!/usr/bin/env python3
"""Exercise packaged file URLs with networking disabled and all official questions."""
import json,hashlib,re
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'touroku-hanbaisha-ios/native-ios/OfflineWeb'
bank=json.loads((ROOT/'touroku-hanbaisha-sprint/official-kansai/APPROVED_OFFICIAL_BANK.json').read_text())
report={'count':0,'figures':0,'externalRequests':[],'pageErrors':[],'consoleErrors':[],'browserEngines':{}}
with sync_playwright() as pw:
    for engine in [pw.chromium,pw.webkit]:
        browser=engine.launch()
        ctx=browser.new_context(viewport={'width':375,'height':812})
        # Block every HTTP(S) request, without WebKit's offline mode also blocking file navigation.
        ctx.route('http://**/*', lambda route: route.abort())
        ctx.route('https://**/*', lambda route: route.abort())
        before=report['count']
        report['browserEngines'][engine.name]=0
        print('START engine='+engine.name,flush=True)
        page=ctx.new_page()
        page.add_init_script("""window.__touhanStudyState=null; window.webkit={messageHandlers:{studyRecord:{postMessage:s=>{window.__savedStudy=JSON.parse(s)}}}};""")
        page.on('request',lambda r:report['externalRequests'].append(r.url) if r.url.startswith(('http:','https:')) else None)
        page.on('pageerror',lambda e:report['pageErrors'].append(str(e)))
        page.on('console',lambda m:report['consoleErrors'].append(m.text) if m.type=='error' else None)
        page.on('console',lambda m: print('BROWSER_CONSOLE '+m.type+' '+m.text,flush=True) if m.type=='error' else None)
        page.goto((OUT/'official-practice.html').as_uri())
        print('DEBUG offlineBank='+str(page.locator('#offlineBank').count())+' bankChars='+str(page.locator('#offlineBank').text_content() and len(page.locator('#offlineBank').text_content()))+' explanationChars='+str(page.locator('#offlineExplanations').text_content() and len(page.locator('#offlineExplanations').text_content()))+' available='+page.locator('#available').inner_text(),flush=True)
        page.wait_for_timeout(1000)
        print('DEBUG_STATE '+json.dumps(page.evaluate("({available:document.querySelector('#available')?.textContent,home:document.querySelector('#homeProgress')?.textContent,scriptCount:document.scripts.length,inline:document.querySelector('script:not([type])')?.textContent.includes('offlineBank'),recordType:typeof records})"),ensure_ascii=False)+' PAGE_ERRORS '+json.dumps(report['pageErrors'],ensure_ascii=False)+' CONSOLE_ERRORS '+json.dumps(report['consoleErrors'],ensure_ascii=False),flush=True)
        expect(page.locator('#available')).to_contain_text('599問')
        expect(page.locator('#homeProgress')).to_have_text('0 / 599')
        assert page.evaluate("JSON.parse(document.getElementById('offlineBank').textContent)") == bank
        explanation_bundle=page.evaluate("JSON.parse(document.getElementById('offlineExplanations').textContent)")
        assert explanation_bundle['schema']=='touroku-hanbaisha-audited-explanations-v1'
        assert explanation_bundle['count']==len(explanation_bundle['records'])==599
        assert explanation_bundle['auditSummary']=={'PASS':599,'HOLD':0,'PENDING':0}
        expect(page.locator('#home')).to_be_visible()
        page.locator('#homeStart').click()
        assert page.evaluate('eligible().length')==50
        assert page.evaluate("Object.values(eligible().reduce((a,q)=>(a[q.chapter]=(a[q.chapter]||0)+1,a),{})).every(n=>n===10)")
        page.locator('#start').click()
        assert page.evaluate('subset.length')==50
        page.locator('#unknown').click()
        expect(page.locator('#score')).to_have_text('正解 0問 / 回答 1問')
        page.locator('#navHome').click()
        page.locator('#resume').click()
        assert page.evaluate('statsFor(records).n')==1
        page.evaluate("study=blankState(); showHome(); window.setPremiumEntitlement(true)")
        page.locator('#homeStart').click()
        assert page.evaluate('eligible().length')==599
        page.locator('#start').click()
        page.evaluate("window.setPremiumEntitlement(false)")
        expect(page.locator('#setup')).to_be_visible()
        assert page.evaluate('eligible().length')==50
        assert page.evaluate('validSession(study.session)')==False
        page.evaluate("window.setPremiumEntitlement(true)")
        page.locator('#start').click()
        for q in bank['questions']:
            assert page.locator('#question').inner_text().strip()
            rendered_question=page.locator('#question').evaluate("el=>Array.from(el.childNodes).map(n=>n.textContent||'').join('')")
            assert not re.search(r'(?<!\n)\n(?!\n)',rendered_question),q['id']
            assert page.locator('#choices button').count()==len(q['choices'])
            for img in page.locator('#sourceFigure img').all():
                img.scroll_into_view_if_needed()
                img.evaluate("(el)=>el.decode()")
                assert img.evaluate("(el)=>el.naturalWidth>0")
                report['figures']+=1
            page.locator('#choices button').nth(q['answer']).click()
            print('CHECK '+engine.name+' '+q['id'],flush=True) if report['count']-before<2 else None
            expect(page.locator('#feedback .result')).to_have_text('正解', timeout=5000)
            expect(page.locator('#feedback .explanation')).to_be_visible()
            assert page.locator('#feedback .explanation').inner_text().strip()
            expect(page.locator('#feedback #attribution')).to_be_visible()
            assert page.locator('#feedback #attribution a').count()>=2
            assert page.locator('#choices button').nth(q['answer']).evaluate("el=>el.classList.contains('good')"), q['id']
            page.locator('#next').click()
            debug=page.evaluate("""() => ({
              feedbackCount:document.querySelectorAll('#feedback').length,
              feedbackChildren:Array.from(document.querySelector('#feedback')?.children||[]).map(n=>({id:n.id,cls:n.className})),
              attributionNodes:Array.from(document.querySelectorAll('#attribution')).map(n=>({parent:n.parentElement?.id,hidden:n.classList.contains('hidden')})),
              nextHandler:document.querySelector('#next')?.onclick?.toString()
            })""")
            if report['count']-before<2 or q['id']==bank['questions'][-1]['id']:
                print('NEXT_STATE '+json.dumps(debug,ensure_ascii=False),flush=True)
            expect(page.locator('#feedback #attribution')).to_have_count(0)
            expect(page.locator('#attribution')).to_be_hidden()
            report['count']+=1
            report['browserEngines'][engine.name]+=1
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
        page.locator('#navSettings').click()
        expect(page.locator('#settings')).to_be_visible()
        page.locator('a[href="./privacy.html"]').click()
        assert 'プライバシーポリシー' in page.locator('body').inner_text()
        page.go_back()
        page.locator('#navSettings').click()
        expect(page.locator('#settings')).to_be_visible()
        page.locator('a[href="./support.html"]').click()
        assert '599問' in page.locator('body').inner_text()
        print(json.dumps({'engine':engine.name,'completed':report['count']-before,'externalRequests':report['externalRequests'],'pageErrors':report['pageErrors']},ensure_ascii=False),flush=True)
        browser.close()
assert report['count']==1198 and report['browserEngines']=={'chromium':599,'webkit':599} and not report['externalRequests'] and not report['pageErrors'],report
report.update({'status':'PASS','bankCount':599,'explanationsCount':599,'nativeSimulatorOfflineBundleVerified':False,'scope':'Packaged OfflineWeb file:// browser tests with all HTTP(S) requests blocked; simulator native bundle verification follows in Q6 workflow.'})
(ROOT/'touroku-hanbaisha-ios/OFFLINE_Q4_BROWSER_20261125.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
