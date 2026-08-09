#!/usr/bin/env python3
from __future__ import annotations

import glob, hashlib, json, re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/'content'; RAW=CONTENT/'raw'; REVIEWED=CONTENT/'reviewed'; MEDIA=CONTENT/'media'; PRODUCT=CONTENT/'product'
PRODUCT.mkdir(parents=True,exist_ok=True)


def load_overlays():
    ranked=[]
    for p in glob.glob(str(REVIEWED/'**'/'*.json'),recursive=True):
        pp=Path(p)
        if 'official-anchor' in pp.parts or 'media-anchor' in pp.parts: rank=1
        elif 'auto' in pp.parts: rank=2
        else: rank=3
        try:d=json.loads(pp.read_text(encoding='utf-8'))
        except Exception:continue
        items=d if isinstance(d,list) else d.get('items',[]) if isinstance(d,dict) else []
        for x in items:
            if isinstance(x,dict) and x.get('id'):ranked.append((rank,pp.name,x))
    ranked.sort(key=lambda x:x[0])
    out={}; provenance={}
    for rank,name,x in ranked:
        qid=x['id']; out[qid]={**out.get(qid,{}),**x}; provenance[qid]=name
    return out,provenance


def load_json_or(path,default):
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else default


def clean_ws(s):return re.sub(r'\s+',' ',str(s or '')).strip()

def canonical_hash(q):
    text=clean_ws(q.get('question')).casefold()+'\n'+'\n'.join(clean_ws(x).casefold() for x in q.get('choices',[]))
    return hashlib.sha256(text.encode()).hexdigest()[:20]


def normalize_case(q, qmap):
    gid=q.get('caseGroupId')
    if not gid:return
    n=int(q['questionNo']); exam=int(q['sourceExam'])
    if n%2==0 and n<=325:
        m=re.search(rf'問\s*{n}(?:（[^）]+）)?\s*',q.get('question',''))
        if m and m.start()>20:
            stem=clean_ws(q['question'][:m.start()]); own=clean_ws(q['question'][m.end():])
            if len(stem)>30 and len(own)>10:
                q['sharedStem']=stem;q['question']=own
                nxt=qmap.get(f'P{exam}-{n+1:03d}')
                if nxt and nxt.get('caseGroupId')==gid:nxt['sharedStem']=stem


def main():
    overlays,prov=load_overlays(); media_manifest=load_json_or(MEDIA/'media-manifest.json',{}); third_list=load_json_or(MEDIA/'third-party-review.json',[]); third={x['id']:x for x in third_list}
    qs=[]
    for exam in (111,110,109):
        d=json.loads((RAW/f'exam-{exam}-raw.json').read_text(encoding='utf-8'));qs.extend(d['questions'])
    qmap={q['id']:q for q in qs}
    for q in qs:
        ov=overlays.get(q['id'],{})
        if ov.get('question_override'):q['question']=ov['question_override']
        if ov.get('choices_override'):q['choices']=ov['choices_override']
        if ov.get('media_rebuild_status')=='text_rebuilt':
            q['requires_media']=False;q['mediaAuditStatus']='rebuilt_as_independent_text';q['mediaRebuildProvenance']=ov.get('rebuild_source')
        q['memoryPoint']=ov.get('memoryPoint');q['explanation']=ov.get('explanation');q['explanationProvenance']=prov.get(q['id']);q['explanationReviewRequired']=bool(ov.get('reviewRequired',False)) if ov else True
        q['release_status']='candidate'
        if q['scoring_status']=='excluded':q['release_status']='reference_excluded'
        if not q.get('memoryPoint') or not q.get('explanation'):q['release_status']='blocked_missing_explanation'
        if q.get('requires_media'):
            if q['id'] in media_manifest:
                q['displayMode']='officialQuestionImage';q['mediaAssets']=media_manifest[q['id']]['assets'];q['mediaAttribution']=media_manifest[q['id']]['attribution'];q['mediaLicense']=media_manifest[q['id']]['license']
                choice_count=len(q.get('choices',[]))
                if not (2<=choice_count<=6):
                    mx=max(q.get('officialAnswerNumbers') or [0]);choice_count=6 if mx==6 else 5
                q['numberedChoiceCount']=choice_count
            elif q['id'] in third:
                q['displayMode']='thirdPartyRebuildRequired';q['thirdPartyReview']=third[q['id']];q['release_status']='blocked_third_party_asset'
            else:q['release_status']='blocked_missing_media_asset'
        else:q['displayMode']='textChoices'
        q['canonicalContentHash']=canonical_hash(q);q['attributionDisplay']=q.get('attribution') or f"出典：厚生労働省『第{q['sourceExam']}回薬剤師国家試験問題及び解答』";q['modificationDisclosureDisplay']='厚生労働省公開問題をもとに、学習表示・解説を加工して作成'
    for q in qs:normalize_case(q,qmap)
    for q in qs:q['canonicalContentHash']=canonical_hash(q)
    hashes={}
    for q in qs:
        h=q['canonicalContentHash']
        if h in hashes:q['historicalRepeatOf']=hashes[h];q['dailySprintCanonicalId']=hashes[h]
        else:hashes[h]=q['id'];q['historicalRepeatOf']=None;q['dailySprintCanonicalId']=q['id']
    out={'schemaVersion':1,'contentVersion':'pharmacist-111-110-109-product-v1','examSystemVersion':'current_106_114','questionCount':len(qs),'questions':qs}
    (PRODUCT/'questions.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    summary={'total':len(qs),'overlayCoverage':sum(1 for q in qs if q.get('explanation')),'mediaReady':sum(1 for q in qs if q.get('mediaAssets')),'rebuiltTextMedia':sum(1 for q in qs if q.get('mediaAuditStatus')=='rebuilt_as_independent_text'),'blocked':sum(1 for q in qs if str(q.get('release_status','')).startswith('blocked')),'excludedReference':sum(1 for q in qs if q.get('release_status')=='reference_excluded'),'historicalRepeats':sum(1 for q in qs if q.get('historicalRepeatOf'))}
    (PRODUCT/'assembly-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':main()
