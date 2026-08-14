#!/usr/bin/env python3
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
APP=ROOT.parent
errors=[]

def need(cond,msg):
    if not cond: errors.append(msg)

runtime=json.loads((ROOT/'product-runtime-audit.json').read_text(encoding='utf-8'))
manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
queue=json.loads((ROOT/'enriched-draft'/'release-queue-ids.json').read_text(encoding='utf-8'))
index=(APP/'index.html').read_text(encoding='utf-8')
sw=(APP/'sw.js').read_text(encoding='utf-8')
app=(APP/'app-v03.js').read_text(encoding='utf-8')
media=(APP/'media-runtime.js').read_text(encoding='utf-8')
avail=(APP/'product-availability.js').read_text(encoding='utf-8')
questions=(APP/'questions-runtime.js').read_text(encoding='utf-8')
scoring=(APP/'scoring-overrides.js').read_text(encoding='utf-8')

need(runtime.get('pass') is True,'product runtime audit not PASS')
need(runtime.get('canonicalTotal')==720 and runtime.get('runtimeEligible')==720,'runtime is not 720/720')
need(runtime.get('blockedIds')==[],'runtime still has blocked ids')
need(runtime.get('mediaResolved')==38 and not runtime.get('mediaMissingAssets'),'media runtime is not 38/38')
summary=queue.get('summary') or {}
for key in ('textPending','mediaPending','dynamicPending','contentConcerns','scoringExceptionPending','expertReviewPending','releaseQuarantined'):
    need(summary.get(key)==0,f'queue {key} is not zero: {summary.get(key)}')
need(summary.get('explained')==720,'explained is not 720')

sets={int(s.get('sourceExam')):s for s in manifest.get('sets') or []}
need(set(sets)=={115,114,113},'manifest exam set mismatch')
for exam in (115,114,113):
    s=sets.get(exam,{})
    need(s.get('status')=='ready',f'exam {exam} not ready')
    need(s.get('questionCount')==240 and s.get('runtimeEligibleCount')==240,f'exam {exam} not 240/240')
    need(s.get('expertBlockedIds')==[],f'exam {exam} still blocked')

scripts=['questions-runtime.js','app-v03.js','media-runtime.js','product-availability.js']
pos=[]
for name in scripts:
    i=index.find(f'src="{name}"')
    need(i>=0,f'index missing {name}')
    pos.append(i)
need(pos==sorted(pos),'runtime script order is incorrect')
need(index.find('scoring-overrides.js') < index.find('questions-runtime.js'),'scoring overrides must load before runtime/app')

need('kangoshi-sprint-v25-20260814-canonical-runtime1' in sw,'service worker cache version not canonical-runtime1')
for name in ('scoring-overrides.js','questions-runtime.js','media-runtime.js','product-availability.js'):
    need(f"'./{name}'" in sw,f'service worker does not precache {name}')
need('window.KANGOSHI_QUESTIONS=ALL.filter' in questions,'questions runtime does not replace legacy pool')
need('runtimeEligible":720' in questions or '"runtimeEligible":720' in questions,'questions runtime metadata is not 720')
need('new MutationObserver(apply)' in media and "className='question-media'" in media,'media renderer markers missing')
need("q.mediaReleaseStatus!=='resolved'" in media,'media renderer does not enforce resolved status')
need("const examNo=[115,114,113][round]" in app,'mock pool is not keyed by source exam')
need("Number(q.sourceExam)===examNo" in app,'mock pool sourceExam filter missing')
need('const SCORING=window.KANGOSHI_SCORING||{}' in app,'scoring runtime not connected to app')
need("s?.status==='ready'&&s?.questionCount===240&&s?.expertReviewedCount===240" in avail,'availability ready gate mismatch')
need('K113-AM005' in scoring and 'K115-AM080' in scoring,'official scoring exception map incomplete marker')

report={
    'schemaVersion':1,
    'canonicalQuestions':runtime.get('canonicalTotal'),
    'runtimeEligible':runtime.get('runtimeEligible'),
    'examSetsReady':sorted([e for e,s in sets.items() if s.get('status')=='ready'],reverse=True),
    'mediaResolved':runtime.get('mediaResolved'),
    'pendingQueues':{k:summary.get(k) for k in ('textPending','mediaPending','dynamicPending','contentConcerns','scoringExceptionPending','expertReviewPending','releaseQuarantined')},
    'scriptOrder':scripts,
    'cacheVersion':'kangoshi-sprint-v25-20260814-canonical-runtime1',
    'pass':not errors,
    'errors':errors
}
(ROOT/'product-ui-runtime-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
