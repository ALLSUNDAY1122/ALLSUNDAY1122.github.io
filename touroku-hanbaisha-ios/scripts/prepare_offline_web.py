#!/usr/bin/env python3
"""Generate deterministic local-only native learning resources from approved bank."""
import hashlib,json,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WEB=ROOT/'touroku-hanbaisha-sprint'
OUT=ROOT/'touroku-hanbaisha-ios/native-ios/OfflineWeb'
bank_path=WEB/'official-kansai/APPROVED_OFFICIAL_BANK.json'
raw=bank_path.read_bytes()
bank=json.loads(raw)
rows=bank['questions']
explanation_path=WEB/'official-kansai/EXPLANATIONS_AUDITED_599.json'
explanation_raw=explanation_path.read_bytes()
explanation_data=json.loads(explanation_raw)
assert explanation_data['schema']=='touroku-hanbaisha-audited-explanations-v1'
explanation_records=explanation_data['records']
assert explanation_data['count']==len(explanation_records)==599
assert explanation_data['auditSummary']=={'PASS':599,'HOLD':0,'PENDING':0}
assert len({x['id'] for x in explanation_records})==599
assert {x['id'] for x in explanation_records}=={q['id'] for q in rows}
assert bank['count']==len(rows)==599
assert len({q['id'] for q in rows})==599 and 'KSAI-2023-090' not in {q['id'] for q in rows}
if OUT.exists(): shutil.rmtree(OUT)
OUT.mkdir()
figures={}
for q in rows:
    assert q['verbatimCertified'] and q['renderReady'] and not q['needsVisualReview']
    for f in q.get('sourceFigures',[]):
        name=f['webPath']
        assert re.fullmatch(r'official-kansai/layout-crops/KSAI-20[2][2-6]-[0-9]{3}-p[0-9]+-[0-9]+\.png',name),name
        assert f['licenseVerified'] and f['visualVerified']
        data=(WEB/name).read_bytes()
        digest=hashlib.sha256(data).hexdigest()
        assert digest==f['sha256'],name
        dest=OUT/name
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(data)
        figures[name]=digest
html=(WEB/'official-practice.html').read_text()
old="fetch(BANK,{cache:'no-store'}).then(r=>{if(!r.ok)throw Error('HTTP '+r.status);return r.json()}).then(d=>{"
assert html.count(old)==1
html=html.replace(old,"Promise.resolve().then(()=>JSON.parse(document.getElementById('offlineBank').textContent)).then(d=>{")
assert html.count("fetch('official-kansai/EXPLANATIONS_AUDITED_599.json',{cache:'no-store'}).then(r=>{if(!r.ok)throw Error('HTTP '+r.status);return r.json()}).then(d=>{if(d?.count!==599||d.records?.length!==599||d.auditSummary?.PASS!==599||d.auditSummary?.HOLD!==0)throw Error('解説監査データの件数・状態が一致しません');explanationMap=new Map(d.records.map(x=>[x.id,x]));}).catch(()=>{explanationMap=new Map()});")==1
html=html.replace("fetch('official-kansai/EXPLANATIONS_AUDITED_599.json',{cache:'no-store'}).then(r=>{if(!r.ok)throw Error('HTTP '+r.status);return r.json()}).then(d=>{if(d?.count!==599||d.records?.length!==599||d.auditSummary?.PASS!==599||d.auditSummary?.HOLD!==0)throw Error('解説監査データの件数・状態が一致しません');explanationMap=new Map(d.records.map(x=>[x.id,x]));}).catch(()=>{explanationMap=new Map()});","const offlineExplanationData=JSON.parse(document.getElementById('offlineExplanations').textContent);if(offlineExplanationData.count!==599||offlineExplanationData.records?.length!==599||offlineExplanationData.auditSummary?.PASS!==599||offlineExplanationData.auditSummary?.HOLD!==0)throw Error('offline explanation bundle integrity failure');explanationMap=new Map(offlineExplanationData.records.map(x=>[x.id,x]));")
premium=json.loads((ROOT/'touroku-hanbaisha-ios/IAP_POLICY.json').read_text())
free= premium['freeIds']
assert len(free)==len(set(free))==50 and set(free)<= {q['id'] for q in rows}
assert all(sum(q['id'] in free and q['chapter']==c for q in rows)==10 for c in {q['chapter'] for q in rows})
payload=raw.decode('utf-8').replace('<',r'\u003c')
assert html.count('</main><script>')==1
explanation_payload=explanation_raw.decode('utf-8').replace('<',r'\u003c')
html=html.replace('</main><script>','</main><script type="application/json" id="offlineBank">'+payload+'</script><script type="application/json" id="offlineExplanations">'+explanation_payload+'</script><script>')
html=html.replace('<head>','<head><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\'; style-src \'unsafe-inline\'; img-src file: data:; connect-src \'none\'; base-uri \'none\'; form-action \'none\'">',1)
html=html.replace('<a href="./index.html">‹ ホーム</a>','<button class="button" id="headerHome">‹ ホーム</button>')
html=html.replace('<div id="question" class="question"></div><div id="rubySequence" class="ruby-sequence hidden"></div>','<div id="question" class="question"><span id="rubySequence" class="ruby-sequence hidden"></span></div>')
# Apply only to the native bundle; keep the public legacy web page unchanged.
from pathlib import Path
shell=Path(__file__).with_name('offline_learning_shell.html').read_text()
logic="const freeIds=new Set("+json.dumps(free)+");\n"+Path(__file__).with_name('offline_learning.js').read_text()
logic+=Path(__file__).with_name('offline_premium.js').read_text()
assert "const attributionNode=$('attribution')" in logic, 'source attribution must remain mounted and reusable across question transitions'
assert "const card=$('quiz').querySelector('article.card')" in logic and "$('feedback').querySelector('#attribution')?.remove()" in logic and "$('feedback').append(attributionNode)" in logic and "attributionNode.classList.add('hidden')" in logic and "function keepSingleAttribution()" in logic and "document.querySelectorAll('#attribution')" in logic, 'source attribution must move into judgement feedback, then be removed and hidden for the next question'
assert "setScreen('home')" in Path(__file__).with_name('offline_learning.js').read_text(), 'home tab must restore the home screen after an active session'
assert "if($('openRecords'))$('openRecords').onclick=showRecords" in logic and "if($('recordsHome'))$('recordsHome').onclick=showHome" in logic, 'new four-tab shell must not require removed legacy navigation nodes'
html=html.replace("return records.filter(q=>($('year')","return records.filter(q=>canStudy(q)&&($('year')")
html=html.replace("if(selected)return;selected=true;const q=subset[position]","if(selected)return;if(!canStudy(subset[position])){beginSetup();return}selected=true;const q=subset[position]")
html=html.replace("selected=false;const q=subset[position];","selected=false;const q=subset[position];if(!canStudy(q)){beginSetup();return;}")
assert html.count("correct+' / '+denominator+'（採点対象）'")==2
html=html.replace("correct+' / '+denominator+'（採点対象）'","'正解 '+correct+'問 / 回答 '+denominator+'問'")

html=html.replace('</style>',Path(__file__).with_name('offline_learning.css').read_text()+'</style>',1)
html=html.replace('<section class="card hidden" id="setup">','<section class="card hidden" id="setup"><div class="mock-top"><div class="eyebrow">模擬試験</div><h2>本番形式</h2><p class="sub">年度・分野を選んで学習します。</p><div id="mockYears" class="mockYears"></div></div>',1)
html=html.replace('<section id="quiz" class="hidden"><div class="meta"><span id="counter"></span><span id="score"></span></div>','<section id="quiz" class="hidden"><div class="quizhead"><button class="button" id="headerHome">‹ ホーム</button><div class="quizmeta"><b>登録販売者</b><span id="qtag"></span></div><div class="counter" id="counter"></div></div><div class="qbar"><div id="progressBar"></div></div><div class="meta"><span id="score"></span></div>')
html=html.replace("function updateCount(){$('count').textContent='この範囲で学べる問題：'+eligible().length+'問';$('start').disabled=!eligible().length}", "function updateCount(){const total=records.filter(q=>($('year').value==='all'||String(q.year)===$('year').value)&&($('chapter').value==='all'||q.chapter===$('chapter').value)).length;const n=eligible().length;$('count').textContent=premiumUnlocked?'この範囲で学べる問題：'+n+'問':'無料で学べる問題：'+n+'問／全'+total+'問（Premiumで全599問）';$('start').disabled=!total}")
html=html.replace("subset=eligible();if(!subset.length)return;sessionScope=", "subset=eligible();if(!subset.length){requestPremium();return}sessionScope=")
html=html.replace("$('counter').textContent=(position+1)+' / '+subset.length+'問';", "$('counter').textContent=(position+1)+' / '+subset.length+'問';$('qtag').textContent=q.chapter;$('progressBar').style.width=(position/subset.length*100)+'%';")
html=html.replace("function appendRich(parent,parts,plain){if(!parts){parent.textContent=plain;return}", "function displayPdfText(value){return String(value||'').replace(/\\r\\n?/g,'\\n').replace(/(?<!\\n)\\n(?!\\n)/g,'')}\nfunction appendRich(parent,parts,plain){const sequence=$('rubySequence');if(!parts){parent.textContent=displayPdfText(plain);if(sequence)parent.append(sequence);return}")
html=html.replace('document.createTextNode(piece.text)','document.createTextNode(displayPdfText(piece.text))')
html=html.replace('parent.append(ruby)}}\nfunction approvedFigures','parent.append(ruby)}if(sequence)parent.append(sequence)}\nfunction approvedFigures')
html=html.replace('body.textContent=explanation.explanation','body.textContent=displayPdfText(explanation.explanation)')
html=html.replace("$('unknown').classList.add('hidden');$('next').classList.remove('hidden');", "$('feedback').append($('attribution'));$('unknown').classList.add('hidden');$('next').classList.remove('hidden');")

html=html.replace('<section class="card" id="setup">',shell+'<p id="saveWarning" class="saveWarning" role="alert"></p><section class="card hidden" id="setup">',1)
html=html.replace("let records=[],subset=[],position=0,correct=0,denominator=0,selected=false,excluded=0;","let records=[],subset=[],position=0,correct=0,denominator=0,selected=false,excluded=0;"+logic+"\nif($('headerHome'))$('headerHome').onclick=showHome;")
html=html.replace("$('chapter').onchange=updateCount;updateCount();","$('chapter').onchange=updateCount;updateCount();showHome();")
html=html.replace("subset=eligible();if(!subset.length)return;position=0;correct=0;denominator=0;excluded=0;","subset=eligible();if(!subset.length)return;sessionScope={year:$('year').value,chapter:$('chapter').value};position=0;correct=0;denominator=0;excluded=0;lastAnswer=null;")
html=html.replace("$('quiz').classList.remove('hidden');show()};","setScreen('quiz');show();checkpoint()};")
html=html.replace("Array.from($('choices').children).forEach", "storeAnswer(q,i);renderAnswer(i);}\nfunction renderAnswer(i){const q=subset[position],exclude=q.excludeFromAccuracyDenominator===true;\nArray.from($('choices').children).forEach",1)
html=html.replace("if(++position<subset.length){show();window.scrollTo(0,0)}else finish()", "if(++position<subset.length){lastAnswer=null;show();checkpoint();window.scrollTo(0,0)}else finish()")
html=html.replace("function finish(){$('quiz').classList.add('hidden');$('complete').classList.remove('hidden');","function finish(){study.session=null;persistStudy();setScreen('complete');")
html=html.replace("$('complete').classList.add('hidden');$('setup').classList.remove('hidden')","setScreen('setup')")
assert 'function renderAnswer(i)' in html and 'checkpoint()' in html and 'id="home"' in html
html=html.replace('候補600問を監査済みと表示しません。','インターネット接続なしで学習できます。')
assert 'fetch(BANK' not in html
(OUT/'official-practice.html').write_text(html,encoding='utf-8')
for name in ['privacy.html','support.html']:
    text=(WEB/name).read_text()
    text=text.replace('<head>','<head><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; base-uri \'none\'; form-action \'none\'">',1)
    (OUT/name).write_text(text,encoding='utf-8')
(OUT/'manifest.json').write_text(json.dumps({'count':599,'bankSha256':hashlib.sha256(raw).hexdigest(),'explanationsCount':599,'explanationsSha256':hashlib.sha256(explanation_raw).hexdigest(),'figures':figures,'mode':'offline-inline-json'},indent=2)+'\n')
print('PASS: generated offline bundle: 599 questions,',len(figures),'verified figures')

# Q6 current-branch trigger: attribution cleanup is validated in the packaged OfflineWeb output.
