#!/usr/bin/env python3
import json
import re
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
EXPECTED={'社会・環境':16,'人体・疾病':26,'食べ物':25,'基礎栄養':14,'応用栄養':16,'栄養教育':13,'臨床栄養':26,'公衆栄養':16,'給食経営':18,'応用力':30}

def need(text, token, label, errors):
    if token not in text: errors.append(f'{label}: missing {token}')

def main():
    errors=[]
    runtime=(ROOT/'questions600.js').read_text(encoding='utf-8')
    if not runtime.startswith('window.KANRI_Q=') or not runtime.rstrip().endswith(';'):
        errors.append('questions600.js runtime wrapper invalid')
        data=[]
    else:
        data=json.loads(runtime[len('window.KANRI_Q='):].rstrip()[:-1])
    if len(data)!=600: errors.append(f'runtime count {len(data)}/600')
    ids=[q.get('id') for q in data]
    if len(ids)!=len(set(ids)): errors.append('runtime duplicate ids')
    for r in (1,2,3):
        rq=[q for q in data if int(q.get('round',0))==r]
        if len(rq)!=200: errors.append(f'round{r} count {len(rq)}/200')
        counts=Counter(q.get('c') for q in rq)
        if dict(counts)!=EXPECTED: errors.append(f'round{r} distribution {dict(counts)}')
    index=(ROOT/'index.html').read_text(encoding='utf-8')
    app=(ROOT/'app-v060.js').read_text(encoding='utf-8')
    css=(ROOT/'styles-v060.css').read_text(encoding='utf-8')
    sw=(ROOT/'sw.js').read_text(encoding='utf-8')
    for token in ['questions600.js?v=060','app-v060.js?v=060','styles-v060.css?v=060','id="roundSeg"','id="mockRounds"','id="roundStats"','id="mockNotice"']:
        need(index,token,'index',errors)
    for forbidden in ['questions.js?v=051','round1-extra-121-140.js?v=051','app.js?v=051','200問データ完成後に有効化します']:
        if forbidden in index or forbidden in app: errors.append(f'legacy runtime remains: {forbidden}')
    for token in ['function startMock','mockComp','compKey','selectedRound','function integrity','KNR','600','200','resultEyebrow']:
        need(app,token,'app',errors)
    for token in ['.roundseg','.mockrounds','.mocknotice','.roundstats','.sourceLink']:
        need(css,token,'css',errors)
    for token in ['questions600.js','app-v060.js','styles-v060.css','kanri-sprint-v060']:
        need(sw,token,'service worker',errors)
    if re.search(r'innerHTML\s*=\s*[^;]*q\.q',app): errors.append('question text inserted to innerHTML without escaping')
    print('=== 管理栄養士 v0.6.0 実装・UI受入監査 ===')
    print(f'questions={len(data)}/600')
    if errors:
        print('FAIL')
        for e in errors: print('-',e)
        raise SystemExit(1)
    print('PASS: 600問ランタイム、3回×10分類、模試200問導線、状態移行、UI Master追加差分、PWAキャッシュを確認')

if __name__=='__main__': main()
