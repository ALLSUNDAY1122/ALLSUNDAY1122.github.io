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
premium=json.loads((ROOT/'touroku-hanbaisha-ios/IAP_POLICY.json').read_text())
free= premium['freeIds']
assert len(free)==len(set(free))==50 and set(free)<= {q['id'] for q in rows}
assert all(sum(q['id'] in free and q['chapter']==c for q in rows)==10 for c in {q['chapter'] for q in rows})
payload=raw.decode('utf-8').replace('<',r'\u003c')
assert html.count('</main><script>')==1
html=html.replace('</main><script>','</main><script type="application/json" id="offlineBank">'+payload+'</script><script>')
html=html.replace('<head>','<head><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\'; style-src \'unsafe-inline\'; img-src file: data:; connect-src \'none\'; base-uri \'none\'; form-action \'none\'">',1)
html=html.replace('<a href="./index.html">‹ ホーム</a>','<button class="button" id="headerHome">‹ ホーム</button>')
# Apply only to the native bundle; keep the public legacy web page unchanged.
from pathlib import Path
shell=Path(__file__).with_name('offline_learning_shell.html').read_text()
logic="const freeIds=new Set("+json.dumps(free)+");\n"+Path(__file__).with_name('offline_learning.js').read_text()
logic+=Path(__file__).with_name('offline_premium.js').read_text()
html=html.replace("return records.filter(q=>($('year')","return records.filter(q=>canStudy(q)&&($('year')")
html=html.replace("if(selected)return;selected=true;const q=subset[position]","if(selected)return;if(!canStudy(subset[position])){beginSetup();return}selected=true;const q=subset[position]")
html=html.replace("selected=false;const q=subset[position];","selected=false;const q=subset[position];if(!canStudy(q)){beginSetup();return;}")
html=html.replace("+'（採点対象）'","+'（セッション正解数 / 回答数）'")

html=html.replace('</style>',Path(__file__).with_name('offline_learning.css').read_text()+'</style>',1)
html=html.replace('<section class="card" id="setup">',shell+'<p id="saveWarning" class="saveWarning" role="alert"></p><section class="card hidden" id="setup">',1)
html=html.replace("let records=[],subset=[],position=0,correct=0,denominator=0,selected=false,excluded=0;","let records=[],subset=[],position=0,correct=0,denominator=0,selected=false,excluded=0;"+logic+"\n$('headerHome').onclick=showHome;")
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
(OUT/'manifest.json').write_text(json.dumps({'count':599,'bankSha256':hashlib.sha256(raw).hexdigest(),'figures':figures,'mode':'offline-inline-json'},indent=2)+'\n')
print('PASS: generated offline bundle: 599 questions,',len(figures),'verified figures')
