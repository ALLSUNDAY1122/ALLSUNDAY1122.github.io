#!/usr/bin/env python3
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
DRAFT=ROOT/'enriched-draft'
MEDIA_RE=re.compile(r'(?:図|写真|画像|グラフ|心電図|波形|別冊)|(?:表\s*(?:を|に|の))',re.I)
queues={
    'textPending':[],
    'mediaPending':[],
    'dynamicPending':[],
    'contentConcerns':[],
    'scoringExceptionPending':[],
    'expertReviewPending':[],
    'releaseQuarantined':[],
    'explained':[]
}

for sid in ('set1','set2','set3'):
    data=json.loads((DRAFT/f'{sid}-draft.json').read_text(encoding='utf-8'))
    for q in data.get('questions',[]):
        stem=str(q.get('question') or '')
        media_cue=bool(MEDIA_RE.search(stem))
        no_text_choices=q.get('answerType') in {'singleChoice','multiChoice'} and len(q.get('choices') or [])==0
        effective_media=bool(q.get('requiresMedia')) or media_cue or no_text_choices
        media_pending=effective_media and q.get('mediaReleaseStatus')!='resolved'
        concern=q.get('contentConcernStatus') not in {None,'none','resolved'}
        scoring_special=q.get('officialScoringStatus') not in {None,'normal'}
        scoring_exception=scoring_special and q.get('scoringExceptionStatus')!='resolved'
        expert_required=q.get('expertReviewStatus') in {'required','pending','expert_review_required'}
        specialist_quarantine=q.get('specialistQuarantineStatus')=='quarantined'
        explained=q.get('explanationStatus')=='ai_explained'
        row={
            'id':q['id'],'setId':sid,'sourceExam':q.get('sourceExam'),'session':q.get('session'),
            'questionNo':q.get('questionNo'),'category':q.get('category'),'majorSubject':q.get('majorSubject'),
            'subject':q.get('subject'),'question':q.get('question'),'answerType':q.get('answerType'),
            'answer':q.get('answer'),'choices':q.get('choices') or [],'requiresMedia':effective_media,
            'sourceRequiresMedia':bool(q.get('requiresMedia')),'mediaCueDetectedInQueue':media_cue or no_text_choices,
            'mediaReleaseStatus':q.get('mediaReleaseStatus'),'mediaRightsStatus':q.get('mediaRightsStatus'),
            'mediaAssets':q.get('mediaAssets') or [],
            'officialScoringStatus':q.get('officialScoringStatus'),'scoringException':q.get('scoringException'),
            'scoringExceptionStatus':q.get('scoringExceptionStatus'),'scoringRuntimeMode':q.get('scoringRuntimeMode'),
            'contentConcernStatus':q.get('contentConcernStatus','none'),'contentConcernReason':q.get('contentConcernReason'),
            'expertReviewStatus':q.get('expertReviewStatus'),'specialistQuarantineStatus':q.get('specialistQuarantineStatus'),
            'specialistQuarantineReasons':q.get('specialistQuarantineReasons') or [],
            'explanationStatus':q.get('explanationStatus'),'dynamicEvidenceStatus':q.get('dynamicEvidenceStatus')
        }

        if explained: queues['explained'].append(q['id'])
        elif not (concern or scoring_exception or media_pending or expert_required): queues['textPending'].append(row)
        if media_pending: queues['mediaPending'].append(row)
        if scoring_exception: queues['scoringExceptionPending'].append(row)
        if concern: queues['contentConcerns'].append(row)
        if expert_required: queues['expertReviewPending'].append(row)
        if specialist_quarantine or concern or scoring_exception or media_pending or expert_required: queues['releaseQuarantined'].append(row)
        if q.get('dynamicEvidenceRequired') and q.get('dynamicEvidenceStatus') not in {'verified','expert_review_required'}: queues['dynamicPending'].append(row)

summary={k:len(v) for k,v in queues.items()}
summary['queueDetectedMediaOverrides']=sum(1 for row in queues['mediaPending'] if row['mediaCueDetectedInQueue'] and not row['sourceRequiresMedia'])
(DRAFT/'pending-queues.json').write_text(json.dumps({'summary':summary,**queues},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
