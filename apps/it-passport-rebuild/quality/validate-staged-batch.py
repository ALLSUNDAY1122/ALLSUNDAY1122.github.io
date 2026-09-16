#!/usr/bin/env python3
import collections,json,re,sys,unicodedata
from pathlib import Path
root=Path(__file__).resolve().parents[1]; qp=root/'questions'
if len(sys.argv)!=2: raise SystemExit('usage: validate-staged-batch.py batch-NN.json')
name=Path(sys.argv[1]).name; staged_path=qp/name
match=re.fullmatch(r'batch-(\d+)\.json',name)
if not match: raise SystemExit(f'invalid staged filename: {name}')
target_no=int(match.group(1))
norm=lambda s: re.sub(r'\s+','',unicodedata.normalize('NFKC',str(s)).lower())
old=json.loads((qp/'original-mock.json').read_text(encoding='utf-8')); batch=json.loads(staged_path.read_text(encoding='utf-8')); manifest=json.loads((qp/'manifest.json').read_text(encoding='utf-8')); config=json.loads((root/'quality/exam-config.json').read_text(encoding='utf-8'))
assert len(batch)==20, f'{name}: len={len(batch)} expected=20'
assert len(old)==manifest['canonical']['original_mock']['current'], 'manifest/canonical count mismatch'
ids={q['id'] for q in old}; texts={norm(q['question']) for q in old}; topics={norm(q.get('topic','')) for q in old}
# Future batches can be prepared before predecessor merges. Exclude every earlier staged item
# that is not already present in canonical, so cross-batch novelty is checked immediately.
for p in sorted(qp.glob('batch-*.json')):
    m=re.fullmatch(r'batch-(\d+)\.json',p.name)
    if not m or int(m.group(1))>=target_no: continue
    for q in json.loads(p.read_text(encoding='utf-8')):
        if q.get('id') in ids: continue
        ids.add(q.get('id')); texts.add(norm(q.get('question',''))); topics.add(norm(q.get('topic','')))
req=set(config['required_fields']); seen_ids=set(); seen_texts=set(); seen_topics=set(); subjects=collections.Counter(); answers=collections.Counter()
for q in batch:
    qid=q.get('id','<missing-id>'); missing=req-set(q); assert not missing, f'{qid}: missing={sorted(missing)}'; assert qid not in ids|seen_ids, f'{qid}: duplicate id'; qt=norm(q['question']); tp=norm(q['topic']); assert qt not in texts|seen_texts, f'{qid}: duplicate question'; assert tp not in topics|seen_topics, f'{qid}: duplicate canonical/prior-stage/current topic={q["topic"]}'; assert q['subject'] in config['subjects']; assert q['round']==3; assert len(q['choices'])==4 and len({norm(x) for x in q['choices']})==4; ci=q['correct_index']; assert isinstance(ci,int) and 0<=ci<4; assert q['syllabus_version']==manifest['current_syllabus_version']=='6.5'; assert q['origin_type']=='original' and q['rights_basis']=='original_question_based_on_public_syllabus'; assert q['source_url']=='https://www.ipa.go.jp/shiken/syllabus/gaiyou.html'; assert q['reference_date']=='2026-09-16'; assert len(q['question'])>=20 and len(q['explanation'])>=35
    correct=str(q['choices'][ci]); exp=norm(q['explanation']); parts=[norm(x) for x in re.split(r'[と・/／,、\s]+',correct) if norm(x)]; assert norm(correct) in exp or tp in exp or (len(parts)>1 and all(x in exp for x in parts)), f'{qid}: weak explanation grounding'
    subjects[q['subject']]+=1; answers[ci]+=1; seen_ids.add(qid); seen_texts.add(qt); seen_topics.add(tp)
assert subjects=={'ストラテジ系':7,'マネジメント系':4,'テクノロジ系':9}, subjects
assert answers=={0:5,1:5,2:5,3:5}, answers
print(f'PASS {name}: canonical={len(old)} staged=20 subjects={dict(subjects)} answers={dict(answers)} all_topics_novel=true incl_prior_stages')
