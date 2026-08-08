import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'..');
const questionsPath=path.join(repo,'kikenbutsu-otsu4-sprint','questions.js');
const fixupsPath=path.join(repo,'kikenbutsu-otsu4-sprint','question-fixups.js');
const output=path.join(repo,'kikenbutsu-otsu4-sprint','questions.generated.json');
const source=[
  fs.readFileSync(questionsPath,'utf8'),
  fs.readFileSync(fixupsPath,'utf8'),
  ';globalThis.__OTSU4={QUESTIONS,CONTENT_VERSION,LAW_BASELINE,QUESTION_BANK_META};'
].join('\n');
const context={console};
vm.createContext(context);
vm.runInContext(source,context,{filename:questionsPath,timeout:5000});
const {QUESTIONS,CONTENT_VERSION,LAW_BASELINE,QUESTION_BANK_META}=context.__OTSU4;
const errors=[];
const warnings=[];
const expected={total:360,subjects:{'法令':144,'物理・化学':96,'性質・消火':120}};
const counts={};
const ids=new Set();
const exact=new Set();
const stemCounts=new Map();
for(const q of QUESTIONS){
  counts[q.subject]=(counts[q.subject]||0)+1;
  if(ids.has(q.id))errors.push(`duplicate id ${q.id}`); ids.add(q.id);
  if(!Array.isArray(q.choices)||q.choices.length!==5)errors.push(`${q.id}: choices != 5`);
  if(new Set(q.choices||[]).size!==5)errors.push(`${q.id}: duplicate choice text`);
  if(!Number.isInteger(q.answer)||q.answer<0||q.answer>4)errors.push(`${q.id}: invalid answer index`);
  if(!q.point||!q.detail)errors.push(`${q.id}: explanation missing`);
  if(!q.sourceTitle||!q.sourceURL||!q.sourceCheckedAt)errors.push(`${q.id}: source metadata missing`);
  if(q.subject==='法令'&&!q.legalEffectiveDate)errors.push(`${q.id}: legalEffectiveDate missing`);
  const sig=JSON.stringify([q.question,q.choices,q.answer]);
  if(exact.has(sig))errors.push(`${q.id}: exact duplicate signature`); else exact.add(sig);
  const stem=q.question
    .replace(/（比較セット\d+）/g,'')
    .replace(/（反復演習\s+[A-Z]\d+）/g,'')
    .replace(/\s+/g,'');
  stemCounts.set(stem,(stemCounts.get(stem)||0)+1);
}
if(QUESTIONS.length!==expected.total)errors.push(`total ${QUESTIONS.length} != ${expected.total}`);
for(const [s,n] of Object.entries(expected.subjects))if(counts[s]!==n)errors.push(`${s}: ${counts[s]} != ${n}`);
const repeated=[...stemCounts.values()].filter(n=>n>1).length;
if(repeated)warnings.push(`${repeated} repeated-stem groups are retained as deliberate repetition variants`);
const report={ok:errors.length===0,contentVersion:CONTENT_VERSION,lawBaseline:LAW_BASELINE,counts,total:QUESTIONS.length,errors,warnings,meta:QUESTION_BANK_META};
console.log(JSON.stringify(report,null,2));
if(errors.length)process.exit(1);
if(!process.argv.includes('--check')){
  fs.writeFileSync(output,JSON.stringify({contentVersion:CONTENT_VERSION,lawBaselineDate:LAW_BASELINE,questions:QUESTIONS},null,2)+'\n');
  console.log(`wrote ${path.relative(repo,output)}`);
}
