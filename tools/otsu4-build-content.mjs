import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'..');
const files=[
  path.join(repo,'kikenbutsu-otsu4-sprint','questions.js'),
  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v2.js')
];
const output=path.join(repo,'kikenbutsu-otsu4-sprint','questions.generated.json');
const source=[...files.map(f=>fs.readFileSync(f,'utf8')),';globalThis.__OTSU4={QUESTIONS,OTSU4_BANK_VERSION,OTSU4_BANK_AUDIT_DATE};'].join('\n');
const context={console};
vm.createContext(context);
vm.runInContext(source,context,{filename:'otsu4-bank-v2',timeout:10000});
const {QUESTIONS,OTSU4_BANK_VERSION,OTSU4_BANK_AUDIT_DATE}=context.__OTSU4;

const expected={total:360,subjects:{'法令':144,'物理・化学':96,'性質・消火':120}};
const effective={fireServiceAct:'2025-06-01',cabinetOrder:'2026-04-04',regulations:'2026-04-04'};
const qty={
  '特殊引火物':50,
  '第一石油類（非水溶性）':200,
  '第一石油類（水溶性）':400,
  'アルコール類':400,
  '第二石油類（非水溶性）':1000,
  '第二石油類（水溶性）':2000,
  '第三石油類（非水溶性）':2000,
  '第三石油類（水溶性）':4000,
  '第四石油類':6000,
  '動植物油類':10000
};
const errors=[];
const warnings=[];
const counts={};
const topicCounts={};
const ids=new Map();
const questions=new Map();
const objectives=new Map();
const explanations=new Map();
const signatures=new Map();
const pad=[];
const bad=(id,msg)=>errors.push(`${id}: ${msg}`);
const dup=(map,key,id,label)=>{if(map.has(key)){pad.push({id,reason:`${label} duplicates ${map.get(key)}`});bad(id,`${label} duplicates ${map.get(key)}`)}else map.set(key,id)};
const answerText=q=>q.choices?.[q.answer];
const refs=q=>Array.isArray(q.sourceRefs)?q.sourceRefs:[];
const hasRef=(q,needle)=>refs(q).some(r=>String(r.url||'').includes(needle));

if(OTSU4_BANK_VERSION!=='otsu4-2026-08-product-v2')errors.push(`bank version mismatch: ${OTSU4_BANK_VERSION}`);
if(OTSU4_BANK_AUDIT_DATE!=='2026-08-09')errors.push(`audit date mismatch: ${OTSU4_BANK_AUDIT_DATE}`);

for(const q of QUESTIONS){
  counts[q.subject]=(counts[q.subject]||0)+1;
  topicCounts[`${q.subject}/${q.topic}`]=(topicCounts[`${q.subject}/${q.topic}`]||0)+1;
  dup(ids,q.id,q.id,'id');
  dup(questions,String(q.question).trim(),q.id,'question text');
  dup(objectives,String(q.learningObjective||'').trim(),q.id,'learningObjective');
  dup(explanations,JSON.stringify([q.subject,q.point,q.detail]),q.id,'subject+memoryPoint+detail');
  dup(signatures,JSON.stringify([q.question,q.choices,q.answer,q.point,q.detail]),q.id,'full semantic package');

  if(!/^([LPS])\d{3}$/.test(q.id))bad(q.id,'invalid stable id');
  if(!expected.subjects[q.subject])bad(q.id,`invalid subject ${q.subject}`);
  if(!q.topic||!q.question||!q.point||!q.detail||!q.learningObjective)bad(q.id,'content field missing');
  if(!Array.isArray(q.choices)||q.choices.length!==5)bad(q.id,'choices must be exactly 5');
  if(Array.isArray(q.choices)&&new Set(q.choices).size!==5)bad(q.id,'duplicate choice text');
  if(!Number.isInteger(q.answer)||q.answer<0||q.answer>4)bad(q.id,'invalid answer index');
  if(!q.sourceTitle||!q.sourceURL||!q.sourceCheckedAt||!q.sourceLocator)bad(q.id,'source metadata missing');
  if(q.sourceCheckedAt!=='2026-08-09')bad(q.id,`sourceCheckedAt ${q.sourceCheckedAt} != 2026-08-09`);
  if(!Array.isArray(q.sourceRefs)||q.sourceRefs.length<1)bad(q.id,'sourceRefs missing');
  if(refs(q).some(r=>!r.title||!r.url||!r.locator))bad(q.id,'sourceRefs entry incomplete');
  if(/反復演習|比較セット\d+|最も適切なものは最も適切なものを選べ|undefined|NaN/.test(`${q.question} ${q.point} ${q.detail}`))bad(q.id,'padding/malformed marker detected');

  const url=String(q.sourceURL||'');
  if(q.subject==='法令'){
    if(url.includes('323AC1000000186')&&q.legalEffectiveDate!==effective.fireServiceAct)bad(q.id,'Fire Service Act effective date mismatch');
    if(url.includes('334CO0000000306')&&q.legalEffectiveDate!==effective.cabinetOrder)bad(q.id,'Cabinet Order effective date mismatch');
    if(url.includes('334M50000002055')&&q.legalEffectiveDate!==effective.regulations)bad(q.id,'Regulations effective date mismatch');
    if(url.includes('laws.e-gov.go.jp')&&!q.legalEffectiveDate)bad(q.id,'e-Gov legal item missing effective date');
  }

  if(q.topic==='指定数量'){
    const cat=Object.keys(qty).find(k=>q.question.includes(k));
    if(!cat)bad(q.id,'designated-quantity category not parseable');
    else if(answerText(q)!==`${qty[cat].toLocaleString('ja-JP')} L`)bad(q.id,`designated quantity answer mismatch for ${cat}`);
  }

  if(q.topic==='指定数量計算'||q.topic==='指定数量応用'){
    const cat=Object.keys(qty).find(k=>q.question.includes(k));
    const m=q.question.match(/([\d,]+) L/);
    if(!cat||!m)bad(q.id,'single quantity calculation not parseable');
    else {
      const actual=Number(m[1].replace(/,/g,''))/qty[cat];
      const shown=Number(String(answerText(q)).replace('倍',''));
      if(Math.abs(actual-shown)>1e-9)bad(q.id,`quantity multiple mismatch ${actual} != ${shown}`);
    }
  }

  if(q.topic==='倍数合算'){
    let expectedSum=0,matched=0;
    for(const [cat,base] of Object.entries(qty)){
      const re=new RegExp(cat.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'を([\\d,]+) L');
      const m=q.question.match(re);
      if(m){expectedSum+=Number(m[1].replace(/,/g,''))/base;matched++}
    }
    const shown=Number(String(answerText(q)).replace('倍',''));
    expectedSum=Math.round(expectedSum*100)/100;
    if(matched!==2)bad(q.id,`mixed quantity calculation parsed ${matched} items`);
    else if(Math.abs(expectedSum-shown)>1e-9)bad(q.id,`mixed quantity multiple mismatch ${expectedSum} != ${shown}`);
  }

  if(q.topic==='石油類区分'){
    const m=q.question.match(/引火点が(-?\d+)℃/);
    const water=q.question.includes('水溶性液体')&&!q.question.includes('非水溶性液体');
    if(!m)bad(q.id,'petroleum flash point not parseable');
    else {
      const fp=Number(m[1]);
      const exp=fp<21?`第一石油類（${water?'水溶性':'非水溶性'}）`:fp<70?`第二石油類（${water?'水溶性':'非水溶性'}）`:fp<200?`第三石油類（${water?'水溶性':'非水溶性'}）`:'第四石油類';
      if(answerText(q)!==exp)bad(q.id,`petroleum classification mismatch: expected ${exp}`);
      if(!hasRef(q,'323AC1000000186'))bad(q.id,'petroleum classification lacks Fire Service Act reference');
    }
  }

  if(/^S(?:00[1-9]|0[1-5]\d|060)$/.test(q.id)){
    if(!hasRef(q,'pubchem.ncbi.nlm.nih.gov'))bad(q.id,'named-substance item lacks granular PubChem reference');
  }
  if(q.subject==='性質・消火'&&['品名分類','指定数量応用'].includes(q.topic)&&!hasRef(q,'laws.e-gov.go.jp'))bad(q.id,'statutory property item lacks e-Gov reference');
}

if(QUESTIONS.length!==expected.total)errors.push(`total ${QUESTIONS.length} != ${expected.total}`);
for(const [s,n] of Object.entries(expected.subjects))if(counts[s]!==n)errors.push(`${s}: ${counts[s]} != ${n}`);

const report={
  ok:errors.length===0,
  bankVersion:OTSU4_BANK_VERSION,
  auditDate:OTSU4_BANK_AUDIT_DATE,
  currentEffectiveDates:effective,
  counts,
  total:QUESTIONS.length,
  exactQuestionDuplicates:QUESTIONS.length-questions.size,
  duplicateLearningObjectives:QUESTIONS.length-objectives.size,
  duplicateExplanationPackages:QUESTIONS.length-explanations.size,
  antiPaddingFindings:pad.length,
  errors,
  warnings,
  topicCounts
};
console.log(JSON.stringify(report,null,2));
if(errors.length)process.exit(1);
if(!process.argv.includes('--check')){
  fs.writeFileSync(output,JSON.stringify({contentVersion:OTSU4_BANK_VERSION,lawAuditDate:OTSU4_BANK_AUDIT_DATE,currentEffectiveDates:effective,questions:QUESTIONS},null,2)+'\n');
  console.log(`wrote ${path.relative(repo,output)}`);
}
