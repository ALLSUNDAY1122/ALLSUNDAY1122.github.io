#!/usr/bin/env python3
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
APP=ROOT.parent
errors=[]

def need(cond,msg):
    if not cond: errors.append(msg)

runtime=json.loads((ROOT/'product-runtime-audit.json').read_text(encoding='utf-8'))
quarantine=json.loads((ROOT/'release-quarantine-20261125.json').read_text(encoding='utf-8'))
qids=sorted(x['id'] for x in quarantine.get('items') or [])
expected_eligible=720-len(qids)
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
need(runtime.get('canonicalTotal')==720 and runtime.get('runtimeEligible')==expected_eligible,f'runtime is not {expected_eligible}/720')
need(runtime.get('blockedIds')==qids,'runtime blocked ids must equal the official-PDF release quarantine exactly')
need(quarantine.get('releaseEligibleCount')==expected_eligible,'quarantine summary count mismatch')
need(not runtime.get('mediaMissingAssets'),'runtime media asset missing')
need(isinstance(runtime.get('eligibleMediaQuestions'),list),'runtime audit lacks eligible media list')
summary=queue.get('summary') or {}
for key in ('textPending','dynamicPending','contentConcerns','scoringExceptionPending','expertReviewPending'):
    need(summary.get(key)==0,f'queue {key} is not zero: {summary.get(key)}')
# Media still pending rights review / specialist quarantine must be inside the release quarantine.
for key in ('mediaPending','releaseQuarantined'):
    need(set(queue.get(key) or [])<=set(qids),f'queue {key} ids are not all release-quarantined')
need(summary.get('explained')==720,'explained is not 720')

sets={int(s.get('sourceExam')):s for s in manifest.get('sets') or []}
need(set(sets)=={115,114,113},'manifest exam set mismatch')
for exam in (115,114,113):
    s=sets.get(exam,{})
    eq=[i for i in qids if i.startswith(f'K{exam}-')]
    need(s.get('status')==('ready' if not eq else 'pending_release_review'),f'exam {exam} status mismatch')
    need(s.get('questionCount')==240 and s.get('runtimeEligibleCount')==240-len(eq),f'exam {exam} runtime not {240-len(eq)}/240')
    need(s.get('releaseEligibleCount')==240-len(eq),f'exam {exam} release eligibility not {240-len(eq)}/240')
    need(s.get('releaseBlockedIds')==eq,f'exam {exam} release-blocked ids differ from quarantine')
    need('expertReviewedCount' not in s,f'exam {exam} contains misleading expertReviewedCount')
need((manifest.get('releaseGate') or {}).get('primarySourceAuditRequired') is True,'primary source audit gate missing')
need((manifest.get('releaseGate') or {}).get('humanReviewAtPrototypeAndTestFlight') is True,'human review gate does not match canonical procedure')
need((manifest.get('releaseGate') or {}).get('expertReviewRequired') is not True,'legacy expertReviewRequired gate remains')

scripts=['questions-runtime.js','app-v03.js','media-runtime.js','product-availability.js']
pos=[]
for name in scripts:
    i=index.find(f'src="{name}"')
    need(i>=0,f'index missing {name}')
    pos.append(i)
need(pos==sorted(pos),'runtime script order is incorrect')
need(index.find('scoring-overrides.js') < index.find('questions-runtime.js'),'scoring overrides must load before runtime/app')

need('kangoshi-sprint-v26-20261125-canonical-runtime2' in sw,'service worker cache version not canonical-runtime2')
for name in ('scoring-overrides.js','questions-runtime.js','media-runtime.js','product-availability.js'):
    need(f"'./{name}'" in sw,f'service worker does not precache {name}')
need('window.KANGOSHI_QUESTIONS=ALL.filter' in questions,'questions runtime does not replace legacy pool')
need(f'"runtimeEligible":{expected_eligible}' in questions,f'questions runtime metadata is not {expected_eligible}')
need('new MutationObserver(apply)' in media and "className='question-media'" in media,'media renderer markers missing')
need("q.mediaReleaseStatus!=='resolved'" in media,'media renderer does not enforce resolved status')
need("const examNo=[115,114,113][round]" in app,'mock pool is not keyed by source exam')
need("Number(q.sourceExam)===examNo" in app,'mock pool sourceExam filter missing')
need('const SCORING=window.KANGOSHI_SCORING||{}' in app,'scoring runtime not connected to app')
need("s?.status==='ready'&&s?.questionCount===240&&s?.releaseEligibleCount===240" in avail,'availability ready gate mismatch')
need('専門監査' not in avail,'availability UI still claims specialist review')
need('K113-AM005' in scoring and 'K115-AM080' in scoring,'official scoring exception map incomplete marker')

report={
    'schemaVersion':2,
    'canonicalQuestions':runtime.get('canonicalTotal'),
    'runtimeEligible':runtime.get('runtimeEligible'),
    'examSetsReady':sorted([e for e,s in sets.items() if s.get('status')=='ready'],reverse=True),
    'releaseEligibleByExam':{str(e):sets[e].get('releaseEligibleCount') for e in sorted(sets,reverse=True)},
    'mediaResolved':runtime.get('mediaResolved'),
    'eligibleMediaCount':runtime.get('eligibleMediaCount'),
    'pendingQueues':{k:summary.get(k) for k in ('textPending','mediaPending','dynamicPending','contentConcerns','scoringExceptionPending','expertReviewPending','releaseQuarantined')},
    'reviewPolicy':'ai_ci_primary_source_audit_plus_human_prototype_testflight',
    'scriptOrder':scripts,
    'cacheVersion':'kangoshi-sprint-v26-20261125-canonical-runtime2',
    'releaseQuarantined':len(qids),
    'pass':not errors,
    'errors':errors
}
(ROOT/'product-ui-runtime-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
