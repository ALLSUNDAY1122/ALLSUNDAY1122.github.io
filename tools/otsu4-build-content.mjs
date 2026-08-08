import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'..');
const questionsPath=path.join(repo,'kikenbutsu-otsu4-sprint','questions.js');
const fixupsPath=path.join(repo,'kikenbutsu-otsu4-sprint','question-fixups.js');
const output=path.join(repo,'kikenbutsu-otsu4-sprint','questions.generated.json');
const source=[fs.readFileSync(questionsPath,'utf8'),fs.readFileSync(fixupsPath,'utf8'),';globalThis.__OTSU4={QUESTIONS,CONTENT_VERSION,LAW_BASELINE,QUESTION_BANK_META};'].join('\n');
const context={console};
vm.createContext(context);
vm.runInContext(source,context,{filename:questionsPath,timeout:5000});
const {QUESTIONS,CONTENT_VERSION,LAW_BASELINE,QUESTION_BANK_META}=context.__OTSU4;

const errors=[];
const warnings=[];
const expected={total:360,subjects:{'法令':144,'物理・化学':96,'性質・消火':120}};
const counts={};
const ids=new Set();
const signatures=new Set();
const questionTextSeen=new Map();
const padding=new Map();
const sourceTrace=[];
const addPadding=(id,reason)=>{if(!padding.has(id))padding.set(id,[]);padding.get(id).push(reason)};

for(const q of QUESTIONS){
  counts[q.subject]=(counts[q.subject]||0)+1;
  if(ids.has(q.id))errors.push(`duplicate id ${q.id}`); ids.add(q.id);
  if(!Array.isArray(q.choices)||q.choices.length!==5)errors.push(`${q.id}: choices != 5`);
  if(new Set(q.choices||[]).size!==5)errors.push(`${q.id}: duplicate choice text`);
  if(!Number.isInteger(q.answer)||q.answer<0||q.answer>4)errors.push(`${q.id}: invalid answer index`);
  if(!q.point||!q.detail)errors.push(`${q.id}: explanation missing`);
  if(!q.sourceTitle||!q.sourceURL||!q.sourceCheckedAt)errors.push(`${q.id}: source metadata missing`);

  if(q.subject==='法令'){
    const expectedDate=q.sourceTitle.includes('危険物の規制に関する政令')?'2026-04-04':'2025-06-01';
    if(q.legalEffectiveDate!==expectedDate)errors.push(`${q.id}: legalEffectiveDate ${q.legalEffectiveDate} != ${expectedDate}`);
  }
  if(q.subject==='性質・消火'&&(q.topic==='分類'||q.topic==='石油類区分')&&q.legalEffectiveDate!=='2025-06-01'){
    errors.push(`${q.id}: statutory classification legalEffectiveDate must be 2025-06-01`);
  }
  if(q.subject==='性質・消火'&&!['分類','石油類区分'].includes(q.topic)&&q.legalEffectiveDate){
    errors.push(`${q.id}: non-statutory item must not use legalEffectiveDate`);
  }

  const sig=JSON.stringify([q.question,q.choices,q.answer]);
  if(signatures.has(sig))addPadding(q.id,'exact duplicate question/choices/answer'); else signatures.add(sig);
  if(questionTextSeen.has(q.question))addPadding(q.id,`question text duplicates ${questionTextSeen.get(q.question)}`); else questionTextSeen.set(q.question,q.id);
  if(/最も適切なものは最も適切なものを選べ|正しいものは最も適切なものを選べ/.test(q.question))addPadding(q.id,'malformed generated wording');

  if(q.sourceTitle.includes('総務省消防庁')&&q.subject==='性質・消火'&&['分類','安全取扱い'].includes(q.topic))sourceTrace.push(`${q.id}: broad FDMA page is not granular evidence for this substance-specific fact`);
  if(q.sourceTitle.startsWith('基礎物理・化学')&&q.subject==='性質・消火'&&['水溶性','消火'].includes(q.topic)&&/^S(?:0[0-5]\d|060)$/.test(q.id))sourceTrace.push(`${q.id}: generic chemistry source is not granular evidence for this substance-specific fact`);
  if(q.sourceTitle.startsWith('消防試験研究センター')&&q.subject==='法令')sourceTrace.push(`${q.id}: exam subject page is not direct authority for license rights`);
}

const designatedGroups=new Map();
for(const q of QUESTIONS.filter(q=>q.subject==='法令'&&q.topic==='指定数量')){
  const key=q.point;
  if(!designatedGroups.has(key))designatedGroups.set(key,[]);
  designatedGroups.get(key).push(q.id);
}
for(const group of designatedGroups.values())for(const id of group.slice(1))addPadding(id,'same designated-quantity fact rephrased');

const templateDedupe=(items,label)=>{
  const seen=new Map();
  for(const q of items){
    const key=JSON.stringify([q.point,q.detail,q.choices[q.answer]]);
    if(seen.has(key))addPadding(q.id,`${label}; same learning point as ${seen.get(key)}`); else seen.set(key,q.id);
  }
};
templateDedupe(QUESTIONS.filter(q=>q.subject==='性質・消火'&&q.topic==='安全取扱い'),'substance-name-only safety template');
templateDedupe(QUESTIONS.filter(q=>q.subject==='性質・消火'&&q.topic==='消火'&&/^S(?:0[0-5]\d|060)$/.test(q.id)),'substance-name-only extinguishing template');

if(QUESTIONS.length!==expected.total)errors.push(`total ${QUESTIONS.length} != ${expected.total}`);
for(const [s,n] of Object.entries(expected.subjects))if(counts[s]!==n)errors.push(`${s}: ${counts[s]} != ${n}`);

const conceptKeys=new Set(QUESTIONS.map(q=>JSON.stringify([q.subject,q.point,q.detail])));
const conceptExplanationExcess=QUESTIONS.length-conceptKeys.size;
if(padding.size)errors.push(`anti-padding gate: ${padding.size} clearly non-independent entries`);
if(sourceTrace.length)errors.push(`source-traceability gate: ${sourceTrace.length} entries need more granular authority`);
if(conceptExplanationExcess)warnings.push(`${conceptExplanationExcess} entries reuse an existing subject+memoryPoint+detail combination`);

const report={ok:errors.length===0,contentVersion:CONTENT_VERSION,lawAuditDate:LAW_BASELINE,currentEffectiveDates:{fireServiceAct:'2025-06-01',hazardousMaterialsCabinetOrder:'2026-04-04'},counts,total:QUESTIONS.length,errors,warnings,padding:{count:padding.size,items:[...padding.entries()].map(([id,reasons])=>({id,reasons}))},sourceTraceability:{count:sourceTrace.length,items:sourceTrace},conceptExplanationExcess,meta:QUESTION_BANK_META};
console.log(JSON.stringify(report,null,2));
if(errors.length)process.exit(1);
if(!process.argv.includes('--check')){
  fs.writeFileSync(output,JSON.stringify({contentVersion:CONTENT_VERSION,lawBaselineDate:LAW_BASELINE,questions:QUESTIONS},null,2)+'\n');
  console.log(`wrote ${path.relative(repo,output)}`);
}
