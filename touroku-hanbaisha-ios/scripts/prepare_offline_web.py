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
payload=raw.decode('utf-8').replace('<',r'\u003c')
assert html.count('</main><script>')==1
html=html.replace('</main><script>','</main><script type="application/json" id="offlineBank">'+payload+'</script><script>')
html=html.replace('<head>','<head><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\'; style-src \'unsafe-inline\'; img-src file: data:; connect-src \'none\'; base-uri \'none\'; form-action \'none\'">',1)
html=html.replace('<a href="./index.html">‹ ホーム</a>','<a href="./official-practice.html">‹ 学習範囲</a>')
html=html.replace('候補600問を監査済みと表示しません。','インターネット接続なしで学習できます。')
assert 'fetch(BANK' not in html
(OUT/'official-practice.html').write_text(html,encoding='utf-8')
for name in ['privacy.html','support.html']:
    text=(WEB/name).read_text()
    text=text.replace('<head>','<head><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; base-uri \'none\'; form-action \'none\'">',1)
    (OUT/name).write_text(text,encoding='utf-8')
(OUT/'manifest.json').write_text(json.dumps({'count':599,'bankSha256':hashlib.sha256(raw).hexdigest(),'figures':figures,'mode':'offline-inline-json'},indent=2)+'\n')
print('PASS: generated offline bundle: 599 questions,',len(figures),'verified figures')
