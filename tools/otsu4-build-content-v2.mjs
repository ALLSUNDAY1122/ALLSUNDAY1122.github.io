import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'..');
const input=[
  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v2-bootstrap.js'),
  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v2.js'),
  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v2-fixups.js'),
  path.join(repo,'kikenbutsu-otsu4-sprint','question-bank-v3-wave1-certified.js')
];
const output=path.join(repo,'kikenbutsu-otsu4-sprint','questions.generated.json');
const src=[...input.map(f=>fs.readFileSync(f,'utf8')),';globalThis.__BANK={QUESTIONS,CONTENT_VERSION,OTSU4_BANK_VERSION,OTSU4_BANK_AUDIT_DATE};'].join('\n');
const ctx={console}; vm.createContext(ctx); vm.runInContext(src,ctx,{timeout:10000});
const {QUESTIONS,CONTENT_VERSION,OTSU4_BANK_VERSION,OTSU4_BANK_AUDIT_DATE}=ctx.__BANK;
const expected={total:480,subjects:{'法令':192,'物理・化学':128,'性質・消火':160}};
const dates={fireServiceAct:'2025-06-01',cabinetOrder:'2026-04-04',regulations:'2026-04-04'};
const qty={'特殊引火物':50,'第一石油類（非水溶性）':200,'第一石油類（水溶性）':400,'アルコール類':400,'第二石油類（非水溶性）':1000,'第二石油類（水溶性）':2000,'第三石油類（非水溶性）':2000,'第三石油類（水溶性）':4000,'第四石油類':6000,'動植物油類':10000};
const subQty={'ジエチルエーテル':50,'二硫化炭素':50,'ガソリン':200,'ベンゼン':200,'トルエン':200,'アセトン':400,'メタノール':400,'エタノール':400,'イソプロピルアルコール':400,'灯油':1000,'軽油':1000,'重油':2000,'エチレングリコール':4000,'引火点200℃以上250℃未満の潤滑油':6000,'動植物油類の定義に該当するなたね油':10000};
const errors=[],warnings=[],counts={},topicCounts={};
const seen={id:new Map(),q:new Map(),objective:new Map(),explanation:new Map(),full:new Map()};
const findings=[];
const fail=(id,msg)=>errors.push(`${id}: ${msg}`);
const unique=(kind,key,id)=>{if(seen[kind].has(key)){const prior=seen[kind].get(key);findings.push({id,kind,prior});fail(id,`${kind} duplicates ${prior}`)}else seen[kind].set(key,id)};
const ans=q=>q.choices?.[q.answer];
const refs=q=>Array.isArray(q.sourceRefs)?q.sourceRefs:[];
const has=(q,x)=>refs(q).some(r=>String(r.url||'').includes(x));
const escRe=s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
const parseMultiple=s=>Number(String(s).replace('倍',''));

if(CONTENT_VERSION!=='otsu4-2026-08-product-v2')errors.push(`CONTENT_VERSION ${CONTENT_VERSION}`);
if(OTSU4_BANK_VERSION!=='otsu4-2026-08-product-v2')errors.push(`bank version ${OTSU4_BANK_VERSION}`);
if(OTSU4_BANK_AUDIT_DATE!=='2026-08-09')errors.push(`audit date ${OTSU4_BANK_AUDIT_DATE}`);

for(const q of QUESTIONS){
  counts[q.subject]=(counts[q.subject]||0)+1;
  topicCounts[`${q.subject}/${q.topic}`]=(topicCounts[`${q.subject}/${q.topic}`]||0)+1;
  unique('id',q.id,q.id);
  unique('q',String(q.question).trim(),q.id);
  unique('objective',String(q.learningObjective||'').trim(),q.id);
  unique('explanation',JSON.stringify([q.subject,q.point,q.detail]),q.id);
  unique('full',JSON.stringify([q.question,q.choices,q.answer,q.point,q.detail]),q.id);
  if(!/^[LPS]\d{3}$/.test(q.id))fail(q.id,'bad stable id');
  if(!(q.subject in expected.subjects))fail(q.id,`bad subject ${q.subject}`);
  if(!q.topic||!q.question||!q.point||!q.detail||!q.learningObjective)fail(q.id,'required content missing');
  if(!Array.isArray(q.choices)||q.choices.length!==5)fail(q.id,'must have five choices');
  if(Array.isArray(q.choices)&&new Set(q.choices).size!==5)fail(q.id,'duplicate choices');
  if(!Number.isInteger(q.answer)||q.answer<0||q.answer>4)fail(q.id,'bad answer index');
  if(!q.sourceTitle||!q.sourceURL||!q.sourceCheckedAt||!q.sourceLocator)fail(q.id,'source metadata missing');
  if(q.sourceCheckedAt!=='2026-08-09')fail(q.id,`sourceCheckedAt=${q.sourceCheckedAt}`);
  if(refs(q).length<1||refs(q).some(r=>!r.title||!r.url||!r.locator))fail(q.id,'sourceRefs incomplete');
  if(/反復演習|比較セット\d+|undefined|NaN|最も適切なものは最も適切なものを選べ/.test(`${q.question} ${q.point} ${q.detail}`))fail(q.id,'padding/malformed marker');
  const u=String(q.sourceURL);
  if(q.subject==='法令'&&u.includes('laws.e-gov.go.jp')){
    const d=u.includes('323AC1000000186')?dates.fireServiceAct:u.includes('334CO0000000306')?dates.cabinetOrder:u.includes('334M50000002055')?dates.regulations:null;
    if(d&&q.legalEffectiveDate!==d)fail(q.id,`legalEffectiveDate=${q.legalEffectiveDate}, expected ${d}`);
  }
  if(q.topic==='指定数量'){
    const cat=Object.keys(qty).find(k=>q.question.includes(k));
    if(!cat)fail(q.id,'cannot parse designated category');
    else if(ans(q)!==`${qty[cat].toLocaleString('ja-JP')} L`)fail(q.id,`designated quantity mismatch for ${cat}`);
  }
  if(q.topic==='指定数量計算'){
    const cat=Object.keys(qty).find(k=>q.question.includes(k)); const m=q.question.match(/([\d,]+) L/);
    if(!cat||!m)fail(q.id,'cannot parse law quantity calculation');
    else {const x=Math.round((Number(m[1].replace(/,/g,''))/qty[cat])*1000)/1000, y=parseMultiple(ans(q)); if(Math.abs(x-y)>1e-9)fail(q.id,`quantity multiple ${y}, expected ${x}`)}
  }
  if(q.topic==='指定数量応用'){
    const table=q.subject==='性質・消火'?subQty:qty;
    const name=Object.keys(table).find(k=>q.question.includes(k)); const m=q.question.match(/([\d,]+) L/);
    if(!name||!m)fail(q.id,'cannot parse applied quantity calculation');
    else {const x=Math.round((Number(m[1].replace(/,/g,''))/table[name])*1000)/1000, y=parseMultiple(ans(q)); if(Math.abs(x-y)>1e-9)fail(q.id,`applied multiple ${y}, expected ${x}`)}
  }
  if(q.topic==='倍数合算'){
    let total=0,matched=0;
    for(const [cat,base] of Object.entries(qty)){const m=q.question.match(new RegExp(escRe(cat)+'を([\\d,]+) L')); if(m){total+=Number(m[1].replace(/,/g,''))/base;matched++}}
    total=Math.round(total*1000)/1000; const y=parseMultiple(ans(q));
    if(matched!==2)fail(q.id,`mixed calculation parsed ${matched} items`); else if(Math.abs(total-y)>1e-9)fail(q.id,`mixed multiple ${y}, expected ${total}`);
  }
  if(q.topic==='石油類区分'){
    const m=q.question.match(/引火点が(-?\d+)℃/); const water=q.question.includes('水溶性液体')&&!q.question.includes('非水溶性液体');
    if(!m)fail(q.id,'cannot parse flash point'); else {const fp=Number(m[1]);const exp=fp<21?`第一石油類（${water?'水溶性':'非水溶性'}）`:fp<70?`第二石油類（${water?'水溶性':'非水溶性'}）`:fp<200?`第三石油類（${water?'水溶性':'非水溶性'}）`:'第四石油類';if(ans(q)!==exp)fail(q.id,`petroleum class ${ans(q)}, expected ${exp}`)}
    if(!has(q,'323AC1000000186'))fail(q.id,'petroleum classification lacks Fire Service Act reference');
  }
  if(/^S(?:00[1-9]|0[1-5]\d|060)$/.test(q.id)&&!has(q,'pubchem.ncbi.nlm.nih.gov'))fail(q.id,'named-substance item lacks PubChem reference');
  if(q.subject==='性質・消火'&&['品名分類','指定数量応用'].includes(q.topic)&&!has(q,'laws.e-gov.go.jp'))fail(q.id,'statutory property item lacks e-Gov reference');
}
if(QUESTIONS.length!==expected.total)errors.push(`total ${QUESTIONS.length} != ${expected.total}`);
for(const [s,n] of Object.entries(expected.subjects))if(counts[s]!==n)errors.push(`${s} ${counts[s]} != ${n}`);
const report={ok:errors.length===0,bankVersion:OTSU4_BANK_VERSION,auditDate:OTSU4_BANK_AUDIT_DATE,currentEffectiveDates:dates,total:QUESTIONS.length,counts,exactQuestionDuplicates:QUESTIONS.length-seen.q.size,duplicateLearningObjectives:QUESTIONS.length-seen.objective.size,duplicateExplanationPackages:QUESTIONS.length-seen.explanation.size,antiPaddingFindings:findings.length,errors,warnings,topicCounts};
console.log(JSON.stringify(report,null,2));
if(errors.length)process.exit(1);
if(!process.argv.includes('--check'))fs.writeFileSync(output,JSON.stringify({contentVersion:CONTENT_VERSION,lawAuditDate:OTSU4_BANK_AUDIT_DATE,currentEffectiveDates:dates,questions:QUESTIONS},null,2)+'\n');