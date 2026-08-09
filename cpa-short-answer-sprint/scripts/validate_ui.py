#!/usr/bin/env python3
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
APP=ROOT/'cpa-short-answer-sprint'
DATA=ROOT/'learning-sprint/cpa-short-answer/integration/questions-all-279.json'
CANON=ROOT/'learning-sprint/cpa-short-answer/integration/canonical-map-279.json'
errors=[]

def check(cond,msg):
    if not cond: errors.append(msg)

qs=json.loads(DATA.read_text(encoding='utf-8'))
cm=json.loads(CANON.read_text(encoding='utf-8'))
cmap=cm.get('canonical_map',{})
unique=[q for q in qs if cmap.get(q['id'],q['id'])==q['id']]
check(len(qs)==279,f'出題枠 {len(qs)}/279')
check(len(unique)==278,f'通常学習ユニーク {len(unique)}/278')
subjects={'企業法':20,'管理会計論':18,'監査論':20,'財務会計論':35}
for r in (1,2,3):
    rq=[q for q in qs if q.get('round')==r]
    check(len(rq)==93,f'第{r}回 {len(rq)}/93')
    check(sum(int(q.get('points',0)) for q in rq)==500,f'第{r}回 配点500ではない')
    for s,n in subjects.items():
        check(sum(1 for q in rq if q.get('subject')==s)==n,f'第{r}回 {s} 件数不正')
english=[q for q in qs if q.get('round')==3 and q.get('language')=='en']
check(len(english)==5,f'第3回英語問題 {len(english)}/5')
check(sum(int(q.get('points',0)) for q in english)==28,'第3回英語配点 28点ではない')

index=(APP/'index.html').read_text(encoding='utf-8')
css=(APP/'style-v21.css').read_text(encoding='utf-8')
js=(APP/'app-v21.js').read_text(encoding='utf-8')
manifest=json.loads((APP/'manifest.json').read_text(encoding='utf-8'))
sw=(APP/'sw.js').read_text(encoding='utf-8')

for token in ['--paper:#f7f3ea','--ai:#2f4a6d','--shu:#d8452c','--midori:#2f7d5c','--kin:#b5872b','max-width:520px','background-size:28px 28px','width:82px','grid-template-columns:repeat(4,1fr)']:
    check(token in css,f'Golden Master CSS欠損: {token}')
for marker in ['今日のスプリント','苦手をつぶす','模擬試験','分野から解く','ここだけ覚える','3回 × 93問','ENGLISH','JSONを書き出す','3連続']:
    check(marker in js,f'機能/UI文言欠損: {marker}')
for selector in ['class="nav"','class="today-ring"','class="question-card"','class="result-page"']:
    check(selector in js,f'主要DOM欠損: {selector}')
check('style-v21.css' in index and 'app-v21.js' in index,'indexのv2.1参照不正')
check(manifest.get('orientation')=='portrait','manifest portrait固定なし')
check(manifest.get('display')=='standalone','manifest standaloneなし')
check('questions-all-279.json' in sw and 'canonical-map-279.json' in sw,'SWで問題データ未キャッシュ')
check("dailyGoal:8" in js,'標準8問でない')
check("[4,8,16]" in js,'4/8/16設定なし')

if errors:
    print('FAIL')
    for e in errors: print('-',e)
    raise SystemExit(1)
print('PASS: CPA v2.1 UI静的監査')
print(json.dumps({'exam_slots':len(qs),'normal_unique':len(unique),'english_questions':len(english),'english_points':sum(q['points'] for q in english)},ensure_ascii=False))
